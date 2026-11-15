#!/usr/bin/env bash
# Install & start a private RustDesk server on a Linux VPS/home server.
# Usage:  sudo ./setup.sh <public-host-or-ip>
#   e.g.  sudo ./setup.sh remote.example.com
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  echo "Usage: sudo $0 <public-host-or-ip>" >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

cd "$(dirname "$0")"

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  echo ">> Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin missing - install docker-compose-plugin" >&2
  exit 1
fi

# 2. Firewall (only if ufw is present)
if command -v ufw >/dev/null 2>&1; then
  echo ">> Opening ports in ufw..."
  ufw allow 21115:21117/tcp
  ufw allow 21116/udp
fi

# 3. Start
mkdir -p data
echo "$HOST" > data/public_host
docker compose pull
docker compose up -d

# 4. Wait for key
echo ">> Waiting for server key..."
for _ in $(seq 1 30); do
  [[ -s data/id_ed25519.pub ]] && break
  sleep 1
done
if [[ ! -s data/id_ed25519.pub ]]; then
  echo "Key not generated - check: docker compose logs hbbs" >&2
  exit 1
fi

./print-config.sh
