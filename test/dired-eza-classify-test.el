;;; dired-eza-classify-test.el --- Classify tests -*- lexical-binding: t; no-byte-compile: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'dired-eza-test-helper)

(ert-deftest dired-eza-classify-types-and-precedence ()
  (let ((colors (dired-eza-colors-parse
                 "di=34:ln=36:fi=37:ex=32:su=35:sg=33:tw=31:ow=32:st=33:*.txt=91")))
    (dolist (case '(("drwxr-xr-x" . "di") ("lrwxrwxrwx" . "ln")
                    ("prw-r--r--" . "pi") ("srwxr-xr-x" . "so")
                    ("brw-r--r--" . "bd") ("crw-r--r--" . "cd")
                    ("-rwxr-xr-x" . "ex") ("-rwsr-sr-x" . "su")
                    ("-rwSr--r--" . "su") ("-rwxr-Sr-x" . "sg")
                    ("drwxrwxrwt" . "tw") ("drwxrwxrwT" . "tw")
                    ("drwxrwxrwx" . "ow") ("drwxr-xr-t" . "st")))
      (should (equal (cdr (dired-eza-classify colors "a.txt" (car case))) (cdr case))))))

(ert-deftest dired-eza-classify-suffix-fallbacks-and-resets ()
  (let ((colors (dired-eza-colors-parse "ex=0:*.txt=31:fi=32:di=")))
    (should (equal (car (dired-eza-classify colors "x.txt" "-rwxr-xr-x"))
                   '(:foreground "#800000")))
    (should (equal (car (dired-eza-classify colors "x.txt" "drwxr-xr-x"))
                   dired-eza-colors--reset)))
  (should (equal (car (dired-eza-classify (dired-eza-colors-parse "no=33")
                                       "x" "-rw-r--r--")) '(:foreground "#808000"))))

(provide 'dired-eza-classify-test)
;;; dired-eza-classify-test.el ends here
