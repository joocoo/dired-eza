# dired-eza

eza-like colors for Emacs Dired

Version **0.4.0** is an independent Emacs Lisp minor-mode package. It is
not eza and is not affiliated with the eza project. It adds filename colors
to native Dired using `LS_COLORS`, and metadata colors using `EZA_COLORS`,
with Emacs theme faces as fallbacks.
It has no runtime dependencies outside Emacs built-ins.

Targets: **Emacs 30.1+ and 31**, on Linux, macOS, and Windows. Local validation
uses Emacs 31.1 on macOS. Emacs 30, native Windows/Linux, and live TRAMP sessions
remain manual compatibility checks. Evil is exercised in the user's running
Emacs session; it is not a package dependency. Tests include synthetic remote
listings and Windows-style case comparisons.

There are no GitHub Actions workflows or automatic Git hooks. Run the local
checks below before pushing.

## Install and enable

This initial checkout is **not published to a package archive**. Add its
directory to `load-path`, or use this local installation configuration:

```emacs-lisp
(use-package dired-eza
  :load-path "/absolute/path/to/dired-eza"
  :ensure nil
  :hook (dired-mode . dired-eza-mode))
```

Once available in a configured package archive, the intended configuration is:

```emacs-lisp
(use-package dired-eza
  :ensure t
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
faces provide colors immediately. To override only this package:

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
Run `M-x dired-eza-refresh` after changing color strings.

## Size colors

Sizes now use five magnitude categories, with distinct theme fallbacks:
`dired-eza-size-byte`, `dired-eza-size-kilo`, `dired-eza-size-mega`,
`dired-eza-size-giga`, and `dired-eza-size-tera`. The last also covers larger
units. Dired still controls the display format (for example, `-alh`).

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

From the repository root, with Emacs on your executable search path:

```sh
emacs --batch -Q -L . -L test -l dired-eza-test -f ert-run-tests-batch-and-exit
```

On macOS, if needed, replace `emacs` with
`/Applications/Emacs.app/Contents/MacOS/Emacs`.

Compile with warnings treated as errors:

```sh
emacs --batch -Q -L . --eval '(setq byte-compile-error-on-warn t)' \
  -f batch-byte-compile dired-eza-colors.el dired-eza-classify.el dired-eza-permissions.el dired-eza-size.el dired-eza-metadata.el dired-eza.el
```

Tests exercise parsing, style conversion, precedence, size thresholds and
units, timestamp formats, numeric IDs, device exclusions, real Dired font-lock,
enable/disable/refresh, marked files, hide-details, buffer-local isolation,
native `ls-lisp` listings/reverts, and a synthetic TRAMP-path buffer with
filesystem/process functions guarded. That test disables Dired's own symlink
checks to isolate added work. It does not contact a remote host.

## Architecture and research

Six small modules separate parsing, pure classification, permission styles,
size styles, owner/date styles, and Dired rendering.
See [docs/DESIGN.md](docs/DESIGN.md) for the research sources and design choices.
The project brief for continued work is [docs/PROJECT.md](docs/PROJECT.md).

## License

GPL-3.0-or-later; see [LICENSE](LICENSE). This is the initial project license
choice, consistent with the Emacs package ecosystem. No external source code
has been vendored into the implementation.
