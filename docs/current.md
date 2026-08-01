# Current state

Last updated: 2026-08-01

Observatory `0.1.1` is feature-complete and published on GitHub. It packages
the post-release high-priority reliability hardening described below.

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

The `main` branch and latest downloadable GitHub release are `0.1.1` at
[github.com/KidPudel/Observatory](https://github.com/KidPudel/Observatory).

The release is versioned as build 2 and has passed automated tests,
sampler-budget measurement, optimized universal archiving, code-signature
verification, and checksum verification. Publication was explicitly approved
with hands-on validation still outstanding. The remaining post-release checks
are targeted validation of the hardening changes and clean-account installation
through the [`installation guide`](installation.md). Track those checks in
[`release-checklist.md`](release-checklist.md).

Current user-facing constraints are kept in
[`known-limitations.md`](known-limitations.md).
