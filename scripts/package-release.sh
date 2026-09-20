#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
ARCH="${ARCH:-$(uname -m)}"
export ARCH
APP_DIR="$(./scripts/build-app.sh)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
RELEASE_DIR="$(mktemp -d "$PROJECT_DIR/build/release.XXXXXX")"
NAME="Plainleaf-$VERSION-macos-$ARCH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$RELEASE_DIR/$NAME.zip"
ditto -x -k "$RELEASE_DIR/$NAME.zip" "$RELEASE_DIR/extracted"
python3 scripts/verify-app.py "$RELEASE_DIR/extracted/Plainleaf.app" "$ARCH" >&2
cp docs/RELEASE_NOTES.md "$RELEASE_DIR/$NAME-notes.md"
{
  git rev-parse HEAD
  git status --short
  swift --version
  xcodebuild -version
  shasum -a 256 Package.resolved
} > "$RELEASE_DIR/$NAME-build.txt"
cd "$RELEASE_DIR"
shasum -a 256 "$NAME.zip" "$NAME-notes.md" "$NAME-build.txt" > "$NAME-SHA256SUMS.txt"
shasum -a 256 -c "$NAME-SHA256SUMS.txt" >&2
echo "$RELEASE_DIR"
