# Observatory privacy disclosure

Observatory measures application resource use locally on the Mac where it runs.
It has no account, cloud service, analytics SDK, advertising SDK, or network
upload feature.

## What Observatory observes

Observatory uses public macOS process and workspace APIs to read:

- process identity and application ownership evidence;
- CPU time;
- physical memory;
- disk read and write counters;
- wakeup counters;
- process and thread counts; and
- whether a measured application is foreground, visible, hidden, or idle.

The live Now timeline is bounded in memory and is discarded when it ages out or
Observatory quits. Persistent recording begins only when the user explicitly
starts a controlled test.

## What Observatory does not collect

Observatory does not:

- capture or inspect the screen;
- monitor keyboard input;
- inspect the clipboard;
- read text fields, document contents, filenames, URLs, or browsing history;
- record audio or video;
- perform OCR;
- request Screen Recording or Input Monitoring permission; or
- send measurements off the Mac.

## Local storage

Controlled-test metadata, raw one-second metric samples, and summaries remain
in Observatory's private Application Support directory until the user deletes
the test. Each test also has a private `session.json` summary. Interface
preferences and grouping rules remain local.

Deleting a test removes its catalog records, samples, and exact summary folder.
It does not delete unrelated tests. Removing the application alone does not
remove its Application Support data.

Observatory is not sandboxed in the initial GitHub build because process
inspection is its core purpose. The ordinary collector uses public macOS APIs
and does not install a privileged helper or request administrator access.
