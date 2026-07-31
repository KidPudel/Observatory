# Documentation map

This is the entry point for people and agents changing Observatory. Read the
smallest set of documents that can authoritatively answer the task.

## Required reading

For every implementation task:

1. Read [`current.md`](current.md).
2. Read the task-specific specification from the routes below.

Also read:

- [`concept.md`](concept.md) and
  [`specifications/release-scope.md`](specifications/release-scope.md) when
  changing product behavior or release scope;
- [`implementation-plan.md`](implementation-plan.md) when changing sequence,
  dependencies, or release scope;
- [`progress.md`](progress.md) only when historical implementation or
  verification evidence is needed.

## Task routes

| Task | Read |
| --- | --- |
| Build or launch | `scripts/run.sh` and the workflow below |
| Install, package, or publish a release | [`installation.md`](installation.md), [`privacy.md`](privacy.md), [`known-limitations.md`](known-limitations.md), and [`release-checklist.md`](release-checklist.md) |
| Visual design, layout, motion, or styling | [`visual_design_concept.md`](visual_design_concept.md) |
| App structure, dependencies, or concurrency | [`specifications/architecture.md`](specifications/architecture.md) |
| Process discovery, metrics, timelines, or grouping | [`specifications/metrics-and-grouping.md`](specifications/metrics-and-grouping.md) |
| Live application cards or process details | [`specifications/now.md`](specifications/now.md) |
| Manual or automatic controlled tests | [`specifications/sessions.md`](specifications/sessions.md) |
| Saved results or cross-test comparison | [`specifications/saved-results.md`](specifications/saved-results.md) |
| SQLite, summaries, retention, deletion, or privacy | [`specifications/storage-and-privacy.md`](specifications/storage-and-privacy.md) |

## Developer workflow

Run the Debug application from the repository root with:

```sh
./scripts/run.sh
```

The script builds the Debug application into `.build` and opens
`Observatory.app`.
Xcode is optional unless the task requires its debugger, previews, or another
IDE-only tool.

## Document roles

| Document | Authority |
| --- | --- |
| `concept.md` | Stable product purpose and principles |
| `specifications/release-scope.md` | Current release boundary and product-wide acceptance |
| Feature specifications | Required behavior and feature acceptance criteria |
| `visual_design_concept.md` | Presentation within required product behavior |
| `specifications/architecture.md` | Technical boundaries and dependency rules |
| `implementation-plan.md` | Delivery sequence, dependencies, and exit gates |
| `current.md` | Current release state and next action |
| `progress.md` | Append-only historical work and verification record |
| Release documents | User-facing privacy, installation, limitation, and packaging guidance |

When documents disagree, use this authority order:

1. the user's latest explicit decision;
2. product concept;
3. release boundary;
4. relevant feature specification;
5. visual or architecture specification within its area;
6. implementation plan;
7. current-state snapshot.

The history log never overrides an active specification.

## Update contract

After a code implementation task:

- update `current.md` only if status, next actions, or limitations changed;
- append the implementation change and its verification to `progress.md`;
- update a specification only when required behavior changed;
- update the implementation plan only when sequence, scope, or dependencies
  change.

New ideas are not active requirements. Add them to the release scope and a focused
specification only after the user places them in scope.
