# Metrics and application grouping specification

Status: Active

## Stable identities

A process identity is not a PID alone. It contains at least:

- PID
- process start time
- executable path when available
- bundle or responsible application evidence when available

PID reuse must create a new identity.

An application identity contains:

- bundle identifier when available
- bundle URL
- display name and icon
- primary process identity

Command-line applications without bundles may use an executable-based identity,
but they are secondary to the app-focused release.

## Sampling cadence

Initial defaults:

| Situation | Interval |
| --- | --- |
| Now visible | 1 second |
| Active controlled-test round | 1 second |
| Controlled-test warm-up | 1 second |
| App hidden with no recording | No persistent sampling required |

Rate calculations use the actual monotonic interval. They never assume the
timer fired exactly on schedule.

At the initial one-second cadence, sampling the primary processes of 25 running
applications should consume no more than 2% of one CPU core on average, measured
as sampler wall-clock work divided by the requested interval over at least 100
iterations. A single pass should remain below 100 ms at the 95th percentile.
These are prototype budgets for the ordinary collector without persistence or
debug instrumentation; representative-machine evidence belongs in
`progress.md`.

## Metric definitions

### CPU

For each process:

```text
core-equivalents = delta(user CPU time + system CPU time) / elapsed wall time
Activity Monitor percentage = core-equivalents × 100
total capacity percentage = core-equivalents / active logical CPU count × 100
```

Application CPU is the sum of current grouped process core-equivalents.

- “CPU now” is the five-second rolling average.
- “CPU peak” is the highest valid one-second application sample in the session.
- A tooltip exposes all three representations.

Core-equivalents describe CPU time and do not imply equal performance between
Apple silicon efficiency and performance cores.

### Memory

- Use physical footprint where publicly available.
- Application memory is the sum of current grouped process footprints.
- “Memory peak” is the highest grouped value observed during the session.
- Exited processes stop contributing to current memory but remain in historical
  samples.

### Disk

- Read and written byte counters are converted to rates using sample deltas.
- Counter resets or a new process identity start a new baseline.
- Current rates are grouped across live member processes.
- Session totals retain bytes recorded before a member process exited.

### Wakeups

- Present wakeups as a rate over the actual sample interval.
- Preserve cumulative session wakeups when supported by the public counter.
- Do not convert wakeups into a battery percentage.

### Counts and state

- Process count includes live grouped processes.
- Thread count is summed when available.
- Foreground state comes from the current frontmost application.
- Visible, hidden, and idle are presentation states defined from platform state
  and recent resource activity; the idle threshold requires calibration.

## Application ownership

Ownership evidence, strongest first:

1. Manual include or exclude rule
2. Primary application PID
3. Executable located inside the application bundle
4. Explicit responsible/parent application identity when publicly available
5. Descendant relationship to a known application process
6. Related bundle identifier or XPC service location
7. Name similarity

Name similarity alone never produces high confidence.

Confidence levels:

- **High:** strong bundle, primary PID, or manual evidence
- **Medium:** ancestry or related helper evidence without bundle containment
- **Low:** weak heuristic evidence
- **Unassigned:** insufficient or conflicting evidence

A process may have only one owning application at a time. Conflicts remain
visible for review rather than being double-counted.

## Manual overrides

Advanced process details allow:

- always include a matching process identity pattern;
- always exclude a matching process from the application;
- apply the decision only to the current session;
- reset one rule;
- reset all grouping rules.

Persistent rules should prefer stable executable or bundle evidence over PIDs or
display names. The UI previews which current processes a rule would match.

## Process lifecycle

- Preserve the final observed cumulative CPU and disk contribution of processes
  that exit during a recorded session.
- Detect new processes before grouping the next application snapshot.
- A restarted helper receives a new process identity but may join the same
  application group.

## Recorded metric timelines

Every controlled-test sample retains its wall-clock timestamp, measured elapsed
time, warm-up state, application state, grouped metrics, and partial-data state.
Result charts use measured elapsed time without rewriting the stored sample.

The synchronized cursor presents exact values from the nearest recorded sample,
including elapsed and clock time. Missing or unavailable samples create visible
gaps rather than zeroes. Testers locate meaningful changes directly in the
metric series.

## Acceptance criteria

- CPU calculation uses monotonic elapsed time and counter deltas.
- PID reuse cannot inherit the previous process's counters.
- Exited-process totals remain in a session while current memory drops.
- No process contributes to two application totals.
- Low-confidence ownership is visibly distinguishable.
- Manual reset restores automatic grouping.
- Synthetic counter fixtures cover resets, exits, restarts, and delayed timer
  intervals.
- Stored test samples preserve measured elapsed time and wall-clock timestamps.
- Timeline gaps distinguish unavailable collection from zero usage.
- Scrubbing a result returns exact recorded values without mutating raw data.
