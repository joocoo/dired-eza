;;; dired-eza-du-test.el --- Cached disk usage tests -*- lexical-binding: t; no-byte-compile: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
(require 'dired-eza-test-helper)
(require 'wdired)

(defmacro dired-eza-du-test--isolated (&rest body)
  (declare (indent 0) (debug t))
  `(let ((native-comp-enable-subr-trampolines nil)
         (dired-eza-du--cache (make-hash-table :test #'equal))
         (dired-eza-du--failures (make-hash-table :test #'equal))
         (dired-eza-du--pending (make-hash-table :test #'equal))
         (dired-eza-du--loaded nil) (dired-eza-du--dirty nil)
         (dired-eza-du--queue nil) (dired-eza-du--process nil)
         (dired-eza-du--save-timer nil) (dired-eza-du-cache-file nil))
     (unwind-protect (progn ,@body)
       (when dired-eza-du--process
         (set-process-sentinel dired-eza-du--process #'ignore)
         (let ((output (process-buffer dired-eza-du--process)))
           (when (process-live-p dired-eza-du--process)
             (delete-process dired-eza-du--process))
           (when (buffer-live-p output) (kill-buffer output))))
       (when dired-eza-du--save-timer (cancel-timer dired-eza-du--save-timer)))))

(defmacro dired-eza-du-test--listing (&rest body)
  (declare (indent 0) (debug t))
  `(let ((default-directory "/fixture/"))
     (dired-eza-test--buffer
       (setq-local dired-check-symlinks nil)
       ,@body)))

(defun dired-eza-du-test--wait ()
  (let ((deadline (+ (float-time) 10)))
    (while (and dired-eza-du--process (< (float-time) deadline))
      (accept-process-output nil 0.02))
    (should-not dired-eza-du--process)
    (should-not dired-eza-du--queue)))

(defun dired-eza-du-test--columns ()
  (mapcar (lambda (overlay)
            (save-excursion
              (goto-char (overlay-start overlay))
              (let ((start (line-beginning-position))
                    (filename (dired-move-to-filename)))
                (string-width
                 (concat (buffer-substring-no-properties start (overlay-start overlay))
                         (overlay-get overlay 'display)
                         (buffer-substring-no-properties (overlay-end overlay) filename))))))
          dired-eza-du--overlays))

(ert-deftest dired-eza-du-cached-listing-needs-no-scan ()
  (dired-eza-du-test--isolated
    (puthash "/fixture/directory" (list (float-time) 1234567890) dired-eza-du--cache)
    (dired-eza-du-test--listing
      (let ((before (buffer-string)) (position (point)))
        (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "unexpected scan"))))
          (dired-eza-du-mode 1)
          (should (equal before (buffer-string)))
          (should (= position (point)))
          (should-not (buffer-modified-p))
          (should (apply #'= (dired-eza-du-test--columns)))
          (should (cl-some (lambda (overlay)
                             (equal (string-trim (overlay-get overlay 'display)) "1.1GiB"))
                           dired-eza-du--overlays))
          (dired-eza-du-mode 1)
          (should (= (length dired-eza-du--overlays) 4))
          (dired-eza-du-mode -1)
          (should-not dired-eza-du--overlays)
          (should-not (memq #'dired-eza-du--render dired-after-readin-hook)))))))

(ert-deftest dired-eza-du-stale-values-visible-and-deduplicated ()
  (dired-eza-du-test--isolated
    (puthash "/fixture/directory" '(0 4096) dired-eza-du--cache)
    ;; Keep the worker idle so we can inspect scheduling deterministically.
    (cl-letf (((symbol-function 'dired-eza-du--next) #'ignore))
      (dired-eza-du-test--listing
        (dired-eza-du-mode 1)
        (should (equal dired-eza-du--queue '("/fixture/directory")))
        (should (cl-some (lambda (overlay)
                           (equal (string-trim (overlay-get overlay 'display)) "4KiB"))
                         dired-eza-du--overlays))
        (dired-eza-du--render)
        (should (= (length dired-eza-du--queue) 1))
        (dired-eza-du-mode -1)))))

(ert-deftest dired-eza-du-tramp-does-not-load-cache-or-start-processes ()
  (dired-eza-du-test--isolated
    (dired-eza-du-test--listing
      (setq default-directory "/ssh:unreachable.invalid:/fixture/")
      (cl-letf (((symbol-function 'dired-eza-du--load) (lambda () (ert-fail "cache IO")))
                ((symbol-function 'make-process) (lambda (&rest _) (ert-fail "process"))))
        (dired-eza-du-mode 1)
        (should-not dired-eza-du-mode)
        (should-not dired-eza-du--overlays)
        (dired-eza-du--enqueue "/ssh:unreachable.invalid:/fixture/directory")
        (should-not dired-eza-du--queue)))))

(ert-deftest dired-eza-du-cache-survives-buffer-and-session ()
  (dired-eza-du-test--isolated
    (let* ((root (make-temp-file "dired-eza-cache-" t))
           (dired-eza-du-cache-file (expand-file-name "sub/cache.eld" root)))
      (unwind-protect
          (progn
            (dired-eza-du--store "/fixture/directory" 8192)
            (dired-eza-du--save)
            (setq dired-eza-du--cache (make-hash-table :test #'equal)
                  dired-eza-du--loaded nil)
            (dired-eza-du--load)
            (should (= (cadr (gethash "/fixture/directory" dired-eza-du--cache)) 8192))
            (dotimes (_ 2)
              (dired-eza-du-test--listing
                (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "scan after revisit"))))
                  (dired-eza-du-mode 1))))
            (with-temp-file dired-eza-du-cache-file (insert "(invalid . cache)"))
            (setq dired-eza-du--loaded nil)
            (dired-eza-du--load)
            (should (= (cadr (gethash "/fixture/directory" dired-eza-du--cache)) 8192)))
        (delete-directory root t)))))

(ert-deftest dired-eza-du-hide-details-and-wdired ()
  (dired-eza-du-test--isolated
    (puthash "/fixture/directory" (list (float-time) 1234) dired-eza-du--cache)
    (dired-eza-du-test--listing
      (let ((inhibit-read-only t))
        (dired-insert-set-properties (point-min) (point-max)))
      (dired-hide-details-mode 1)
      (let ((spec (copy-tree buffer-invisibility-spec)))
        (dired-eza-du-mode 1)
        (should (equal spec buffer-invisibility-spec))
        (font-lock-ensure)
        (dolist (overlay dired-eza-du--overlays)
          (should (invisible-p (overlay-start overlay))))
        (wdired-change-to-wdired-mode)
        (should-not dired-eza-du--overlays)
        (wdired-abort-changes)
        (dired-eza-du--resume)
        (should dired-eza-du--overlays)
        (should dired-hide-details-mode)))))

(ert-deftest dired-eza-du-native-scan-unusual-names-and-column-stability ()
  (skip-unless (executable-find "du"))
  (dired-eza-du-test--isolated
    (let ((root (make-temp-file "dired-eza-scan-" t)) buffer)
      (unwind-protect
          (progn
            (dolist (name '("normal" "space and\nnewline" "-dash"))
              (make-directory (expand-file-name (concat name "/nested") root) t)
              (write-region (make-string 8192 ?x) nil
                            (expand-file-name (concat name "/nested/data") root) nil 'silent))
            (make-symbolic-link (expand-file-name "normal" root) (expand-file-name "link" root))
            (setq buffer (dired-noselect root "-alhb"))
            (with-current-buffer buffer
              (dired-eza-mode 1)
              (dired-eza-du-mode 1)
              (should (processp dired-eza-du--process))
              (should (= (hash-table-count dired-eza-du--pending) 3))
              (let ((columns (dired-eza-du-test--columns)) (before (buffer-string)))
                (should (apply #'= columns))
                (dired-eza-du-test--wait)
                (should (equal columns (dired-eza-du-test--columns)))
                (should (equal before (buffer-string)))
                (should-not (buffer-modified-p))
                (should (= (hash-table-count dired-eza-du--cache) 3))
                (dolist (overlay dired-eza-du--overlays)
                  (when-let* ((path (overlay-get overlay 'dired-eza-du-path)))
                    (let ((expected (with-temp-buffer
                                      (should (= (call-process "du" nil t nil "-sk" path) 0))
                                      (goto-char (point-min))
                                      (should (looking-at "[0-9]+"))
                                      (* 1024 (string-to-number (match-string 0))))))
                      (should (= (cadr (gethash path dired-eza-du--cache)) expected)))))
                (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "scan on fresh revert"))))
                  (revert-buffer nil t))
                (dired-eza-du-refresh)
                (should (processp dired-eza-du--process))
                (dired-eza-du-test--wait))))
        (when (buffer-live-p buffer) (kill-buffer buffer))
        (delete-directory root t)))))

(ert-deftest dired-eza-du-failed-process-is-throttled ()
  (dired-eza-du-test--isolated
    (let ((dired-eza-du-program "dired-eza-nonexistent-command"))
      (dired-eza-du-test--listing
        (dired-eza-du-mode 1)
        (dired-eza-du-test--wait)
        (should (gethash "/fixture/directory" dired-eza-du--cache))
        (should-not (cadr (gethash "/fixture/directory" dired-eza-du--cache)))
        (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "immediate retry"))))
          (dired-eza-du--render))))))

(ert-deftest dired-eza-du-failed-refresh-preserves-measurement-date ()
  (dired-eza-du-test--isolated
    (puthash "/fixture/directory" '(1234 8192) dired-eza-du--cache)
    (dired-eza-du--store "/fixture/directory" nil)
    (should (equal (gethash "/fixture/directory" dired-eza-du--cache) '(1234 8192)))
    (dired-eza-du-test--listing
      (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "retry during cooldown"))))
        (dired-eza-du-mode 1)
        (should-not dired-eza-du--queue)))
    (dired-eza-du--store "/fixture/directory" 16384)
    (should-not (gethash "/fixture/directory" dired-eza-du--failures))
    (should (= (cadr (gethash "/fixture/directory" dired-eza-du--cache)) 16384))))

(ert-deftest dired-eza-du-retains-numeric-and-unit-colors ()
  (dired-eza-du-test--isolated
    (puthash "/fixture/directory" (list (float-time) 8192) dired-eza-du--cache)
    (dired-eza-du-test--listing
      (setq-local dired-eza-eza-colors "sn=31:sb=32")
      (dired-eza-mode 1)
      (dired-eza-du-mode 1)
      (dolist (overlay dired-eza-du--overlays)
        (let* ((display (overlay-get overlay 'display))
               (number (string-match "[0-9]" display)))
          (should (member '(:foreground "#800000")
                          (get-text-property number 'face display)))
          (when (overlay-get overlay 'dired-eza-du-path)
            (should (member '(:foreground "#008000")
                            (get-text-property (1- (length display)) 'face display)))))))))

(ert-deftest dired-eza-du-one-worker-survives-buffer-destruction ()
  (skip-unless (executable-find "du"))
  (dired-eza-du-test--isolated
    (let ((root (make-temp-file "dired-eza-leave-" t)) buffer)
      (unwind-protect
          (progn
            (make-directory (expand-file-name "child" root))
            (setq buffer (dired-noselect root "-alh"))
            (with-current-buffer buffer (dired-eza-du-mode 1))
            (let ((process dired-eza-du--process))
              (kill-buffer buffer)
              (should (eq process dired-eza-du--process))
              (dired-eza-du-test--wait)
              (should (integerp (cadr (gethash (expand-file-name "child" root)
                                              dired-eza-du--cache)))))
            (setq buffer (dired-noselect root "-alh"))
            (with-current-buffer buffer
              (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (ert-fail "rescan on revisit"))))
                (dired-eza-du-mode 1))))
        (when (buffer-live-p buffer) (kill-buffer buffer))
        (delete-directory root t)))))

(provide 'dired-eza-du-test)
;;; dired-eza-du-test.el ends here
