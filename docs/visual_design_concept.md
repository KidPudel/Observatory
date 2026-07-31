# Visual design

Observatory should feel calm, precise, and native. It is a technical tool, but
it should not feel cold or crowded.

## Character

- Editorial, not decorative.
- Friendly, not playful.
- Dense where data needs it; spacious everywhere else.
- Native macOS behavior with a more considered finish.
- Warm neutral surfaces, clear type, and restrained depth.

No ambient gradients, neon, glass-heavy effects, or decorative animation.
Application icons and data provide the color.

## Layout

The app uses one open canvas without a permanent sidebar.

- Normal window: about `980 × 680`.
- Compact window: down to `820 × 600`.
- Outer spacing: 24 points, or 16 in compact layouts.
- Use a four-point spacing grid.
- Let narrow layouts collapse into one clear vertical flow.

Now and Tests share one centered tab bar at the top. The selected destination
is not repeated as a large title. Each view starts with a quiet serif purpose
line and its actual controls.

Settings opens as a card inside the current window. It uses the same materials
as the rest of the app and blocks interaction with the canvas behind it.

## Color and depth

Light mode uses a warm off-white canvas around `#F8F7F4`. Dark mode uses neutral
graphite around `#1B1B1B` to `#131313`.

Surfaces are opaque and close to the canvas color. Hairline borders and short,
soft shadows create depth. There should be no more than three visible levels:
canvas, content, and overlay.

Color has a job:

- CPU: muted slate blue.
- Memory: soft violet.
- Disk: desaturated sage.
- Wakeups: muted ochre.
- Errors and destructive actions: semantic red.

Chart series use cyan, violet, mint, and warm coral. Labels and line patterns
must also identify them.

## Type and icons

Use native macOS fonts.

- Serif for purpose lines, editorial headings, and empty states.
- SF Pro for controls, labels, and data.
- Monospaced digits for live values.
- SF Symbols for familiar actions.
- Application icons remain the strongest visual identity.

The interface should have clear contrast between large editorial text and
compact data. Do not use large headings just to repeat navigation.

## Components

- Cards use calm neutral fills, a fine edge, and compact spacing.
- Lists use alignment and separators, not a capsule around every row.
- Primary actions have strong contrast. Secondary actions stay quiet.
- Common selectors use the app's own shelves and pills.
- Advanced controls stay hidden until needed.
- Selection uses an edge, checkmark, or tonal change instead of a bright fill.
- Missing data is explained locally.
- Recording is always shown with text, not color alone.

Charts share one visual language: sparse grids, clear axes, stable scrubbing,
and exact values. Missing data, warm-up, and foreground state need distinct
marks.

Empty states use one short explanation and at most one primary action.

## Now

Now is a stable dashboard list.

Application identity comes first, aligned live metrics second, and quick
actions last. Process details expand inline as a compact ledger. At normal
widths the ledger uses two columns; compact layouts use one.

The live chart sits below the list. The total line is strongest. Application
lines are quieter but always labeled and remain distinguishable without color.

## Tests

Test setup starts with application selection, then method and timing. Warm-up,
notes, and other advanced choices come later. The start area always summarizes
what will happen.

The recording prompt is a small draggable panel near the top of the active
display.

Saved Results is a full-width mode inside Tests. When a result or comparison is
open, the library becomes a small browser beside it. The browser can move,
hide, and return without closing the result.

Results and comparisons use the full available width. Warnings appear before
the charts they qualify.

## Motion and accessibility

Motion is short and local. Hover and press feedback lasts about 80–120 ms;
view changes may cross-fade up to 160 ms. Live values update without animation.
Reduce Motion replaces movement with a fade or an immediate change.

Every action remains available to keyboard and VoiceOver users. Focus is
visible. Light, dark, Reduce Transparency, and Increase Contrast preserve the
same hierarchy. Meaning never depends on color alone.

Observatory measures performance, so the interface must not add continuous
visual work. No particles, shaders, parallax, cursor tracking, or decorative
loops.
