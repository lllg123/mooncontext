# Changelog

All notable changes to MoonContext are documented in this file.

## [0.2.0] - 2026-10-13

- Added a native Git-snapshot gate that reads ordinary blobs from a reviewed
  full commit, rejects symlinks and traversal paths, and pins each source ID
  to an exact SHA-256 digest before approving a final context.
- Added rule-field checks so cited code may contain literal template syntax
  or instruction-only markers without bypassing global secret markers.
- Replaced the print-only release demonstration with a verified local build
  artifact; CI exercises failure paths and uploads only the approved example.
- Added regression tests for stale pins, unknown revisions, unpinned citations,
  fenced code examples, and missing system rules.

## [0.1.0] - 2026-09-24

The first release focused on deterministic auditing at the boundary between a
rendered context and a model request.

### Added

- Human-readable and JSON audit reports for Markdown and plain-text artifacts.
- Versioned JSON policies with character budgets, required markers, forbidden
  markers, and strict warning handling.
- Batch auditing with per-artifact results, aggregate summaries, and explicit
  unreadable-input errors.
- SHA-256 fingerprints for connecting a report to the exact UTF-8 text that
  was audited.
- A diff command for comparing single or batch reports across builds.
- Stable diagnostic codes, source positions, exit statuses, and production
  workflow documentation.

### Verification

- MoonBit toolchain: 0.10.14+7d59c7ec9.
- Pinned dependency resolution through moon update.
- Formatting, type checking, all-target builds, tests, and fresh-checkout
  audit examples verified before tagging.

### Known limitations

- The release contains source code and a CLI workflow; it does not publish
  platform-specific binaries.
- The audit command checks explicit input paths and does not discover files
  from a directory implicitly.
- A report fingerprint supports build traceability but is not a digital
  signature or an authorization decision.
