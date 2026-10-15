# Design and research notes

Initial research and permission-key recheck performed 2026-10-15.

## Primary sources

- [Emacs 30 Dired source](https://github.com/emacs-mirror/emacs/blob/emacs-30/lisp/dired.el)
  and the installed Emacs 31.1 `dired.el`: `dired-font-lock-keywords`,
  `dired-move-to-filename`, `dired-move-to-end-of-filename`, and
  `dired-get-filename`. Filename text properties take precedence over parsing
  the listing. `dired-check-symlinks` controls native target checks.
- [Font-lock extension API](https://www.gnu.org/software/emacs/manual/html_node/elisp/Customizing-Keywords.html):
  pass nil as MODE to add/remove keywords in the current buffer. Append our
  keyword and prepend the resulting face so explicit colors take precedence
  while native font-lock still owns fontification and cleanup.
- [GNU ls implementation](https://github.com/coreutils/coreutils/blob/master/src/ls.c):
  `get_funky_string`, `parse_ls_color`, and `get_color_indicator` establish
  escaping, suffix matching, and type/permission priority. Our supported subset
  deliberately avoids categories that need extra filesystem information.
- [eza color manual](https://github.com/eza-community/eza/blob/main/man/eza_colors.5.md),
  [SGR parser](https://github.com/eza-community/eza/blob/main/src/theme/lsc.rs),
  and [environment selection](https://github.com/eza-community/eza/blob/main/src/options/theme.rs):
  eza has metadata-specific keys and its own defaults. LS_COLORS syntax and
  EZA_COLORS semantics must not be conflated. The initial implementation is
  independent; no eza code or built-in color dataset is copied.

Upstream links are moving branches; these notes describe the researched
behavior, not a guarantee that future upstream revisions will match it.

## Components

1. `dired-eza-colors.el`: pure escape scanner, safe numeric SGR conversion,
   type map and ordered suffix rules. Invalid entries do not discard other
   valid entries. Explicit resets differ from absent rules. ANSI wrappers and
   arbitrary Lisp/shell text are never executed or displayed.
2. `dired-eza-classify.el`: pure selection from the decoded basename and
   displayed permission string, with no filesystem queries. Classifier tests
   do not depend on the operating system.
3. `dired-eza-permissions.el`: EZA permission parser and pure bit-to-face mapping,
   including theme fallback faces. Its namespace is independent of LS_COLORS.
4. `dired-eza-size.el`: size-rule expansion, displayed size classification,
   conservative timestamp anchoring, and magnitude fallback faces.
5. `dired-eza-metadata.el`: conservative ownership/date fields, identity snapshots,
   and optional neutral remote rendering.
6. `dired-eza.el`: user configuration, theme fallback faces, buffer-local
   font-lock matcher and minor-mode lifecycle. Dired owns filename boundary
   parsing, quoting, invisibility, navigation and operations.

## Lifecycle and compatibility

Enabling parses the environment snapshot once and installs filename, permission, size and owner/date keywords.
Repeated enables remove the old keyword first. Refresh reparses without
relocating point or rereading the directory. Disable removes the keyword and
flushes font-lock, which restores the native faces. No overlays, global advice,
global keyword mutation, keymaps, or per-file attributes are used.

The matcher skips marked/deletion-flagged rows to preserve native visual
priority, and colors only the filename span. A second matcher colors one permission
character at a time, including on marked rows. It validates the permission
field against Dired's filename boundary and respects the requested font-lock
limit. Symlink targets remain Dired's responsibility. Custom unrecognized listing
formats degrade to native Dired colors. Theme inheritance avoids copying
theme-specific color values.

The package itself performs zero filesystem/process calls when enabled,
refreshed, or fontified. Existing Dired commands and target checks may perform
I/O as usual. Remote color inheritance is explicitly local; it does not ask a
remote host for environment variables. The synthetic TRAMP test isolates our
added behavior; it is not a live remote integration test.

## Validation boundaries

Local ERT and strict byte compilation run on macOS / Emacs 31.1. GitHub Actions
workflows were removed at the user's request. Emacs 30, native Windows/Linux,
and live TRAMP compatibility still need manual validation. Synthetic TRAMP-path
fixtures verify that added coloring performs no file-stat or process calls.
Live reloads verify colors in the user's existing Evil/Dired session.

Permission validation added in 0.2 covers all nine bit keys, ux/ue distinction,
uppercase/lowercase special bits, attribute markers, inode/block prefixes,
namespace isolation, environment inheritance, refresh, disable, and native
hide-details properties.

Size research rechecked the [eza size renderer](https://github.com/eza-community/eza/blob/main/src/output/render/size.rs)
on 2026-10-15: raw byte counts select styles with binary prefixes; displayed
units and numbers have separate styles. Our raw counts use exact integer
thresholds. Rounded human-readable values use the displayed unit category.
Size extraction anchors to known timestamp syntax immediately before the
filename, after the displayed permission field. This avoids assumptions about
owner/group column counts. Unknown timestamp formats and device IDs are
skipped. Both numeric and unit spans respect font-lock limits. ERT covers
boundaries, decimal/binary units, umbrella order, numeric IDs, device IDs,
invisibility, refresh, disable, and unsupported formats.

Ownership and timestamp research rechecked eza's documented `uu/uR/un`,
`gu/gR/gn`, and `da` keys and its user/group renderers on 2026-10-15.
The local identity snapshot uses effective IDs. Group membership automatically
covers the primary group; supplementary groups need a configured complete list.
Remote identity is not inferred from local accounts. Local root aliases come
from ID zero; native Windows does not use Unix root semantics. Owner fields
must match the expected column count after link count and before size; skip
author/context columns and ambiguous names with spaces. Dates reuse the size
module's timestamp grammar and are rendered uniformly, without age queries.
Both owner and timestamp colors can be disabled independently.

## Test organization and local commands

The six module-specific files in `test/` share `dired-eza-test-helper.el`.
`dired-eza-test.el` remains the complete suite entry point, preserving direct
Emacs invocation. Individual module files can also be loaded independently.
The Makefile offers optional local commands; `make check` serializes source
ERT, strict runtime compilation, compiled ERT, and cleanup. No workflows or
Git hooks are installed. CHANGELOG.md records development changes separately
from the feature roadmap and does not imply an archive or tagged release.
