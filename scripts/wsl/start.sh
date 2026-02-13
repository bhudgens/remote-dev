#!/usr/bin/env bash
# Start everything: Chrome + reverse tunnel to EC2.
# Daily driver — run this and start coding on the remote machine.
#
# Usage: start.sh [ec2_netbird_ip]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/remote-dev"
mkdir -p "$LOG_DIR"

# 1. Launch Chrome (skip if already running)
bash "$SCRIPT_DIR/chrome-launch.sh" >"$LOG_DIR/chrome.log" 2>&1 || true

# 2. Start tunnel
bash "$SCRIPT_DIR/tunnel-start.sh" "$@" >"$LOG_DIR/tunnel.log" 2>&1 || {
    echo "Tunnel failed. See $LOG_DIR/tunnel.log"
    exit 1
}

# 3. Show status
bash "$SCRIPT_DIR/status.sh" 2>&1
echo ""
echo "Logs: $LOG_DIR/"
