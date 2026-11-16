#!/usr/bin/env bash
# Instaluje Fox Zdalny na Linuxie (Debian/Ubuntu: .deb, Fedora/RHEL: .rpm) i ustawia stale haslo.
# Uzycie: sudo ./install-linux.sh FoxZdalny-1.5.3-x86_64.deb ['haslo'] [--disable-wayland]
# Uwaga: na Linuxie program wewnetrznie nazywa sie "rustdesk" (polecenie, usluga),
# ale ma Twoj serwer, klucz i ikone.
set -euo pipefail
PKG="${1:-}"; PASSWORD="${2:-}"; DISABLE_WAYLAND=0
for a in "$@"; do [[ "$a" == "--disable-wayland" ]] && DISABLE_WAYLAND=1; done
[[ "$PASSWORD" == "--disable-wayland" ]] && PASSWORD=""
[[ -f "$PKG" ]] || { echo "Uzycie: sudo $0 <plik.deb|.rpm> ['haslo'] [--disable-wayland]" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Uruchom przez sudo." >&2; exit 1; }
[[ -n "$PASSWORD" ]] || PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

case "$PKG" in
  *.deb) apt-get update -y; apt-get install -y "$(realpath "$PKG")" ;;
  *.rpm) $(command -v dnf || command -v yum) install -y "$(realpath "$PKG")" ;;
  *) echo "Nieznany typ pakietu: $PKG" >&2; exit 1 ;;
esac

systemctl enable --now rustdesk
sleep 5
rustdesk --password "$PASSWORD"
systemctl restart rustdesk
sleep 3

if [[ $DISABLE_WAYLAND == 1 && -f /etc/gdm3/custom.conf ]]; then
  sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
  grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf || sed -i '/^\[daemon\]/a WaylandEnable=false' /etc/gdm3/custom.conf
  echo ">> Wayland wylaczony w GDM (zadziala po restarcie)."
fi

ID=$(rustdesk --get-id 2>/dev/null | tail -n1)
echo
echo "======================================"
echo " Komputer: $(hostname)"
echo " ID      : $ID"
echo " Haslo   : $PASSWORD"
echo "======================================"
echo "Zapisz w Vaultwardenie."
