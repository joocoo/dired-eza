;;; dired-eza-mode-test.el --- Mode tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'dired-eza-test-helper)

(ert-deftest dired-eza-font-lock-filename-boundaries ()
  (dired-eza-test--buffer
    (let ((before (buffer-string)) (keymap (current-local-map)))
      (dired-eza-mode 1)
      (font-lock-ensure)
      (should (equal (dired-eza-test--foreground "directory") "#000080"))
      (should (equal (dired-eza-test--foreground "notes.txt") "#800000"))
      (should (equal (dired-eza-test--foreground "script.txt") "#008000"))
      (should (equal (dired-eza-test--foreground "link.txt") "#008080"))
      (should-not (dired-eza-test--foreground "-> notes.txt"))
      (should (equal before (buffer-string)))
      (should (eq keymap (current-local-map)))
      (should-not (buffer-modified-p)))))

(ert-deftest dired-eza-preserves-marks-and-deletion-faces ()
  (dired-eza-test--buffer
    (goto-char (point-min)) (search-forward "notes.txt") (dired-mark 1)
    (goto-char (point-min)) (search-forward "script.txt") (dired-flag-file-deletion 1)
    (dired-eza-mode 1) (font-lock-ensure)
    (should (memq 'dired-marked (ensure-list (dired-eza-test--face "notes.txt"))))
    (should (memq 'dired-flagged (ensure-list (dired-eza-test--face "script.txt")) ))
    (should-not (dired-eza-test--foreground "notes.txt"))))

(ert-deftest dired-eza-mode-disable-and-refresh ()
  (dired-eza-test--buffer
    (dired-eza-mode 1) (dired-eza-mode 1) (font-lock-ensure)
    (should (= (cl-count (car dired-eza--keywords) font-lock-keywords :test #'equal) 1))
    (setq-local dired-eza-ls-colors "*.txt=34")
    (dired-eza-refresh) (font-lock-ensure)
    (should (equal (dired-eza-test--foreground "notes.txt") "#000080"))
    (dired-eza-mode -1) (font-lock-ensure)
    (should-not (dired-eza-test--foreground "notes.txt"))
    (should-not (member (car dired-eza--keywords) font-lock-keywords))))

(ert-deftest dired-eza-environment-inheritance ()
  (dired-eza-test--buffer
    (let ((process-environment (copy-sequence process-environment)))
      (setenv "LS_COLORS" "di=35")
      (setq-local dired-eza-ls-colors nil)
      (dired-eza-mode 1) (font-lock-ensure)
      (should (equal (dired-eza-test--foreground "directory") "#800080"))
      (setq-local dired-eza-ls-colors "")
      (dired-eza-refresh) (font-lock-ensure)
      (should (memq 'dired-eza-directory (ensure-list (dired-eza-test--face "directory")))))))

(ert-deftest dired-eza-hide-details-preserved ()
  (dired-eza-test--buffer
    (dired-hide-details-mode 1)
    (let ((spec (copy-tree buffer-invisibility-spec)))
      (dired-eza-mode 1) (font-lock-ensure)
      (should (equal spec buffer-invisibility-spec))
      (should dired-hide-details-mode)
      (should (equal (dired-eza-test--foreground "notes.txt") "#800000"))
      (dired-eza-mode -1) (font-lock-ensure)
      (should (equal spec buffer-invisibility-spec)))))

(ert-deftest dired-eza-no-io-even-with-remote-default-directory ()
  (dired-eza-test--buffer
    (setq default-directory "/ssh:unreachable.invalid:/directory/")
    ;; Native Dired can itself stat symlinks.  Isolate the mode's added work.
    (setq-local dired-check-symlinks nil)
    (let ((native-comp-enable-subr-trampolines nil))
     (cl-letf (((symbol-function 'file-attributes) (lambda (&rest _) (ert-fail "stat")))
              ((symbol-function 'file-exists-p) (lambda (&rest _) (ert-fail "exists")))
              ((symbol-function 'file-directory-p) (lambda (&rest _) (ert-fail "directory")))
              ((symbol-function 'file-symlink-p) (lambda (&rest _) (ert-fail "symlink")))
              ((symbol-function 'process-file) (lambda (&rest _) (ert-fail "process-file")))
              ((symbol-function 'call-process) (lambda (&rest _) (ert-fail "call-process")))
              ((symbol-function 'start-process) (lambda (&rest _) (ert-fail "start-process"))))
      (dired-eza-mode 1) (font-lock-ensure)
      (should (equal (dired-eza-test--foreground "notes.txt") "#800000"))
      (dired-eza-refresh) (font-lock-ensure)
      (dired-eza-mode -1) (font-lock-ensure)))))

(ert-deftest dired-eza-requires-dired ()
  (with-temp-buffer
    (should-error (dired-eza-mode 1) :type 'user-error)
    (should-not dired-eza-mode)
    (should-error (dired-eza-refresh) :type 'user-error)))

(ert-deftest dired-eza-listings-without-filename-properties ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (remove-text-properties (point-min) (point-max) '(dired-filename nil)))
    (dired-eza-mode 1) (font-lock-ensure)
    (should (equal (dired-eza-test--foreground "notes.txt") "#800000"))
    (should (equal (dired-eza-test--foreground "directory") "#000080"))
    (should (equal (dired-eza-test--foreground "link.txt") "#008080"))))

(ert-deftest dired-eza-classification-indicators-excluded ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (goto-char (point-min)) (search-forward "script.txt") (insert "*")
      (goto-char (point-min)) (search-forward "directory") (insert "/")
      (remove-text-properties (point-min) (point-max) '(dired-filename nil)))
    (setq-local dired-actual-switches "-alF")
    (setq-local dired-eza-ls-colors "*.txt=31:di=34")
    (dired-eza-mode 1) (font-lock-ensure)
    (should (equal (dired-eza-test--foreground "script.txt") "#800000"))
    (should-not (dired-eza-test--foreground "script.txt*"))
    (should-not (dired-eza-test--foreground "directory/"))))

(ert-deftest dired-eza-hidden-rows-remain-hidden ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (goto-char (point-min)) (search-forward "notes.txt")
      (put-text-property (line-beginning-position) (line-end-position) 'invisible 'dired))
    (dired-eza-mode 1) (font-lock-ensure)
    (should-not (dired-eza-test--foreground "notes.txt"))
    (goto-char (point-min)) (search-forward "notes.txt")
    (should (eq (get-text-property (1- (point)) 'invisible) 'dired))))

(ert-deftest dired-eza-multiline-and-unicode-filename ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert "  -rw-r--r-- 1 owner group 42 Oct 15 12:00 ")
      (insert (propertize "日本語\nline.txt" 'dired-filename t))
      (insert "\n"))
    (dired-eza-mode 1) (font-lock-ensure)
    (should (equal (dired-eza-test--foreground "日本語") "#800000"))
    (should (equal (dired-eza-test--foreground "line.txt") "#800000"))))

(ert-deftest dired-eza-global-keywords-unchanged ()
  (let ((original (copy-tree dired-font-lock-keywords)))
    (dired-eza-test--buffer (dired-eza-mode 1) (font-lock-ensure) (dired-eza-mode -1))
    (should (equal original dired-font-lock-keywords))))

(ert-deftest dired-eza-native-ls-lisp-and-revert ()
  (let* ((dir (make-temp-file "dired-eza-test-" t))
         (file (expand-file-name "a file.txt" dir))
         (ls-lisp-use-insert-directory-program nil)
         buffer)
    (unwind-protect
        (progn
          (write-region "test" nil file nil 'silent)
          (setq buffer (dired-noselect dir "-al"))
          (with-current-buffer buffer
            (setq-local dired-eza-ls-colors "*.txt=31")
            (dired-eza-mode 1) (font-lock-ensure)
            (should (equal (dired-eza-test--foreground "a file.txt") "#800000"))
            (revert-buffer nil t) (font-lock-ensure)
            (should dired-eza-mode)
            (should (equal (dired-eza-test--foreground "a file.txt") "#800000"))
            (goto-char (point-min)) (search-forward "a file.txt")
            (should (equal (dired-get-filename) file))))
      (when (buffer-live-p buffer) (kill-buffer buffer))
      (delete-directory dir t))))

(provide 'dired-eza-mode-test)
;;; dired-eza-mode-test.el ends here
