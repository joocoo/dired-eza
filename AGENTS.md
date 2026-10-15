# Contributor instructions

## Project

`dired-eza` provides **eza-like colors for Emacs Dired**. It is independent of
eza and must not imply affiliation. Target Emacs 30.1+ and 31 on Linux, macOS,
and Windows. Use only Emacs built-ins at runtime; do not require eza.
License: GPL-3.0-or-later.

Read `README.md`, `docs/DESIGN.md`, and `ROADMAP.md` before changing behavior.
Check actual Dired implementations and upstream eza color specifications when
adding mappings. Keep support claims consistent with implemented and tested
behavior; do not claim package-archive availability without verifying it.

## Architecture

- `dired-eza-colors.el`: safe escape/SGR parsing and ordered color rules.
- `dired-eza-classify.el`: pure filename/type classification.
- `dired-eza-permissions.el`: per-character permission styles.
- `dired-eza-size.el`: displayed size fields, categories, and unit styles.
- `dired-eza-metadata.el`: owner/group/date fields and identity snapshots.
- `dired-eza.el`: configuration, minor-mode lifecycle, and Dired font-lock.
- `test/dired-eza-*-test.el`: focused module and Dired integration tests.
- `test/dired-eza-test-helper.el`: shared test fixtures and assertions.
- `test/dired-eza-test.el`: stable entry point loading the complete ERT suite.
- `Makefile`: optional local test/compile/check/clean commands.
- `CHANGELOG.md`: development changes; do not invent release dates or tags.

Keep parsing and classification separate from buffer rendering. Use lexical
binding, the `dired-eza-` prefix, docstrings, and theme-inheriting fallback faces.
Preserve the distinction between missing rules and explicit color resets.
LS_COLORS and EZA_COLORS have separate namespaces; shared key names can have
different meanings. Never evaluate environment-variable contents or insert
terminal control sequences into buffers.

## Dired and remote behavior

- Extend font-lock buffer-locally. Preserve listing text, point, modified state,
  sorting, file operations, marks, deletion flags, Evil bindings, and invisibility.
- Let Dired identify filenames and decode quoting. Skip unknown or ambiguous
  layouts rather than guessing column positions.
- Read metadata from existing listings. Do not add subprocesses, per-file stat
  calls, symlink-target checks, or remote environment/identity queries.
- Cache parsed rules and local identity at enable/refresh time. Avoid account
  lookups during fontification. Supplementary groups require explicit identities.
- Remote ownership stays neutral unless remote identities are explicitly supplied.
  Never identify a remote user by comparing against the local account.
- Keep enable/disable idempotent and reversible. Respect font-lock region limits
  and hide-details; add no global advice or global Dired keyword mutations.

## Local validation

Run `make check` from the repository root after changing Lisp behavior. It
runs ERT against source, compiles with warnings as errors, reruns ERT against
compiled modules, and removes generated runtime `.elc` files on success.
`make test`, `make compile`, and `make clean` are also available. Override the
executable with `make EMACS=/path/to/emacs check`. Make is optional.

Direct ERT invocation (also works without Make):

```sh
emacs --batch -Q -L . -L test -l dired-eza-test -f ert-run-tests-batch-and-exit
```

Compile all runtime modules with warnings treated as errors:

```sh
emacs --batch -Q -L . --eval '(setq byte-compile-error-on-warn t)' \
  -f batch-byte-compile dired-eza-colors.el dired-eza-classify.el \
  dired-eza-permissions.el dired-eza-size.el dired-eza-metadata.el dired-eza.el
```

Run ERT against source and compiled files when relevant. Avoid stale `.elc`
files masking source edits. Do not commit generated `.elc` or `.eln` files.
On macOS, use `/Applications/Emacs.app/Contents/MacOS/Emacs` if `emacs` is not
on PATH. Documentation-only edits need review, not a full test rerun.

Add focused ERT coverage for new parsing, precedence, field boundaries, and
lifecycle behavior. Preserve the tests guarding filesystem/process calls.
Synthetic TRAMP and Windows fixtures are not substitutes for live platform
tests. Report the Emacs version/platform actually tested and any unverified
compatibility claims.

## Repository policy

- **Do not add GitHub Actions workflows.** The user explicitly requested their
  removal. Keep validation local; do not install automatic Git hooks.
- Preserve unrelated work. Keep changes scoped and document new public options,
  behavior, limitations, and roadmap updates.
- Never embed local account information, machine-specific paths, credentials,
  or private configuration in distributable examples or tests.
- Do not alter the user's personal Emacs configuration or live session unless
  the current task authorizes it.
- Do not publish releases, create remote repositories, or push commits without
  authorization for that action in the current task.
