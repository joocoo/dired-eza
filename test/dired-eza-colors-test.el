;;; dired-eza-colors-test.el --- Colors tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'dired-eza-test-helper)

(ert-deftest dired-eza-colors-empty-and-duplicates ()
  (should-not (dired-eza-colors-types (dired-eza-colors-parse nil)))
  (should (equal (dired-eza-test--style ":di=31:di=34:di=bad::" "di")
                 '(:foreground "#000080")))
  (should (equal (dired-eza-test--style "di=" "di") dired-eza-colors--reset)))

(ert-deftest dired-eza-colors-escaped-delimiters ()
  (let ((colors (dired-eza-colors-parse "*a\\:b=31:*c\\=d=32:*e\\\\f=34")))
    (should (equal (dired-eza-colors-suffix colors "za:b") '(:foreground "#800000")))
    (should (equal (dired-eza-colors-suffix colors "zc=d") '(:foreground "#008000")))
    (should (equal (dired-eza-colors-suffix colors "ze\\f") '(:foreground "#000080")))))

(ert-deftest dired-eza-colors-numeric-and-control-escapes ()
  (should (equal (dired-eza-colors--unescape "a\\072b\\x3d!") "a:b=!"))
  (should (equal (dired-eza-colors--unescape "^A\\e\\_\\?") (string 1 27 32 127)))
  (should-not (dired-eza-colors--unescape "bad\\"))
  (should-not (dired-eza-colors--unescape "bad^"))
  (should-not (dired-eza-colors--unescape "bad\\x")))

(ert-deftest dired-eza-colors-suffix-order-and-literal-semantics ()
  (let ((colors (dired-eza-colors-parse "*.tar.gz=31:*.gz=32:*a?b=34")))
    (should (equal (dired-eza-colors-suffix colors "x.tar.gz") '(:foreground "#008000")))
    (should-not (dired-eza-colors-suffix colors "xaab"))
    (should (dired-eza-colors-suffix colors "xa?b"))))

(ert-deftest dired-eza-colors-suffix-case-collisions ()
  (should (dired-eza-colors-suffix (dired-eza-colors-parse "*.jpg=31") "X.JPG"))
  (let ((colors (dired-eza-colors-parse "*.jpg=31:*.JPG=32")))
    (should (equal (dired-eza-colors-suffix colors "x.JPG") '(:foreground "#008000")))
    (should-not (dired-eza-colors-suffix colors "x.Jpg")))
  (should (dired-eza-colors-suffix
           (dired-eza-colors-parse "*.jpg=31:*.JPG=32:*.jpg=32") "x.Jpg")))

(ert-deftest dired-eza-colors-sgr-palette ()
  (should (equal (dired-eza-colors-sgr "01;94;103")
                 '(:weight bold :foreground "#0000ff" :background "#ffff00")))
  (should (equal (dired-eza-colors-sgr "38;5;196;48;5;232")
                 '(:foreground "#ff0000" :background "#080808")))
  (should (equal (dired-eza-colors-sgr "38;2;1;2;255") '(:foreground "#0102ff")))
  (should (equal (dired-eza-colors-sgr "48;2;20;30;40") '(:background "#141e28"))))

(ert-deftest dired-eza-colors-sgr-resets ()
  (let ((style (dired-eza-colors-sgr "1;3;4;7;9;22;23;24;27;29;39;49")))
    (should (eq (plist-get style :weight) 'normal))
    (should (eq (plist-get style :slant) 'normal))
    (should-not (plist-get style :underline))
    (should-not (plist-get style :inverse-video))
    (should-not (plist-get style :strike-through)))
  (should (equal (dired-eza-colors-sgr "31;0") dired-eza-colors--reset))
  (should (equal (plist-get (dired-eza-colors-sgr "31;0;32") :foreground) "#008000")))

(ert-deftest dired-eza-colors-reject-malformed-and-control-payloads ()
  (dolist (s '("38" "38;5" "38;5;256" "38;2;1;2" "48;2;-1;0;0"
               "31hello" "\e[31m" "(progn (error x))"))
    (should-not (dired-eza-colors-sgr s)))
  (let ((colors (dired-eza-colors-parse "lc=\\e[:rc=m:di=bad:wat=31:ln=target:fi=32")))
    (should (= (length (dired-eza-colors-types colors)) 1)))
  (should (dired-eza-colors-sgr "5;6;8;999")))

(provide 'dired-eza-colors-test)
;;; dired-eza-colors-test.el ends here
