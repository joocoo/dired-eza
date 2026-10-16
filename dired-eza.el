;;; dired-eza.el --- eza-like colors for Emacs Dired -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; Version: 0.4.0
;; Package-Requires: ((emacs "30.1"))
;; Keywords: files, faces
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A standalone minor mode for native Dired with LS_COLORS inheritance.
;; Only Emacs built-ins are required.  This project is independent of eza.
;;
;; (use-package dired-eza
;;   :ensure t
;;   :hook (dired-mode . dired-eza-mode))
;;
;; Until published to a package archive, install from a local checkout.

;;; Code:
(require 'dired)
(require 'font-lock)
(require 'dired-eza-classify)

(defgroup dired-eza nil
  "eza-like colors for Emacs Dired."
  :group 'dired :prefix "dired-eza-")

(require 'dired-eza-permissions)
(require 'dired-eza-size)
(require 'dired-eza-metadata)
(require 'dired-eza-du)

(defcustom dired-eza-ls-colors nil
  "LS_COLORS override, or nil to inherit Emacs's environment.
An empty string uses theme fallbacks.  Use `dired-eza-refresh' after changes.
Remote buffers use this local environment too; no remote shell is queried."
  :type '(choice (const :tag "Inherit LS_COLORS" nil) string)
  :group 'dired-eza)

(defcustom dired-eza-eza-colors nil
  "EZA_COLORS override for metadata, or nil to inherit the environment.
If EZA_COLORS is unset, inherit EXA_COLORS instead.  An empty string uses
theme fallbacks.  Run `dired-eza-refresh' after changes.  Filename rules
continue to come from LS_COLORS."
  :type '(choice (const :tag "Inherit EZA_COLORS" nil) string)
  :group 'dired-eza)

(defface dired-eza-file '((t (:inherit default)))
  "Fallback for regular filenames." :group 'dired-eza)
(defface dired-eza-directory '((t (:inherit dired-directory)))
  "Fallback for directory names." :group 'dired-eza)
(defface dired-eza-symlink '((t (:inherit dired-symlink)))
  "Fallback for symbolic links." :group 'dired-eza)
(defface dired-eza-executable '((t (:inherit font-lock-function-name-face)))
  "Fallback for executable files." :group 'dired-eza)
(defface dired-eza-special '((t (:inherit font-lock-constant-face)))
  "Fallback for pipes, sockets and devices." :group 'dired-eza)

(defvar-local dired-eza--colors nil)
(defvar-local dired-eza--face nil)
(defvar-local dired-eza--permission-rules nil)
(defvar-local dired-eza--permission-face nil)
(defvar-local dired-eza--size-rules nil)
(defvar-local dired-eza--size-face nil)
(defvar-local dired-eza--metadata-rules nil)
(defvar-local dired-eza--identity nil)
(defvar-local dired-eza--metadata-face nil)
(defconst dired-eza--keywords
  '((dired-eza--match (0 dired-eza--face prepend))
    (dired-eza--match-permission (0 dired-eza--permission-face prepend))
    (dired-eza--match-size (0 dired-eza--size-face prepend))
    (dired-eza--match-metadata (0 dired-eza--metadata-face prepend)))
  "Buffer-local addition to Dired's existing font-lock rules.")

(defun dired-eza--permissions (start)
  "Read permission characters before filename START on this line."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward dired-permission-flags-regexp start t)
      (let ((pos (match-beginning 1)))
        (when (<= (+ pos 10) start)
          (buffer-substring-no-properties pos (+ pos 10)))))))

(defun dired-eza--fallback (kind)
  "Return the theme fallback face for KIND."
  (cond ((equal kind "di") 'dired-eza-directory)
        ((equal kind "ln") 'dired-eza-symlink)
        ((member kind '("ex" "su" "sg")) 'dired-eza-executable)
        ((member kind '("pi" "so" "bd" "cd")) 'dired-eza-special)
        ((member kind '("tw" "ow" "st")) 'dired-eza-directory)
        (t 'dired-eza-file)))

(defun dired-eza--match (limit)
  "Find the next unmarked filename before font-lock LIMIT.
Use Dired's own boundaries; leave marks, deletion flags, metadata,
symlink arrows, targets, and hidden-subdirectory contents to Dired."
  (catch 'found
    (while (< (point) limit)
      (let ((origin (point)) start end name permissions)
        (save-excursion
          (beginning-of-line)
          (when (and (= (char-after) ?\s)
                     (setq start (dired-move-to-filename))
                     (>= start origin) (< start limit)
                     (not (dired--hidden-p))
                     (setq permissions (dired-eza--permissions start))
                     (setq end (dired-move-to-end-of-filename t))
                     (> end start) (<= end limit))
            ;; `no-dir' decodes Dired's quoted names without stat calls.
            (goto-char start)
            (setq name (condition-case nil (dired-get-filename 'no-dir t)
                         (error nil)))))
        (when name (goto-char end))
        (forward-line 1)
        (when name
          (let* ((result (dired-eza-classify dired-eza--colors name permissions))
                 (style (car result)) (fallback (dired-eza--fallback (cdr result))))
            (setq dired-eza--face (if style (list style fallback) fallback)))
          (set-match-data (list start end))
          (throw 'found t))))
    nil))

(defun dired-eza--match-permission (limit)
  "Match one displayed permission character before font-lock LIMIT.
Recognize fields only on Dired listing rows.  Support inode/block prefixes
and optional ACL indicators, without matching permission-like filenames."
  (catch 'found
    (while (< (point) limit)
      (let ((origin (point)) start end permissions)
        (save-excursion
          (when-let* ((filename (dired-move-to-filename)))
            (unless (dired--hidden-p)
              (beginning-of-line)
              (when (re-search-forward dired-permission-flags-regexp filename t)
                (setq start (match-beginning 1) end (+ start 10))
                (when (and (< end filename) (memq (char-after end) '(?+ ?@ ?.)))
                  (setq end (1+ end)))
                (when (<= end filename)
                  (setq permissions (buffer-substring-no-properties start end)))))))
        (if (and permissions (< (max origin start) end)
                 (< (max origin start) limit))
            (let ((pos (max origin start)))
              (setq dired-eza--permission-face
                    (dired-eza-permissions-face dired-eza--permission-rules
                                                permissions (- pos start)))
              (goto-char (1+ pos))
              (set-match-data (list pos (point)))
              (throw 'found t))
          (forward-line 1))))
    nil))

(defun dired-eza--match-size (limit)
  "Match a numeric size or its unit before font-lock LIMIT."
  (catch 'found
    (while (< (point) limit)
      (let ((origin (point)) field)
        (save-excursion
          (when-let* ((filename (dired-move-to-filename))
                      ((not (dired--hidden-p))))
            (beginning-of-line)
            (when (and (re-search-forward dired-permission-flags-regexp filename t)
                       (not (memq (char-after (match-beginning 1)) '(?b ?c))))
              (setq field (dired-eza-size-field (+ (match-beginning 1) 10) filename)))))
        (if (and field (< (max origin (nth 0 field)) (nth 2 field))
                 (< (max origin (nth 0 field)) limit))
            (let* ((pos (max origin (nth 0 field)))
                   (unit (>= pos (nth 1 field)))
                   (end (min limit (nth (if unit 2 1) field))))
              (setq dired-eza--size-face
                    (dired-eza-size-face dired-eza--size-rules (nth 3 field) unit))
              (goto-char end)
              (set-match-data (list pos end))
              (throw 'found t))
          (forward-line 1))))
    nil))

(defun dired-eza--match-metadata (limit)
  "Match one enabled ownership or timestamp field before font-lock LIMIT."
  (catch 'found
    (while (< (point) limit)
      (let ((origin (point)) fields)
        (save-excursion
          (when-let* ((filename (dired-move-to-filename))
                      ((not (dired--hidden-p))))
            (beginning-of-line)
            (when (re-search-forward dired-permission-flags-regexp filename t)
              (setq fields (dired-eza-metadata-fields
                            (+ (match-beginning 1) 10) filename dired-actual-switches)))))
        (let ((field (cl-find-if
                      (lambda (f)
                        (and (> (nth 1 f) origin) (< (max origin (car f)) limit)
                             (if (eq (nth 2 f) 'date) dired-eza-color-timestamps
                               dired-eza-color-ownership))) fields)))
          (if field
              (let ((start (max origin (car field))) (end (min limit (nth 1 field))))
                (setq dired-eza--metadata-face
                      (dired-eza-metadata-face dired-eza--metadata-rules dired-eza--identity
                                               (nth 2 field) (nth 3 field)))
                (goto-char end)
                (set-match-data (list start end))
                (throw 'found t))
            (forward-line 1)))))
    nil))

;;;###autoload
(defun dired-eza-refresh ()
  "Re-read LS_COLORS and EZA_COLORS and refontify this Dired buffer."
  (interactive)
  (unless (and (derived-mode-p 'dired-mode) (bound-and-true-p dired-eza-mode))
    (user-error "Enable dired-eza-mode in a Dired buffer first"))
  (setq dired-eza--colors
        (dired-eza-colors-parse (or dired-eza-ls-colors (getenv "LS_COLORS"))))
  (let ((eza (or dired-eza-eza-colors (getenv "EZA_COLORS") (getenv "EXA_COLORS"))))
    (setq dired-eza--permission-rules (dired-eza-permissions-parse eza)
          dired-eza--size-rules (dired-eza-size-parse eza)
          dired-eza--metadata-rules (dired-eza-metadata-parse eza)))
  (setq dired-eza--identity
        (and dired-eza-color-ownership
             (dired-eza-metadata-identity (file-remote-p default-directory))))
  (font-lock-flush))

;;;###autoload
(define-minor-mode dired-eza-mode
  "Color native Dired filenames, permissions, sizes, ownership and dates.
Inherit LS_COLORS for names and EZA_COLORS for metadata, with theme
fallbacks.
Only font-lock rules are added.  No listing commands, file handlers,
invisibility properties, key bindings, or global Dired settings change."
  :lighter " Eza" :group 'dired-eza
  (cond
   ((not (derived-mode-p 'dired-mode))
    (setq dired-eza-mode nil)
    (user-error "dired-eza-mode requires Dired"))
   (dired-eza-mode
    ;; Remove first so repeated positive enables are idempotent.
    (font-lock-remove-keywords nil dired-eza--keywords)
    (font-lock-add-keywords nil dired-eza--keywords 'append)
    (dired-eza-refresh))
   (t
    (font-lock-remove-keywords nil dired-eza--keywords)
    (setq dired-eza--colors nil dired-eza--face nil
          dired-eza--permission-rules nil dired-eza--permission-face nil
          dired-eza--size-rules nil dired-eza--size-face nil
          dired-eza--metadata-rules nil dired-eza--metadata-face nil
          dired-eza--identity nil)
    (font-lock-flush))))

(provide 'dired-eza)
;;; dired-eza.el ends here
