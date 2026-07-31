# Observatory

Observatory — activity monitor, but more. Created for developers and power users who wants more.

1. groups related processes into understandable application totals;
2. records usage tests from one up to 4 applications at once to see and compare the results;
3. stores test results for You to analyze and compare with any other result.

Available only on macOS.

Observatory is local-first. All the data recorded stays only on your local device.

## Requirements

- macOS 14 or later
- Apple silicon for the currently tested release path
- Xcode 26 or later when building from source

## Build and run

From the repository root:

```sh
./scripts/run.sh
```

This builds the Debug configuration into `.build` and opens `Observatory.app`.

To produce an ad-hoc-signed release candidate, its ZIP archive, and a SHA-256
checksum:

```sh
./scripts/release.sh
```

The release artifacts are written to `.release/`.

## Release information

- [Privacy disclosure](docs/privacy.md)
- [Installation guide](docs/installation.md)
- [Known limitations](docs/known-limitations.md)
- [Release checklist](docs/release-checklist.md)
