# Changelog

## Unreleased — 0.4.0 development

### Added

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

### Changed

- Organized the test suite into six module-specific files with shared helpers.
  The existing `dired-eza-test` suite entry point remains available.

### Removed

- GitHub Actions workflow; validation is run locally.

### Validation

- Tested locally on macOS with Emacs 31.1, including an existing Evil/Dired
  session. Emacs 30, native Linux/Windows, and live TRAMP remain unverified.
- No package-archive publication or tagged release is recorded here.
