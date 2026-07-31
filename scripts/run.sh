#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
derived_data_path="$repository_root/.build"
app_path="$derived_data_path/Build/Products/Debug/Observatory.app"

xcodebuild \
  -project "$repository_root/Observatory.xcodeproj" \
  -scheme Observatory \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$derived_data_path" \
  build

open "$app_path"
