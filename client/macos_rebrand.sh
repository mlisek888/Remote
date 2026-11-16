#!/usr/bin/env bash
# Renames the built RustDesk.app to <app_name>.app, fixes Info.plist and re-signs ad-hoc.
# The app code expects /Applications/<app_name>.app/Contents/MacOS/<app_name>.
# Usage: macos_rebrand.sh <dir containing RustDesk.app>
set -euo pipefail
DIR="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP=$(python3 -c "import json;print(json.load(open('$HERE/branding.json'))['app_name'])")
DISPLAY=$(python3 -c "import json;print(json.load(open('$HERE/branding.json'))['display_name'])")
BUNDLE_ID=$(python3 -c "import json;print(json.load(open('$HERE/branding.json'))['bundle_id'])")
ENT="${ENTITLEMENTS:-flutter/macos/Runner/Release.entitlements}"

cd "$DIR"
rm -rf "$APP.app"
mv RustDesk.app "$APP.app"
mv "$APP.app/Contents/MacOS/RustDesk" "$APP.app/Contents/MacOS/$APP"
PL="$APP.app/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PL"; }
pb "Set :CFBundleExecutable $APP"
pb "Set :CFBundleName $APP"
pb "Set :CFBundleIdentifier $BUNDLE_ID"
pb "Delete :CFBundleDisplayName" 2>/dev/null || true
pb "Add :CFBundleDisplayName string $DISPLAY"
cd - >/dev/null

# Ad-hoc signature (no Apple Developer account). Inner code first, then the bundle.
A="$DIR/$APP.app"
codesign --force --sign - "$A/Contents/MacOS/service"
for f in "$A"/Contents/MacOS/*.dylib; do [ -e "$f" ] && codesign --force --sign - "$f"; done
codesign --force --sign - --entitlements "$ENT" "$A"
codesign --verify --deep --strict --verbose=2 "$A"
echo "Rebranded: $A"
