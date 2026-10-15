;;; dired-eza-classify.el --- Classify existing Dired metadata -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Pure classification from a filename and displayed permission string.
;; No file attributes, subprocesses, or remote operations.

;;; Code:
(require 'dired-eza-colors)

(defun dired-eza-classify (colors filename permissions)
  "Return (STYLE . KIND) for COLORS, FILENAME and PERMISSIONS.
KIND is an LS_COLORS type key.  STYLE may be nil for theme fallback.
Only regular files use suffix rules.  Configured special permission rules
take precedence over suffixes; reset special rules disable that category."
  (let* ((types (dired-eza-colors-types colors))
         (type (if (= (length permissions) 10) (aref permissions 0) ?-))
         (exec (and (= (length permissions) 10)
                    (or (memq (aref permissions 3) '(?x ?s))
                        (memq (aref permissions 6) '(?x ?s))
                        (memq (aref permissions 9) '(?x ?t)))))
         (kind (or (cdr (assq type '((?d . "di") (?l . "ln") (?p . "pi")
                                    (?s . "so") (?b . "bd") (?c . "cd"))))
                   "fi"))
         candidates special)
    (when (= (length permissions) 10)
      (cond
       ((= type ?d)
        (let ((sticky (memq (aref permissions 9) '(?t ?T)))
              (writable (= (aref permissions 8) ?w)))
          (setq candidates (append (and sticky writable '("tw"))
                                   (and writable '("ow")) (and sticky '("st"))))))
       ((= type ?-)
        (setq candidates (append (and (memq (aref permissions 3) '(?s ?S)) '("su"))
                                 (and (memq (aref permissions 6) '(?s ?S)) '("sg"))
                                 (and exec '("ex")))))))
    (setq special
          (cl-find-if (lambda (key)
                        (let ((style (cdr (assoc key types))))
                          (and style (not (equal style dired-eza-colors--reset)))))
                      candidates))
    (if special
        (cons (cdr (assoc special types)) special)
      (cons (or (and (equal kind "fi") (dired-eza-colors-suffix colors filename))
                (cdr (assoc kind types)) (cdr (assoc "no" types)))
            (if (and exec (equal kind "fi")) "ex" kind)))))

(provide 'dired-eza-classify)
;;; dired-eza-classify.el ends here
