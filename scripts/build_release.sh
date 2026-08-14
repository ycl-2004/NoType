#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/NoType.app"
VERSION="${RELEASE_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Packaging/Info.plist")}"
ARCH="$(uname -m)"
WHISPER_MODEL_DIR="${WHISPER_MODEL_DIR:-/Users/yichenlin/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930}"
WHISPER_TOKENIZER_DIR="${WHISPER_TOKENIZER_DIR:-/Users/yichenlin/Documents/huggingface/models/openai/whisper-large-v3}"
ARCHIVE_PATH="$DIST_DIR/NoType-$VERSION-$ARCH.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

if [[ "$ARCH" != "arm64" ]]; then
  echo "NoType release packaging currently requires Apple Silicon (arm64); got $ARCH" >&2
  exit 1
fi

if [[ ! -d "$WHISPER_MODEL_DIR" ]]; then
  echo "Whisper model directory not found: $WHISPER_MODEL_DIR" >&2
  exit 1
fi

if [[ ! -f "$WHISPER_TOKENIZER_DIR/tokenizer.json" ]]; then
  echo "Whisper tokenizer.json not found in: $WHISPER_TOKENIZER_DIR" >&2
  exit 1
fi

echo "Building NoType $VERSION release from the current checkout..."
INCLUDE_MODEL=1 \
WHISPER_MODEL_DIR="$WHISPER_MODEL_DIR" \
WHISPER_TOKENIZER_DIR="$WHISPER_TOKENIZER_DIR" \
"$ROOT_DIR/scripts/build_app.sh"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
echo "Creating release archive at $ARCHIVE_PATH"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" | tee "$CHECKSUM_PATH"

echo "Release ready:"
echo "  App:      $APP_DIR"
echo "  Archive:  $ARCHIVE_PATH"
echo "  Checksum: $CHECKSUM_PATH"
