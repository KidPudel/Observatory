# Now view specification

Status: Active

## Purpose

Now answers: “What are my applications doing right now?” It presents
application totals first and keeps process details available without making them
the primary interface.

## Default state

- Now is selected when the app opens.
- A calm dashboard list contains running applications.
- The monitor itself appears like any other selectable application but is never
  included in another application's totals.
- System-only and unassigned processes are hidden by default behind an advanced
  filter.

## Application row

Each row contains:

- application icon and display name;
- foreground, visible, hidden, or idle state;
- CPU now;
- memory now and session/live peak;
- disk read/write rate;
- wakeup activity;
- grouped process count;
- an unavailable or partial-data indicator when required.

Clicking a row expands an inline process list. Expansion must not navigate away
or stop live updates.

## Metric presentation

CPU representation options:

- Activity Monitor-style percentage, default;
- core-equivalents;
- percentage of total logical CPU capacity.

The selected representation is persisted. A tooltip or detail view shows all
representations and the averaging window.

Memory uses human-readable binary units consistently. Disk shows read and write
directions separately when both are material.

Words such as Low, Moderate, or High supplement values; they never replace the
underlying measurement.

## Live totals plot

- A compact, bottom-centered plot shows the most recent 60 seconds of the
  combined sampled running-application total.
- The metric selector uses the same CPU, memory, disk I/O, wakeups, and process
  count choices as controlled-test result timelines.
- CPU follows the active Now representation. Other metrics retain the units
  used by the application list.
- CPU and memory offer fitted and system-capacity vertical scales. CPU capacity
  follows its active representation and logical processor count; memory
  capacity uses installed physical memory. The live heading states the current
  value relative to that capacity.
- Disk throughput, wakeups, and process count remain fitted because they do not
  have one truthful fixed system-capacity value.
- An optional Applications control adds one labeled line for each running
  application while retaining the stronger combined-total line.
- Hovering or clicking the plot selects the nearest visible line and reveals
  its application name, exact value, and clock time. The selected line becomes
  stronger while the remaining lines recede.
- Application lines supplement color with distinct stroke patterns, and their
  text legend entries can also select a line.
- Missing application values create a gap in the combined line rather than
  being treated as zero.
- The timeline remains bounded and in memory. It is never added to Saved
  Results or other persistent storage.

## Process details

Each process row can show:

- process name and PID;
- CPU, memory, disk, wakeups, and thread count;
- ownership confidence;
- ownership evidence;
- include or exclude action for ambiguous processes.

At normal widths, expanded processes use an adaptive two-column ledger of
compact two-line entries. Narrow widths fall back to one column. The layout
must preserve process order, metric labels, ownership actions, and VoiceOver
reading order. Repeated metric labels use one quiet header per ledger column
rather than appearing inside every process entry. High-confidence ownership may
use a compact icon when its full meaning remains available through help and
accessibility; lower confidence remains textually explicit.

Process pairs must have stable identities and participate independently in the
dedicated native virtualized scroll surface. An expanded application must not
place all of its members inside one monolithic child whose off-screen rows are
remeasured together.

The dashboard panel's visible beginning and end must travel with its native list
content. Its rounded frame must not remain fixed as though the rows were
scrolling through a stationary card viewport.

Technical identifiers are hidden until the user opens advanced details.

## Interaction

- Search matches application names first and process names second.
- A compact custom control strip reveals contextual choice shelves for sorting
  and CPU representation without stock picker menus.
- Sort options include name, CPU, memory, disk, wakeups, and process count.
- Sort changes should use stable animation and avoid visually reordering every
  second unless the user selected a live metric sort.
- The user can pause visual updates without stopping collection.
- A quick action adds an application to a new controlled test.
- Pointer hover clarifies interactive rows, metrics, controls, and quick actions
  without hiding functionality from keyboard or VoiceOver users.

## Empty and partial states

- When no user applications are available, explain that the view will populate
  as applications launch.
- If one metric is unavailable, keep the row and label only that metric
  unavailable.
- If ownership is incomplete, show “Partial total” with an explanation.

## Acceptance criteria

- The view displays application totals rather than a flat process table.
- Values update at the configured live cadence.
- Expanding and collapsing a group does not alter its totals.
- Large process groups do not create avoidable full-width whitespace or require
  one oversized vertical row per process at normal widths.
- Scrolling a large expanded group does not remeasure every off-screen process
  pair or publish live snapshot replacements during the active scroll and
  momentum interval.
- The dashboard list exposes all required application metrics, inline
  expansion, and the controlled-test quick action.
- The live totals plot remains centered below the list, switches all five
  metrics, can show or hide labeled application lines, and identifies the
  selected line with its name, exact value, and clock time.
- System scale uses the current Mac's logical CPU capacity or installed
  physical memory without changing the underlying samples.
- CPU representation changes produce mathematically equivalent values.
- The CPU representation preference survives relaunch.
- Inaccessible metrics never appear as zero unless zero was genuinely measured.
- Live timeline memory remains bounded and its samples are not persisted.
- Ambiguous process ownership is discoverable without cluttering every row.
- VoiceOver and keyboard users can reach rows, metrics, and process actions.
