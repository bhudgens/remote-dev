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
apt-get install -y curl jq git systemd-container

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

# ── Convenience script for ubuntu to switch to bhudgens ─────────────────────

cat > /home/ubuntu/become-bhudgens.sh << 'BECOME'
#!/bin/bash
exec sudo machinectl shell bhudgens@
BECOME
chmod 755 /home/ubuntu/become-bhudgens.sh
chown ubuntu:ubuntu /home/ubuntu/become-bhudgens.sh

# ── Install VS Code relay wrapper ─────────────────────────────────────────────

cat > /usr/local/bin/code << 'CODESCRIPT'
#!/bin/bash
CODE_RELAY_PORT=9223
path=$(realpath "${1:-.}")
echo "$path" | nc -q 0 localhost $CODE_RELAY_PORT 2>/dev/null || {
    echo "Error: VS Code relay not available. Is the tunnel running on your workstation?"
    echo "  Run: ./scripts/wsl/start.sh"
    exit 1
}
echo "Opening in VS Code: $path"
CODESCRIPT
chmod 755 /usr/local/bin/code

echo "=== user-data complete: $(date -u) ==="
