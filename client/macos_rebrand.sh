#!/usr/bin/env bash
# Renames a built RustDesk.app to <app_name>.app, fixes Info.plist and re-signs ad-hoc.
# The app code expects /Applications/<app_name>.app/Contents/MacOS/<app_name>.
# Usage: macos_rebrand.sh <variants/xxx.json> <dir containing RustDesk.app> [variant config to embed]
#   The optional 3rd argument (fox_variants/<id>.json) is copied to Contents/Resources/fox_custom.json,
#   which overrides the config compiled into the binary.
set -euo pipefail
VARIANT="$1"; DIR="$2"; EMBED="${3:-}"
val() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$VARIANT" "$1"; }
APP=$(val app_name); DISPLAY=$(val display_name); BUNDLE_ID=$(val bundle_id)
ENT="${ENTITLEMENTS:-flutter/macos/Runner/Release.entitlements}"

A="$DIR/$APP.app"
rm -rf "$A"
mv "$DIR/RustDesk.app" "$A"
mv "$A/Contents/MacOS/RustDesk" "$A/Contents/MacOS/$APP"
if [[ -n "$EMBED" ]]; then cp "$EMBED" "$A/Contents/Resources/fox_custom.json"; fi
PL="$A/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PL"; }
pb "Set :CFBundleExecutable $APP"
pb "Set :CFBundleName $APP"
pb "Set :CFBundleIdentifier $BUNDLE_ID"
pb "Delete :CFBundleDisplayName" 2>/dev/null || true
pb "Add :CFBundleDisplayName string $DISPLAY"

# Ad-hoc signature (no Apple Developer account). Inner code first, then the bundle.
codesign --force --sign - "$A/Contents/MacOS/service"
for f in "$A"/Contents/MacOS/*.dylib; do [ -e "$f" ] && codesign --force --sign - "$f"; done
codesign --force --sign - --entitlements "$ENT" "$A"
codesign --verify --deep --strict --verbose=2 "$A"
echo "Rebranded: $A"
