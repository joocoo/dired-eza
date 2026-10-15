;;; dired-eza-colors.el --- Parse LS_COLORS safely -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Pure parsing and ANSI SGR conversion.  No evaluation or filesystem access.

;;; Code:
(require 'cl-lib)
(require 'subr-x)

(cl-defstruct (dired-eza-colors (:constructor dired-eza-colors--create))
  types suffixes)

(defconst dired-eza-colors--palette
  ["#000000" "#800000" "#008000" "#808000"
   "#000080" "#800080" "#008080" "#c0c0c0"
   "#808080" "#ff0000" "#00ff00" "#ffff00"
   "#0000ff" "#ff00ff" "#00ffff" "#ffffff"])

(defconst dired-eza-colors--reset
  '(:inherit default :weight normal :slant normal :underline nil
    :inverse-video nil :strike-through nil :foreground unspecified
    :background unspecified)
  "An explicit terminal reset, distinct from a missing rule.")

(defun dired-eza-colors--indexed (n)
  "Return xterm color N as a hex string."
  (cond ((< n 16) (aref dired-eza-colors--palette n))
        ((< n 232)
         (let* ((n (- n 16)) (steps [0 95 135 175 215 255]))
           (format "#%02x%02x%02x" (aref steps (/ n 36))
                   (aref steps (% (/ n 6) 6)) (aref steps (% n 6)))))
        (t (let ((v (+ 8 (* 10 (- n 232)))))
             (format "#%02x%02x%02x" v v v)))))

(defun dired-eza-colors-sgr (value)
  "Convert numeric SGR VALUE to face attributes, or nil if malformed.
Unsupported numeric attributes (including blinking and concealment) are
ignored.  Empty values and SGR 0 explicitly select the default face."
  (when (string-match-p "\\`[0-9;]*\\'" value)
    (catch 'invalid
      (let ((codes (mapcar (lambda (s) (if (equal s "") 0 (string-to-number s)))
                           (split-string value ";" nil)))
            attrs)
        (when (equal value "") (setq codes '(0)))
        (while codes
          (let ((n (pop codes)))
            (cond
             ((= n 0) (setq attrs (copy-sequence dired-eza-colors--reset)))
             ((= n 1) (setq attrs (plist-put attrs :weight 'bold)))
             ((= n 2) (setq attrs (plist-put attrs :weight 'light)))
             ((= n 3) (setq attrs (plist-put attrs :slant 'italic)))
             ((= n 4) (setq attrs (plist-put attrs :underline t)))
             ((= n 7) (setq attrs (plist-put attrs :inverse-video t)))
             ((= n 9) (setq attrs (plist-put attrs :strike-through t)))
             ((= n 22) (setq attrs (plist-put attrs :weight 'normal)))
             ((= n 23) (setq attrs (plist-put attrs :slant 'normal)))
             ((= n 24) (setq attrs (plist-put attrs :underline nil)))
             ((= n 27) (setq attrs (plist-put attrs :inverse-video nil)))
             ((= n 29) (setq attrs (plist-put attrs :strike-through nil)))
             ((memq n '(39 49))
              (setq attrs (plist-put attrs (if (= n 39) :foreground :background)
                                     'unspecified)))
             ((or (<= 30 n 37) (<= 90 n 97) (<= 40 n 47) (<= 100 n 107))
              (let* ((fg (or (<= 30 n 37) (<= 90 n 97)))
                     (index (cond ((<= 30 n 37) (- n 30))
                                  ((<= 40 n 47) (- n 40))
                                  ((<= 90 n 97) (+ 8 (- n 90)))
                                  (t (+ 8 (- n 100))))))
                (setq attrs (plist-put attrs (if fg :foreground :background)
                                       (aref dired-eza-colors--palette index)))))
             ((memq n '(38 48))
              (let* ((kind (pop codes))
                     (count (cond ((eq kind 5) 1) ((eq kind 2) 3)
                                  (t (throw 'invalid nil))))
                     components)
                (dotimes (_ count)
                  (unless (and codes (<= 0 (car codes) 255))
                    (throw 'invalid nil))
                  (push (pop codes) components))
                (setq components (nreverse components))
                (setq attrs
                      (plist-put attrs (if (= n 38) :foreground :background)
                                 (if (= kind 5)
                                     (dired-eza-colors--indexed (car components))
                                   (apply #'format "#%02x%02x%02x" components)))))))))
        ;; Even an unsupported-only numeric sequence is a valid neutral style.
        (or attrs '(:inherit default))))))

(defun dired-eza-colors--split (text delimiter)
  "Split TEXT on unescaped DELIMITER, retaining escape sequences."
  (let ((i 0) (start 0) parts)
    (while (< i (length text))
      (cond ((memq (aref text i) '(?\\ ?^)) (setq i (1+ i)))
            ((= (aref text i) delimiter)
             (push (substring text start i) parts)
             (setq start (1+ i))))
      (setq i (1+ i)))
    (nreverse (cons (substring text start) parts))))

(defun dired-eza-colors--unescape (text)
  "Decode dircolors escapes in TEXT; return nil for incomplete escapes."
  (catch 'invalid
    (let ((i 0) chars)
      (while (< i (length text))
        (let ((c (aref text i)))
          (setq i (1+ i))
          (cond
           ((= c ?\\)
            (when (= i (length text)) (throw 'invalid nil))
            (setq c (aref text i) i (1+ i))
            (cond
             ((or (<= ?0 c ?7) (memq c '(?x ?X)))
              (let* ((hex (memq c '(?x ?X)))
                     (start (if hex i (1- i)))
                     (pattern (if hex "[0-9a-fA-F]" "[0-7]")))
                (while (and (< i (length text))
                            (string-match-p pattern (char-to-string (aref text i))))
                  (setq i (1+ i)))
                (when (= start i) (throw 'invalid nil))
                (setq c (% (string-to-number (substring text start i)
                                            (if hex 16 8)) 256))))
             (t (setq c (or (cdr (assq c '((?a . 7) (?b . 8) (?e . 27)
                                           (?f . 12) (?n . 10) (?r . 13)
                                           (?t . 9) (?v . 11) (?? . 127)
                                           (?_ . 32)))) c)))))
           ((= c ?^)
            (when (= i (length text)) (throw 'invalid nil))
            (setq c (aref text i) i (1+ i))
            (unless (or (<= ?@ c ?~) (= c ??)) (throw 'invalid nil))
            (setq c (if (= c ??) 127 (logand c 31)))))
          (push c chars)))
      (apply #'string (nreverse chars)))))

(defun dired-eza-colors-parse (text)
  "Parse LS_COLORS TEXT into a `dired-eza-colors' object.
Last valid definition wins.  A leading * introduces a literal suffix,
not a shell glob.  Unknown keys and malformed entries are ignored locally.
Terminal control wrappers are never emitted.  `ln=target' is intentionally
ignored because target classification would require filesystem access."
  (let (types suffixes)
    (dolist (entry (dired-eza-colors--split (or text "") ?:))
      (let* ((parts (dired-eza-colors--split entry ?=))
             (key (and (= (length parts) 2)
                       (dired-eza-colors--unescape (car parts))))
             (value (and key (dired-eza-colors--unescape (cadr parts))))
             (style (and value (dired-eza-colors-sgr value))))
        (when (and key style)
          (cond ((string-prefix-p "*" key)
                 (push (list (substring key 1) style) suffixes))
                ((member key '("no" "fi" "di" "ln" "pi" "so" "bd" "cd"
                               "su" "sg" "st" "ow" "tw" "ex"))
                 (setf (alist-get key types nil nil #'equal) style))))))
    ;; GNU's case-collision rule: suffix families with distinct styles match
    ;; exactly; otherwise use case-insensitive matching.  Drop shadowed rules.
    (let ((seen (make-hash-table :test #'equal)) unique)
      (dolist (rule suffixes)
        (unless (gethash (car rule) seen)
          (puthash (car rule) t seen)
          (push rule unique)))
      (setq suffixes (nreverse unique)))
    (dolist (rule suffixes)
      (setcdr (cdr rule)
              (list (cl-some
                     (lambda (other)
                       (and (equal (downcase (car rule)) (downcase (car other)))
                            (not (equal (cadr rule) (cadr other)))))
                     suffixes))))
    (dired-eza-colors--create :types types :suffixes suffixes)))

(defun dired-eza-colors-suffix (colors filename)
  "Return the last matching suffix style from COLORS for FILENAME."
  (cadr (cl-find-if (lambda (rule)
                      (string-suffix-p (car rule) filename (not (nth 2 rule))))
                    (dired-eza-colors-suffixes colors))))

(defun dired-eza-colors-parse-keys (text keys &optional umbrellas)
  "Parse EZA_COLORS TEXT for supported KEYS into a separate style alist.
UMBRELLAS maps shorthand keys to lists of keys to set in input order.
`reset' sets every supported key to the default face."
  (let (rules)
    (dolist (entry (dired-eza-colors--split (or text "") ?:))
      (if (equal entry "reset")
          (setq rules (mapcar (lambda (key) (cons key dired-eza-colors--reset)) keys))
        (let* ((parts (dired-eza-colors--split entry ?=))
               (key (and (= (length parts) 2)
                         (dired-eza-colors--unescape (car parts))))
               (value (and key (dired-eza-colors--unescape (cadr parts))))
               (style (and value (dired-eza-colors-sgr value))))
          (when style
            (dolist (target (or (cdr (assoc key umbrellas))
                               (and (member key keys) (list key))))
              (setf (alist-get target rules nil nil #'equal) style))))))
    rules))

(provide 'dired-eza-colors)
;;; dired-eza-colors.el ends here
