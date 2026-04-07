#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE_NAME="NoType"
EXECUTABLE_NAME="noType"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_BUNDLE_NAME.app"
LEGACY_APP_DIR="$DIST_DIR/$EXECUTABLE_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE=""
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_FILE="$RESOURCES_DIR/AppIcon.icns"

for candidate in "App_icon.png" "App_Icon.png"; do
  if [[ -f "$ROOT_DIR/$candidate" ]]; then
    ICON_SOURCE="$ROOT_DIR/$candidate"
    break
  fi
done

echo "Building release binary..."
cd "$ROOT_DIR"
swift build -c release

echo "Creating app bundle at $APP_DIR"
if [[ "$LEGACY_APP_DIR" != "$APP_DIR" ]]; then
  rm -rf "$LEGACY_APP_DIR"
fi
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

find "$BUILD_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$RESOURCES_DIR/" \;

if [[ -n "$ICON_SOURCE" ]]; then
  ICON_WIDTH="$(sips -g pixelWidth "$ICON_SOURCE" | awk '/pixelWidth:/ { print $2 }')"
  ICON_HEIGHT="$(sips -g pixelHeight "$ICON_SOURCE" | awk '/pixelHeight:/ { print $2 }')"

  if [[ "$ICON_WIDTH" != "$ICON_HEIGHT" ]]; then
    echo "Icon source must be square, got ${ICON_WIDTH}x${ICON_HEIGHT}: $ICON_SOURCE" >&2
    exit 1
  fi

  if (( ICON_WIDTH < 1024 )); then
    echo "Icon source must be at least 1024x1024, got ${ICON_WIDTH}x${ICON_HEIGHT}: $ICON_SOURCE" >&2
    exit 1
  fi

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
fi

touch "$APP_DIR"

echo "App ready: $APP_DIR"
