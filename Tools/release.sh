#!/bin/zsh
# Builds a Release copy of Markmer and zips it for distribution.
#
#   Tools/release.sh            # version from project.yml (MARKETING_VERSION)
#   Tools/release.sh 1.2.0      # override the version
#
# Output: dist/Markmer-<version>.zip plus a SHA-256 checksum.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/p' project.yml | head -1)}"
[[ -n "$version" ]] || { echo "could not determine version" >&2; exit 1; }

derived="build/Release"
app="$derived/Build/Products/Release/Markmer.app"
dist="dist"
zip="$dist/Markmer-$version.zip"

command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet

rm -rf "$app"
xcodebuild -project Markmer.xcodeproj -scheme Markmer -configuration Release \
  -derivedDataPath "$derived" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  build | grep -E "error:|warning: .*Markmer|BUILD" || true

[[ -d "$app" ]] || { echo "build failed: $app not found" >&2; exit 1; }

mkdir -p "$dist"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
shasum -a 256 "$zip" | tee "$zip.sha256"
echo "Release zip: $zip"
