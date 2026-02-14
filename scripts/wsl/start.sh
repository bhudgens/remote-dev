#!/usr/bin/env bash
# Start everything: Chrome + reverse tunnel + code relay to EC2.
# Daily driver — run this and start coding on the remote machine.
#
# Usage: start.sh [ec2_netbird_ip]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

LOG_DIR="${TMPDIR:-/tmp}/remote-dev"
mkdir -p "$LOG_DIR"

# ── Discover EC2 IP ──────────────────────────────────────────────────────────

EC2_IP="${1:-}"
if [[ -z "$EC2_IP" ]]; then
    log_info "Discovering $EC2_PEER_NAME peer..."
    EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1
    log_info "Found $EC2_PEER_NAME at $EC2_IP"
fi

# 1. Launch Chrome (skip if already running)
bash "$SCRIPT_DIR/chrome-launch.sh" >"$LOG_DIR/chrome.log" 2>&1 || true

# 2. Start tunnel (pass discovered IP)
bash "$SCRIPT_DIR/tunnel-start.sh" "$EC2_IP" >"$LOG_DIR/tunnel.log" 2>&1 || {
    echo "Tunnel failed. See $LOG_DIR/tunnel.log"
    exit 1
}

# 3. Start code relay (background)
bash "$SCRIPT_DIR/code-relay.sh" "$EC2_IP" >"$LOG_DIR/code-relay.log" 2>&1 &
log_info "Code relay started (PID: $!)"

# 4. Sync code and dotfiles to EC2
log_info "Syncing to EC2..."
bash "$SCRIPT_DIR/sync.sh" >"$LOG_DIR/sync.log" 2>&1 || log_warn "Sync failed. See $LOG_DIR/sync.log"

# 5. Show status
bash "$SCRIPT_DIR/status.sh" 2>&1
echo ""
echo "Logs: $LOG_DIR/"
