;;; dired-eza-test-helper.el --- Shared ERT fixtures and helpers -*- lexical-binding: t; no-byte-compile: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'ert)
(require 'cl-lib)
(require 'dired-eza)
(require 'ls-lisp)
(require 'tramp)

(defun dired-eza-test--style (text key)
  (cdr (assoc key (dired-eza-colors-types (dired-eza-colors-parse text)))))

(defmacro dired-eza-test--buffer (&rest body)
  (declare (indent 0) (debug t))
  `(with-temp-buffer
     (dired-mode default-directory "-al")
     (let ((inhibit-read-only t))
       (insert "  /fixture:\n  total 0\n")
       (dolist (row '(("drwxr-xr-x" "directory") ("-rw-r--r--" "notes.txt")
                      ("-rwxr-xr-x" "script.txt") ("lrwxrwxrwx" "link.txt")))
         (insert "  " (car row) " 1 owner group 123 Oct 15 12:00 ")
         (insert (propertize (cadr row) 'dired-filename t))
         (when (equal (car row) "lrwxrwxrwx") (insert " -> notes.txt"))
         (insert "\n")))
     (setq-local dired-subdir-alist (list (cons default-directory (copy-marker 1))))
     (set-buffer-modified-p nil)
     (setq-local dired-eza-ls-colors "di=34:*.txt=31:ln=36:ex=32")
     (setq-local dired-eza-eza-colors "")
     (setq-local dired-eza-user-identities '("owner" "1000"))
     (setq-local dired-eza-group-identities '("group" "100"))
     (goto-char (point-min))
     ,@body))

(defun dired-eza-test--face (name)
  (save-excursion
    (goto-char (point-min))
    (search-forward name)
    (get-text-property (1- (point)) 'face)))

(defun dired-eza-test--foreground (name)
  (let ((face (dired-eza-test--face name)))
    (cl-loop for item in (if (listp face) face (list face))
             when (and (listp item) (plist-member item :foreground))
             return (plist-get item :foreground))))

(defun dired-eza-test--permission-face (filename index)
  (save-excursion
    (goto-char (point-min))
    (search-forward filename)
    (beginning-of-line)
    (forward-char (+ 2 index))
    (get-text-property (point) 'face)))

(defun dired-eza-test--size-row (name size &optional date prefix permissions owners)
  (let ((inhibit-read-only t))
    (goto-char (point-max))
    (insert (or prefix "  ") (or permissions "-rw-r--r--")
            (or owners " 1 owner group ") size " " (or date "Oct 15 12:00") " ")
    (insert (propertize name 'dired-filename t))
    (insert "\n")))

(defun dired-eza-test--size-face (filename size &optional offset)
  (save-excursion
    (goto-char (point-min)) (search-forward filename) (beginning-of-line)
    (search-forward (concat " " size " ") (line-end-position))
    (get-text-property (+ (- (point) 1 (length size)) (or offset 0)) 'face)))

(provide 'dired-eza-test-helper)
;;; dired-eza-test-helper.el ends here
