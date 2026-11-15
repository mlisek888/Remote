#!/usr/bin/env bash
# Backs up server keys (the only state that matters).
set -euo pipefail
cd "$(dirname "$0")"
OUT="rustdesk-keys-$(date +%Y%m%d-%H%M%S).tar.gz"
tar czf "$OUT" data/id_ed25519 data/id_ed25519.pub
chmod 600 "$OUT"
echo "Backup: $(pwd)/$OUT  - store it somewhere safe (it contains the PRIVATE key)."
