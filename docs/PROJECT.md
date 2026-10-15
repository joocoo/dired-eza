# Project brief

Continue developing **dired-eza**, described as **eza-like colors for Emacs
Dired**. This is an independent project with no claim of eza affiliation.

Build a standalone Emacs Lisp minor-mode package for Emacs 30 and 31 on Linux,
macOS, and Windows, using only Emacs built-ins at runtime. Preserve native
Dired operations, hide-details, Evil keymaps, and TRAMP behavior. Avoid
subprocesses and additional remote stat calls in the coloring layer.

Read Dired's current font-lock implementation and eza's real color keys before
adding behavior. Keep parsing, classification, and rendering separate and
testable. Inherit LS_COLORS for names/types, then add EZA_COLORS support for
permission characters, numeric size categories, users/groups, and timestamps.
Use theme face fallbacks. Never assume the two formats share key meanings.

Versions 0.1 through 0.4 implement LS_COLORS filename rendering and
EZA_COLORS permissions, sizes, owner/group, and timestamp colors through a
reversible minor mode. Keep GitHub Actions workflows out of this project. Use ERT and strict byte compilation; preserve existing files. Keep
README support claims aligned with actual validation. The intended published
configuration is:

```emacs-lisp
(use-package dired-eza
  :ensure t
  :hook (dired-mode . dired-eza-mode))
```

Follow ROADMAP.md for metadata work. Do not claim package-archive availability
until publication actually happens. Initial license: GPL-3.0-or-later.
