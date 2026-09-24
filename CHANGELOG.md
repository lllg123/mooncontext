# Changelog

All notable changes to MoonContext are documented in this file.

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

- MoonBit toolchain: 0.10.11+6ff76a5f9.
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

[0.1.0]: https://github.com/lllg123/mooncontext/releases/tag/v0.1.0
