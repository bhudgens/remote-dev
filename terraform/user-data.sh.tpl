#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== user-data start: $(date -u) ==="

# ── System packages ──────────────────────────────────────────────────────────

apt-get update
apt-get install -y curl jq

# ── Install NetBird ──────────────────────────────────────────────────────────

curl -fsSL https://pkgs.netbird.io/install.sh | sh

# ── Register as NetBird peer ─────────────────────────────────────────────────

netbird up \
  --setup-key "${setup_key}" \
  --management-url "${management_url}"

echo "=== user-data complete: $(date -u) ==="
