;;; dired-eza-permissions.el --- Permission character colors -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; EZA_COLORS permission keys live in a separate namespace from LS_COLORS.
;; Work only from displayed permission characters, without filesystem access.

;;; Code:
(require 'dired-eza-colors)

(defface dired-eza-permission-read '((t (:inherit font-lock-string-face)))
  "Fallback for read permissions." :group 'dired-eza)
(defface dired-eza-permission-write '((t (:inherit font-lock-warning-face)))
  "Fallback for write permissions." :group 'dired-eza)
(defface dired-eza-permission-execute '((t (:inherit font-lock-function-name-face)))
  "Fallback for execute permissions." :group 'dired-eza)
(defface dired-eza-permission-special '((t (:inherit warning :weight bold)))
  "Fallback for setuid, setgid and sticky bits." :group 'dired-eza)
(defface dired-eza-permission-missing '((t (:inherit shadow)))
  "Fallback for absent permission bits and the regular-file indicator."
  :group 'dired-eza)
(defface dired-eza-permission-type '((t (:inherit font-lock-type-face)))
  "Fallback for the listing's file-type indicator." :group 'dired-eza)
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
     ((= index 0) (setq fallback 'dired-eza-permission-type))
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
      (if style (list style fallback) fallback))))

(provide 'dired-eza-permissions)
;;; dired-eza-permissions.el ends here
