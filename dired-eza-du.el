;;; dired-eza-du.el --- Cached background directory disk usage -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Opt-in disk usage for local Dired buffers.  A single asynchronous worker
;; shares a persistent cache across buffers.  Listing text is never changed.

;;; Code:
(require 'cl-lib)
(require 'dired)
(require 'dired-eza-size)

(defcustom dired-eza-du-cache-file
  (expand-file-name "cache/dired-eza-du.eld" user-emacs-directory)
  "Local file holding cached disk usage, or nil for memory-only caching."
  :type '(choice (const nil) file) :group 'dired-eza)

(defcustom dired-eza-du-cache-ttl 600
  "Seconds before a cached size is refreshed on the next directory visit.
Stale sizes remain visible during refresh.  Descendant changes are not
watched; use `dired-eza-du-refresh' to force recalculation."
  :type 'natnum :group 'dired-eza)

(defcustom dired-eza-du-program "du"
  "Local du executable supporting -sk (GNU and BSD/macOS du).
Output is interpreted as allocated 1024-byte blocks, not apparent bytes.
There is no Lisp fallback when this program is unavailable."
  :type 'string :group 'dired-eza)

(defvar dired-eza-du--cache (make-hash-table :test #'equal))
(defvar dired-eza-du--failures (make-hash-table :test #'equal))
(defvar dired-eza-du--loaded nil)
(defvar dired-eza-du--dirty nil)
(defvar dired-eza-du--save-timer nil)
(defvar dired-eza-du--queue nil)
(defvar dired-eza-du--pending (make-hash-table :test #'equal))
(defvar dired-eza-du--process nil)
(defvar-local dired-eza-du--overlays nil)
(defvar-local dired-eza-du--width 10)
(defvar-local dired-eza-du--suspended nil)
(defvar dired-eza--size-rules)
(defvar dired-eza-du-mode)

(defun dired-eza-du--load ()
  "Load validated cache data once, without evaluating its contents."
  (unless dired-eza-du--loaded
    (setq dired-eza-du--loaded t)
    (when (and dired-eza-du-cache-file
               (not (file-remote-p dired-eza-du-cache-file)))
      (condition-case nil
          (with-temp-buffer
            ;; Bound input size and reject truncated or malformed data.
            (insert-file-contents dired-eza-du-cache-file nil 0 (* 4 1024 1024))
            (let* ((read-circle nil)
                   (data (read (current-buffer))))
              (skip-chars-forward " \t\r\n")
              (when (and (eobp) (listp data) (eq (car data) 1))
                (dolist (entry (cdr data))
                  (when (and (listp entry) (= (length entry) 3)
                             (stringp (nth 0 entry))
                             (file-name-absolute-p (nth 0 entry))
                             (not (file-remote-p (nth 0 entry)))
                             (numberp (nth 1 entry))
                             (>= (nth 1 entry) 0)
                             (integerp (nth 2 entry)) (>= (nth 2 entry) 0))
                    (puthash (car entry) (cdr entry) dired-eza-du--cache))))))
        (error nil)))))

(defun dired-eza-du--save ()
  "Atomically save successful entries; failures remain session-local."
  (when dired-eza-du--save-timer
    (cancel-timer dired-eza-du--save-timer)
    (setq dired-eza-du--save-timer nil))
  (when (and dired-eza-du--dirty dired-eza-du-cache-file
             (not (file-remote-p dired-eza-du-cache-file)))
    (let (temporary)
      (unwind-protect
          (condition-case err
              (let ((directory (file-name-directory
                                (expand-file-name dired-eza-du-cache-file)))
                    entries)
                (make-directory directory t)
                (maphash (lambda (path value)
                           (when (and (integerp (cadr value))
                                      (< (- (float-time) (car value)) 604800))
                             (push (cons path value) entries)))
                         dired-eza-du--cache)
                (setq temporary (make-temp-file (expand-file-name ".dired-eza-du-" directory)))
                (with-temp-file temporary
                  (let ((print-length nil) (print-level nil))
                    (prin1 (cons 1 entries) (current-buffer))))
                (rename-file temporary dired-eza-du-cache-file t)
                (setq dired-eza-du--dirty nil))
            (error (message "dired-eza cache: %s" (error-message-string err))))
        (when (and temporary (file-exists-p temporary)) (delete-file temporary))))))

(defun dired-eza-du--store (path bytes)
  "Cache BYTES for PATH, or a failure when BYTES is nil."
  (if bytes
      (progn
        (remhash path dired-eza-du--failures)
        (puthash path (list (float-time) bytes) dired-eza-du--cache))
    (puthash path (float-time) dired-eza-du--failures)
    ;; Keep the original measurement date when a refresh fails.
    (unless (cadr (gethash path dired-eza-du--cache))
      (puthash path (list (float-time) nil) dired-eza-du--cache)))
  (setq dired-eza-du--dirty t)
  (unless dired-eza-du--save-timer
    (setq dired-eza-du--save-timer (run-with-idle-timer 1 nil #'dired-eza-du--save))))

(defun dired-eza-du--clear ()
  "Remove this buffer's size overlays, preserving the underlying listing."
  (mapc #'delete-overlay dired-eza-du--overlays)
  (setq dired-eza-du--overlays nil))

(defun dired-eza-du--style (text category)
  "Return TEXT with numeric and unit colors for CATEGORY."
  (let ((display (copy-sequence text))
        (rules (and (boundp 'dired-eza--size-rules) dired-eza--size-rules)))
    (when (string-match "\\`[0-9.,]+" display)
      (let ((end (match-end 0)))
        (put-text-property 0 end 'face (dired-eza-size-face rules category) display)
        (put-text-property end (length display) 'face
                           (dired-eza-size-face rules category t) display)))
    display))

(defun dired-eza-du--paint (overlay text &optional bytes)
  "Display TEXT in OVERLAY, using size colors for BYTES when available."
  (overlay-put overlay 'dired-eza-du-text text)
  (overlay-put overlay 'dired-eza-du-bytes bytes)
  (let ((width (max dired-eza-du--width (1+ (string-width text))
                    (- (overlay-end overlay) (overlay-start overlay)))))
    (if (> width dired-eza-du--width)
        (progn
          (setq dired-eza-du--width width)
          (dolist (row dired-eza-du--overlays)
            (dired-eza-du--paint row (or (overlay-get row 'dired-eza-du-text) "")
                                 (overlay-get row 'dired-eza-du-bytes))))
      (let ((display (if bytes
                         (dired-eza-du--style
                          text (dired-eza-size-category (number-to-string bytes) nil))
                       text)))
        (overlay-put overlay 'display
                     (concat (make-string (- width (string-width text)) ?\s) display))))))

(defun dired-eza-du--show (overlay path)
  "Show cached disk usage for PATH in OVERLAY, including stale values."
  (let* ((entry (gethash path dired-eza-du--cache))
         (bytes (cadr entry))
         (pending (gethash path dired-eza-du--pending))
         (stale (and entry (> (- (float-time) (car entry)) dired-eza-du-cache-ttl))))
    (dired-eza-du--paint overlay
                         (cond (bytes (file-size-human-readable bytes 'iec))
                               (pending "…") (entry "?") (t "—"))
                         bytes)
    (overlay-put overlay 'help-echo
                 (format "Recursive disk usage%s%s; M-x dired-eza-du-refresh to rescan"
                         (if entry (format ", measured %s"
                                           (format-time-string "%H:%M" (seconds-to-time (car entry)))) "")
                         (cond (pending ", refreshing")
                               ((gethash path dired-eza-du--failures) ", scan failed")
                               (stale ", stale") (t ""))))))

(defun dired-eza-du--notify (path)
  "Update live overlays for PATH without retaining dead buffers."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and dired-eza-du-mode (eq major-mode 'dired-mode))
        (dolist (overlay dired-eza-du--overlays)
          (when (equal (overlay-get overlay 'dired-eza-du-path) path)
            (dired-eza-du--show overlay path)))))))

(defun dired-eza-du--next ()
  "Run one queued local scan, sharing work across every Dired buffer."
  (unless dired-eza-du--process
    (when-let* ((path (pop dired-eza-du--queue)))
      (let ((output (generate-new-buffer " *dired-eza-du*"))
            ;; A sentinel can start the next job while a TRAMP buffer is current.
            (default-directory temporary-file-directory))
        (condition-case nil
            (setq dired-eza-du--process
                  (make-process
                   :name "dired-eza-du" :buffer output :noquery t
                   :connection-type 'pipe :command (list dired-eza-du-program "-sk" path)
                   :sentinel
                   (lambda (process _event)
                     (when (memq (process-status process) '(exit signal))
                       (when (eq process dired-eza-du--process)
                         (setq dired-eza-du--process nil)
                         (let ((bytes
                                (when (and (eq (process-status process) 'exit)
                                           (= (process-exit-status process) 0)
                                           (buffer-live-p output))
                                  (with-current-buffer output
                                    (goto-char (point-min))
                                    (when (looking-at "\\([0-9]+\\)[\t ]")
                                      (* 1024 (string-to-number (match-string 1))))))))
                           (dired-eza-du--store path bytes))
                         (remhash path dired-eza-du--pending)
                         (dired-eza-du--notify path))
                       (when (buffer-live-p output) (kill-buffer output))
                       (dired-eza-du--next)))))
          (error
           (kill-buffer output)
           (remhash path dired-eza-du--pending)
           (dired-eza-du--store path nil)
           (dired-eza-du--notify path)
           (dired-eza-du--next)))))))

(defun dired-eza-du--enqueue (path)
  "Queue PATH once, never passing remote paths to a subprocess."
  (unless (or (file-remote-p path) (gethash path dired-eza-du--pending))
    (puthash path t dired-eza-du--pending)
    (setq dired-eza-du--queue (nconc dired-eza-du--queue (list path)))))

(defun dired-eza-du--render (&optional force)
  "Render shared-width size fields, queuing missing or stale sizes.
With FORCE, queue every eligible directory.  Never scan . or .. entries."
  (dired-eza-du--clear)
  (when (and dired-eza-du-mode (eq major-mode 'dired-mode)
             (not (file-remote-p default-directory)))
    (dired-eza-du--load)
    (setq dired-eza-du--width 10)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let (permissions filename field)
          (when (and (setq filename (dired-move-to-filename))
                     (save-excursion
                       (beginning-of-line)
                       (when (re-search-forward dired-permission-flags-regexp filename t)
                         (setq permissions (match-beginning 1))))
                     (not (memq (char-after permissions) '(?b ?c)))
                     (setq field (dired-eza-size-field (+ permissions 10) filename)))
            (let* ((text (buffer-substring (nth 0 field) (nth 2 field)))
                   (start (save-excursion
                            (goto-char (nth 0 field))
                            (skip-chars-backward " \t" (+ permissions 10)) (point)))
                   (overlay (make-overlay start (nth 2 field)))
                   (name (dired-get-filename 'no-dir t))
                   (path (and (eq (char-after permissions) ?d)
                              name (not (member name '("." "..")))
                              (dired-get-filename nil t))))
              ;; Replacement strings inherit hide-details and hidden-row state.
              (overlay-put overlay 'evaporate t)
              (push overlay dired-eza-du--overlays)
              (if (and path (not (file-remote-p path)))
                  (let ((entry (gethash path dired-eza-du--cache)))
                    (overlay-put overlay 'dired-eza-du-path path)
                    (when (or force
                              (and (or (null entry)
                                       (> (- (float-time) (car entry)) dired-eza-du-cache-ttl))
                                   (> (- (float-time)
                                         (gethash path dired-eza-du--failures 0))
                                      dired-eza-du-cache-ttl)))
                      (dired-eza-du--enqueue path))
                    (dired-eza-du--show overlay path))
                (dired-eza-du--paint overlay (dired-eza-du--style text (nth 3 field)))))))
        (forward-line 1)))
    (dired-eza-du--next)))

;;;###autoload
(defun dired-eza-du-refresh ()
  "Recalculate local directory disk usage without blocking Dired.
Previously cached values remain visible until new results arrive."
  (interactive)
  (unless (and dired-eza-du-mode (eq major-mode 'dired-mode)
               (not (file-remote-p default-directory)))
    (user-error "Enable dired-eza-du-mode in a local Dired buffer first"))
  (dired-eza-du--render t))

(defun dired-eza-du--suspend ()
  "Remove size displays during WDired edits."
  (setq dired-eza-du--suspended t)
  (dired-eza-du--clear))

(defun dired-eza-du--resume ()
  "Restore size displays after WDired returns to Dired."
  (when (and dired-eza-du--suspended (eq major-mode 'dired-mode))
    (setq dired-eza-du--suspended nil)
    (dired-eza-du--render)))

;;;###autoload
(define-minor-mode dired-eza-du-mode
  "Show cached recursive disk usage in local Dired size columns.
One background du worker fills a persistent cache shared by all buffers.
Cached sizes expire after `dired-eza-du-cache-ttl' seconds; they remain
visible while refreshed.  Symlinks, dot entries, and TRAMP are not scanned.
Scanning continues after leaving a buffer so revisits can use its results.
Underlying listing text and Dired's native sorting remain unchanged."
  :lighter " Eza-du" :group 'dired-eza
  (when (and dired-eza-du-mode
             (or (not (derived-mode-p 'dired-mode))
                 (file-remote-p default-directory)))
    (setq dired-eza-du-mode nil))
  (dired-eza-du--clear)
  (dolist (pair '((dired-before-readin-hook . dired-eza-du--clear)
                  (dired-after-readin-hook . dired-eza-du--render)
                  (kill-buffer-hook . dired-eza-du--clear)
                  (change-major-mode-hook . dired-eza-du--clear)
                  (wdired-mode-hook . dired-eza-du--suspend)
                  (post-command-hook . dired-eza-du--resume)))
    (remove-hook (car pair) (cdr pair) t)
    (when dired-eza-du-mode (add-hook (car pair) (cdr pair) nil t)))
  (setq dired-eza-du--suspended nil)
  (when dired-eza-du-mode (dired-eza-du--render)))

(add-hook 'kill-emacs-hook #'dired-eza-du--save)

(provide 'dired-eza-du)
;;; dired-eza-du.el ends here
