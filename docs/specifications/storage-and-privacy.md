# Storage and privacy specification

Status: Active

## Storage model

Observatory stores its catalog under its private Application Support directory.
SQLite is the source of truth for controlled-test relationships, raw samples,
and summaries.

SQLite stores:

- grouping rules;
- controlled-test metadata and application identities;
- rounds;
- one-second grouped metric samples;
- per-application aggregate summaries.

Local interface preferences may use `UserDefaults`. Database migrations are
mandatory from the first schema version. Raw metric samples are immutable;
derived summaries may be regenerated.

## Test summary folders

Every controlled test creates a private folder before recording:

```text
Application Support/Observatory/
└── Recordings/
    └── Sessions/
        └── 2026-07-27 14-32 — Telescope vs VS Code/
            └── session.json
```

Folder and file names stay stable across application updates. Test folder
names:

- begin with local date and time;
- include a sanitized test name;
- receive a numeric suffix on collision;
- are never used as database identity.

`session.json` contains test context, rounds, and aggregate results. It omits raw
one-second samples; SQLite remains the timeline source of truth.

## Privacy

- Everything remains local.
- Recording starts only through an explicit controlled test.
- Now samples outside a test remain in memory and are not added to Saved Results.
- Observatory does not capture screen content, monitor keyboard input, inspect
  clipboard contents, read input fields, perform OCR, or analyze user content.
- Observatory never requests Screen Recording or Input Monitoring permission.
- A visible indicator remains present while a controlled test records metrics.

## Retention and deletion

| Data | Default retention |
| --- | --- |
| Now samples outside a test | Memory only; discarded when no longer needed or when Observatory quits |
| Controlled-test samples, metadata, rounds, and summaries | Until the test is deleted |
| Grouping rules and preferences | Until the user resets them or clears Observatory data |

Controlled-test samples are not automatically compacted because their
one-second shape is required for timelines and comparison.

The user can delete one test or all recorded tests. Deleting a test removes its
database records and exact private summary folder after confirmation. It does
not affect unrelated tests. Preference and grouping-rule reset remain separate
actions.

## Acceptance criteria

- Every created controlled test has a dated private summary folder.
- Now does not persist samples outside a controlled test.
- Controlled tests never request Screen Recording or Input Monitoring
  permission.
- No screen, keyboard, clipboard, or input-field content appears in stored data.
- Raw test metrics remain available until test deletion.
- Database migration and interruption tests protect stored results.
- Deleting one test removes its database records and summary folder without
  affecting another test.
