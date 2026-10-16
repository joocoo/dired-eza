# Roadmap

## 0.1 — native filenames (implemented)

LS_COLORS parser, SGR conversion, pure listing-based classifier, buffer-local
minor mode, theme fallbacks, ERT, documentation, and local validation.
No publication or hosting is assumed.

## 0.2 — EZA_COLORS permission characters (implemented)

Individual rwx and absent bits, special bits, ACL indicators, theme fallbacks,
EZA_COLORS/EXA_COLORS inheritance, explicit resets, and separate namespaces.
No added filesystem calls. The file-type indicator uses its own theme face.

## 0.3 — numeric and human-readable sizes (implemented)

Magnitude-based numeric and unit styles, umbrella keys, theme fallbacks,
1024-based raw-byte thresholds (optional 1000), and displayed-unit categories.
Conservative timestamp anchoring avoids coloring other numeric fields.
No added filesystem calls; device IDs and unrecognized formats are skipped.

## 0.4 — ownership and timestamps (implemented)

Optional owner/group and timestamp colors using `uu/uR/un`, `gu/gR/gn`, and
`da`, with theme fallbacks. Local identity and primary group are snapshotted
once per refresh; supplementary groups accept explicit configuration. Remote
identity stays neutral unless supplied. No remote identity queries are added.
GitHub Actions workflows have been removed; validation is run locally.

## Default visual distinction (implemented)

Read/write/execute use yellow/red/green, with normal user bits, bold group
bits, and filled other bits, all sharing the same palette. Size categories progress blue/green/yellow/red
and red fill. Directory flags are brighter blue and bold; symlink flags
have a filled background. Light-mode other bits and link flags use soft
fills with dark text. Explicit EZA_COLORS rules and resets retain precedence.

Light/dark face palettes follow each Emacs frame automatically, preserving role
emphasis and explicit color overrides.

## Later — remaining metadata and compatibility

Research baseline: [eza color specification](https://github.com/eza-community/eza/blob/main/man/eza_colors.5.md),
checked 2026-10-15. Recheck upstream source before implementation.

| Area | Actual keys to investigate and implement |
| --- | --- |
| Permissions (done in 0.2) | `ur/uw/ux/ue`, `gr/gw/gx`, `tr/tw/tx`, `su/sf`, `xx`, `xa` |
| Size categories (done in 0.3) | `nb/nk/nm/ng/nt`; numeric umbrella `sn`; unit keys `ub/uk/um/ug/ut` and umbrella `sb` |
| User and group fields (done in 0.4) | `uu/uR/un`, `gu/gR/gn` |
| Timestamp (done in 0.4) | `da` |

The metadata layer must parse existing listing fields without extra stats.
Test BSD/GNU/ls-lisp, numeric IDs, omitted columns, ACL markers, locale-dependent
dates, human-readable sizes, inode/block prefixes, and inserted subdirectories.
Raw sizes are already categorized without units; extend format recognition
conservatively and preserve the documented raw-byte threshold policy.
Honor hide-details by adding faces without changing invisibility.

Use a separate EZA namespace: `su` and `tw`, for example, have different roles
in LS_COLORS and EZA_COLORS. Specify EZA-over-LS filename overrides, umbrella
key ordering, and `reset` behavior explicitly. Investigate `EXA_COLORS` fallback
only when EZA_COLORS is unset. Do not introduce an eza executable dependency.

Remote identity uses supplied names/IDs or a neutral fallback. Keep that policy
when extending metadata support.

## Later

- Extend recognized types using listing-provided information when reliable;
  design any optional symlink/capability lookups separately with explicit costs.
- Profile large directories and large suffix sets before adding caches.
- Manually verify Evil, live TRAMP, terminal themes, and native Windows Dired.
- Add package metadata and release packaging once maintainer identity and
  hosting are chosen. Validate with package-lint at that point.
- Publish to an archive so the documented `:ensure t` configuration can work.

## Optional cached recursive disk usage (implemented)

Separate opt-in `dired-eza-du-mode` with a persistent shared cache, configurable
TTL, stale values during background refresh, manual rescan, and one deduplicated
local `du -sk` worker. TRAMP, symlinks, and dot entries are excluded. Shared-width
overlays preserve native listings, size colors, hide-details, and WDired.
Default coloring remains free of scans. Native sorting uses original sizes;
filesystem watching, cross-process cache merging, and Windows validation remain
outside this implementation.
