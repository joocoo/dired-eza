;;; dired-eza-permissions.el --- Permission character colors -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; EZA_COLORS permission keys live in a separate namespace from LS_COLORS.
;; Work only from displayed permission characters, without filesystem access.

;;; Code:
(require 'dired-eza-colors)

(defface dired-eza-permission-read
  '((((class color) (background light)) (:inherit font-lock-string-face :foreground "#806000" :weight normal))
    (((class color)) (:inherit font-lock-string-face :foreground "#ffd700" :weight normal))
    (t (:inherit font-lock-string-face :weight normal)))
  "Fallback for read permissions." :group 'dired-eza)
(defface dired-eza-permission-write
  '((((class color) (background light)) (:inherit font-lock-warning-face :foreground "#b02020" :weight normal))
    (((class color)) (:inherit font-lock-warning-face :foreground "#ff5f5f" :weight normal))
    (t (:inherit font-lock-warning-face :weight normal)))
  "Fallback for write permissions." :group 'dired-eza)
(defface dired-eza-permission-execute
  '((((class color) (background light)) (:inherit font-lock-function-name-face :foreground "#006b2d" :weight normal))
    (((class color)) (:inherit font-lock-function-name-face :foreground "#00af00" :weight normal))
    (t (:inherit font-lock-function-name-face :weight normal)))
  "Fallback for execute permissions." :group 'dired-eza)
(defface dired-eza-permission-group '((t (:weight bold)))
  "Fallback emphasis for group read, write and execute permissions."
  :group 'dired-eza)
(defface dired-eza-permission-group-read
  '((t (:inherit dired-eza-permission-read)))
  "Fallback for group read permissions, inheriting the shared yellow." :group 'dired-eza)
(defface dired-eza-permission-group-write
  '((t (:inherit dired-eza-permission-write)))
  "Fallback for group write permissions, inheriting the shared red." :group 'dired-eza)
(defface dired-eza-permission-group-execute
  '((t (:inherit dired-eza-permission-execute)))
  "Fallback for group execute permissions, inheriting the shared green." :group 'dired-eza)
(defface dired-eza-permission-other
  '((((class color) (background light)) (:inverse-video nil))
    (t (:inverse-video t)))
  "Fallback fill for other read, write and execute permissions.
Light backgrounds use pale fills with dark text.  On dark backgrounds,
reverse video uses the permission color as the background."
  :group 'dired-eza)
(defface dired-eza-permission-other-read
  '((((class color) (background light))
     (:inherit dired-eza-permission-read :background "#fff0b3"))
    (t (:inherit dired-eza-permission-read)))
  "Soft light-background fill for other read permissions." :group 'dired-eza)
(defface dired-eza-permission-other-write
  '((((class color) (background light))
     (:inherit dired-eza-permission-write :background "#fbe1e1"))
    (t (:inherit dired-eza-permission-write)))
  "Soft light-background fill for other write permissions." :group 'dired-eza)
(defface dired-eza-permission-other-execute
  '((((class color) (background light))
     (:inherit dired-eza-permission-execute :background "#dcefdc"))
    (t (:inherit dired-eza-permission-execute)))
  "Soft light-background fill for other execute permissions." :group 'dired-eza)
(defface dired-eza-permission-special '((t (:inherit warning :weight bold)))
  "Fallback for setuid, setgid and sticky bits." :group 'dired-eza)
(defface dired-eza-permission-missing '((t (:inherit shadow)))
  "Fallback for absent permission bits and the regular-file indicator."
  :group 'dired-eza)
(defface dired-eza-permission-type '((t (:inherit font-lock-type-face)))
  "Fallback for the listing's file-type indicator." :group 'dired-eza)
(defface dired-eza-permission-directory
  '((((class color) (background light)) (:inherit dired-eza-permission-type :foreground "#1464a0" :weight bold))
    (((class color)) (:inherit dired-eza-permission-type :foreground "#5fafff" :weight bold))
    (t (:inherit dired-eza-permission-type :weight bold)))
  "Bright, bold fallback for the directory flag." :group 'dired-eza)
(defface dired-eza-permission-symlink
  '((((class color) (background light))
     (:inherit dired-eza-permission-type :foreground "#1464a0"
      :background "#dcebf7" :inverse-video nil))
    (t (:inherit dired-eza-permission-type :inverse-video t)))
  "Filled fallback for the symlink flag.
Light backgrounds use dark blue on pale blue.  Dark backgrounds use
reverse video with the inherited type color."
  :group 'dired-eza)
(defface dired-eza-permission-attribute '((t (:inherit font-lock-constant-face)))
  "Fallback for a displayed ACL or extended-attribute indicator." :group 'dired-eza)

(defconst dired-eza-permissions--keys
  '("ur" "uw" "ux" "ue" "gr" "gw" "gx" "tr" "tw" "tx" "su" "sf" "xx" "xa"))

(defun dired-eza-permissions-parse (text)
  "Parse supported EZA_COLORS permission rules from TEXT into an alist.
Last valid definition wins.  Ignore other metadata and filename keys.
`reset' clears permission defaults until overridden by following entries.
Never merge this map into the LS_COLORS filename map."
  (dired-eza-colors-parse-keys text dired-eza-permissions--keys))

(defun dired-eza-permissions-face (rules permissions index)
  "Return a face for PERMISSIONS character INDEX, using parsed RULES.
INDEX 0 denotes the type; 1..9 are rwx bits; 10 is an optional attribute.
Uppercase S and T are special bits even when execute permission is absent."
  (let* ((char (aref permissions index))
         (regular (= (aref permissions 0) ?-))
         key fallback)
    (cond
     ((= index 10) (setq key "xa" fallback 'dired-eza-permission-attribute))
     ((= char ?-) (setq key "xx" fallback 'dired-eza-permission-missing))
     ((= index 0)
      (setq fallback (pcase char
                       (?d 'dired-eza-permission-directory)
                       (?l 'dired-eza-permission-symlink)
                       (_ 'dired-eza-permission-type))))
     ((memq char '(?s ?S ?t ?T))
      (setq key (if regular "su" "sf") fallback 'dired-eza-permission-special))
     (t
      (setq key (aref [nil "ur" "uw" "ux" "gr" "gw" "gx" "tr" "tw" "tx"] index))
      (when (and (= index 3) (not regular)) (setq key "ue"))
      (setq fallback (pcase char
                       (?r 'dired-eza-permission-read)
                       (?w 'dired-eza-permission-write)
                       (?x 'dired-eza-permission-execute)
                       (_ 'dired-eza-permission-missing)))))
    (let ((style (cdr (assoc key rules))))
      (cond
       (style (list style fallback))
       ((and (<= 4 index) (<= index 6) (memq char '(?r ?w ?x)))
        (list 'dired-eza-permission-group
              (pcase char
                (?r 'dired-eza-permission-group-read)
                (?w 'dired-eza-permission-group-write)
                (?x 'dired-eza-permission-group-execute))))
       ((and (<= 7 index) (<= index 9) (memq char '(?r ?w ?x)))
        (list 'dired-eza-permission-other
              (pcase char
                (?r 'dired-eza-permission-other-read)
                (?w 'dired-eza-permission-other-write)
                (?x 'dired-eza-permission-other-execute))))
       (t fallback)))))

(provide 'dired-eza-permissions)
;;; dired-eza-permissions.el ends here
