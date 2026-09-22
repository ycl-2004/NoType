#!/bin/zsh
# Remove only regenerable project-local outputs. Keep the final app, shared models and QA evidence.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT_DIR/Package.swift" ]] || exit 1
if [[ -L "$ROOT_DIR/.build" ]]; then
  echo "Refusing to follow a symlink at .build" >&2
  exit 1
fi
if [[ -d "$ROOT_DIR/.build" ]]; then
  du -sh "$ROOT_DIR/.build"
  rm -rf -- "$ROOT_DIR/.build"
fi
for artifact in "$ROOT_DIR"/dist/NoType-*-arm64.zip(N) "$ROOT_DIR"/dist/NoType-*-arm64.zip.sha256(N); do
  rm -f -- "$artifact"
done
echo "Development outputs removed. dist/NoType.app and downloaded models were preserved."
