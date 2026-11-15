#!/usr/bin/env bash
# Prints everything clients need: host, public key and a one-line config string
# (the same format as RustDesk "Export server config": reversed URL-safe base64 JSON).
set -euo pipefail
cd "$(dirname "$0")"

HOST="${1:-$(cat data/public_host 2>/dev/null || true)}"
KEY="$(tr -d '\r\n' < data/id_ed25519.pub)"
if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <public-host-or-ip>" >&2
  exit 1
fi

JSON=$(printf '{"host":"%s","relay":"%s","api":"","key":"%s"}' "$HOST" "$HOST" "$KEY")
CONFIG=$(printf '%s' "$JSON" | base64 -w0 | tr '+/' '-_' | rev)

cat <<OUT

================ RustDesk - Twoj serwer ================
ID server   : $HOST
Relay server: $HOST
Key         : $KEY

Config string (do skryptow instalacyjnych / Import w kliencie):
$CONFIG
========================================================
Porty do otwarcia na routerze/firewallu:
  TCP 21115, 21116, 21117   UDP 21116
OUT

printf '%s\n' "$CONFIG" > data/client-config.txt
echo "(zapisano tez do server/data/client-config.txt)"
