#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$repo_root/DerivedData"
products="$derived_data/Build/Products/Debug"
probe_directory=$(mktemp -d "${TMPDIR:-/tmp}/observatory-sampler.XXXXXX")
probe_binary="$probe_directory/SamplerProbe"

trap 'rm -rf "$probe_directory"' EXIT

xcodebuild build \
  -project "$repo_root/Observatory.xcodeproj" \
  -scheme Observatory \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO >/dev/null

xcrun swiftc \
  -parse-as-library \
  -I "$products" \
  -L "$products" \
  -lObservatoryDomain \
  -framework AppKit \
  "$repo_root/ObservatoryApp/Sources/MacOSProcessServices.swift" \
  "$repo_root/scripts/SamplerProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
