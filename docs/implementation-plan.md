# Implementation plan

This is the ordered release roadmap. It retains completed phases so their
dependencies, deliverables, and exit gates remain visible. Required behavior
belongs in the feature specifications; current status also appears in
[`current.md`](current.md).

## Delivery principles

- Build observable vertical slices.
- Establish measurement correctness before presentation polish.
- Use recorded metric timelines as test evidence.
- Prefer public macOS APIs and represent unavailable values honestly.
- Record exit-gate evidence in [`progress.md`](progress.md).

## Phase 0 — Product and specification foundation

Status: Verified

Deliverables:

- Product concept.
- Documentation map and update rules.
- Release scope and feature specifications.
- Architecture and implementation sequence.

Exit gate:

- Specifications have no known product contradictions.
- Decisions required for scaffolding are resolved.

## Phase 1 — Native application foundation

Status: Verified

Dependencies: Phase 0

Deliverables:

- Native Swift macOS project.
- SwiftUI app shell with Now and Tests destinations, with Saved Results
  integrated into Tests.
- Dependency setup, including GRDB.
- Domain types and protocol boundaries.
- Unit-test target and development fixtures.

Exit gate:

- The app builds and launches.
- Now, Tests, and Saved Results are navigable.
- Domain and persistence tests pass.

## Phase 2 — Process discovery and sampling

Status: Verified

Dependencies: Phase 1

Deliverables:

- Running application discovery.
- PID enumeration and stable process identity.
- CPU, memory, disk, wakeup, process, and thread sampling.
- Delta calculation and handling for exited or restarted processes.
- Sampler overhead measurement.

Exit gate:

- Samples are correct against known test workloads.
- Unavailable or inaccessible processes are represented explicitly.
- Ordinary collection remains within the performance budget.

## Phase 3 — Application grouping

Status: Verified

Dependencies: Phase 2

Deliverables:

- Bundle, path, ancestry, and helper-based ownership rules.
- Group confidence and evidence.
- Include, exclude, and reset manual overrides.
- Grouped live metrics.

Exit gate:

- Native, Electron/browser, and helper-heavy fixtures group correctly.
- Ambiguous processes never silently receive a high-confidence owner.

## Phase 4 — Now vertical slice

Status: Verified

Dependencies: Phases 2 and 3

Deliverables:

- Live application dashboard list.
- Metric representation switching and defaults.
- Expandable process details.
- Sorting, searching, and explicit unavailable states.
- A bounded live-total timeline with optional per-application lines and fitted
  or system-capacity scaling for CPU and memory.

Exit gate:

- The acceptance criteria in `specifications/now.md` pass.
- Live values update without disruptive movement or excessive overhead.
- The live timeline remains in memory and does not become a saved result.

## Phase 5 — Test engine and manual controlled tests

Status: Verified

Dependencies: Phases 2 through 4

Deliverables:

- Test creation and selection of one to four applications.
- Manual rounds, warm-up, compact recording prompt, and optional configurable
  global shortcut.
- Test metric persistence and result summaries.
- Multiple rounds and combined results.

Exit gate:

- A one-application and a two-application manual test can be completed and
  revisited.
- Interrupted and cancelled tests recover without corrupting saved data.

## Phase 6 — Automatic foreground-idle controlled tests

Status: Verified

Dependencies: Phase 5

Deliverables:

- Equal-duration foreground rotation across selected applications.
- Activation confirmation, bounded retries, and visible failure states.
- Warm-up and repeated rounds.
- Clear “Foreground idle” result labeling.

Exit gate:

- A complete unattended test works without Accessibility permission on
  supported macOS versions, or the constraint is documented and respecified.

## Phase 7 — Test result metric timelines

Status: Verified

Dependencies: Phases 2, 5, and 6

Deliverables:

- A metric selector for CPU, memory, disk, wakeups, and process count.
- Swift Charts timelines over measured elapsed time.
- A synchronized cursor showing exact metric values, elapsed time, and clock
  time.
- Shared scales for side-by-side results with an explicit independent-scale
  option.
- Foreground, warm-up, unavailable, and partial-sample presentation without
  changing raw samples.

Exit gate:

- A one-application result plots every stored metric.
- A multi-application result synchronizes its cursor and elapsed-time scale.
- Scrubbing exposes exact values and timestamps.
- Warm-up, unavailable samples, and different durations remain honest and
  distinguishable.

## Phase 8 — Saved results and cross-test comparison

Status: Verified

Dependencies: Phases 5 and 7

Deliverables:

- A library of saved controlled tests and individual application results.
- Reopening of individual saved results.
- Selection of two to four results from any tests.
- Same-application and different-application comparison.
- Elapsed-time alignment, normalized rates, and warnings based on recorded
  version, duration, mode, date, and workload note.
- Test deletion controls.

Exit gate:

- Results from unrelated tests can be compared without modifying raw data.
- Same-application results from separate tests can be compared.
- Different durations show totals and normalized rates.
- Deleting one test removes its records and summary folder without affecting
  another test.
- Browsing Saved Results never starts persistent sampling.

## Phase 9 — Hardening and GitHub release

Status: Ready for distribution

Dependencies: Phases 7 and 8

Deliverables:

- Observatory product identity and persistent appearance/launch-view Settings.
- Accessibility, keyboard navigation, and appearance review.
- Performance and long-duration reliability testing.
- Privacy disclosure and unsigned-build installation guidance.
- Release archive, checksum, and known-limitations document.

Exit gate:

- The release acceptance criteria pass on supported macOS versions.
- A clean Mac user account can install, approve, and run the release using the
  published instructions.
