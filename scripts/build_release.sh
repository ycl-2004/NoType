#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/NoType.app"
VERSION="${RELEASE_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Packaging/Info.plist")}"
ARCH="$(uname -m)"
ARCHIVE_PATH="$DIST_DIR/NoType-$VERSION-$ARCH.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

if [[ "$ARCH" != "arm64" ]]; then
  echo "NoType release packaging currently requires Apple Silicon (arm64); got $ARCH" >&2
  exit 1
fi

# Build from a clean release directory. build_app.sh copies every *.bundle it finds there, so a
# stale one left by a removed dependency would otherwise be signed into the archive.
rm -rf "$ROOT_DIR/.build/arm64-apple-macosx/release"

echo "Building NoType $VERSION release from the current checkout..."
"$ROOT_DIR/scripts/build_app.sh"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
echo "Creating release archive at $ARCHIVE_PATH"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" | tee "$CHECKSUM_PATH"

echo "Release ready:"
echo "  App:      $APP_DIR"
echo "  Archive:  $ARCHIVE_PATH"
echo "  Checksum: $CHECKSUM_PATH"
