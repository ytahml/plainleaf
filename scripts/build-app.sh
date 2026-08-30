#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Plainleaf.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_RESOURCES="$PROJECT_DIR/Sources/Plainleaf/Resources"

cd "$PROJECT_DIR"

if [[ ! -f "$SOURCE_RESOURCES/AppIcon.icns" ]]; then
  swift "$PROJECT_DIR/scripts/make-icon.swift" >/dev/null
fi

BIN_DIR="$(swift build -c release --product Plainleaf --show-bin-path)"
swift build -c release --product Plainleaf

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/Plainleaf" "$MACOS_DIR/Plainleaf"
cp "$SOURCE_RESOURCES/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SOURCE_RESOURCES/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

for bundle in "$BIN_DIR"/*.bundle; do
  if [[ -d "$bundle" ]]; then
    ditto "$bundle" "$RESOURCES_DIR/${bundle:t}"
  fi
done

chmod 755 "$MACOS_DIR/Plainleaf"
codesign --force --sign - \
  --entitlements "$SOURCE_RESOURCES/Plainleaf.entitlements" \
  "$APP_DIR" >/dev/null

echo "$APP_DIR"
