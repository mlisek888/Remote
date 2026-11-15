#!/usr/bin/env bash
# Installs RustDesk on macOS and points it at YOUR server.
# Usage: sudo ./install-macos.sh '<CONFIG_STRING>' ['<PASSWORD>']
# After the script: grant Screen Recording + Accessibility (see README) - macOS does not allow scripting that.
set -euo pipefail

CONFIG="${1:-}"; PASSWORD="${2:-}"
if [[ -z "$CONFIG" ]]; then echo "Usage: sudo $0 '<CONFIG_STRING>' ['<PASSWORD>']" >&2; exit 1; fi
if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi
if [[ -z "$PASSWORD" ]]; then
  PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
fi

case "$(uname -m)" in
  arm64) ARCH=aarch64 ;;
  x86_64) ARCH=x86_64 ;;
  *) echo "Unsupported arch" >&2; exit 1 ;;
esac

VER="${RUSTDESK_VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/rustdesk/rustdesk/releases/latest | sed 's#.*/tag/##')}"
VER="${VER#v}"
echo ">> RustDesk $VER ($ARCH)"
TMP=$(mktemp -d); trap 'hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

curl -fL -o "$TMP/rustdesk.dmg" "https://github.com/rustdesk/rustdesk/releases/download/$VER/rustdesk-$VER-$ARCH.dmg"
mkdir "$TMP/mnt"
hdiutil attach "$TMP/rustdesk.dmg" -mountpoint "$TMP/mnt" -nobrowse -quiet
rm -rf /Applications/RustDesk.app
cp -R "$TMP/mnt/RustDesk.app" /Applications/
xattr -dr com.apple.quarantine /Applications/RustDesk.app 2>/dev/null || true

BIN=/Applications/RustDesk.app/Contents/MacOS/RustDesk
# Start once as the logged-in user so the service/agent gets registered.
CONSOLE_USER=$(stat -f%Su /dev/console)
sudo -u "$CONSOLE_USER" open -a RustDesk || true
sleep 8

"$BIN" --config "$CONFIG"
"$BIN" --option verification-method use-permanent-password
"$BIN" --option approve-mode password
"$BIN" --password "$PASSWORD"
ID=$("$BIN" --get-id 2>/dev/null | tail -n1)

cat <<OUT

======================================
 Host    : $(scutil --get ComputerName)
 ID      : $ID
 Password: $PASSWORD
======================================
TERAZ RECZNIE (jednorazowo):
 1. System Settings > Privacy & Security > Screen Recording  -> wlacz RustDesk
 2. System Settings > Privacy & Security > Accessibility     -> wlacz RustDesk
 3. W RustDesk: kliknij "Install" / "Start service" jesli widzisz taki baner
    (potrzebne do dostepu przy ekranie logowania).
OUT
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
