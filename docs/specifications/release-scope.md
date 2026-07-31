# Release scope

Status: Active

## Goal

Deliver a native macOS application that:

1. explains the live resource use of whole applications;
2. runs intentional one-to-four-application controlled tests;
3. plots recorded metrics over measured time;
4. reopens an individual application result later; and
5. compares it with results from other saved tests.

Observatory is a local analysis tool for developers, power users, and reviewers. It
is not a fleet-monitoring or telemetry service.

## Included

### Now

- Discover running user applications.
- Combine owned processes into application totals.
- Show CPU, memory, disk, wakeups, process count, and state.
- Expand an application into process details.
- Switch CPU representations and persist the preferred default.
- Show ownership confidence and advanced include/exclude overrides.
- Plot a bounded live total across sampled running applications for CPU,
  memory, disk I/O, wakeups, and process count.
- Optionally add labeled lines for the individual running applications without
  persisting the live timeline.
- Let CPU and memory use either a fitted vertical scale or the Mac's logical
  CPU and installed-memory capacity.

### Tests and saved results

- Select one to four running applications.
- Run one controlled test at a time in manual guided or automatic
  foreground-idle mode.
- Support optional warm-up and repeated rounds.
- Store one-second CPU, memory, disk, wakeup, process-count, and state samples.
- Show summaries and synchronized metric timelines over measured elapsed time.
- Reveal exact elapsed time, clock time, and metric values while scrubbing.
- Compare application results within a multi-application test without changing
  raw samples.
- Preserve completed controlled tests in a full-width Saved Results mode within
  Tests.
- Keep a concise Saved Results browser available beside content opened from the
  library, while the opened result or comparison remains the dominant pane;
  allow the browser to move left or right and to hide or reveal.
- Reopen a complete test with the same result presentation shown immediately
  after completion.
- Reopen individual application results.
- Compare two to four results from any saved tests, including repeated results
  for the same application.
- Align series by measured elapsed time.
- Show totals and normalized rates for different-duration results.
- Disclose differing recorded context before interpretation.
- Never start monitoring.

### Preferences

- Offer System, Light, and Dark appearance choices, defaulting to System.
- Offer Now and Tests as launch destinations, defaulting to Now.
- Migrate the retired History launch preference to Tests with Saved Results
  initially active.
- Persist all choices locally and apply appearance changes immediately.
- Keep Settings visually consistent with the main Observatory workspace.

### Storage and privacy

- Keep the SQLite catalog in private Application Support storage.
- Create a dated private summary folder containing `session.json` for every
  test.
- Retain raw test metrics until the user deletes the test.
- Provide deletion controls without affecting unrelated results.
- Keep all data local.

## Excluded

This release does not include:

- screenshots, screen recording, keyboard monitoring, or input activity traces;
- passive or silent persistent monitoring outside a user-started test;
- per-application network or GPU metrics;
- thermal attribution or literal per-application battery percentage;
- cloud upload, synchronization, sharing, or remote monitoring;
- scripted workloads, test templates, or regression alerts;
- administrator helpers;
- automatic updates, notarization, or Mac App Store distribution;
- raw-data export or re-import.

An excluded idea becomes active only after an explicit scope decision and an
updated focused specification.

## Platform boundary

- macOS 14 or later.
- Apple silicon is the primary development target.
- Intel validation does not block the first personal release.
- SwiftUI and Swift Charts behavior used by the product must work on macOS 14.
- The project must build without a paid Apple Developer Program membership.

## Product-wide acceptance criteria

- Application totals never silently include low-confidence unrelated processes.
- Metric labels explain units and aggregation windows.
- Missing measurements never appear as measured zero.
- Raw recorded samples remain unchanged during chart alignment or comparison.
- Different-duration results include normalized values.
- Result charts expose exact elapsed and clock time for recorded samples.
- Now samples are not persisted outside a controlled test.
- Observatory never requests Screen Recording or Input Monitoring permission.
- Observatory's own collection cost is not attributed to another application.
- Ordinary sampling stays within the documented performance budget.
- A saved result reopens after restarting Observatory.
- A second controlled test cannot start while one is active.
- Appearance and default-view preferences persist across launches.
