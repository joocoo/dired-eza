;;; dired-eza-permissions-test.el --- Permissions tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'dired-eza-test-helper)

(ert-deftest dired-eza-permissions-parse-separate-namespace ()
  (let ((rules (dired-eza-permissions-parse "ur=31:ur=32:ur=bad:tw=33:su=34:di=35:*.el=36")))
    (should (= (length rules) 3))
    (should (equal (cdr (assoc "ur" rules)) '(:foreground "#008000")))
    (should-not (assoc "di" rules)))
  (should (equal (cdr (assoc "ur" (dired-eza-permissions-parse "ur=")))
                 dired-eza-colors--reset))
  (let ((rules (dired-eza-permissions-parse "ur=31:reset:uw=32")))
    (should (equal (cdr (assoc "ur" rules)) dired-eza-colors--reset))
    (should (equal (cdr (assoc "uw" rules)) '(:foreground "#008000")))))

(ert-deftest dired-eza-permissions-nine-independent-bits ()
  (let* ((keys '("ur" "uw" "ux" "gr" "gw" "gx" "tr" "tw" "tx"))
         (rules (cl-loop for key in keys for n from 1
                         collect (cons key (list :foreground (format "color%d" n))))))
    (cl-loop for index from 1 to 9 do
             (should (equal (plist-get (car (dired-eza-permissions-face rules "-rwxrwxrwx" index))
                                       :foreground)
                            (format "color%d" index))))
    (should (eq (dired-eza-permissions-face rules "drwxrwxrwx" 3)
                'dired-eza-permission-execute))
    (push '("ue" . (:foreground "other")) rules)
    (should (equal (car (dired-eza-permissions-face rules "drwxrwxrwx" 3))
                   '(:foreground "other")))))

(ert-deftest dired-eza-permissions-special-and-absent-bits ()
  (let ((rules (dired-eza-permissions-parse "su=31:sf=32:xx=33:xa=34")))
    (dolist (index '(3 6 9))
      (should (equal (car (dired-eza-permissions-face rules "-rwSrwSrwT" index))
                     '(:foreground "#800000")))
      (should (equal (car (dired-eza-permissions-face rules "drwsrwsrwt" index))
                     '(:foreground "#008000"))))
    (should (equal (car (dired-eza-permissions-face rules "----------" 7))
                   '(:foreground "#808000")))
    (should (equal (car (dired-eza-permissions-face rules "-rwxrwxrwx+" 10))
                   '(:foreground "#000080")))))

(ert-deftest dired-eza-permissions-theme-fallbacks ()
  (should (eq (dired-eza-permissions-face nil "-rwxr-xr-x" 1) 'dired-eza-permission-read))
  (should (eq (dired-eza-permissions-face nil "-rwxr-xr-x" 2) 'dired-eza-permission-write))
  (should (eq (dired-eza-permissions-face nil "-rwxr-xr-x" 3) 'dired-eza-permission-execute))
  (should (eq (dired-eza-permissions-face nil "-rwxr-xr-x" 5) 'dired-eza-permission-missing)))

(ert-deftest dired-eza-permissions-native-font-lock-and-disable ()
  (dired-eza-test--buffer
    (setq-local dired-eza-eza-colors "ur=31:uw=32:ux=33:xx=34")
    (dired-eza-mode 1) (font-lock-ensure)
    (cl-loop for index in '(1 2 3 5)
             for color in '("#800000" "#008000" "#808000" "#000080") do
             (should (equal (plist-get (car (dired-eza-test--permission-face "script.txt" index))
                                       :foreground) color)))
    (should (equal (dired-eza-test--foreground "script.txt") "#008000"))
    (dired-eza-mode -1) (font-lock-ensure)
    (should-not (dired-eza-test--permission-face "script.txt" 1))))

(ert-deftest dired-eza-permissions-attribute-and-prefixes ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert "  1234 8 -rwxrwxrwx@ 1 owner group 42 Oct 15 12:00 ")
      (insert (propertize "prefixed" 'dired-filename t))
      (insert "\n"))
    (setq-local dired-eza-eza-colors "xa=35:ur=31")
    (dired-eza-mode 1) (font-lock-ensure)
    (goto-char (point-min)) (search-forward "-rwxrwxrwx@")
    (should (equal (plist-get (car (get-text-property (1- (point)) 'face)) :foreground)
                   "#800080"))
    (search-backward "1234")
    (should-not (get-text-property (point) 'face))))

(ert-deftest dired-eza-permissions-preserve-hide-details-and-marks ()
  (dired-eza-test--buffer
    (goto-char (point-min)) (search-forward "notes.txt") (dired-mark 1)
    (let ((inhibit-read-only t))
      (dired-insert-set-properties (point-min) (point-max)))
    (dired-hide-details-mode 1)
    (dired-eza-mode 1) (font-lock-ensure)
    (should (memq 'dired-eza-permission-read
                  (ensure-list (dired-eza-test--permission-face "notes.txt" 1))))
    (should (memq 'dired-marked (ensure-list (dired-eza-test--face "notes.txt"))))
    (goto-char (point-min)) (search-forward "notes.txt") (beginning-of-line) (forward-char 3)
    (should (invisible-p (point)))))

(ert-deftest dired-eza-permissions-do-not-match-filename-text ()
  (dired-eza-test--buffer
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert "  -rw-r--r-- 1 owner group 42 Oct 15 12:00 ")
      (insert (propertize "-rwxrwxrwx.txt" 'dired-filename t))
      (insert "\n"))
    (dired-eza-mode 1) (font-lock-ensure)
    (should (equal (dired-eza-test--foreground "-rwxrwxrwx.txt") "#800000"))))

(ert-deftest dired-eza-permissions-environment-and-refresh ()
  (dired-eza-test--buffer
    (let ((process-environment (copy-sequence process-environment)))
      (setq-local dired-eza-eza-colors nil)
      (setenv "EZA_COLORS" nil) (setenv "EXA_COLORS" "ur=31")
      (dired-eza-mode 1)
      (should (equal (cdr (assoc "ur" dired-eza--permission-rules)) '(:foreground "#800000")))
      (setenv "EZA_COLORS" "") (dired-eza-refresh)
      (should-not dired-eza--permission-rules)
      (setenv "EZA_COLORS" "ur=32") (dired-eza-refresh)
      (should (equal (cdr (assoc "ur" dired-eza--permission-rules)) '(:foreground "#008000")))
      (setq-local dired-eza-eza-colors "ur=34") (dired-eza-refresh)
      (should (equal (cdr (assoc "ur" dired-eza--permission-rules)) '(:foreground "#000080"))))))

(provide 'dired-eza-permissions-test)
;;; dired-eza-permissions-test.el ends here
