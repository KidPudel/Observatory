#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
release_root="$repository_root/.release"
derived_data_path="$release_root/DerivedData"

version=$(
    xcodebuild \
        -project "$repository_root/Observatory.xcodeproj" \
        -scheme Observatory \
        -configuration Release \
        -showBuildSettings |
        awk '/ MARKETING_VERSION = / { print $3; exit }'
)

if [[ -z "$version" ]]; then
    print -u2 "Could not read MARKETING_VERSION."
    exit 1
fi

archive_path="$release_root/Observatory-$version.xcarchive"
app_path="$archive_path/Products/Applications/Observatory.app"
zip_name="Observatory-$version-macos.zip"
zip_path="$release_root/$zip_name"
checksum_path="$zip_path.sha256"

mkdir -p "$release_root"

for output in "$archive_path" "$zip_path" "$checksum_path"; do
    if [[ -e "$output" ]]; then
        print -u2 "Release output already exists: $output"
        print -u2 "Move or remove that exact output before rebuilding the candidate."
        exit 1
    fi
done

xcodebuild -quiet test \
    -project "$repository_root/Observatory.xcodeproj" \
    -scheme Observatory \
    -configuration Debug \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO

xcodebuild -quiet archive \
    -project "$repository_root/Observatory.xcodeproj" \
    -scheme Observatory \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    -derivedDataPath "$derived_data_path"

if [[ ! -d "$app_path" ]]; then
    print -u2 "Archive did not contain Observatory.app."
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

(
    cd "$release_root"
    shasum -a 256 "$zip_name" > "$zip_name.sha256"
)

print
print "Release candidate ready:"
print "  $zip_path"
print "  $checksum_path"
