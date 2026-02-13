#!/usr/bin/env bash
# Start everything: Chrome + reverse tunnel to EC2.
# Daily driver — run this and start coding on the remote machine.
#
# Usage: start.sh [ec2_netbird_ip]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Starting remote dev session..."
echo ""

# 1. Launch Chrome (skip if already running)
bash "$SCRIPT_DIR/chrome-launch.sh" 2>&1 || true
echo ""

# 2. Start tunnel
bash "$SCRIPT_DIR/tunnel-start.sh" "$@" 2>&1
echo ""

# 3. Show status
bash "$SCRIPT_DIR/status.sh" 2>&1
