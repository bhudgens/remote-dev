#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== user-data start: $(date -u) ==="

# ── Set hostname ─────────────────────────────────────────────────────────────

hostnamectl set-hostname "${hostname}"

# ── Create bhudgens user ─────────────────────────────────────────────────────

useradd -m -s /bin/bash bhudgens
usermod -aG sudo bhudgens
echo "bhudgens ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/bhudgens

# ── System packages ──────────────────────────────────────────────────────────

apt-get update
apt-get install -y curl jq git

# ── Install NetBird ──────────────────────────────────────────────────────────

curl -fsSL https://pkgs.netbird.io/install.sh | sh

# ── Register as NetBird peer with SSH server enabled ─────────────────────────

netbird up \
  --setup-key "${setup_key}" \
  --management-url "${management_url}" \
  --allow-server-ssh \
  --enable-ssh-local-port-forwarding \
  --enable-ssh-remote-port-forwarding \
  --enable-ssh-sftp \
  --hostname "${hostname}"

echo "=== user-data complete: $(date -u) ==="
