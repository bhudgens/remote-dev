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
log_info "Step 1/4: Launching Chrome with CDP..."
if ! bash "$SCRIPT_DIR/chrome-launch.sh" >"$LOG_DIR/chrome.log" 2>&1; then
    log_error "Chrome launch failed. Error details:"
    echo "─────────────────────────────────────────────────────────────────────"
    tail -10 "$LOG_DIR/chrome.log"
    echo "─────────────────────────────────────────────────────────────────────"
    log_error "Full log: $LOG_DIR/chrome.log"
    exit 1
fi

# 2. Start tunnel (pass discovered IP)
log_info "Step 2/4: Creating reverse SSH tunnel..."
if ! bash "$SCRIPT_DIR/tunnel-start.sh" "$EC2_IP" >"$LOG_DIR/tunnel.log" 2>&1; then
    log_error "Tunnel creation failed. Error details:"
    echo "─────────────────────────────────────────────────────────────────────"
    tail -10 "$LOG_DIR/tunnel.log"
    echo "─────────────────────────────────────────────────────────────────────"
    log_error "Full log: $LOG_DIR/tunnel.log"
    exit 1
fi

# 3. Start code relay (background)
log_info "Step 3/4: Starting VS Code relay..."
bash "$SCRIPT_DIR/code-relay.sh" "$EC2_IP" >"$LOG_DIR/code-relay.log" 2>&1 &
log_info "Code relay started (PID: $!)"

# 4. Sync code and dotfiles to EC2
log_info "Step 4/4: Syncing to EC2..."
if ! bash "$SCRIPT_DIR/sync.sh" >"$LOG_DIR/sync.log" 2>&1; then
    log_warn "Sync failed. Error details:"
    echo "─────────────────────────────────────────────────────────────────────"
    tail -10 "$LOG_DIR/sync.log"
    echo "─────────────────────────────────────────────────────────────────────"
    log_warn "Full log: $LOG_DIR/sync.log"
    log_warn "Continuing despite sync failure..."
fi

# 5. Show status
echo ""
log_info "Startup complete! Current status:"
echo "─────────────────────────────────────────────────────────────────────"
bash "$SCRIPT_DIR/status.sh" 2>&1
echo "─────────────────────────────────────────────────────────────────────"
echo ""
log_info "Logs available at: $LOG_DIR/"
