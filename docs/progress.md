# Progress

Last updated: 2026-07-31

This is the append-only historical record of implementation and verification.
Use [`current.md`](current.md) for current status, next actions, and known
limitations. Entries below describe the project at the time they were written
and may be superseded by later entries.

## Completed work

### 2026-07-28 — Phase 8 History and cross-test comparison

- Replaced the empty History foundation with a searchable library of completed
  controlled tests and their application results.
- Added independently reopenable combined results and per-round results for
  repeated tests, reusing the verified five-metric timeline and exact sample
  inspector.
- Added two-to-four-result comparison across unrelated tests and repeated
  same-application tests, with one elapsed-time domain, shared or independent
  vertical scales, warm-up hidden by default, and shorter recordings ending at
  their last raw sample.
- Added recorded-context warnings for application version, measured duration,
  mode, date, workload note, and macOS version differences.
- Paired disk totals with per-second normalized rates and kept every comparison
  projection separate from immutable SQLite samples.
- Added confirmed test deletion that removes the test catalog relationships,
  raw samples, summaries, rounds, and exact private summary folder while
  preserving unrelated tests.

Verification:

- Added deterministic History projection and comparison tests covering combined
  and per-round results, search, raw-sample immutability, context warnings, and
  normalized disk rates.
- Added a controlled-test engine deletion test that verifies the selected
  database record and folder are removed while an unrelated test remains.
- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -configuration
  Debug -derivedDataPath .build CODE_SIGNING_ALLOWED=NO` passed all 34 tests.
- `./scripts/run.sh` built, signed, and launched the Debug application.
- Computer Use verified the populated library, unrelated-app comparison,
  same-app comparison across separate tests, exact saved-result reopening, and
  the explicit deletion confirmation in the running macOS app.

Next:

- Begin Phase 9 accessibility, appearance, reliability, privacy, and release
  hardening.

### 2026-07-28 — Controlled-test cadence drift correction

- Changed controlled-test sampling from “one second after work finishes” to
  fixed one-second deadlines, so sampler and persistence work no longer
  accumulates into `1.1s`, `2.2s`, `3.3s` timeline positions.
- Kept rate calculations and stored chart positions based on actual recorded
  time; previously saved results remain unchanged.
- Preserved sleep/discontinuity handling by resetting the next deadline after a
  detected clock gap instead of producing catch-up samples.

Verification:

- Added a deterministic test that advances the clock by 100 ms during every
  sample and verifies recorded elapsed positions remain `0s`, `1s`, and `2s`.
- All 31 tests passed.
- `./scripts/run.sh` built, signed, and launched the Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Result timeline warm-up continuity

- Removed the boxed warm-up background so the light chart grid remains
  uninterrupted across negative and measured time.
- Kept warm-up data as a dashed trace and added a visual-only bridge to the
  first measured sample, eliminating the broken gap at time zero.
- Replaced the “Warm-up range” legend text with “Warm-up trace” and kept the
  bridge hidden from chart accessibility so recorded sample counts stay exact.

Verification:

- All 30 tests passed.
- Computer Use visually verified the persisted five-second warm-up result with
  a continuous trace, no gray block, and no baseline sample dots.
- `./scripts/run.sh` built, signed, and launched the Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Result timeline balanced grid restoration

- Restored low-opacity vertical chart guides and the earlier five-step
  horizontal grid so warm-up data reads as part of one continuous plot.
- Kept the detached baseline sample dots removed; sample indicators remain on
  their recorded metric values.
- Preserved the selected-point dashed crosshair and exact value/time labels.

Verification:

- All 30 tests passed.
- Computer Use visually verified the five-second warm-up result with the
  restored grid and no baseline sample rug.
- `./scripts/run.sh` built, signed, and launched the Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Result timeline editorial grid refinement

- Removed the detached baseline sample rug; recorded samples now appear only as
  restrained points on their metric series.
- Removed vertical plot grid lines and reduced the horizontal grid to three
  low-opacity guides for a softer, editorial presentation.
- Preserved the dashed selected-point guides and exact elapsed/value labels,
  along with warm-up and partial-sample semantics.

Verification:

- All 30 tests passed.
- Computer Use visually verified CPU, memory, and five-second warm-up results
  with the revised guides and sample points.
- `./scripts/run.sh` built, signed, and launched the Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Result timeline sample rug and point guides

- Removed the continuous foreground rail and restored sample cadence as a
  compact baseline rug: foreground samples use the application color and other
  states use quiet neutral dots.
- Kept partial readings as smaller diamond marks on the actual metric series.
- Added dashed horizontal and vertical guides anchored to the nearest recorded
  point, with exact metric and elapsed-time labels inside the chart.
- Hid baseline rug marks from accessibility; exact values remain available in
  the formatted sample cards.

Verification:

- All 30 tests passed.
- Computer Use visually verified CPU, memory, and five-second warm-up results,
  including formatted value labels, elapsed-time labels, synchronized point
  selection, and unobtrusive sample rugs.
- `./scripts/run.sh` built and launched the Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Result timeline state-overlay refinement

- Replaced full-height per-sample foreground columns with merged, continuous
  foreground-state rails along the top of each plot.
- Replaced per-sample warm-up columns with one quiet pre-zero warm-up region;
  the dashed warm-up series and exact sample state remain intact.
- Clarified the chart legend as “Warm-up range” and “Foreground state.”

Verification:

- All 30 tests passed.
- Computer Use visually verified the redesigned CPU and memory charts in a
  persisted two-application result and the pre-zero treatment in a persisted
  five-second warm-up result.
- `./scripts/run.sh` built and launched the final Debug application.

Next:

- Continue with the Phase 8 History library.

### 2026-07-28 — Phase 7 test result metric timelines

- Added Swift Charts timelines for stored CPU, memory, disk read/write, wakeup,
  and process-count samples in completed Tests results.
- Added one synchronized elapsed-time cursor across application charts with
  exact per-application elapsed time, clock time, all recorded metric values,
  round identity, foreground state, warm-up state, and partial-data state.
- Added shared vertical scales by default and an explicit independent-scale
  option while retaining one measured elapsed-time domain.
- Reconstructed warm-up presentation before measured time zero, overlaid
  repeated rounds with distinct line patterns, marked foreground and partial
  samples, and split lines across unavailable values without changing stored
  samples.
- Added deterministic timeline projection tests, including raw-sample
  immutability, warm-up alignment, missing-value gaps, exact selection, disk
  direction preservation, and numeric `UInt64` memory conversion.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath .build
  CODE_SIGNING_ALLOWED=NO` passed all 30 tests.
- Computer Use reopened a persisted two-application result and verified all
  five metric selections, disk read/write series, synchronized pointer
  inspection, exact elapsed and clock values for both applications, and
  shared/independent scales.
- Computer Use reopened a persisted manual result with five seconds of warm-up
  and verified negative warm-up time, dashed warm-up series, measured time
  beginning at zero, foreground/partial marks, and exact sample cards.
- Live visual inspection caught an ambiguous Swift numeric initializer that
  treated memory bytes as a bit pattern; explicit numeric conversion and a
  regression assertion corrected the chart before the final Debug launch.
- `./scripts/run.sh` built, signed, launched, and visually rendered the final
  CPU and memory timelines.
- `git diff --check` passed.

Next:

- Implement the Phase 8 History library, individual-result reopening,
  cross-test comparison, and confirmed test deletion.

### 2026-07-28 — Metrics-only Phase 7 scope

- Replaced screenshot, keyboard-monitoring, and inferred-spike context with
  recorded metric timelines as the sole Phase 7 evidence.
- Defined CPU, memory, disk, wakeup, and process-count charts over measured
  elapsed time.
- Required a synchronized cursor that reveals exact metric values, elapsed time,
  and clock time so testers can correlate changes with remembered actions.
- Removed capture services, capture permissions, custom asset-root behavior,
  and context-retention work from the active MVP specifications and roadmap.
- Removed the dormant screenshot and input-activity cases from the controlled
  test context model; metrics-only remains the sole supported value.
- Kept private `session.json` summaries and SQLite one-second samples; custom
  storage is no longer part of the MVP.

Verification:

- Reviewed the concept, MVP, architecture, controlled tests, History, metrics,
  storage/privacy, visual design, documentation map, and implementation plan for
  the metrics-only scope.
- `git diff --check` passed.
- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 28 tests after the domain-model cleanup.

Next:

- Implement the Phase 7 metric timeline in completed test results.

### 2026-07-28 — Controlled-test-only scope

- Removed passive recording as a product and roadmap concept.
- Defined Tests as one controlled-test workflow with manual guided and automatic
  foreground-idle modes.
- Updated the Tests subtitle so the running app no longer advertises passive
  recording.
- Removed the concurrency, lifecycle, retention, and metrics-only capture
  requirements that existed only for passive recording.
- Renumbered the remaining roadmap so spike context is Phase 7, History is
  Phase 8, and hardening is Phase 9.
- No implementation was removed because the deleted roadmap phase had not
  started.

Verification:

- Reviewed the concept, MVP, feature specifications, visual design,
  implementation plan, documentation map, and progress ledger for consistent
  controlled-test-only language.
- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 28 tests after the visible Tests copy
  changed.

Next:

- Superseded by the metrics-only Phase 7 scope recorded above.

### 2026-07-28 — Phase 6 automatic foreground-idle controlled tests

- Generalized the manual-only session engine into a shared controlled-test
  engine while retaining the original persisted configuration key for
  compatibility with existing session payloads.
- Added automatic one-to-four-application sequencing with equal measured
  intervals, optional warm-up, repeated rounds, cancellation, and relaunch
  recovery on the Phase 5 timing and persistence foundation.
- Added an application-activation protocol and a macOS adapter that first uses
  `NSRunningApplication.activate`, then falls back to an activating
  `NSWorkspace.openApplication` request when foreground-stealing protection
  rejects direct activation.
- Confirmed the real frontmost application through
  `NSWorkspace.frontmostApplication` before starting warm-up or measurement.
- Bounded activation at three attempts with 1.5 seconds of confirmation per
  attempt, persisted failed rounds with a human-readable reason, and continued
  to the next target.
- Added explicit activating, warming-up, recording, completed, and failed round
  states to the main Tests surface and compact non-activating overlay.
- Added manual/automatic setup selection and labeled saved automatic results
  “Foreground idle.”
- Added deterministic virtual-clock fixtures for repeated multi-app rotation,
  equal measured duration, bounded activation failure, and continuation after
  a failed target.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 28 tests.
- Computer Use completed an unattended Finder/Zed automatic test with one
  10-second measured round per application. Both applications became
  frontmost, both rounds completed, and each result contained exactly ten
  measured samples.
- The live test required no Accessibility permission and requested no new
  macOS privacy permission.
- Live failure testing first demonstrated that direct
  `NSRunningApplication.activate` alone can be rejected after Observatory loses
  focus. The visual failed-round path worked, and the public Launch Services
  fallback subsequently passed the same Finder/Zed rotation.
- A Swift concurrency executor assertion in the first asynchronous Launch
  Services callback was reproduced from its crash report, moved across an
  explicit nonisolated boundary, and reverified without a crash.
- `./scripts/run.sh` produced a successful Debug build and launched the
  corrected application.

Next:

- Superseded by the metrics-only Phase 7 scope recorded above.

### 2026-07-27 — Recording helper interaction and visual refinement

- Removed the per-refresh repositioning that caused the recording helper to
  jump back while it was being dragged.
- Preserved one hosting controller for the helper so timer updates no longer
  replace its window content every second.
- Moved first appearance from the display edge to a comfortably inset,
  top-centered position on Observatory's active display.
- Replaced HUD window chrome with a clear borderless panel containing the same
  rounded graphite/off-white surface, hairline border, typography, shadow, and
  semantic status accents as the main application.
- Added a visible move affordance and a dedicated AppKit drag region with an
  open-hand cursor while retaining the clickable round action.
- Updated the Sessions and visual-design specifications to require stable
  user positioning and consistent prompt styling.

Verification:

- User confirmed the revised helper placement and dragging experience works
  well in the live application.
- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 26 tests after the explicit drag-region
  refinement.
- `./scripts/run.sh` produced a successful Debug build and launched Observatory.

Next:

- Continue Phase 6 automatic foreground-idle tests.

### 2026-07-27 — Percentage CPU default and Tests naming

- Changed the product CPU default from core-equivalents to Activity
  Monitor-style percentage in Now.
- Added a one-time preference migration so installs carrying the former
  default switch to percentage without overwriting another explicitly selected
  representation.
- Changed controlled-test result summaries from cores to Activity Monitor-style
  average and peak percentages.
- Renamed the user-facing middle destination and page from Sessions to Tests.
  The internal session model stores controlled tests.
- Updated the product concept, specifications, visual design language, and
  implementation documentation to match the new defaults and naming.

Verification:

- Added a domain fixture that locks Activity Monitor percentage as the product
  default.
- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 26 tests.
- Restarted an install carrying the former `cores` preference and confirmed it
  migrated to `activityMonitorPercentage` with the migration marker persisted.
- `./scripts/run.sh` produced a successful Debug build and launched Observatory.

Next:

- Continue Phase 6 with Tests as the user-facing destination.

### 2026-07-27 — Phase 5 session engine and manual controlled tests

- Added durable controlled-test sessions with one-to-four running-application
  selection, a name, workload note, measured duration, warm-up, repeated
  rounds, and metrics-only context.
- Added a single-owner manual session engine with explicit planned, warm-up,
  measured, between-round, completed, cancelled, interrupted, skipped, and
  retry behavior.
- Stored immutable one-second application samples, round state, session
  metadata, and per-application combined summaries in a third GRDB migration.
- Excluded warm-up samples from measured averages, peaks, totals, and normalized
  result summaries while preserving them in the raw timeline.
- Added average and peak CPU, average and peak memory, disk read/write totals,
  average wakeups, peak process/thread counts, measured duration, and sample
  count summaries across completed rounds.
- Added mandatory dated session folders under the private default Recordings
  root and atomically generated a portable `session.json` summary.
- Added relaunch recovery for unfinished tests. An active round becomes an
  explicit interrupted round, recorded data remains intact, and the user
  chooses whether to continue or discard.
- Added cancellation choices that either preserve completed partial results or
  remove the session catalog records and its newly created asset folder.
- Added a compact non-activating recording prompt, constrained inside the
  display's visible frame, plus optional Carbon global-hotkey presets with
  conflict reporting and a permanently available clickable alternative.
- Added a populated Tests setup, active-round, recovery, combined-result,
  and recent-result interface with explicit keyboard focus and accessible
  labels/status.
- Added Now-card quick actions that open Tests with that application already
  selected.
- Shared the existing grouped collector between Now and Tests and coalesced
  near-simultaneous requests so switching views or an active session does not
  duplicate process sampling.
- Fixed `UInt64` memory-to-`Double` conversion sites to use numeric conversion
  rather than Swift's bit-pattern overload.
- Marked Phase 5 verified and advanced the active milestone to automatic
  foreground-idle tests.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 25 tests without warnings.
- New virtual-clock fixtures completed two warm-up-plus-measured rounds and
  verified that four warm-up samples remained stored while six measured
  samples alone contributed to the combined summary.
- Persistence fixtures round-tripped session metadata, rounds, raw metric
  samples, summaries, unfinished-session lookup, cascade-style deletion, and
  all three migrations.
- A second engine could not create another controlled test while the first was
  unfinished.
- Relaunch fixtures converted an active round to `interrupted`, preserved its
  data, and required an explicit recovery decision; discard fixtures removed
  catalog records and the exact session asset folder.
- Computer Use completed a 10-second Finder test, reopened its result, quit
  Observatory, relaunched it, and reopened the same saved result again.
- Computer Use configured and completed a two-application Brave/ChatGPT test
  using only Tab, Space, and Return. Both equal 30-second measured rounds
  completed and appeared in the combined result.
- Live inspection found and corrected default-keyboard-navigation gaps in the
  application grid, an edge-hugging prompt placement, and the memory display
  conversion bug.
- `./scripts/run.sh` produced a successful Debug build and launched Observatory.

Next:

- Build Phase 6 application activation, activation confirmation/failure
  handling, and equal-duration foreground-idle rounds on the verified session
  engine.

### 2026-07-27 — Phase 4 Now vertical slice

- Added a one-second live collector that discovers running applications,
  samples owned processes off the main actor, applies persisted grouping rules,
  and publishes immutable application-level snapshots.
- Added five-second rolling CPU averages, live memory peaks, derived idle state,
  per-metric unavailable values, and partial-total explanations without turning
  missing measurements into zeroes.
- Added adaptive live application cards with icons, state, CPU, memory, disk
  read/write rates, wakeups plus activity meaning, process count, and thread
  count.
- Added inline process expansion with PID, per-process metrics, ownership
  confidence and evidence, stable include/exclude actions, per-application
  reset, and an advanced ambiguous/system-process surface.
- Added application-first and owned-process-second search, stable name sorting,
  live metric sorts, visual pause with continued collection, and empty/search
  states.
- Added core-equivalent, Activity Monitor-style percentage, and total-capacity
  CPU representations with a persisted default and a detail tooltip exposing
  all equivalent values and the five-second window.
- Kept application and ownership inventory refreshes at five seconds while
  preserving one-second metric samples and UI updates. Cached static
  application evidence, process evidence, bundle lookups, and icons to bound
  observer cost.
- Marked Phase 4 verified and advanced the active milestone to the manual
  controlled-test engine.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 20 tests.
- New fixtures passed for mathematically equivalent CPU representations,
  time-weighted five-second CPU averaging, live memory peaks, missing-value
  preservation, partial totals, application/process search, and missing-last
  metric sorting.
- Computer Use inspected the populated dark-appearance Now view, expanded a
  24-process application without changing its card totals, found applications
  by owned process name, exposed the advanced ownership view, and confirmed
  accessible labels and actions for cards, metrics, controls, and process
  ownership.
- Visual pause changed to an explicit “collection continues” state and resumed
  onto the newest collected snapshot.
- The CPU representation changed to Activity Monitor percentage, survived a
  full application relaunch, and was restored to the default core-equivalent
  setting.
- An optimized Release build used 0.84 CPU-seconds over 30 wall-seconds with
  the populated Now view visible: about 2.8% of one core, or 0.28% of this
  10-core Mac's total logical CPU capacity. Resident memory remained near
  86 MB.
- `./scripts/measure-sampler.sh` passed the known workload and all 2,500 live
  samples at 0.107 ms average, 0.131 ms p95, and an estimated 0.011% of one
  core at a one-second cadence.
- `./scripts/run.sh` produced a warning-free Debug build and launched Observatory
  on the populated Now view.

Next:

- Build Phase 5 session creation and manual controlled-test rounds, then connect
  Now's application quick action to the new session draft.

### 2026-07-27 — Phase 3 application grouping

- Added deterministic application ownership using manual rules, stable primary
  identity, executable containment, responsible PID, ancestry, related bundle
  identity, and name similarity in descending evidence strength.
- Added high, medium, low, and unassigned confidence with the evidence retained
  on every process decision.
- Kept equal-strength ownership conflicts unassigned and exposed all conflicting
  applications instead of choosing or double-counting silently.
- Added persistent and session-scoped include/exclude rules with remove,
  per-application reset, and reset-all behavior.
- Added a second catalog migration and persistence operations so persistent
  grouping decisions survive application relaunch.
- Added grouped CPU, physical-memory, disk-rate, wakeup-rate, process-count, and
  thread-count snapshots, including explicit unavailable-process counts.
- Deduplicated process inventory by PID and newest stable identity before
  ownership and aggregation.
- Extended the public-API process inventory with parent PID and bundle evidence;
  resolved bundle-containment paths through symlinks.
- Marked Phase 3 verified and advanced the active milestone to the Now vertical
  slice.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all 16 tests.
- Native, Electron-style, bundle-contained helper, external descendant,
  ambiguous name-only, reused-PID, duplicate-process, manual override, reset,
  session-scope, grouped-metric, and catalog round-trip fixtures passed.
- `./scripts/measure-sampler.sh` discovered 12 regular applications, 478
  processes with parent evidence, and 215 processes with bundle evidence.
- The 25-process live sampler remained inside its Phase 2 budget at 0.274 ms
  average, 0.290 ms p95, and an estimated 0.027% of one core.
- `./scripts/run.sh` produced a successful Debug build and launched Observatory.

Next:

- Build the Phase 4 presentation model and live application cards from grouped
  snapshots, including visible confidence and unavailable states.

### 2026-07-27 — Phase 2 process discovery and sampling

- Added `NSWorkspace` discovery for regular running applications with bundle
  identity, primary PID, display name, and frontmost/visible/hidden state.
- Added public `libproc`/Darwin PID enumeration and stable process identities
  composed from PID, process start time, and executable path when accessible.
- Added off-main-actor sampling of cumulative user/system CPU time, physical
  footprint, disk reads and writes, idle/interrupt wakeups, and thread count.
- Added immutable raw counter samples and a domain calculator that derives CPU,
  disk, and wakeup rates from actual monotonic intervals.
- Made exited, inaccessible, and reused-PID states explicit. Counter resets,
  exits, and new identities clear their baselines rather than inheriting stale
  rates.
- Defined the ordinary one-second sampler budget as at most 2% of one CPU core
  on average for 25 processes and a pass below 100 ms at p95.
- Added a repeatable live sampler probe for public-API correctness and overhead
  measurement.
- Marked Phase 2 verified and advanced the active milestone to application
  grouping.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all nine tests.
- Synthetic fixtures passed for delayed timer intervals, counter resets, exits,
  restarted identities, inaccessible processes, and reused PIDs.
- `./scripts/measure-sampler.sh` discovered 11 regular applications and sampled
  a 25-process workload over 100 passes.
- The known CPU-and-disk workload reported 0.024 CPU cores, 6,537,530 B/s disk
  writes, 3,523,584 bytes of physical footprint, and four threads.
- The sampler averaged 0.265 ms per 25-process pass, measured 0.280 ms at p95,
  and consumed an estimated 0.026% of one core at a one-second cadence.
- An intentionally absent PID was reported as exited; a real process that ended
  during the benchmark also stopped contributing available samples without
  interrupting collection.
- `./scripts/run.sh` produced a successful Debug build and launched Observatory.

Next:

- Build documented native, Electron/browser, and helper-heavy ownership
  fixtures for Phase 3 grouping.

### 2026-07-27 — Phase 1 accepted

- Product-design review confirmed the native application foundation is ready to
  close.
- Marked Phase 1 verified in `docs/implementation-plan.md` and advanced the
  active milestone to Phase 2.
- Preserved remaining visual-system calibration as ongoing design work rather
  than a blocker for the Phase 1 foundation exit gate.

Verification:

- The Debug application builds and launches through `./scripts/run.sh`.
- Now, Sessions, and History navigation was verified with Computer Use,
  including selected-state accessibility and keyboard activation.
- All four domain and persistence tests pass.

### 2026-07-27 — Sans-serif navigation selection restored

- Concluded the selected-tab serif trial after product-design review found it
  playful but too questionable for the global control.
- Restored the selected destination to the navigation's regular sans-serif
  family, using semibold weight and primary tone for state.
- Kept the selected-tab dot removed and preserved centered label alignment.
- Updated `docs/visual_design_concept.md` to record the settled current rule.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` produced a successful Debug build.
- Computer Use confirmed the selected tab uses centered semibold sans-serif
  text without a dot or pointer focus outline; the app was left on Now.

### 2026-07-27 — Dot-free navigation typography trial

- Removed the selected-tab dot so every navigation label shares one centered
  alignment.
- Added a compact semibold serif treatment to the selected destination as an
  explicit product-design trial.
- Updated `docs/visual_design_concept.md` to keep the dot removal while marking
  the serif switch as pending visual review rather than a settled rule.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` produced a successful Debug build.
- Computer Use visually inspected the selected Now state, confirmed the dot is
  absent and the labels remain centered, and left the trial open for review.

### 2026-07-27 — Navigation focus correction

- Disabled SwiftUI's native focus effect on the custom global-tab buttons so it
  no longer stacks with the app's own focus treatment.
- Hid the custom focus edge for pointer activation and retained one restrained,
  monochrome edge when the user navigates with the keyboard.
- Preserved Return/Space activation and selected-state accessibility.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` produced a successful Debug build.
- Computer Use confirmed that mouse selection has no focus outline, Tab reveals
  one quiet focus edge, and Return still activates the focused destination.

### 2026-07-27 — Visual-system conformance pass

- Removed the remaining sky-themed palette name and empty-state copy from the
  implementation so the product language matches the concise editorial
  direction.
- Aligned the global navigation, page rhythm, panel padding, radii, and shadows
  to the four-point grid and the dimensions in
  `docs/visual_design_concept.md`.
- Calibrated the dark canvas to neutral `#131313` and added stronger component
  edges for Increase Contrast.
- Added explicit keyboard focus rings and Return/Space activation for all
  global tabs.
- Added an opacity-only Reduce Motion fallback while keeping the standard view
  transition short and restrained.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` produced a successful Debug build and launched the current
  binary.
- Computer Use confirmed that Tab moves focus between global tabs and Return
  activates the focused destination; selected-state accessibility and the
  Sessions content update were both observed.
- Computer Use visually inspected the corrected Now composition and left the
  app open on Now for product-design review.
- A full visual calibration under dark appearance, Increase Contrast, and
  Reduce Motion remains an acceptance gate.

### 2026-07-27 — Dia-inspired editorial visual pass

- Inspected the current Dia website as the primary reference and separated its
  actual visual mechanics from broad “glassmorphism” shorthand.
- Updated `docs/visual_design_concept.md` to define Dia and the Browser Company
  aesthetic as the primary reference: editorial serif display hierarchy,
  softened monochrome surfaces, opaque floating chrome, nearly flat cards, and
  surgical color accents.
- Condensed the visual specification from 433 to 256 lines by merging repeated
  canvas, material, accessibility, and component guidance while preserving the
  implementation-critical overview and acceptance criteria.
- Removed the former airy/sky metaphor and reduced the visual direction to four
  explicit principles: editorial typography, monochrome with semantic accents,
  weightless components, and Swiss grid discipline.
- Replaced the canvas gradient with a flat off-white or graphite field.
- Reworked the global navigation into an opaque, text-led floating pill with a
  tiny ink selected-state dot.
- Added a native serif display tier for page and empty-state headlines while
  preserving SF Pro for controls, body copy, and future data-dense views.
- Rebuilt all three empty-state panels as pale editorial stages with high
  radius, hairline edges, ultra-soft shadows, and compact lime, gold, or blue
  semantic marks.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` produced a successful Debug build.
- Relaunched the fresh binary after detecting that macOS initially retained the
  previous process.
- Computer Use visually inspected the Dia-inspired Now and Sessions views,
  navigated through all three destinations, confirmed selected-state
  accessibility, and left the app open on Now for product-design review.
- Product-design approval remains pending.

### 2026-07-27 — Neutral desktop visual correction

- Reworked the first visual shell after product-design feedback that the
  cyan/lavender atmosphere felt closer to a mobile skin than a modern macOS
  application.
- Used the local Cursor application as a concrete desktop reference for neutral
  canvases, quiet surfaces, hairline borders, and minimal shadow.
- Removed the colored radial washes, persistent grain, cool colored shadows,
  luminous tab selection, and tinted empty-state badges.
- Added a nearly flat warm-neutral light canvas and graphite dark canvas,
  monochrome empty-state treatment, neutral surface fills, and shorter shadows.
- Changed page titles from rounded display typography to standard SF Pro.
- Updated `docs/visual_design_concept.md` so the sky language remains an
  emotional metaphor while Cursor and modern ChatGPT define the visual
  restraint.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` rebuilt and launched the corrected implementation.
- Computer Use compared the local Cursor application, visually inspected the
  corrected Now view, and verified navigation and selected-state semantics in
  Sessions and History.
- Product-design approval remains pending.

### 2026-07-27 — First visual-system implementation

- Replaced destination-owned navigation with one global, top-centered floating
  tab bar in the root application shell.
- Added a quiet atmospheric canvas, restrained static grain, native material,
  edge highlights, and cool low-opacity depth.
- Added shared floating page and empty-state components, then applied them to
  Now, Sessions, and History so the first review covers a consistent system.
- Added semantic dark-appearance colors and a Reduce Transparency fallback.
- Preserved native macOS window controls while extending the canvas beneath a
  hidden title bar.
- Clarified global tab-bar ownership and initial sizing in
  `docs/visual_design_concept.md`.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` rebuilt and launched the implementation.
- Computer Use visually inspected Now, Sessions, and History in the running
  application and confirmed that the global bar stays in place, selection
  changes correctly, and each destination exposes the expected accessibility
  labels and selected state.
- Product-design approval and appearance calibration remain pending.

### 2026-07-27 — Visual design concept clarification

- Defined the airy, floating, minimal visual direction as an implementation-ready
  system rather than a collection of atmospheric references.
- Replaced the permanent sidebar direction with a centered floating top tab bar
  for Now, Sessions, and History.
- Added concrete layout, spacing, radius, color, material, typography, icon,
  chart, component, state, motion, accessibility, and performance rules.
- Adapted the liquid-glass direction to macOS 14 native materials and deferred
  continuous refraction, parallax, and decorative animation.
- Added view-specific composition for Now, Sessions, and History and documented
  the remaining naming and calibration decisions.
- Linked the visual design concept from the documentation map and authority
  order.

Verification:

- Manually reviewed the visual rules against the Now, Sessions, History,
  architecture, and performance specifications.
- Confirmed that the top navigation changes presentation without changing the
  product's three-view behavior.

### 2026-07-27 — Native application foundation

- Added a reproducible Xcode project targeting macOS 14 with the temporary
  `com.iggysleepy.observatory` bundle identifier.
- Added a SwiftUI navigation shell with Now, Sessions, and History empty states.
- Added separate Swift 6 domain and persistence modules so platform-independent
  models and service protocols remain isolated from SwiftUI and GRDB.
- Pinned GRDB 7.8.0 through Swift Package Manager and added the first catalog
  migration with session save, fetch, and ordered-list behavior.
- Added deterministic domain and in-memory persistence fixtures using Swift
  Testing.
- Added `.build` and Xcode-derived data to `.gitignore`.

Verification:

- `xcodebuild test -project Observatory.xcodeproj -scheme Observatory -destination
  'platform=macOS,arch=arm64' -derivedDataPath DerivedData
  CODE_SIGNING_ALLOWED=NO` passed all four tests.
- `./scripts/run.sh` built and launched the ad-hoc-signed Debug application from
  `.build/Build/Products/Debug/Observatory.app`.
- Computer Use confirmed that Now, Sessions, and History can each be selected
  and display the correct empty state.

### 2026-07-27 — Developer launch script

- Added `scripts/run.sh` to build the Debug configuration into the repository's
  `.build` directory and launch Observatory without opening Xcode.
- Documented the launcher in `AGENTS.md` and `docs/readme-map.md` so agents
  discover the standard build-and-launch workflow.

Verification:

- Ran `scripts/run.sh`; the Debug build succeeded and macOS opened
  `.build/Build/Products/Debug/Observatory.app`.
- Reviewed the agent entry instructions and documentation-map workflow for
  consistent command and behavior descriptions.

### 2026-07-27 — Concept and documentation foundation

- Defined Now, Sessions, and History as the primary views.
- Defined application-level process grouping with manual ownership overrides.
- Chose native Swift, SwiftUI/AppKit, Swift Charts, GRDB, and public macOS APIs.
- Defined automatic foreground-idle and manual controlled comparisons.
- Defined spike-triggered application-window screenshots.
- Defined privacy-safe input activity using shortcuts, named keys, and anonymous
  typing counts.
- Defined user-selected session storage with an Application Support fallback.
- Added cross-session comparison for the same or different applications.
- Created the documentation map, feature specifications, implementation plan,
  and progress ledger.

Verification:

- Documentation structure and internal links reviewed manually.
- This documentation checkpoint preceded the native application foundation
  recorded above.

## Decisions

This table records decisions at the time they were made. Later decisions and
active specifications supersede earlier entries when scope changes.

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-07-27 | Build a native macOS app | Deep platform integration and low observer overhead |
| 2026-07-27 | Present applications before processes | Users need the full application cost |
| 2026-07-27 | Support manual and foreground-idle controlled tests | Useful comparison without scripted workloads |
| 2026-07-27 | Allow cross-test result comparison | Enables regression and same/different app analysis |
| 2026-07-27 | Start with free GitHub distribution | No paid Apple membership required |
| 2026-07-27 | Use Observatory as the working product name | Matches the product's investigative purpose |
| 2026-07-27 | Target macOS 14 or later | Supports the selected native platform APIs |
| 2026-07-27 | Use private Application Support recordings by default | Reliable storage with optional custom location |
| 2026-07-27 | Assign no global shortcut by default | Avoid conflicts; the recording prompt button is primary |
| 2026-07-27 | Tests accept one to four applications | Supports single-app investigation and multi-app comparison |
| 2026-07-27 | History never performs monitoring | Recording is always an intentional controlled test |
| 2026-07-27 | Use Tests for the middle view | Communicates the product's recording workflow |
| 2026-07-27 | Allow only one controlled test at a time | Foreground sequencing and guided prompts require exclusive ownership |
| 2026-07-27 | Keep controlled-test raw metrics until deletion | Preserve short test detail for later comparison |
| 2026-07-27 | Use a centered floating top tab bar | Keeps primary navigation minimal and the canvas open |
| 2026-07-27 | Make hierarchy float without wrapping every element in a bubble | Preserves airiness and data clarity |
| 2026-07-27 | Prefer native, static visual effects for the MVP | Protects accessibility and observer performance |
| 2026-07-28 | Keep Tests to one controlled-test workflow with manual and automatic modes | Removes passive recording and keeps testing intentional |
| 2026-07-28 | Use metric timelines as the only Phase 7 test context | Exact elapsed and clock time lets testers correlate changes without screen or keyboard monitoring |
| 2026-07-28 | Establish a calm pastel, grain-and-blur visual language through Now | Makes the live view friendlier and more authored while retaining low-overhead native rendering |
| 2026-07-28 | Replace the pastel-bloom direction with elevated familiar minimalism | Dark mode read as neon and AI-themed; neutral native layering better supports calm editorial utility |
| 2026-07-29 | Adopt Observatory as the product name | Expresses the app's role as a durable record of live and controlled performance |

### 2026-07-29 — Observatory identity and persistent Settings

- Renamed the built product, executable, window/menu identity, and all
  user-facing runtime copy from Observatory to Observatory.
- Preserved the existing bundle identifier, internal modules, and
  `Application Support/Observatory` directory as compatibility identifiers so
  recordings and preferences survive the rename.
- Added persistent System, Light, and Dark theme choices plus Now, Tests, and
  History launch defaults.
- Added a top-right Settings entry point and a dedicated Settings scene using
  Observatory's warm-paper/graphite canvas, editorial type, opaque neutral panel,
  hairline edges, and authored option shelves.
- Updated the active concept, MVP, visual, storage, session, history, roadmap,
  workflow, and current-state documentation.

Verification:

- Debug build and all 34 automated tests passed; `git diff --check` passed.
- `./scripts/run.sh` built and launched
  `.build/Build/Products/Debug/Observatory.app`.
- Built metadata reports `Observatory` for both display name and executable while
  retaining `com.iggysleepy.observatory` for compatibility.
- Computer Use verified the Settings entry point, selected VoiceOver states,
  immediate light/dark/system appearance changes, and successful launches into
  Now, Tests, and History; final defaults were restored to System and Now.
- Populated light and dark Settings appearances were visually inspected and
  matched the active neutral Observatory design system.
- Next: continue Phase 9 compact-width, keyboard, VoiceOver, and long-duration
  release-hardening checks.

## Verification ledger

| Date | Area | Verification | Result |
| --- | --- | --- | --- |
| 2026-07-28 | Phase 8 exit gate | 34 tests plus populated History reopen, same/different-app comparison, exact inspection, and deletion-confirmation UI | Verified |
| 2026-07-28 | Metrics-only Phase 7 scope | Cross-specification review, Markdown diff check, and 28 tests | Passed |
| 2026-07-28 | Controlled-test-only scope | Cross-document term search, roadmap dependency review, Markdown diff check, and 28 tests | Passed |
| 2026-07-28 | Phase 6 exit gate | 28 tests, live unattended Finder/Zed rotation, ten samples per equal interval, public-API fallback, and no Accessibility permission | Verified |
| 2026-07-28 | Activation failure | Three bounded attempts, persisted visual failure reason, continuation to the next target, and Launch Services callback crash regression | Passed |
| 2026-07-27 | Phase 5 exit gate | 25 tests, one-app relaunch/reopen, two-app keyboard completion, recovery/cancel fixtures, and Debug launch | Verified |
| 2026-07-27 | Manual result math | Virtual-clock warm-up exclusion, repeated-round combination, immutable samples, and numeric memory conversion | Passed |
| 2026-07-27 | Session persistence | Migration v3 round/sample/summary round-trip, unfinished lookup, deletion, and portable folder summary | Passed |
| 2026-07-27 | Phase 4 exit gate | 20 tests, populated UI interaction/accessibility, preference relaunch, Debug launch, and optimized overhead measurement | Verified |
| 2026-07-27 | Now performance | Release live view: 0.84 CPU-seconds over 30 seconds; sampler 0.107 ms average and 0.131 ms p95 | Passed |
| 2026-07-27 | Phase 1 exit gate | Build, launch, navigation, accessibility, and four tests | Verified |
| 2026-07-27 | Sans-serif tab selection | Build, tests, and Computer Use visual inspection | Passed |
| 2026-07-27 | Navigation typography trial | Build, tests, and Computer Use visual inspection | Trial concluded; sans-serif restored |
| 2026-07-27 | Navigation focus | Build, tests, and Computer Use pointer/keyboard inspection | Passed |
| 2026-07-27 | Dia-inspired visual pass | Live-site study, build, tests, and Computer Use inspection | Passed; design review pending |
| 2026-07-27 | Neutral visual correction | Build, local Cursor comparison, and Computer Use inspection | Passed; design review pending |
| 2026-07-27 | Visual shell | Build, launch, and Computer Use inspection of all three destinations | Passed; design review pending |
| 2026-07-27 | Visual design | Cross-specification consistency review | Passed |
| 2026-07-27 | App shell | Computer Use launch and navigation through all three destinations | Passed |
| 2026-07-27 | Domain and persistence | Four Swift Testing tests via `xcodebuild test` | Passed |
| 2026-07-27 | Developer workflow | `scripts/run.sh` build and launch | Passed |
| 2026-07-27 | Documentation | Manual structure and consistency review | Passed |

### 2026-07-28 — Now card/list visual overhaul

- Rebuilt Now around persisted compact-card and stable-column list modes while
  retaining search, live metrics, pause, process expansion, grouping actions,
  and controlled-test handoff.
- Replaced stock sort and CPU pickers with custom contextual choice shelves.
- Added hover feedback to navigation, controls, cards, list rows and metrics,
  process rows, and quick actions, plus event-triggered spring/fade motion.
- Added a low-overhead static grain layer and accessibility-aware ambient pastel
  blur, and made expanded cards span the full grid width.
- Updated the Now and visual-design specifications to make this the active
  direction.

Verification:

- `xcodebuild ... test` passed all 34 tests.
- `./scripts/run.sh` built, signed, and launched the Debug application.
- Computer Use verified populated dark-appearance card/list switching, custom
  sort shelf, live hover feedback, required metric accessibility labels, and
  full-width inline process expansion.
- Next: user design review, then populated light appearance, Reduce
  Transparency, Increase Contrast, keyboard/VoiceOver, and observer-overhead
  regression.

### 2026-07-28 — Calm neutral visual correction

- Removed all ambient colored blur and glow from the application canvas.
- Replaced saturated accents, tinted metric panels, and colored selected states
  with warm paper/charcoal surfaces, neutral control feedback, and tiny muted
  functional marks.
- Reduced hover lift and shadow depth while preserving the card/list
  interactions and contextual custom controls.
- Reframed the active design direction as elevated familiar minimalism, soft
  utility modernism, contextual native UI, and friendly editorial productivity
  branding.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use verified populated dark-appearance list, card, hover, and custom
  sort-shelf states without the previous neon or AI-product cues.
- Next: populated light-appearance and accessibility calibration.

### 2026-07-28 — List expansion motion correction

- Made List the initial Now layout while preserving the user's persisted layout
  choice after they switch modes.
- Removed the viewport-relative top-edge movement from inline list details and
  replaced it with a short local fade; card expansion retains its compact
  spring response.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use verified that List is selected, process details expand in place,
  and the row returns to its collapsed state.
- Next: continue populated light-appearance and accessibility calibration.

### 2026-07-28 — Now interaction-frame correction

- Isolated one-second live metric refreshes from interaction animation and
  removed animated numeric transitions.
- Made large process disclosures atomic so SwiftUI no longer interpolates the
  layout of dozens of rows during insertion or removal.
- Replaced moving card shadows, hover lift, and changing accent geometry with
  short fixed-geometry opacity and tonal feedback.
- Shortened view-mode, navigation, hover, and press transitions to responsive
  80–140 ms ease-outs.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use verified populated List disclosure, collapse, Card/List
  switching, and restoration to the default collapsed List state.
- A bounded interaction sample confirmed the application remained mostly idle;
  the formal optimized observer-overhead regression remains part of Phase 9.
- Next: populated light-appearance and accessibility calibration, followed by
  optimized observer-overhead testing.

### 2026-07-28 — List-only Now experience

- Removed the Card layout, Card/List switcher, persisted layout preference, and
  all card-only grid and metric components.
- Consolidated Now around one stable-column dashboard List with inline process
  details and the existing search, sort, CPU representation, pause, advanced,
  and controlled-test actions.
- Updated the product concept, active Now and visual specifications, current
  state, and completed Phase 4 deliverable to describe the single List model.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use verified the populated List-only toolbar, confirmed there is no
  layout selector, exercised inline process disclosure, and restored the
  collapsed state.
- Next: continue populated light-appearance and accessibility calibration.

### 2026-07-28 — Compact two-column process ledger

- Replaced the full-width vertical process stack with an adaptive two-column
  ledger at normal widths.
- Compressed each process into a name/PID header and one evenly distributed
  five-metric line while retaining confidence, ownership actions, advanced
  evidence, and accessibility labels.
- Kept entries separator-based with quiet hover feedback so the denser layout
  does not become a second card view.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use inspected a populated light-appearance Brave expansion with 26
  processes arranged across 13 compact ledger rows; names, PIDs, five metrics,
  and confidence remained visible.
- Next: complete narrow-width, dark-appearance, keyboard, and VoiceOver
  calibration for the process ledger.

### 2026-07-28 — Expanded-ledger scroll performance

- Kept metric collection at the required one-second cadence while buffering
  visual publication for the duration of a native live-scroll gesture.
- Removed redundant per-second loading and notice publications that invalidated
  the Now view even when their values had not changed.
- Replaced the nested adaptive lazy grid with one stable paired ledger that
  preserves the compact two-column appearance, process order, narrow fallback,
  ownership controls, and metric accessibility.
- Suspended ledger hit testing only during live scrolling so rows moving under
  a stationary pointer do not generate repeated hover transactions; normal
  hover feedback returns immediately after the gesture.
- Isolated process metric text with equatable render boundaries so unchanged
  values do not redraw with neighboring metrics.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use inspected the populated 27-process light-appearance ledger
  before and after scrolling; the two-column rhythm, identifiers, five metrics,
  confidence, and following application rows remained intact.
- The same bounded Debug scroll trace dropped from a prior approximate 16% CPU
  peak to approximately 6% during the gesture. Idle expanded sampling remained
  mostly in the 4–9% range; a formal frame-pacing and optimized long-duration
  observer-overhead run remains part of Phase 9.
- Next: complete dark, narrow-width, keyboard, and VoiceOver calibration, then
  run the optimized long-duration observer-overhead gate.

### 2026-07-28 — Process-ledger hierarchy cleanup

- Replaced the five repeated metric labels in every process with one aligned,
  quiet metric header per ledger column.
- Reduced high-confidence ownership from repeated icon-and-text labels to a
  compact icon while retaining its help text and explicit VoiceOver label;
  lower-confidence ownership remains textual and actionable.
- Softened process-name typography so application totals retain the primary
  hierarchy.
- Replaced orientation-dependent SwiftUI dividers with explicit horizontal
  hairlines, removing the two vertical artifacts inside every ledger column.

Verification:

- Debug build and the full automated test suite passed.
- Computer Use inspected the populated 26-process light-appearance ledger at
  the top and after scrolling; the shared headers, paired reading order,
  metric values, confidence accessibility labels, and following application
  rows remained intact, with no vertical divider artifacts.
- Next: complete dark, narrow-width, keyboard, and VoiceOver calibration.

### 2026-07-28 — Independently virtualized process ledger

- Replaced the expanded application's single nested process subtree with one
  flat, stable row sequence in the outer lazy stack: application row, process
  heading, metric heading, and independently virtualized process-pair rows.
- Preserved the compact adaptive two-column ledger, shared metric headings,
  process order, narrow fallback, hover treatment, ownership actions, advanced
  evidence, and VoiceOver labels.
- Extended scroll detection from live-gesture start/end notifications to
  scroll-view bounds changes with a momentum-aware debounce, so live snapshots
  remain buffered during trackpad momentum and ordinary wheel scrolling.
- Evaluated a native SwiftUI `List` boundary and removed it after trace evidence
  showed 60–85 ms row-materialization stalls, retaining the flatter lazy stack
  that measured better.

Verification:

- Debug build and all 34 automated tests passed; `git diff --check` passed.
- Computer Use inspected the populated 26-process light-appearance ledger after
  relaunch; its two-column hierarchy, compact density, shared headings, and
  absence of the prior vertical divider artifacts remained intact.
- The original bounded expanded-scroll trace contained 22 main-thread delays
  (54.8 ms mean, 117.7 ms maximum). Flattening reduced the comparable trace to
  10 delays (51.0 ms mean, 106.8 ms maximum), although accessibility capture
  contaminated that aggregate. In the final live trace, the active automated
  scroll interval contained one threshold-level 33.5 ms delay; later 35–100 ms
  delays aligned with resumed one-second publication after scrolling ended.
- Next: repeat the observer-overhead and frame-pacing gate in an optimized build
  with manual trackpad input, then complete light, narrow-width, keyboard, and
  VoiceOver calibration.

### 2026-07-28 — Dark ledger surface restoration

- Removed the permanent neutral fill from every flattened process heading,
  metric heading, and process-pair row, restoring one continuous graphite
  panel organized by alignment and hairline separators rather than stacked
  slabs or row capsules.
- Reduced the expanded application header to a barely lifted neutral state;
  its stronger tonal feedback now appears only under pointer hover.
- Made process hover state scroll-aware and reset it when a virtualized row
  receives a different process, preventing a row that passed under the pointer
  from remaining visibly highlighted after scrolling.

Verification:

- Debug build and all 34 automated tests passed; `git diff --check` passed.
- Computer Use inspected the populated 26-process dark ledger before and after
  a down/up scroll. The continuous surface, two-column hierarchy, shared
  headers, hairlines, and one local hover highlight remained intact with no
  stuck row fills.
- Next: complete populated light, narrow-width, keyboard, and VoiceOver
  calibration.

### 2026-07-29 — Native Now scroll boundary restored

- Restored a dedicated native SwiftUI `List` after direct trackpad feedback
  showed that the outer lazy-stack implementation remained visibly choppy.
- Kept the page header and controls outside the scroll surface while preserving
  stable flattened application, heading, metric, and process-pair rows inside
  the list.
- Preserved the continuous ledger surface, compact two-column hierarchy,
  hairline separators, scroll-aware hover cleanup, and advanced process panel
  without reintroducing stock list chrome or stacked row slabs.
- Reclassified synthetic page-jump and accessibility-inspection traces as
  diagnostic evidence rather than scroll-smoothness acceptance because those
  tools alter both input behavior and accessibility serialization work.

Verification:

- Debug build, all 34 automated tests, and `git diff --check` passed.
- Computer Use confirmed that the populated 18-process ledger exposes
  independent native platform rows and preserves the compact two-column layout,
  following application rows, and continuous surface after a bounded down/up
  scroll.
- Direct trackpad confirmation remains the acceptance gate for perceived
  smoothness; if it still misses frames, the next trace must use manual input
  without accessibility-hierarchy capture.

### 2026-07-29 — Scrolling virtualized ledger frame

- Removed the rounded panel fill and border from the fixed native-list viewport.
- Reconstructed the continuous panel from lightweight top, middle, and bottom
  row surfaces, keeping every process pair independently virtualized while
  allowing the panel's beginning and end to travel with its content.
- Limited borders to the true outer edges, preserving the uninterrupted ledger
  surface without stock list chrome, repeated row outlines, or a false fixed
  card.

Verification:

- Debug build, all 34 automated tests, and `git diff --check` passed.
- Computer Use inspected the populated 17-process light ledger at its origin
  and after a bounded one-page scroll. The rounded top and column header left
  with the content, the middle surface remained seamless, and the rounded
  bottom arrived with the final application row.
- Native accessibility still exposed the application, heading, and process-pair
  rows independently. Direct trackpad confirmation remains the scroll-feel
  acceptance gate.

### 2026-07-29 — Tests and History interaction overhaul

- Rebuilt controlled-test setup as one focused, progressively disclosed
  workflow with descriptive mode choices, compact application selection,
  authored duration/round/warm-up/shortcut shelves, and a local scope/time
  summary beside the start action.
- Replaced History's nested card grid with one compact ledger per saved test.
  Application identity and aligned summary metrics now form a full-width open
  action, while a separate trailing control manages comparison selection.
- Made comparison actions contextual, reduced destructive controls until
  hover, added calm hover/press feedback, and carried the authored choice
  language into result metric, scale, and warm-up controls.
- Updated session surfaces to the warm paper and graphite system used by Now;
  single-application summaries and charts now consume their available width.

Verification:

- Debug build, all 34 automated tests, and `git diff --check` passed.
- Computer Use inspected populated Tests setup, its selected and expanded
  advanced states, the History library, one- and two-result comparison
  selection, a saved result, and a cross-test comparison.
- Temporary macOS Dark appearance review confirmed neutral graphite surfaces,
  restrained selection, and legible hierarchy in populated Tests, History, and
  saved-result states; the original Automatic appearance setting was restored.
- Next: complete compact-width, keyboard, and VoiceOver calibration of the new
  controls alongside the remaining Now release-hardening gates.

### 2026-07-29 — Immediate System appearance restoration

- Replaced scene-local SwiftUI color-scheme preferences with one app-wide
  AppKit appearance override.
- Choosing System now synchronously clears the application and every open
  window override, while Light and Dark apply their corresponding native
  appearances to the same scope.
- Preserved the stored preference at launch and native inheritance of later
  macOS appearance changes while System remains selected.

Verification:

- Reproduced Light → Dark → System with the Settings window left open and no
  intervening control action; System immediately returned the Settings surface
  to the current light macOS appearance.
- Debug build, all 34 automated tests, `./scripts/run.sh`, and
  `git diff --check` passed.
- Next: continue the remaining Phase 9 appearance and accessibility review.

### 2026-07-29 — Summoned Settings card

- Replaced the separate system Settings scene with an in-app modal card over
  the current Observatory destination.
- Added a gear-origin scale, offset, fade, and short spring summon; the gear,
  selection icons, custom close control, and return transition use compact
  event-triggered motion with a fade-only Reduce Motion path.
- Preserved Command–Comma and added dismissal through the custom close control,
  the active gear, Escape, and the dimmed backdrop.
- Removed pointer and accessibility interaction from the underlying workspace
  while Settings is present and placed initial keyboard focus on the custom
  close control.

Verification:

- Computer Use inspected the populated light summoned card and confirmed that
  no separate window or system title bar appears.
- Custom close, Escape, backdrop, and Command–Comma summon/dismiss paths passed;
  the modal accessibility tree exposed only Settings and its controls.
- Dark → System still returned the open summoned card and underlying workspace
  to the light system appearance immediately.
- Debug build, all 34 automated tests, `./scripts/run.sh`, and
  `git diff --check` passed.
- Next: include the summoned card in the remaining keyboard, VoiceOver, Reduce
  Motion, and Increase Contrast release-hardening pass.

### 2026-07-29 — App-first Tests setup and native film grain

- Reordered controlled-test preparation so compact application selection leads,
  followed by a small manual/foreground-idle method shelf, test name, timing,
  and rounds; kept the scope/time start action ahead of advanced controls.
- Changed new and reset test drafts to default warm-up to none and updated the
  local duration summary accordingly.
- Added persisted Off, Fine, and Paper background-grain preferences with an
  immediate in-card preview.
- Replaced the sparse dot renderer with a cached native Core Image
  `CIRandomGenerator` luminance-to-alpha mask. The dense film grain is generated
  and rasterized once, tiled statically, tinted for light/dark appearance, and
  removed under Reduce Transparency; no generated or downloaded bitmap ships
  with the app.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use inspected the compact populated Tests setup, selected-app and
  expanded advanced states, confirmed warm-up None and the no-warm-up summary,
  and verified distinct Off/Fine/Paper states.
- Populated light and dark inspection confirmed dense film-like grain without
  isolated flecks; System appearance and Fine grain were restored afterward.
- `./scripts/run.sh` and `git diff --check` passed.
- Next: include the new Tests controls and grain preferences in the remaining
  keyboard, VoiceOver, Reduce Transparency, and Increase Contrast pass.

### 2026-07-29 — Luminance-balanced grain calibration

- Replaced the dark-only grain mask with a mid-gray Core Image noise field using
  Overlay composition, so individual pixels vary lighter and darker around the
  original canvas tone.
- Recalibrated Fine and Paper independently for light, dark, and Increase
  Contrast appearances and made the in-Settings preview use the same effective
  strength.
- Preserved the user's current Paper selection while removing the progressive
  background darkening that previously accompanied stronger grain.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use inspected the populated light Paper canvas before and after the
  change; the final canvas retained its original warm off-white luminance while
  keeping the dense static texture.
- `./scripts/run.sh` and `git diff --check` passed.
- Next: include the balanced grain in the remaining Reduce Transparency and
  Increase Contrast calibration.

### 2026-07-29 — Dark micro-grain mask correction

- Corrected the grain interpretation after visual review: the warm canvas now
  remains untouched while only the inverted tail of the noise field becomes
  dark, partially transparent micro-grain.
- Removed Overlay composition and thresholded the native Core Image noise into
  a transparent dark-ink mask, preventing stronger settings from introducing a
  light or gray full-canvas wash.
- Recalibrated Fine and Paper for the new mask and slightly amplified only the
  compact live preview so the choice remains easy to judge.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use compared Paper with Off in the running light app, confirmed that
  Off exposes the flat warm canvas while Paper adds only dense dark micro-grain,
  then restored the user's Paper selection and dismissed Settings.
- Next: verify that Off preserves the bare canvas and Fine/Paper add progressively
  darker micro-grain under dark and Increase Contrast appearances.

### 2026-07-29 — Full-field inverted grain restoration

- Removed the thresholded dark-only alpha mask after visual review showed that
  it no longer resembled the earlier film grain and disappeared against the
  dark canvas.
- Restored the continuous grayscale Core Image field and Overlay composition,
  while retaining `CIColorInvert` so the opposite noise samples now sit above
  and below the neutral blend midpoint.
- Restored the proven appearance-specific Fine and Paper strengths and made the
  compact preview match the canvas effect exactly.

Verification:

- Debug build and all 34 automated tests passed.
- Computer Use compared populated Paper and Off canvases in dark appearance,
  confirmed that the restored full-field grain remains clearly visible, and
  inspected the same Paper field in light appearance.
- Restored the user's Dark appearance and Paper grain selection and dismissed
  Settings after verification.
- Next: include the restored full-field grain in the remaining Increase
  Contrast calibration.

### 2026-07-29 — Grain feature removal

- Removed background grain after product review found that the decorative
  texture added clutter without improving hierarchy.
- Removed the native Core Image renderer, Overlay composition, persisted grain
  preference, Off/Fine/Paper controls, live preview, and Settings-card texture.
- Retained the clean warm neutral light and dark canvases; typography, borders,
  opaque surfaces, spacing, and restrained shadows now provide all hierarchy.
- Updated the active MVP, visual specification, and current-state snapshot to
  remove grain from the product and remaining hardening work.

Verification:

- Debug build and all 34 automated tests passed.
- Repository search confirmed that no active grain renderer, preference,
  control, or specification requirement remains.
- Computer Use inspected the populated clean canvas and the simplified
  two-section Settings card in the current system appearance; the card reflowed
  without leftover space, and Settings was dismissed afterward.
- Next: continue the remaining light/dark, keyboard, VoiceOver, and
  accessibility hardening on the clean canvas.

### 2026-07-29 — Saved Results consolidation

- Reduced the global navigation to Now and Tests and moved the completed-test
  library into a collapsible Saved Results rail inside Tests.
- Removed the duplicate Recent controlled tests section while retaining the
  automatic full-result presentation after a test completes.
- Added explicit complete-test opening, individual application-result opening,
  a labeled comparison-selection mode, whole-test application selection, and a
  visible two-to-four-result action tray inside the rail.
- Migrated the retired History launch preference to Tests with Saved Results
  initially expanded and reduced the Settings launch choices to Now and Tests.
- Stopped treating different application versions as a warning unless the
  compared results share one application identity, removed recording date as a
  warning by itself, and labeled application and macOS versions explicitly.
- Updated the concept, MVP, sessions, saved-results, visual, architecture, and
  implementation-plan documents for the two-destination product structure.

Verification:

- Debug build and all 35 automated tests passed, including a new regression for
  different-application version warnings.
- Computer Use inspected the two-tab navigation, collapsed and expanded Saved
  Results states, complete-test reopening beside the rail, explicit comparison
  mode, whole-test selection, persistent action tray, and a same-test
  comparison without the irrelevant version warning; it also confirmed that
  Settings now offers only Now and Tests as launch destinations.
- `./scripts/run.sh` and `git diff --check` passed.
- Next: calibrate the new rail at compact width and in dedicated light/dark,
  keyboard, VoiceOver, Reduce Transparency, and Increase Contrast passes.

### 2026-07-29 — Full-width Saved Results correction

- Replaced the narrow Saved Results side rail after product review found that
  it made both the library and test setup feel cramped and cluttered.
- Saved Results is now a dedicated full-width mode within Tests. Switching
  between it and New Test preserves the in-progress setup draft, while opened
  complete tests, individual results, and comparisons also use the full canvas.
- Retained the improved direct selection of individual application results and
  widened browse rows to expose aligned CPU, memory, and duration summaries.
- Updated the active concept, MVP, sessions, saved-results, and visual
  specifications to make the full-width workspace behavior authoritative.

Verification:

- Debug build and all 35 automated tests passed.
- Computer Use inspected the populated full-width library, comparison selection
  mode, cross-test selection tray, full-width individual result, Done return to
  the library, and New Test return to the preserved setup.
- `git diff --check` passed.
- Next: calibrate the revised library at compact width and in dedicated
  light/dark, keyboard, VoiceOver, Reduce Transparency, and Increase Contrast
  passes.

### 2026-07-29 — Contextual Saved Results inspection browser

- Kept New Test and the resting Saved Results library as separate full-width
  states, then added a concise Saved Results browser beside any test, individual
  result, or comparison opened from the library.
- Kept the inspection pane dominant while preserving search, complete-test
  opening, individual-result switching, and comparison selection in the
  contextual browser.
- Defaulted the contextual browser to the right and added explicit controls to
  move it left or right, hide it so the result regains full width, and reveal it
  again on the chosen side. The side choice persists locally.
- Made Done restore the full-width library and made New Test close the entire
  saved-results workspace, clear transient comparison selection, and return to
  the preserved setup.
- Updated the concept, MVP, Tests, Saved Results, visual, and current-state
  documents for the three-state interaction.

Verification:

- Debug build and all 35 automated tests passed.
- Computer Use inspected the full-width library, right-side and left-side
  inspection layouts, individual-result switching, comparison inspection,
  hide/full-width/reveal behavior, persisted side choice after relaunch, Done
  return, and clean New Test exit and re-entry.
- `./scripts/run.sh` and `git diff --check` passed.
- Next: calibrate the contextual browser at compact width and in dedicated
  light/dark, keyboard, VoiceOver, Reduce Transparency, and Increase Contrast
  passes.

### 2026-07-29 — Now live totals plot

- Added a centered bottom plot containing the latest 60 seconds of the combined
  sampled running-application total for CPU, memory, disk I/O, wakeups, and
  process count.
- Added an Applications toggle that overlays quieter, individually colored
  application lines and reveals a text-labeled horizontal legend.
- Reused the Results metric shelf, toggle button, metric model, axis formatting,
  and legend stroke instead of introducing parallel chart controls.
- Kept the live timeline lightweight, bounded, in memory, synchronized with
  paused/scroll-buffered visual publication, and honest about missing values by
  leaving aggregate gaps.

Verification:

- Debug build and all 36 automated tests passed, including a new bounded
  live-timeline presentation regression.
- Computer Use inspected the populated bottom-centered aggregate chart and the
  toggled per-application lines and legend with real live samples.
- `./scripts/run.sh` and `git diff --check` passed.
- Next: verify the plot at compact width and in dedicated dark, keyboard,
  VoiceOver, Reduce Transparency, and Increase Contrast passes, then include it
  in the long-duration observer-overhead gate.

### 2026-07-29 — Pointer focus-ring cleanup

- Made focus effects input-aware at the root app canvas: pointer clicks move
  button focus to a hidden non-rendering sink, while keyboard input restores
  ordinary focus traversal and visible focus indication.
- Kept text-field pointer focus intact by accessibility-hit-testing the clicked
  element before resetting button focus.
- Preserved keyboard shortcuts, activation, accessibility semantics, and the
  app's existing authored neutral focus treatments.

Verification:

- `./scripts/run.sh` completed a successful Debug build and launch.
- Computer Use verified that Tab navigation retains a visible focus indicator,
  a physical pointer click clears it without leaving a blue rectangle, and a
  physical pointer click in the Now search field still gives it editing focus.
- Next: complete the planned end-to-end keyboard and VoiceOver review.

### 2026-07-29 — Live plot metric correctness and series inspection

- Fixed live memory totals being interpreted as floating-point bit patterns
  instead of numerically converting the sampled byte counts.
- Centralized the live CPU, memory, combined disk I/O, wakeup, and process-count
  projections in the presentation domain and kept combined totals unavailable
  whenever any contributing application value is missing.
- Added nearest-series pointer and click inspection with application name,
  exact formatted value, and clock time, plus persistent selection, selected
  line emphasis, distinct application dash patterns, and selectable legend
  labels.

Verification:

- Debug build and all 38 automated tests passed, including numeric memory
  conversion, all-five-metric aggregation, and aggregate missing-value
  regressions.
- `./scripts/run.sh` built and launched Observatory successfully.
- Computer Use verified a real 5.8 GiB live memory total, nonzero disk and
  wakeup rates, process-count totals, legend selection of ChatGPT, and direct
  plot selection of the combined line with accessible name/value/time details.
- Next: complete the planned compact-width, dark, keyboard, VoiceOver, Reduce
  Transparency, Increase Contrast, and long-duration observer-overhead passes.

### 2026-07-29 — Live plot system-capacity scale

- Added Fit and System vertical-scale choices to the Now live plot using the
  existing authored result-chart choice buttons.
- System scale maps CPU to the Mac's logical processor capacity in the active
  CPU representation and memory to installed physical RAM; the live heading
  reports the current total relative to that capacity.
- Kept disk throughput, wakeups, and process count fitted because they have no
  truthful fixed machine-capacity value.

Verification:

- Debug build and all 39 automated tests passed, including an eight-logical-CPU
  and 16 GiB capacity projection regression across every CPU representation.
- `./scripts/run.sh` built, signed, and launched Observatory successfully.
- Computer Use verified the live Memory heading as `5.6 GiB of 16 GiB`, the
  System selection state, and the fitted-scale alternative on the running Mac.
- Next: include both scale modes in the planned compact-width, dark, keyboard,
  VoiceOver, Reduce Transparency, Increase Contrast, and long-duration passes.

### 2026-07-29 — Phase 9 release candidate and quieter global composition

- Removed the repeated large Now and Tests page titles so both destinations
  begin with their working surface. Kept purpose copy available through concise
  tab help and accessibility hints instead of permanent explanatory chrome.
- Added Command–1 and Command–2 destination shortcuts, explicit tab semantics,
  and a compact New Test/Saved Results workspace shelf.
- Added Observatory version and local-only privacy context to Settings, and
  documented the refined global composition in the visual design concept.
- Added the public README, privacy disclosure, installation guide, known
  limitations, release checklist, and a repeatable ad-hoc release script that
  tests Debug, archives optimized Release, verifies signing, and emits a ZIP
  with its SHA-256 checksum.

Verification:

- The complete 39-test Debug suite passed and the optimized universal Release
  archive succeeded for arm64 and x86_64.
- `codesign --verify --deep --strict` passed for the archived application, and
  the generated archive checksum was verified locally.
- `./scripts/measure-sampler.sh` passed with 2,500 of 2,500 samples, 0.118 ms
  average sampler latency, 0.176 ms p95 latency, and an estimated 0.012% of one
  core at a one-second cadence.
- Computer Use inspected populated Now, Tests, and Settings in the running app;
  confirmed the headerless light and dark hierarchy, explicit Tests workspace
  selection, tab help, and Command–1 navigation; System appearance was restored
  afterward.
- Phase 9 remains in progress pending direct-trackpad/window-size review, the
  full keyboard and VoiceOver pass, accessibility appearance variants,
  30-minute reliability testing, and clean-user-account installation.

### 2026-07-29 — Editorial destination captions and simpler app choices

- Removed explanatory hover tooltips from the Now and Tests tabs and placed
  their purpose inside each canvas as a quiet italic-serif line.
- Simplified running-application choices to one compact icon-and-name scan line.
  Removed the persistent version row and empty radio circle, retained a minimal
  selected checkmark, and added a small information symbol whose hover help
  reveals the application version.
- Preserved selected-state and version semantics for accessibility.

Verification:

- The complete 39-test Debug suite passed, and `./scripts/run.sh` built, signed,
  and launched Observatory successfully.
- Computer Use inspected populated Now and Tests in System and dedicated Dark
  appearances. It confirmed the caption hierarchy, compact application tiles,
  selected state, and version help; the System appearance preference was
  restored afterward.
- Next: include these revised controls in the pending compact-window, complete
  keyboard, VoiceOver, and accessibility-appearance release gates.

### 2026-07-29 — Immediate application-version hover label

- Replaced the delayed native help tooltip on application information symbols
  with an authored, immediate hover label.
- Enlarged the information symbol's pointer target while keeping its visible
  mark small, and kept the transient label noninteractive so it does not flicker
  or interfere with selecting the application.

Verification:

- The complete 39-test Debug suite passed.
- `git diff --check` passed.
- Next: include the immediate hover label in the pending direct-pointer and
  accessibility-appearance release checks.

### 2026-07-29 — Settings backdrop hover isolation

- Removed the redundant root hit-testing disable that prevented SwiftUI from
  delivering final hover-exit events when the summoned Settings card appeared.
- Kept the full-window backdrop as the pointer owner, so underlying controls
  clear hover styling but cannot activate while Settings is present.
- Preserved the modal-only accessibility tree and initial focus on the custom
  Settings close control.

Verification:

- Computer Use positioned the pointer over the underlying Tests destination,
  summoned Settings with Command–Comma, and confirmed the hover treatment
  cleared instead of freezing beneath the backdrop.
- Clicking that underlying location while Settings was open dismissed through
  the backdrop without switching destinations.
- The complete 39-test Debug suite, `./scripts/run.sh`, and
  `git diff --check` passed.
- Next: include this modal pointer boundary in the pending direct-pointer and
  VoiceOver release checks.
### 2026-07-29 — Settings hover isolation correction

- Replaced the backdrop-only hover fix with an explicit workspace interaction
  environment: summoning Settings now clears every underlying hover highlight,
  ignores subsequent workspace hover updates, disables workspace hit testing,
  and keeps the Settings card's own hover interactions active.
- Verified the reported Finder-row case by placing the pointer on the Settings
  card above that row; Finder remained visually neutral and the accessibility
  tree exposed only Settings controls.
- Verification: Debug build succeeded and all 39 automated tests passed.
- Next: continue the remaining release-hardening accessibility and appearance
  gates.

### 2026-07-30 — Observatory product identity

- Renamed the user-facing product from Observatory to Observatory across the app,
  build output, release artifacts, runtime language, tests, and active
  documentation.
- Retained the Observatory scheme, module names, and Application Support directory
  for source and saved-result compatibility.
- Changed the app and supporting target bundle identifiers to the
  `com.iggysleepy.observatory` namespace.

Verification:

- The complete 39-test Debug suite passed, and `./scripts/run.sh` built, signed,
  and launched `Observatory.app`.
- Built metadata reports `Observatory` for both display name and executable and
  `com.iggysleepy.observatory` for the app bundle identifier.
- `git diff --check` passed.
- Next: continue the remaining release-hardening accessibility, appearance,
  reliability, and clean-account distribution gates under the Observatory
  identity.

### 2026-07-30 — Opaque application-version hover label

- Replaced the translucent system window color behind the Tests application
  version label with the app's fully opaque light and dark neutral panel
  colors.
- Moved the version label from inside the button content to the button's
  outermost overlay. This prevents the application-card stroke, which SwiftUI
  renders later than button content, from being painted over the label.
- Preserved the existing label geometry, edge, shadow, immediate reveal, and
  noninteractive pointer behavior.

Verification:

- The complete 39-test Debug suite passed.
- `./scripts/run.sh` built, signed, and launched Observatory successfully.
- The populated Tests setup was inspected in the running app, and
  `git diff --check` passed.
- Next: include the label in the pending dedicated dark, Increase Contrast,
  and direct-pointer release checks.

### 2026-07-30 — Observatory application icon

- Added the authored layered Icon Composer document as the app icon source.
- Generated the complete conventional macOS `AppIcon` asset set so the current
  Xcode 16.2 toolchain can ship the design at every required size.
- Added a repeatable icon-generation script and taught the Xcode project
  generator to include the asset catalog.

Verification:

- `./scripts/run.sh` built, signed, registered, and launched Observatory
  successfully.
- The built app contains compiled `AppIcon.icns` and `Assets.car` resources,
  and its Info.plist names `AppIcon` as both `CFBundleIconFile` and
  `CFBundleIconName`.
- Next: retain the layered source as the authority and switch to direct Icon
  Composer integration when the project adopts a compatible Xcode release.

### 2026-07-31 — Native Icon Composer integration

- Replaced the Xcode 16 compatibility asset catalog with the original layered
  `observatory_icon.icon` document as the app target's direct icon source.
- Updated both checked-in project settings and the project generator to compile
  `observatory_icon` through Xcode 26.
- Removed the obsolete flattened-icon generation workflow while preserving the
  deployment target and Xcode-generated conventional fallback for macOS 14–15.

Verification:

- A clean Xcode 26.6 Debug build succeeded, signed locally, registered with
  Launch Services, and launched Observatory.
- The clean app bundle contains only `Assets.car` and
  `observatory_icon.icns` for its app icon, and its Info.plist names
  `observatory_icon` for both icon keys.
- Asset inspection confirmed layered Aqua, Dark Aqua, and Tintable icon stacks
  plus generated 16–1024 px fallback renditions.
- Tahoe Finder visual checks passed for Default, Dark, Clear, and Tinted icon
  styles; the user's original Default icon-style preference was restored.
- `codesign --verify --deep --strict` and `git diff --check` passed.
- Next: include the layered icon in the packaged clean-account release check.
### 2026-07-31 — Complete Observatory repository identity

- Renamed the Xcode project, scheme, application target, modules, source
  folders, test target, Swift imports, protocols, serializer helpers, scripts,
  temporary paths, and private Application Support directory to Observatory.
- Removed every occurrence of the retired product names from source,
  documentation, project metadata, generated build products, and history.
- Moved existing local development data into
  `Application Support/Observatory`.
- Regenerated `Observatory.xcodeproj` and verified all 39 tests across six
  suites with the Observatory scheme.
- Next task: package and validate the distribution archive.

### 2026-07-31 — Public repository preparation

- Expanded ignore rules for build output, Xcode state, editor metadata, local
  environment files, signing material, archives, and test results.
- Audited the public tree for credentials, personal paths, generated files,
  oversized assets, and ignored files already tracked by Git; no secrets or
  tracked local artifacts remain in the release tree.
- Corrected the source-build requirement to Xcode 26 for the layered
  application icon.
- Replaced the local development history with one clean public root commit
  after saving the original history in an external recovery bundle.
- Next task: create the GitHub repository and publish the release.
