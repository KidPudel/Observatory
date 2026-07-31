# Observatory

Observatory is a native macOS activity monitor for developers and power users.
It shows the resource use of whole applications, records controlled tests, and
makes results easy to compare.

## Principles

- Applications come first. Processes are supporting detail.
- Measurements have clear units and time ranges.
- Missing data is never shown as zero.
- Comparisons keep the original samples and show differences in context.
- Everything stays local.
- The monitor stays lightweight.

## Now

Now shows what running applications are using.

Related processes are grouped into one application total. Each application
shows CPU, memory, disk activity, wakeups, process count, and state. The row can
expand to show its processes and grouping details.

A 60-second chart shows the live total. It can also show separate application
lines. CPU and memory can be viewed against the Mac's capacity.

Now is temporary. It does not save samples.

## Tests

Tests records one to four applications in two ways:

- Manual guided: the user performs the workload.
- Automatic foreground idle: Observatory brings each application forward for
  the same amount of time without simulating input.

A test can have a warm-up and repeated rounds. Only one test runs at a time.

Results contain summaries and timelines for CPU, memory, disk activity,
wakeups, and process count. Exact values can be inspected by elapsed time and
clock time.

Saved Results keeps completed tests inside Tests. A result can be reopened or
compared with two to four other results. Comparisons align by elapsed time,
keep raw samples unchanged, and make different conditions visible.

## Privacy

Recording starts only when the user starts a test. Observatory does not capture
the screen, keyboard input, clipboard contents, files, or user content. It does
not request Screen Recording or Input Monitoring access.

Recorded data stays in private Application Support storage until the user
deletes it.

## Platform

Observatory supports macOS 14 and later. Apple silicon is the tested release
target.

The app uses public macOS APIs and does not need administrator access. GitHub
releases are ad-hoc signed and can be built without a paid Apple Developer
Program membership.
