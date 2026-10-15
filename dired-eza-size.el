;;; dired-eza-size.el --- Size categories from Dired listings -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Parse the displayed size, anchored to a recognized timestamp and Dired's
;; filename boundary.  Never query file attributes to obtain a size.

;;; Code:
(require 'dired-eza-colors)

(defcustom dired-eza-size-base 1024
  "Magnitude threshold for raw byte counts.
1024 follows eza's raw-byte coloring.  Use 1000 for decimal thresholds.
Human-readable sizes use their displayed unit, without guessing exact bytes."
  :type '(choice (const 1024) (const 1000)) :group 'dired-eza)

(defface dired-eza-size-byte '((t (:inherit shadow)))
  "Fallback for byte-sized values." :group 'dired-eza)
(defface dired-eza-size-kilo '((t (:inherit font-lock-constant-face)))
  "Fallback for kilobyte-sized values." :group 'dired-eza)
(defface dired-eza-size-mega '((t (:inherit font-lock-string-face)))
  "Fallback for megabyte-sized values." :group 'dired-eza)
(defface dired-eza-size-giga '((t (:inherit font-lock-keyword-face)))
  "Fallback for gigabyte-sized values." :group 'dired-eza)
(defface dired-eza-size-tera '((t (:inherit warning :weight bold)))
  "Fallback for terabyte-sized values and larger." :group 'dired-eza)

(defun dired-eza-size-parse (text)
  "Parse numeric and unit size keys from EZA_COLORS TEXT.
`sn' sets all numeric styles; `sb' sets all unit styles, in input order."
  (dired-eza-colors-parse-keys
   text '("nb" "nk" "nm" "ng" "nt" "ub" "uk" "um" "ug" "ut")
   '(("sn" "nb" "nk" "nm" "ng" "nt") ("sb" "ub" "uk" "um" "ug" "ut"))))

(defun dired-eza-size-category (number unit)
  "Return category 0..4 for displayed NUMBER and UNIT, or nil if invalid.
Raw integers use `dired-eza-size-base'.  K/M/G/T and larger displayed units
select their category directly.  Values above terabytes share category 4."
  (let ((case-fold-search nil))
    (cond
     ((or (null unit) (equal unit "") (member unit '("B" "b")))
      (when (string-match-p "\\`[0-9]+\\'" number)
        (let ((bytes (string-to-number number)) (category 0)
              (threshold dired-eza-size-base))
          (while (and (< category 4) (>= bytes threshold))
            (setq category (1+ category) threshold (* threshold dired-eza-size-base)))
          category)))
     ((and (string-match-p "\\`[0-9]+\\(?:[.,][0-9]+\\)?\\'" number)
           (string-match-p "\\`[kKMGTPEZYRQ]\\(?:i?[Bb]?\\)?\\'" unit))
      (pcase (aref unit 0) ((or ?k ?K) 1) (?M 2) (?G 3) (_ 4))))))

(defun dired-eza-size-face (rules category &optional unit)
  "Return numeric or UNIT face for CATEGORY using parsed RULES."
  (let* ((key (concat (if unit "u" "n") (aref ["b" "k" "m" "g" "t"] category)))
         (fallback (aref [dired-eza-size-byte dired-eza-size-kilo dired-eza-size-mega
                         dired-eza-size-giga dired-eza-size-tera] category))
         (style (cdr (assoc key rules))))
    (if style (list style fallback) fallback)))

(defconst dired-eza-size--timestamp
  (let* ((space "[ \t]+")
         (month "[[:alpha:].']+")
         (day "[0-3]?[0-9]")
         (year "[0-9]\\{4\\}")
         (clock "[0-2][0-9]:[0-5][0-9]\\(?::[0-6][0-9]\\(?:[.,][0-9]+\\)?\\)?")
         (time-or-year (concat "\\(?:" clock "\\|" year "\\)")))
    (concat "\\(?:"
            ;; ISO, long-ISO and full-ISO, with optional numeric timezone.
            year "-[01][0-9]-[0-3][0-9]"
            "\\(?:[ T]" clock "\\(?:" space "[-+][0-2][0-9][0-5][0-9]\\)?\\)?"
            "\\|" month space day space time-or-year "\\(?:" space year "\\)?"
            "\\|" day "\\.?" space month space time-or-year
            "\\|" month space day "," space year
            "\\)"))
  "Conservative timestamp forms recognized after a size field.")

(defconst dired-eza-size--field-regexp
  (concat "\\(?:\\`\\|[ \t]\\)"
          "\\([0-9]+\\(?:[.,][0-9]+\\)?\\)"
          "\\([bBkKMGTPEZYRQ]\\(?:i?[Bb]?\\)?\\)?[ \t]+"
          "\\(" dired-eza-size--timestamp "\\)[ \t]+\\'"))

(defun dired-eza-size-field (start filename)
  "Find the size field between START and FILENAME in the current buffer.
Return (NUMBER-START NUMBER-END UNIT-END CATEGORY DATE-START DATE-END), or nil.
Timestamp anchoring avoids mistaking numeric owners, links or dates for sizes."
  (let ((text (buffer-substring-no-properties start filename))
        (case-fold-search nil))
    (when (string-match dired-eza-size--field-regexp text)
      (let* ((begin (+ start (match-beginning 1)))
             (number-end (+ start (match-end 1)))
             (end (+ start (or (match-end 2) (match-end 1))))
             (date-start (+ start (match-beginning 3)))
             (date-end (+ start (match-end 3)))
             (category (dired-eza-size-category (match-string 1 text) (match-string 2 text))))
        (when category (list begin number-end end category date-start date-end))))))

(provide 'dired-eza-size)
;;; dired-eza-size.el ends here
