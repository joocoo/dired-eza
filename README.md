# dired-eza

eza-like colors for Emacs Dired

> **Issues and pull requests are not monitored and will be ignored.**

Version **0.4.0** is an independent Emacs Lisp minor-mode package. It is
not eza and is not affiliated with the eza project. It adds filename colors
to native Dired using `LS_COLORS`, and metadata colors using `EZA_COLORS`,
with Emacs theme faces as fallbacks.
It has no runtime dependencies outside Emacs built-ins.

Targets: **Emacs 30.1+ and 31**, on Linux, macOS, and Windows. Local validation
uses Emacs 31.1 on macOS and Linux. Emacs 30, native Windows, and live TRAMP sessions
remain manual compatibility checks. Evil is exercised in the user's running
Emacs session; it is not a package dependency. Tests include synthetic remote
listings and Windows-style case comparisons.

There are no GitHub Actions workflows or automatic Git hooks. Run the local
checks below before pushing.

## Install and enable

The package is hosted at [joocoo/dired-eza](https://github.com/joocoo/dired-eza).
It is not published to a package archive. Choose one installation method.
Git is required to install or update from the repository; coloring itself
requires only Emacs built-ins.

### Built-in VC installation (Emacs 30 and 31)

```emacs-lisp
(use-package dired-eza
  :vc (:url "https://github.com/joocoo/dired-eza.git"
       :branch "main"
       :rev :newest)
  :hook (dired-mode . dired-eza-mode))
```

This uses Emacs's built-in package manager and installs the latest commit
from `main`. The `:vc` keyword handles installation; no package-archive entry
or local `:load-path` is needed. `:rev :newest` selects the current commit on
initial installation; it does not update the package on every startup.
To fetch updates, use `M-x package-vc-upgrade RET dired-eza RET` and restart
Emacs to ensure all definitions come from the updated package.
See the [use-package installation manual](https://www.gnu.org/software/emacs/manual/html_node/use-package/Install-package.html).

### straight.el

If you already use [straight.el](https://github.com/radian-software/straight.el),
place this declaration after its bootstrap and use-package integration:

```emacs-lisp
(use-package dired-eza
  :ensure nil
  :straight (:type git :host github :repo "joocoo/dired-eza"
             :branch "main" :files ("dired-eza*.el"))
  :hook (dired-mode . dired-eza-mode))
```

This recipe includes all runtime modules. Update with
`M-x straight-pull-package RET dired-eza RET`, then restart Emacs.

### Local development checkout

```emacs-lisp
(use-package dired-eza
  :load-path "/absolute/path/to/dired-eza"
  :ensure nil
  :hook (dired-mode . dired-eza-mode))
```

Without `use-package`:

```emacs-lisp
(add-to-list 'load-path "/absolute/path/to/dired-eza")
(autoload 'dired-eza-mode "dired-eza" nil t)
(add-hook 'dired-mode-hook #'dired-eza-mode)
```

Use `M-x dired-eza-mode` to toggle the mode in one Dired buffer.

## Color inheritance

By default the package reads `LS_COLORS` from **Emacs's process environment**.
A graphical Emacs may not inherit the environment of your interactive shell.
You can set it in Emacs or set a package-specific override:

```emacs-lisp
(setq dired-eza-ls-colors
      "di=1;34:ln=36:ex=32:*.el=38;5;141:*.md=38;2;100;180;210")
```

`nil` means inherit `LS_COLORS`; `""` means use theme fallbacks.
Run `M-x dired-eza-refresh` in each enabled buffer after changing the value
or environment. Rules are parsed once per enable/refresh, not per filename or metadata field.
Ordinary Dired reverts reuse the parsed rules and recolor the new listing.
Theme fallbacks reference named faces, so theme changes do not require parsing.

| Supported rule | Meaning |
| --- | --- |
| `fi`, `di`, `ln` | Regular file, directory, symlink |
| `pi`, `so`, `bd`, `cd` | Pipe, socket, block device, character device |
| `ex`, `su`, `sg` | Executable, setuid file, setgid file |
| `tw`, `ow`, `st` | Sticky and other-writable, other-writable, sticky directory |
| `no` | Default style when no more specific rule applies |
| `*suffix` | Literal filename suffix, including compound suffixes |

Suffixes apply to regular files. Configured non-reset setuid, setgid, and
executable rules take precedence, in that order. Directory precedence is
`tw`, `ow`, `st`, then `di`. The last valid type definition or matching suffix
wins; longest suffix does not automatically win. Suffixes match without case
distinction unless differently styled case variants of that suffix exist;
then that suffix family matches exactly. This follows modern GNU `ls`.
`*a?b` matches the literal ending `a?b`, not the shell pattern `a?b`.

Empty values and `0` explicitly reset to the default face. Reset special
permission rules disable that category, allowing ordinary type/suffix rules.
Malformed entries are skipped individually. Escaped delimiters, backslashes,
octal, hex, and caret escapes are decoded without evaluating Lisp or shell
text. SGR supports standard/bright foreground and background colors, xterm
256 colors, RGB, bold, dim weight, italic, underline, reverse, strike-through,
and their resets. Unsupported numeric SGR attributes are ignored; malformed
extended colors reject the entry. Blink and conceal are not rendered.
The first 16 colors use a fixed ANSI palette; terminal display may approximate
colors according to its capabilities.

Fallback faces: `dired-eza-file`, `dired-eza-directory`, `dired-eza-symlink`,
`dired-eza-executable`, and `dired-eza-special`. Customize them via
`M-x customize-group RET dired-eza`.

## Permission colors

Permission characters are colored individually: read, write, execute, missing
bits (`-`), special bits (`s/S/t/T`), and optional ACL/attribute markers
(`+`, `@`, `.`). Owner, group, and other bits can each have distinct colors.
The file-type character has its own theme fallback. No per-file metadata is fetched.

By default, permission colors inherit `EZA_COLORS` from Emacs, or `EXA_COLORS`
when EZA_COLORS is unset. Without those variables, theme-based permission
faces provide colors immediately: read is yellow, write red, and execute green.
All three permission groups share the same palette. User bits have
normal weight, group bits are bold, and other bits use the
permission color as a background fill. Missing and special bits retain their
separate styles. The `d` directory flag is brighter blue and bold; the `l`
symlink flag uses a filled background. Explicit rules
replace this default role emphasis, including explicit resets.
To override only this package:

```emacs-lisp
(setq dired-eza-eza-colors
      "ur=33:uw=31:ux=32:ue=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32:su=35:sf=35:xx=90:xa=36")
```

Supported keys: `ur/uw/ux/ue`, `gr/gw/gx`, `tr/tw/tx`, `su/sf`, `xx`, and
`xa`. The meanings follow the [eza permission color specification](https://github.com/eza-community/eza/blob/main/man/eza_colors.5.md).
These rules are parsed separately from LS_COLORS, whose `su` and `tw` mean
something different. EZA filename keys and unsupported metadata keys are ignored. Empty or zero values explicitly reset a bit's color; `reset` resets
all supported permission keys, followed by any explicit overrides.

Customize `dired-eza-permission-read`, `dired-eza-permission-write`,
`dired-eza-permission-execute`, `dired-eza-permission-special`,
`dired-eza-permission-missing`, `dired-eza-permission-type`, and
`dired-eza-permission-attribute` to adjust the theme fallbacks.
`dired-eza-permission-directory` and `dired-eza-permission-symlink` control
the directory and link flags independently of filename colors.
`dired-eza-permission-group-read`, `dired-eza-permission-group-write`, and
`dired-eza-permission-group-execute` inherit the shared permission colors by default and allow group-specific customization.
`dired-eza-permission-group` controls bold emphasis and
`dired-eza-permission-other` controls fill emphasis. The
`dired-eza-permission-other-read`, `-write`, and `-execute` faces provide pale
fills in light mode; dark mode uses reverse video.
Run `M-x dired-eza-refresh` after changing color strings.

## Size colors

Sizes now use five magnitude categories, with distinct theme fallbacks:
`dired-eza-size-byte`, `dired-eza-size-kilo`, `dired-eza-size-mega`,
`dired-eza-size-giga`, and `dired-eza-size-tera`. The last also covers larger
units. Defaults are blue for bytes, green for kilobytes, yellow for megabytes,
red for gigabytes, and a red background fill for terabytes and larger. Both
numbers and units use these defaults. Explicit numeric/unit rules replace
these defaults, including the fill. Color displays use light/dark palettes while
monochrome displays retain theme-inheriting fallbacks.
Dired still controls the display format (for example, `-alh`).

EZA_COLORS keys `nb/nk/nm/ng/nt` set numeric styles; `ub/uk/um/ug/ut` set unit
styles. `sn` sets all numeric styles and `sb` all unit styles, in input order.
For example, append this to your existing `dired-eza-eza-colors` value:

```text
nb=90:nk=36:nm=32:ng=33:nt=1;31:sb=35
```

Raw integer byte counts use powers of 1024, matching eza's raw-byte behavior.
Set `dired-eza-size-base` to 1000 for decimal thresholds, then refresh.
Human-readable sizes use their displayed unit: `1.5K` and `999K` are both in
kilobytes; `1M` is megabytes. Rounding prevents recovering exact byte counts
from a listing, so the package does not attempt to do that. Binary suffixes
such as `MiB` and decimal commas such as `1,5K` are recognized too.

Size fields are anchored to recognized timestamps and Dired's filename
boundary. This handles standard BSD/GNU/ls-lisp dates, long/full ISO dates,
numeric owners, omitted ownership columns, ACL flags, and inode/block prefixes.
Device IDs, grouped raw counts such as `1,234`, and unknown date formats are
left with native highlighting. Directories retain their displayed size and
can be colored just like files. No filesystem lookups are added.

## Cached directory disk usage (optional)

`dired-eza-mode` keeps its default coloring behavior without scans. Enable the
separate `dired-eza-du-mode` to show recursive **allocated disk usage** for local
directories in the size column:

```emacs-lisp
(use-package dired-eza
  :vc (:url "https://github.com/joocoo/dired-eza.git"
       :branch "main" :rev :newest)
  :hook ((dired-mode . dired-eza-mode)
         (dired-mode . dired-eza-du-mode)))
```

Or run `M-x dired-eza-du-mode` in a local Dired buffer. The mode silently stays
off for TRAMP. It requires a local GNU or BSD/macOS `du` supporting `-sk`;
`dired-eza-du-program` selects the executable. Native Windows needs a compatible
`du`; Windows behavior has not been verified. No shell or Lisp scanning fallback
is used. Ordinary files retain their listing sizes, which can be apparent sizes
rather than allocated space. Dot entries and symlinks are never scanned.

Cached sizes appear immediately, including stale entries. Missing sizes show
`…` while a **single asynchronous worker** calculates them; failures show `?`
or retain the last successful total. Requests for the same path are shared
across buffers. Scans continue when navigating away so revisiting can use the
result, even with `dired-kill-when-opening-new-dired-buffer` enabled. Background
scanning still uses disk I/O, and the first measurement of a large tree takes
time. Unknown listing layouts are skipped.

The cache survives Emacs restarts in `dired-eza-du-cache-file` (by default
`cache/dired-eza-du.eld` under `user-emacs-directory`). Set the option to nil
for memory-only caching. The file contains local directory paths and totals,
is read as data, and is written atomically after idle time or on Emacs exit.
Entries older than a week are omitted when saving. Separate Emacs processes
do not merge simultaneous cache writes; the last writer wins.

`dired-eza-du-cache-ttl` defaults to **600 seconds**. Reopening or reverting a
listing refreshes expired entries in the background; there is no filesystem
watcher or periodic rescan. Changes deep inside a folder can leave totals stale
until expiry or a manual refresh. Run `M-x dired-eza-du-refresh` to force a
rescan while retaining the previous values. Failed scans are throttled for the
same interval and are not persisted.

All recognized size fields share a padded column, keeping dates and filenames
aligned as results arrive. Display overlays preserve listing text, point,
marks, hide-details, and file operations, and disappear when the mode is
disabled. WDired temporarily hides them and restores them after returning to
Dired. Dired sorting still uses its original listing values, not cached totals.

## Light and dark backgrounds

Permission colors, directory flags, and sizes automatically follow each Emacs
frame's background mode. Light backgrounds use darker gold (`#806000`), red
(`#b02020`), green (`#006b2d`), and blue (`#1464a0`) for contrast; dark backgrounds
keep the brighter palette. Normal user bits, bold group bits, and filled other
bits retain their distinction in both modes. Light-mode other bits use pale
amber, rose, and green fills with dark text, avoiding heavy solid blocks.
The link flag uses dark blue text on pale blue in light mode.

Emacs reevaluates the face specifications when themes/background modes change;
no package refresh or polling is needed. This follows Emacs's background mode,
not the operating system's appearance independently. Theme-inherited faces continue to follow their theme; the dark-mode link
flag inherits its type color. Explicit
`LS_COLORS`/`EZA_COLORS` colors and customized faces retain precedence.

## Optional ownership and timestamp colors

Owner/group columns now distinguish your identity, root, and other identities.
Timestamps use a muted `shadow`-based face so filenames remain prominent.
Both are enabled by default and can be switched off independently:

```emacs-lisp
(setq dired-eza-color-ownership nil)  ; omit this to keep owner/group colors
(setq dired-eza-color-timestamps nil) ; omit this to keep date colors
```

Run `M-x dired-eza-refresh` after changing options. Override colors with
EZA_COLORS keys `uu/uR/un` (self/root/other owner), `gu/gR/gn`
(member/root/other group), and `da` (whole timestamp). The fallback faces are
`dired-eza-owner-self`, `dired-eza-owner-root`, `dired-eza-owner-other`,
`dired-eza-group-member`, `dired-eza-group-root`, `dired-eza-group-other`,
and `dired-eza-timestamp`.

Local user and primary-group names/IDs are captured once per refresh with
Emacs built-ins. No subprocesses or per-file identity lookups are added.
Supplementary groups are not automatically enumerated: set
`dired-eza-group-identities` to a complete list of group names and numeric ID
strings to include them. `dired-eza-user-identities` similarly overrides the
current user's recognized names/IDs. Current identity/membership takes priority
when it is also root. Unix root detection is disabled on native Windows;
Windows user/group names compare without case distinction.

TRAMP ownership is neutral by default. Supply those identity lists
buffer-locally to recognize a remote user or groups; the package does not use
your local account for a remote host or query the host for identity. Remote
root identities are not inferred. Timestamp and size colors still work.

Owner/group extraction honors omitted columns (`-g`, `-o`, GNU `-G`,
`--no-group`) and skips ambiguous layouts, names with spaces, author/context
columns, or unknown timestamps. BSD `-G` with both ownership columns retains
both fields. Timestamp styling is uniform through `da`, without parsing ages
or fetching modification times.

## Native Dired behavior

The mode adds buffer-local font-lock matchers using Dired's filename boundary
helpers. It leaves listing contents, sorting, operations, keyboard maps, and
hide-details properties intact. Marked and deletion-flagged rows keep Dired's
own highlighting. Disabling the mode removes its rules and refontifies.
Unrecognized listing rows are skipped. Filename quoting, `-F` indicators,
inserted subdirectories, and platforms' listing formats are delegated to Dired.

Classification uses the permission string already in the buffer. The package
does not run `ls`, `eza`, or a shell, and does not call file-stat functions.
Native Dired may still run its own listing processes and symlink checks;
their settings are unchanged. TRAMP buffers inherit the local Emacs color
environment, with no remote environment query or added target checks.

### Explicit 0.4 limits

- EZA_COLORS support covers permissions, sizes, ownership, and timestamps.
  Additional metadata and filename overrides remain in [ROADMAP.md](ROADMAP.md).
- `ln=target`, orphan (`or`), missing (`mi`), capabilities (`ca`), multiple hard
  links (`mh`), and doors (`do`) are not implemented. They are ignored; symlinks
  keep the last valid `ln` style or their theme fallback. No target is inspected.
- Control wrappers (`lc`, `rc`, `ec`, `rs`, `cl`) are ignored. Terminal control
  bytes are never inserted into the buffer.
- eza's extension defaults, arbitrary globs, theme files, icons, Git columns,
  and color gradients are outside 0.4. `LSCOLORS` (BSD's other format) is not
  `LS_COLORS` and is not parsed.
- Other packages replacing Dired font-lock may compete with this mode.

## Development and tests

With Make installed, run these commands from the repository root:

```sh
make test     # run ERT against the current source/compiled modules
make compile  # byte-compile with warnings treated as errors
make check    # test source, compile, test compiled modules, then clean
make clean    # remove this package's generated .elc files
```

Choose an Emacs executable when it is not on PATH:

```sh
make EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs check
```

Make is an optional development convenience, not a runtime dependency. The
following direct Emacs commands also work without Make, including on Windows.
From the repository root, with Emacs on your executable search path:

```sh
emacs --batch -Q -L . -L test -l dired-eza-test -f ert-run-tests-batch-and-exit
```

On macOS, if needed, replace `emacs` with
`/Applications/Emacs.app/Contents/MacOS/Emacs`.

Compile with warnings treated as errors:

```sh
emacs --batch -Q -L . --eval '(setq byte-compile-error-on-warn t)' \
  -f batch-byte-compile dired-eza-colors.el dired-eza-classify.el dired-eza-permissions.el dired-eza-size.el dired-eza-metadata.el dired-eza-du.el dired-eza.el
```

The suite entry point `test/dired-eza-test.el` loads seven focused test files:

- `test/dired-eza-colors-test.el`
- `test/dired-eza-classify-test.el`
- `test/dired-eza-permissions-test.el`
- `test/dired-eza-size-test.el`
- `test/dired-eza-metadata-test.el`
- `test/dired-eza-mode-test.el`
- `test/dired-eza-du-test.el`

Shared fixtures live in `test/dired-eza-test-helper.el`. To run one module:

```sh
emacs --batch -Q -L . -L test -l dired-eza-size-test -f ert-run-tests-batch-and-exit
```

Tests exercise parsing, style conversion, precedence, size thresholds and
units, timestamp formats, numeric IDs, device exclusions, real Dired font-lock,
enable/disable/refresh, marked files, hide-details, buffer-local isolation,
native `ls-lisp` listings/reverts, and a synthetic TRAMP-path buffer with
filesystem/process functions guarded. That test disables Dired's own symlink
checks to isolate added work. It does not contact a remote host.

## Architecture and research

Seven small modules separate parsing, pure classification, permission styles,
size styles, owner/date styles, optional cached disk usage, and Dired rendering.
See [docs/DESIGN.md](docs/DESIGN.md) for the research sources and design choices.
The project brief for continued work is [docs/PROJECT.md](docs/PROJECT.md).
Development changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## License

GPL-3.0-or-later; see [LICENSE](LICENSE). This is the initial project license
choice, consistent with the Emacs package ecosystem. No external source code
has been vendored into the implementation.
