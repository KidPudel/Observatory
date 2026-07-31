# Controlled tests specification

Status: Active

## Purpose

The Tests destination deliberately records one or more applications over time.
A test with one application investigates that application by itself. A test
with two to four applications also supports side-by-side analysis.

Users select one to four applications. A saved result belongs to one application
within a test so it can later be opened or compared independently.

Every recording created in Tests is a controlled test with one of two modes:

1. **Manual guided:** the user foregrounds and operates each target application.
2. **Automatic foreground idle:** Observatory foregrounds each target for an equal
   measured interval without simulating input.

Saved Results within Tests does not record activity. Its library is full-width
until a saved test, individual result, or comparison opens; during inspection
it becomes a concise contextual browser beside the dominant result pane.

## Test setup

The setup screen collects:

- one to four running applications;
- test name;
- manual guided or automatic foreground-idle mode;
- optional note describing the workload or test purpose.

Application selection leads the setup flow. A compact method shelf and the
timing controls follow so the user first establishes what will be tested and
then decides who drives the test and for how long. Defaults should allow
starting quickly: warm-up defaults to none and advanced controls remain
collapsed. Mode, duration, rounds, warm-up, and shortcut choices use authored,
directly visible selection shelves rather than default picker or stepper chrome.
The start area remains visible before advanced controls and summarizes the
selected applications, rounds, and approximate total time before recording
begins.

Starting a test immediately creates its catalog record and mandatory dated test
folder.

## Concurrency rules

- Only one test may be active at a time.
- Starting a second test opens the existing test instead of creating another.
- Now and the active test share process discovery and metric sampling. Observatory
  samples a process once per cadence and reuses the immutable result.

In addition to the basic setup, a test collects:

- measured duration;
- number of rounds;
- optional warm-up duration.

No global shortcut is assigned by default. The primary control is the button on
a compact Observatory recording prompt that remains available while the target
application is frontmost. The user may configure a global shortcut during test
setup; Observatory reports registration conflicts and always retains a clickable
alternative.

The prompt first appears centered near the top of the active display with a
comfortable visible-frame inset. It uses the same rounded, opaque neutral
surface, border, typography, and semantic status accents as the main
application. The whole non-control background is draggable. Live timer updates
must never reset or fight a user-adjusted position.

### Manual guided rounds

For each selected application and round:

1. The monitor identifies the next target.
2. The user makes it frontmost and prepares the intended action.
3. The user starts using the button on Observatory's compact recording prompt or an
   optional user-configured shortcut.
4. Optional warm-up samples are recorded but excluded from scored summaries.
5. The measured timer runs.
6. A visible but non-obstructive signal marks completion.
7. The monitor waits for the next target.

For a single-application test, only that application's rounds are recorded. For
a multi-application test, the workflow never claims the user performed
equivalent work; it records the user's workload note and context.

The user can retry a round, skip an unavailable application, pause between
rounds, cancel the test, or finish with partial results.

### Automatic foreground-idle rounds

For each application and round:

1. Request activation.
2. Confirm that it became frontmost.
3. Run warm-up.
4. Measure for equal duration without simulated input.
5. Move to the next application.

If activation fails, retry within a small bound and then record the round as
failed. The result must be labeled “Foreground idle”; it must not imply an
active workload.

The monitor's own window should not cover the application under test. A menu
bar or compact overlay may show progress.

## Results

For a single-application test, the result view explains that application's
behavior. For a multi-application test, it additionally compares the selected
applications side by side.

A completed test opens this result automatically. Reopening the complete test
from Saved Results uses the same result presentation. Saved Results may also
open an individual application's combined or per-round result without changing
the recorded test. Content opened from Saved Results keeps the concise library
available for switching results; Done returns to the full library, while New
Test closes the saved-results workspace and returns to the preserved setup.

The result view contains:

- one column or color per application result;
- synchronized CPU, memory, disk, wakeup, and process-count timelines;
- averages, peaks, totals, and normalized rates;
- foreground and warm-up overlays;
- round-to-round variation for controlled tests;
- recorded context: app version, macOS version, date, duration, mode, and note.

Hovering or scrubbing one chart synchronizes the timestamp across all charts.
The cursor shows measured elapsed time, clock time, and the exact value of every
visible metric. This lets testers correlate a change with a remembered action
without capturing screen or keyboard content. Charts use shared scales by
default, with an explicit option for independent scales.
Metric and scale controls use the same compact authored selection language as
test setup so stored results do not fall back to generic segmented controls.

## Interruption and recovery

- Collector or database failure pauses the active test and informs the user.
- App relaunch offers to recover an unfinished test if durable state exists.
- Cancellation preserves or discards the partial result according to an
  explicit user choice.

## Acceptance criteria

- A one-application manual test can be completed and reopened.
- A two-application manual test can be completed entirely by keyboard.
- Automatic mode provides equal measured time or clearly marks failed rounds.
- A second controlled test cannot start while another controlled test is active.
- Warm-up data is stored but excluded from measured aggregates.
- Multiple rounds preserve individual results and a combined summary.
- Every completed result plots its stored metric samples over measured time.
- Scrubbing exposes exact elapsed time, clock time, and metric values.
- Observatory does not capture screenshots or monitor keyboard input.
- A completed application's result can be selected independently in Saved
  Results.
- Raw samples remain unchanged when chart scale or normalization changes.
