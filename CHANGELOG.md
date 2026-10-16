# Changelog

## Unreleased — 0.4.0 development

### Added

- DU-aware native size sorting: `-S`/`--sort=size` orders directory rows by
  cached recursive disk usage, honoring reverse order and directory grouping.
  Missing totals stay last within their group; listings re-sort after their own
  scans finish. Preserves marks, point's file and inserted subdirectory headers,
  uses listing data for ordinary files, and restores native order on disable.
- Cached sorting, completion, reverse/grouping, file units, marks/point,
  inserted subdirectory and native sort-command integration tests.

- Matching `dired-eza-dark-ls-colors` override, nil by default, with the same
  replacement, fallback, and automatic switching behavior as the light option.

- Optional `dired-eza-light-ls-colors` filename palette, defaulting to nil for
  ordinary inheritance. Light-only replacement strings and empty-string theme
  fallback switch automatically on background changes, independently of
  timestamp coloring. Dark-mode filename colors retain their existing rules.

- Default age-based timestamp shading: newer entries have stronger foreground
  contrast, fading to a gray slightly darker than the previous timestamp face.
  Added configurable fade age, opt-out, cached theme/time snapshots, visible
  date parsing with year rollover and offsets, and neutral fallback. Explicit
  `da` styles and resets retain precedence. No filesystem or remote queries.
- Timestamp parsing, palette, fade, override, cache, and lifecycle tests.

- Opt-in `dired-eza-du-mode` for cached recursive local disk usage, using a
  persistent cache and one deduplicated asynchronous worker. Fresh entries
  avoid scans; stale entries remain visible during refresh. Added TTL and
  cache-file options, explicit refresh, failure throttling, TRAMP exclusion,
  aligned size overlays, size colors, and WDired lifecycle handling.
- Focused cache persistence, freshness, background scan, column alignment,
  failure, and synthetic remote-exclusion tests.

- GitHub installation examples for built-in `use-package :vc` and straight.el,
  with update instructions and a local-checkout alternative.

- Native Dired filename colors inherited from `LS_COLORS`, including file types,
  permission-based categories, and ordered literal suffix rules.
- Safe escape and ANSI SGR parsing, including 256-color and RGB styles,
  explicit resets, and theme-based fallback faces.
- Individual permission colors using supported `EZA_COLORS` keys.
- Size colors for raw byte counts and human-readable values, with separate
  numeric/unit styles and configurable raw-byte thresholds.
- Optional owner/group colors and muted timestamp colors.
- Local identity snapshots, configurable group identities, and neutral remote
  ownership when no remote identity is supplied.
- Buffer-local minor mode with reversible font-lock integration, preserving
  native Dired operations, marked filenames, hide-details, and keyboard maps.
- ERT coverage for parsers, classification, metadata fields, mode lifecycle,
  and synthetic remote listings guarded against added filesystem/process calls.
- Local `make test`, `make compile`, `make check`, and `make clean` commands.
- Contributor instructions, design notes, and a feature roadmap.

### Fixed

- Give light-mode timestamps a distinct range: newest is darkest, fading to
  a lighter gray instead of compressing all ages toward black. Dark-mode
  timestamp shading retains its muted darker endpoint.

- Rebuild timestamp shades automatically when themes or frame colors change,
  preventing cached dark-mode whites from remaining on a light background.
  Made the oldest gray forty-five percent darker than the original timestamp gray.

- Mark development tests as source-only so package-vc installation does not
  try to compile test modules without their development load path.

### Changed

- Softened light-mode other-permission fills to pale amber, rose, and green
  with dark text; link flags use dark blue on pale blue.

- Added a contrasting light-background palette for permission bits, directory
  flags, and sizes. Native per-frame face selection follows Emacs theme and
  background-mode changes automatically.

- Permission defaults use yellow/red/green for read/write/execute, normal user
  bits, bold group bits, and filled other bits, all sharing the same palette. Missing and special bits
  keep their existing styles; explicit EZA_COLORS rules take precedence.
- Directory flags use brighter blue and bold; symlink flags use a filled
  background based on the inherited type color. Filename colors are unchanged.
- Size defaults use blue/green/yellow/red/red fill for bytes through terabytes
  and larger, for both numbers and units.

- Organized the test suite into six module-specific files with shared helpers.
  The existing `dired-eza-test` suite entry point remains available.

### Removed

- GitHub Actions workflow; validation is run locally.

### Validation

- Tested locally on macOS with Emacs 31.1, including an existing Evil/Dired
  session. The updated defaults pass all 57 ERT tests against source and compiled modules,
  plus warning-free compilation, on Linux with Emacs 31.1. Emacs 30, native
  Windows, and live TRAMP remain unverified.
- No package-archive publication or tagged release is recorded here.
