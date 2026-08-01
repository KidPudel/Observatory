# Current state

Last updated: 2026-08-01

Observatory 0.1 is feature-complete and published on GitHub. The source tree
also contains post-release high-priority reliability hardening that has not yet
been packaged into a new downloadable archive.

## Included

- Live application totals and process details.
- A 60-second live chart.
- Manual and automatic controlled tests.
- Saved results, timelines, and comparisons.
- Local storage, test deletion, and grouping rules.
- System, Light, and Dark appearances.
- Keyboard and VoiceOver support.
- Release archive and checksum tooling.
- Observatory project, scheme, modules, source folders, and private storage
  identity throughout.
- Atomic controlled-test creation and cancellation-safe sample cleanup.
- Monotonic controlled-test timing with clock-change-safe result ordering.
- Raw per-interval controlled-test metrics with round-boundary counter resets.
- Explicit storage failure reporting instead of temporary or in-memory results.
- A single app window and refreshed foreground/running-application state.

The active product contract is in [`release-scope.md`](specifications/release-scope.md)
and the feature specifications. Verification history is in
[`progress.md`](progress.md).

## Release

The source repository and downloadable `0.1.0` archive are published at
[github.com/KidPudel/Observatory](https://github.com/KidPudel/Observatory).

The remaining release gates are to perform targeted hands-on validation of the
hardening changes, then use the
[`installation guide`](installation.md) to validate the archive on a clean
macOS account. Track that check in
[`release-checklist.md`](release-checklist.md).

Current user-facing constraints are kept in
[`known-limitations.md`](known-limitations.md).
