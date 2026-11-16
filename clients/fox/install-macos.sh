#!/usr/bin/env bash
# Instaluje Fox Zdalny na macOS i ustawia stale haslo.
# Uzycie: sudo ./install-macos.sh FoxZdalny-1.5.3-aarch64.dmg ['haslo']
#   (Mac z Apple M1/M2/M3/M4 -> aarch64, Mac z Intelem -> x86_64)
set -euo pipefail
DMG="${1:-}"; PASSWORD="${2:-}"
[[ -f "$DMG" ]] || { echo "Uzycie: sudo $0 <plik.dmg> ['haslo']" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Uruchom przez sudo." >&2; exit 1; }
[[ -n "$PASSWORD" ]] || PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

MNT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MNT" -nobrowse -quiet
rm -rf /Applications/FoxZdalny.app
cp -R "$MNT/FoxZdalny.app" /Applications/
hdiutil detach "$MNT" -quiet
# Aplikacja nie jest podpisana przez Apple - zdejmujemy kwarantanne, zeby Gatekeeper jej nie blokowal.
xattr -dr com.apple.quarantine /Applications/FoxZdalny.app

BIN=/Applications/FoxZdalny.app/Contents/MacOS/FoxZdalny
sudo -u "$(stat -f%Su /dev/console)" open -a /Applications/FoxZdalny.app || true
sleep 8
"$BIN" --password "$PASSWORD"
ID=$("$BIN" --get-id 2>/dev/null | tail -n1)

cat <<OUT

======================================
 Komputer: $(scutil --get ComputerName)
 ID      : $ID
 Haslo   : $PASSWORD
======================================
TERAZ RECZNIE (jednorazowo na tym Macu):
 1. Ustawienia systemowe > Prywatnosc i ochrona > Nagrywanie ekranu -> wlacz FoxZdalny
 2. Ustawienia systemowe > Prywatnosc i ochrona > Dostepnosc        -> wlacz FoxZdalny
 3. W oknie Fox Zdalny kliknij "Zainstaluj"/"Uruchom usluge", jesli widzisz taki baner
    (potrzebne do dostepu przy ekranie logowania).
OUT
