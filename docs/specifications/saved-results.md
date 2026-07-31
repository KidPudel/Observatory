# Saved Results specification

Status: Active

## Purpose

Saved Results is a full-width library mode inside Tests containing completed
controlled tests and their individual application results. It never starts
persistent sampling. Entering it replaces the setup presentation without
discarding the current setup draft. Opening a complete test, individual result,
or comparison changes the library into a concise contextual browser beside the
dominant inspection pane. Done restores the full-width library. New Test closes
the library, any open inspection, and transient comparison selection, then
returns to the preserved setup. The contextual browser defaults to the right;
the user may move it left or right, hide it so the inspection regains the full
width, and reveal it on the chosen side. Side choice persists locally.

## Empty state

When no saved tests exist, Saved Results explains that completed controlled
tests will appear there and keeps New Test directly available.

## Result library

Each application measured in a test produces a selectable result. The library
supports finding results by recorded:

- application and version;
- test name;
- date;
- mode;
- duration;
- workload note.

The interface distinguishes an individual round from a combined-round result.
Opening a test shows the same complete result presentation used immediately
after test completion. Opening an application result shows its summaries and
synchronized metric timelines.
Each saved test uses one compact ledger surface. Its application results are
separator-based rows rather than nested cards: the primary row action opens the
result, while a distinct trailing control adds or removes it from comparison.
The test header has an explicit action to open the complete test. Comparison
selection is entered through a labeled mode control; selection controls and the
contextual action tray are hidden during ordinary browsing.

During inspection, the concise browser retains search, complete-test opening,
individual-result switching, and comparison selection. It omits wide summary
metrics and destructive controls so it remains secondary to the result or
comparison. Its move, hide, and reveal controls remain explicit and keyboard
reachable. The complete library regains the full content width when the
inspection closes.

## Historical comparison

The user may select two to four application results from any saved tests,
including:

- different applications from unrelated tests;
- the same application before and after an update;
- the same application with different settings;
- repeated results from one test or separate tests.

Comparison behavior:

- series align at measured elapsed time zero;
- warm-up is hidden by default but may be shown;
- shorter results end rather than being stretched;
- averages and rates use each result's measured duration;
- cumulative totals appear with normalized rates where appropriate;
- raw samples are never destructively resampled;
- recorded application version, duration, mode, date, and workload note remain
  visible;
- materially differing recorded context produces a warning without blocking
  comparison;
- different application identities are expected and never produce a warning by
  themselves;
- application-version differences warn only when results for the same
  application identity use different versions.

Charts provide synchronized metric selection and scrubbing consistent with a
completed result in Tests.

## Deletion

- Deleting a test requires confirmation.
- Deletion removes that test, its application results, raw samples, and private
  summary folder.
- Deleting one test does not affect unrelated results.

## Acceptance criteria

- Opening or browsing Saved Results never starts persistent sampling.
- Done from a saved test, individual result, or comparison restores the
  full-width Saved Results library.
- New Test closes all Saved Results inspection and comparison-selection state
  while preserving the test-setup draft.
- The concise browser can move left or right, hide, and reveal without closing
  the inspected result; its chosen side survives relaunch.
- A saved result reopens after restarting Observatory.
- Same-application results from separate tests can be compared.
- Different-application results from unrelated tests can be compared.
- Different durations show totals and normalized rates without stretching raw
  samples.
- Exact recorded values, elapsed time, and clock time remain inspectable.
- Missing collection is distinguishable from measured zero.
- Differing recorded context is visible before interpretation.
- Deleting one test preserves all unrelated tests.
