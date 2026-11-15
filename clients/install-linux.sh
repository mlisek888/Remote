#!/usr/bin/env bash
# Installs RustDesk on Linux (Debian/Ubuntu/Mint/Fedora/RHEL) and points it at YOUR server.
# Usage: sudo ./install-linux.sh '<CONFIG_STRING>' ['<PASSWORD>'] [--disable-wayland]
#   CONFIG_STRING - from server/print-config.sh
#   PASSWORD      - permanent password for unattended access (generated if omitted)
set -euo pipefail

CONFIG="${1:-}"; PASSWORD="${2:-}"; DISABLE_WAYLAND=0
for a in "$@"; do [[ "$a" == "--disable-wayland" ]] && DISABLE_WAYLAND=1; done
[[ "$PASSWORD" == "--disable-wayland" ]] && PASSWORD=""

if [[ -z "$CONFIG" ]]; then echo "Usage: sudo $0 '<CONFIG_STRING>' ['<PASSWORD>'] [--disable-wayland]" >&2; exit 1; fi
if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi
if [[ -z "$PASSWORD" ]]; then
  PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
fi

case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# Latest version via redirect (no GitHub API rate limit). Override with RUSTDESK_VERSION=1.x.y
VER="${RUSTDESK_VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/rustdesk/rustdesk/releases/latest | sed 's#.*/tag/##')}"
VER="${VER#v}"
echo ">> RustDesk $VER ($ARCH)"
BASE="https://github.com/rustdesk/rustdesk/releases/download/$VER"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

if command -v apt-get >/dev/null 2>&1; then
  curl -fL -o "$TMP/rustdesk.deb" "$BASE/rustdesk-$VER-$ARCH.deb"
  apt-get update -y
  apt-get install -y "$TMP/rustdesk.deb"
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
  PM=$(command -v dnf || command -v yum)
  curl -fL -o "$TMP/rustdesk.rpm" "$BASE/rustdesk-$VER-0.$ARCH.rpm"
  "$PM" install -y "$TMP/rustdesk.rpm"
else
  echo "Unsupported distro (need apt or dnf/yum). Install RustDesk manually, then re-run with RUSTDESK_SKIP_INSTALL=1." >&2
  [[ "${RUSTDESK_SKIP_INSTALL:-0}" == 1 ]] || exit 1
fi

systemctl enable --now rustdesk
sleep 5

rustdesk --config "$CONFIG"
rustdesk --option verification-method use-permanent-password
rustdesk --option approve-mode password
rustdesk --password "$PASSWORD"
systemctl restart rustdesk
sleep 3

if [[ $DISABLE_WAYLAND == 1 && -f /etc/gdm3/custom.conf ]]; then
  sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
  grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf || sed -i '/^\[daemon\]/a WaylandEnable=false' /etc/gdm3/custom.conf
  echo ">> Wayland disabled in GDM (takes effect after reboot)."
fi

ID=$(rustdesk --get-id 2>/dev/null | tail -n1)
echo
echo "======================================"
echo " Host    : $(hostname)"
echo " ID      : $ID"
echo " Password: $PASSWORD"
echo "======================================"
echo "Wpisz to do computers.csv (i trzymaj haslo w menedzerze hasel)."
