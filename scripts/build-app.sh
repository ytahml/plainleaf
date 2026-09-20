#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
mkdir -p "$BUILD_DIR"
# Assemble in a fresh directory so failed builds never damage the last app.
STAGING_DIR="$(mktemp -d "$BUILD_DIR/package.XXXXXX")"
APP_DIR="$STAGING_DIR/Plainleaf.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_RESOURCES="$PROJECT_DIR/Sources/Plainleaf/Resources"

cd "$PROJECT_DIR"

if [[ ! -f "$SOURCE_RESOURCES/AppIcon.icns" ]]; then
  swift "$PROJECT_DIR/scripts/make-icon.swift" >/dev/null
fi

ARCH="${ARCH:-$(uname -m)}"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || { print -u2 'ARCH must be arm64 or x86_64'; exit 1; }
BUILD_ARGS=(-c release --product Plainleaf --arch "$ARCH" --force-resolved-versions)
swift build "${BUILD_ARGS[@]}" >&2
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/Plainleaf" "$MACOS_DIR/Plainleaf"
cp "$SOURCE_RESOURCES/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SOURCE_RESOURCES/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

for bundle in Plainleaf_Plainleaf Highlighter_Highlighter; do
  ditto "$BIN_DIR/$bundle.bundle" "$RESOURCES_DIR/$bundle.bundle"
done

LICENSES="$RESOURCES_DIR/Licenses"
mkdir -p "$LICENSES"
cp LICENSE "$LICENSES/Plainleaf.txt"
cp docs/THIRD_PARTY_NOTICES.md "$LICENSES/THIRD_PARTY_NOTICES.md"
cp .build/checkouts/swift-markdown/LICENSE.txt "$LICENSES/swift-markdown-LICENSE.txt"
cp .build/checkouts/swift-markdown/NOTICE.txt "$LICENSES/swift-markdown-NOTICE.txt"
cp .build/checkouts/swift-cmark/COPYING "$LICENSES/swift-cmark-COPYING.txt"
cp Vendor/HighlighterSwift/LICENCE.md "$LICENSES/HighlighterSwift.md"
cp Vendor/HighlighterSwift/Sources/Assets/LICENCE "$LICENSES/highlight.js.txt"
cp Vendor/Flexoki/LICENSE "$LICENSES/Flexoki.txt"
cp "$SOURCE_RESOURCES/Fonts/OFL.txt" "$LICENSES/LXGW-OFL.txt"

chmod 755 "$MACOS_DIR/Plainleaf"
codesign --force --sign - \
  --entitlements "$SOURCE_RESOURCES/Plainleaf.entitlements" \
  "$APP_DIR" >/dev/null

python3 "$PROJECT_DIR/scripts/verify-app.py" "$APP_DIR" "$ARCH" >&2
if [[ -e "$BUILD_DIR/Plainleaf.app" ]]; then
  BACKUP_DIR="$(mktemp -d "$BUILD_DIR/previous.XXXXXX")"
  mv "$BUILD_DIR/Plainleaf.app" "$BACKUP_DIR/Plainleaf.app"
  print -u2 "Previous app retained at $BACKUP_DIR/Plainleaf.app"
fi
mv "$APP_DIR" "$BUILD_DIR/Plainleaf.app"
echo "$BUILD_DIR/Plainleaf.app"
