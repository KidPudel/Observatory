# Architecture specification

Status: Active

## Technical direction

- Swift 6
- SwiftUI application shell
- AppKit bridges for macOS-specific activation, windows, and controls
- Swift Charts
- GRDB over SQLite
- `NSWorkspace` for running and foreground applications
- Public `libproc` and Darwin APIs for process metrics

Observatory runs collection in the main application process.

## Components

### App shell

Owns navigation and preferences. It does not collect metrics directly.

### Application discovery

Observes application launches, termination, activation, visibility, bundle
identity, icons, and primary PIDs.

### Process sampler

Enumerates relevant PIDs and emits immutable timestamped raw process samples. It
does not decide application ownership.

### Application grouper

Consumes process identity and ownership evidence, applies manual overrides, and
produces grouped application snapshots with confidence.

### Test engine

Owns controlled-test state, mode, warm-up and measurement phases, rounds,
interruption, foreground expectations, and result finalization.

### Persistence

Stores the catalog, raw samples, aggregated results, grouping overrides, test
metadata, and private test summaries.

### Presentation models

Transform immutable domain snapshots into Now and Tests view state, including
the Saved Results library inside Tests. Views do not calculate resource
metrics.

## Data flow

```text
macOS APIs
    ↓
Application discovery + process sampler
    ↓
Application grouper
    ↓
Live snapshots ───────────────→ Now
    ↓
Controlled test engine
    ↓
Persistence
    ↓
Test results + Saved Results
```

## Concurrency

- Sampling and persistence must not run on the main actor.
- UI-facing state is published on the main actor.
- Use actors for mutable collector, session, and storage state.
- Prefer immutable, `Sendable` domain values between components.
- Database writes must not block the next metric sample.
- One controlled test may run at a time.
- Now and the active controlled test share the central sampler so collection is
  not duplicated.

## Protocol boundaries

Each external dependency receives a protocol so tests can use deterministic
fixtures:

- clock
- application discovery
- process sampling
- application activation
- persistence

Tests should be able to run a complete controlled test using a virtual clock and
sample fixtures without launching real applications.

## Persistence boundary

The private catalog is the source of truth. Test folders contain portable
summaries, not independent databases that the app must scan on every launch.

Database migrations are mandatory from the first schema version. Raw samples
remain immutable; derived summaries may be regenerated.

## Failure model

Expected partial failures are domain states, not crashes:

- process became inaccessible;
- PID exited or was reused;
- target app did not become frontmost;
- database write failed.

Database failure pauses the active recording and tells the user rather than
pretending it is still saved.

## Dependency rules

- Views depend on presentation models and domain values.
- Domain logic does not import SwiftUI, AppKit, or GRDB.
- Platform adapters implement domain protocols.
- Persistence records domain values but does not own test or comparison
  logic.
- No private frameworks or parsing of undocumented command output.
