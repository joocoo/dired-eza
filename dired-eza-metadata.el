;;; dired-eza-metadata.el --- Ownership and date colors -*- lexical-binding: t; -*-

;; Copyright (C) 2026 dired-eza contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Parse existing listing columns.  Snapshot local identity once per refresh;
;; never resolve each displayed user or group, or query remote identity.

;;; Code:
(require 'dired)
(require 'dired-eza-size)

(defcustom dired-eza-color-ownership t
  "Whether to color displayed user and group columns.
Run `dired-eza-refresh' after changing this option."
  :type 'boolean :group 'dired-eza)
(defcustom dired-eza-color-timestamps t
  "Whether to color displayed timestamps.
Run `dired-eza-refresh' after changing this option."
  :type 'boolean :group 'dired-eza)
(defcustom dired-eza-user-identities nil
  "Names and numeric ID strings to recognize as the current user.
Nil detects local identity once per refresh.  In remote buffers nil leaves
ownership neutral; set this buffer-locally to supply a known remote identity."
  :type '(repeat string) :group 'dired-eza)
(defcustom dired-eza-group-identities nil
  "Names and numeric ID strings to recognize as groups you belong to.
Nil detects the local primary group only.  To include supplementary groups,
provide the complete list here.  Remote buffers require an explicit list."
  :type '(repeat string) :group 'dired-eza)

(defface dired-eza-owner-self '((t (:inherit font-lock-constant-face)))
  "Fallback for the current user's ownership." :group 'dired-eza)
(defface dired-eza-owner-root '((t (:inherit warning)))
  "Fallback for a root owner." :group 'dired-eza)
(defface dired-eza-owner-other '((t (:inherit shadow)))
  "Fallback for other or unknown owners." :group 'dired-eza)
(defface dired-eza-group-member '((t (:inherit font-lock-type-face)))
  "Fallback for a recognized group membership." :group 'dired-eza)
(defface dired-eza-group-root '((t (:inherit warning)))
  "Fallback for a root group." :group 'dired-eza)
(defface dired-eza-group-other '((t (:inherit shadow)))
  "Fallback for other or unknown groups." :group 'dired-eza)
(defface dired-eza-timestamp '((t (:inherit shadow)))
  "Subtle fallback for the timestamp column." :group 'dired-eza)

(defun dired-eza-metadata-parse (text)
  "Parse supported ownership and timestamp EZA_COLORS keys in TEXT."
  (dired-eza-colors-parse-keys text '("uu" "uR" "un" "gu" "gR" "gn" "da")))

(defun dired-eza-metadata-identity (remote)
  "Snapshot identities for a local listing, or explicit REMOTE overrides.
Only the primary local group is auto-detected.  No subprocesses are used."
  (if remote
      (list :users dired-eza-user-identities :groups dired-eza-group-identities)
    (let* ((uid (user-uid)) (gid (group-gid))
           (unix (not (eq system-type 'windows-nt))))
      (list :users (or dired-eza-user-identities
                       (delq nil (list (user-login-name uid) (number-to-string uid))))
            :groups (or dired-eza-group-identities
                        (delq nil (list (group-name gid) (number-to-string gid))))
            :root-users (and unix (delete-dups (delq nil (list "root" "0" (user-login-name 0)))))
            :root-groups (and unix (delete-dups (delq nil (list "root" "0" (group-name 0)))))
            :ignore-case (eq system-type 'windows-nt)))))

(defun dired-eza-metadata--member (value identities ignore-case)
  "Whether VALUE belongs to IDENTITIES, respecting IGNORE-CASE."
  (cl-some (lambda (id) (if ignore-case (eq t (compare-strings value nil nil id nil nil t))
                         (equal value id))) identities))

(defun dired-eza-metadata-face (rules identity kind value)
  "Choose a face from RULES for displayed KIND and VALUE using IDENTITY."
  (let* ((group (eq kind 'group))
         (known (plist-get identity (if group :groups :users)))
         (root (plist-get identity (if group :root-groups :root-users)))
         (ignore-case (plist-get identity :ignore-case))
         (self (dired-eza-metadata--member value known ignore-case))
         (is-root (dired-eza-metadata--member value root ignore-case))
         (key (cond ((eq kind 'date) "da")
                    (self (if group "gu" "uu"))
                    (is-root (if group "gR" "uR"))
                    (known (if group "gn" "un"))))
         (fallback (cond ((eq kind 'date) 'dired-eza-timestamp)
                         (self (if group 'dired-eza-group-member 'dired-eza-owner-self))
                         (is-root (if group 'dired-eza-group-root 'dired-eza-owner-root))
                         (group 'dired-eza-group-other) (t 'dired-eza-owner-other)))
         (style (cdr (assoc key rules))))
    (if style (list style fallback) fallback)))

(defun dired-eza-metadata-fields (start filename switches)
  "Return (START END KIND TEXT) fields between START and FILENAME.
START follows the ten permission characters.  Honor omitted owner/group
columns in SWITCHES.  Skip ambiguous ownership layouts rather than guess."
  (let* ((size (dired-eza-size-field start filename))
         (case-fold-search nil) (size-start (car size)) fields)
    ;; Dates remain useful even on devices or unrecognized size formats.
    (let ((text (buffer-substring-no-properties start filename)))
      (when (string-match (concat "\\(" dired-eza-size--timestamp "\\)[ \t]+\\'") text)
        (let ((date-start (match-beginning 1)))
          (push (list (+ start date-start) (+ start (match-end 1)) 'date
                      (match-string 1 text)) fields)
          (unless size-start
            ;; Device IDs and grouped raw counts can still have owners.
            (let ((prefix (substring text 0 date-start)))
              (when (string-match "[ \t]\\([0-9]+\\(?:,[ \t]*[0-9]+\\)?\\)[ \t]+\\'" prefix)
                (setq size-start (+ start (match-beginning 1)))))))))
    (when (and size-start (not (string-match-p "--author\\|--context\\|-[^- ]*Z" (or switches ""))))
      (let ((end size-start) tokens
            (no-owner (dired-check-switches switches "g" nil))
            (no-group (dired-check-switches switches "[oG]" "no-group")))
        (save-excursion
          (goto-char start)
          (when (looking-at "[+@.]?") (goto-char (match-end 0)))
          (when (looking-at "[ \t]+[0-9]+[ \t]+")
            (goto-char (match-end 0))
            (while (re-search-forward "[^ \t]+" end t)
              (push (list (match-beginning 0) (match-end 0) (match-string-no-properties 0)) tokens))))
        (setq tokens (nreverse tokens))
        ;; BSD -G enables colors rather than hiding groups.  Two unambiguous
        ;; ownership tokens distinguish that layout from GNU's -G omission.
        (when (and (= (length tokens) 2) (not no-owner)
                   (dired-check-switches switches "G" nil)
                   (not (dired-check-switches switches "o" "no-group")))
          (setq no-group nil))
        (when (= (length tokens) (+ (if no-owner 0 1) (if no-group 0 1)))
          (unless no-owner
            (let ((token (pop tokens)))
              (push (list (nth 0 token) (nth 1 token) 'owner (nth 2 token)) fields)))
          (unless no-group
            (let ((token (pop tokens)))
              (push (list (nth 0 token) (nth 1 token) 'group (nth 2 token)) fields))))))
    (sort fields (lambda (a b) (< (car a) (car b))))))

(provide 'dired-eza-metadata)
;;; dired-eza-metadata.el ends here
