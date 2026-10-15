;;; dired-eza-size-test.el --- Size tests -*- lexical-binding: t; no-byte-compile: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'dired-eza-test-helper)

(ert-deftest dired-eza-size-raw-boundaries ()
  (dolist (base '(1024 1000))
    (let ((dired-eza-size-base base))
      (should (= (dired-eza-size-category "0" nil) 0))
      (cl-loop for category from 1 to 4 for threshold = (expt base category) do
               (should (= (dired-eza-size-category (number-to-string (1- threshold)) nil)
                          (1- category)))
               (should (= (dired-eza-size-category (number-to-string threshold) nil) category)))
      (should (= (dired-eza-size-category "999999999999999999999999999" nil) 4)))))

(ert-deftest dired-eza-size-human-categories ()
  (dolist (case '(("123" "B" 0) ("1.5" "K" 1) ("1,5" "k" 1)
                  ("1024" "K" 1) ("1" "MiB" 2) ("2.3" "G" 3)
                  ("99" "TB" 4) ("3" "PiB" 4)))
    (should (= (dired-eza-size-category (nth 0 case) (nth 1 case)) (nth 2 case))))
  (dolist (case '(("1.2" nil) ("1,234" nil) ("-1" nil) ("NaN" "K")
                  ("2" "garbage") ("1" "m")))
    (should-not (dired-eza-size-category (car case) (cadr case)))))

(ert-deftest dired-eza-size-umbrella-order-and-resets ()
  (let ((rules (dired-eza-size-parse "sn=31:nk=32:sb=33:um=34:ur=35")))
    (should (= (length rules) 10))
    (should (equal (cdr (assoc "nb" rules)) '(:foreground "#800000")))
    (should (equal (cdr (assoc "nk" rules)) '(:foreground "#008000")))
    (should (equal (cdr (assoc "um" rules)) '(:foreground "#000080"))))
  (should (equal (cdr (assoc "nk" (dired-eza-size-parse "nk=32:sn=31")))
                 '(:foreground "#800000")))
  (should (equal (cdr (assoc "nb" (dired-eza-size-parse "sn=31:reset:nk=32")))
                 dired-eza-colors--reset))
  (should (equal (cdr (assoc "nk" (dired-eza-size-parse "nk=32:nk=bad")))
                 '(:foreground "#008000"))))

(ert-deftest dired-eza-size-font-lock-raw-and-human ()
  (dired-eza-test--buffer
    (cl-loop for size in '("42" "1536" "1048576" "1073741824" "1099511627776"
                           "1.5K" "2.3M" "4G" "5T")
             for n from 0 do (dired-eza-test--size-row (format "size%d" n) size))
    (dired-eza-mode 1) (font-lock-ensure)
    (cl-loop for size in '("42" "1536" "1048576" "1073741824" "1099511627776"
                           "1.5K" "2.3M" "4G" "5T")
             for face in '(dired-eza-size-byte dired-eza-size-kilo dired-eza-size-mega
                           dired-eza-size-giga dired-eza-size-tera dired-eza-size-kilo
                           dired-eza-size-mega dired-eza-size-giga dired-eza-size-tera)
             for n from 0 do
             (should (memq face (ensure-list (dired-eza-test--size-face (format "size%d" n) size)))))))

(ert-deftest dired-eza-size-numbers-and-units-have-separate-styles ()
  (dired-eza-test--buffer
    (dired-eza-test--size-row "human" "1.5K")
    (setq-local dired-eza-eza-colors "nk=31:uk=32")
    (dired-eza-mode 1) (font-lock-ensure)
    (should (equal (plist-get (car (dired-eza-test--size-face "human" "1.5K")) :foreground)
                   "#800000"))
    (should (equal (plist-get (car (dired-eza-test--size-face "human" "1.5K" 3)) :foreground)
                   "#008000"))
    (setq-local dired-eza-eza-colors "nk=34")
    (dired-eza-refresh) (font-lock-ensure)
    (should (equal (plist-get (car (dired-eza-test--size-face "human" "1.5K")) :foreground)
                   "#000080"))
    (dired-eza-mode -1) (font-lock-ensure)
    (should-not (dired-eza-test--size-face "human" "1.5K"))))

(ert-deftest dired-eza-size-timestamps-and-numeric-owners ()
  (dired-eza-test--buffer
    (cl-loop for date in '("Oct 15 12:00" "Oct 15 2026" "15 oct. 12:00"
                           "2026-10-15 12:00" "2026-10-15 12:00:01.123 -0500"
                           "Oct 15 12:00:00 2026" "Oct 15, 2026")
             for n from 0 do
             (dired-eza-test--size-row (format "date%d" n) "2048" date "  123 8 " nil
                                      " 2000 1000 3000 "))
    (dired-eza-mode 1) (font-lock-ensure)
    (cl-loop for n from 0 to 6 do
             (should (memq 'dired-eza-size-kilo
                           (ensure-list (dired-eza-test--size-face (format "date%d" n) "2048")))))
    (goto-char (point-min)) (search-forward "2000 1000 3000")
    (should (memq 'dired-eza-group-other
                  (ensure-list (get-text-property (1- (point)) 'face))))))

(ert-deftest dired-eza-size-skips-device-ids-and-unknown-dates ()
  (dired-eza-test--buffer
    (dired-eza-test--size-row "block" "8, 1" nil nil "brw-r--r--")
    (dired-eza-test--size-row "char" "8, 2" nil nil "crw-r--r--")
    (dired-eza-test--size-row "unknown" "2048" "unknown date format")
    (dired-eza-test--size-row "grouped" "1,234")
    (dired-eza-mode 1) (font-lock-ensure)
    (should-not (dired-eza-test--size-face "block" "8, 1"))
    (should-not (dired-eza-test--size-face "char" "8, 2"))
    (should-not (dired-eza-test--size-face "unknown" "2048"))
    (should-not (dired-eza-test--size-face "grouped" "1,234"))))

(ert-deftest dired-eza-size-preserves-invisibility-and-marked-names ()
  (dired-eza-test--buffer
    (goto-char (point-min)) (search-forward "notes.txt") (dired-mark 1)
    (let ((inhibit-read-only t)) (dired-insert-set-properties (point-min) (point-max)))
    (dired-hide-details-mode 1)
    (dired-eza-mode 1) (font-lock-ensure)
    (should (memq 'dired-eza-size-byte
                  (ensure-list (dired-eza-test--size-face "notes.txt" "123"))))
    (should (memq 'dired-marked (ensure-list (dired-eza-test--face "notes.txt"))))
    (goto-char (point-min)) (search-forward "notes.txt") (beginning-of-line)
    (search-forward " 123 ")
    (should (invisible-p (- (point) 2)))))

(ert-deftest dired-eza-size-font-lock-limit ()
  (dired-eza-test--buffer
    (dired-eza-test--size-row "limited" "1.5K")
    (dired-eza-mode 1)
    (goto-char (point-min)) (search-forward "limited") (beginning-of-line)
    (search-forward " 1.5K ")
    (let ((start (- (point) 5)))
      (goto-char start)
      (should (dired-eza--match-size (1+ start)))
      (should (= (match-end 0) (1+ start))))))

(provide 'dired-eza-size-test)
;;; dired-eza-size-test.el ends here
