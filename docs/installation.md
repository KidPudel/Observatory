# Installing an Observatory GitHub build

Observatory's initial GitHub archives are ad-hoc signed rather than notarized.
macOS may therefore ask you to confirm that you trust the application.

## Requirements

- macOS 14 or later
- Apple silicon for the currently tested release

## Verify the download

Download both the Observatory ZIP and its `.sha256` file from the same GitHub
release. In Terminal, change to the download directory and run:

```sh
shasum -a 256 -c Observatory-0.1.1-macos.zip.sha256
```

Continue only when the command reports `OK`.

## Install and open

1. Unzip the archive.
2. Move `Observatory.app` to the Applications folder.
3. Control-click Observatory in Finder and choose **Open**.
4. Confirm **Open** in the macOS prompt.

If macOS does not offer Open immediately, try opening Observatory once, then go
to **System Settings → Privacy & Security** and use **Open Anyway** for
Observatory. Do not disable Gatekeeper globally.

Observatory does not require administrator access, Screen Recording, or Input
Monitoring. macOS may limit some process metrics for protected applications;
Observatory displays those measurements as unavailable rather than as zero.

## Updating an ad-hoc build

Quit Observatory, replace the old application in Applications, and open the new
version using the same steps. Because an ad-hoc build's code identity can
change, macOS may ask you to approve access again after an update. Saved tests
remain in Application Support and are not removed by replacing the app.

## Build from source

As an alternative to a downloaded archive:

```sh
git clone https://github.com/KidPudel/Observatory.git
cd Observatory
./scripts/run.sh
```

Xcode resolves the pinned GRDB dependency and builds Observatory locally.
