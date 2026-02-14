#!/usr/bin/env bash
# Stop everything: code relay + tunnel + Chrome.
#
# Usage: stop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

LOG_DIR="${TMPDIR:-/tmp}/remote-dev"
PID_FILE="${LOG_DIR}/code-relay.pid"

# 1. Stop code relay
if [[ -f "$PID_FILE" ]]; then
    RELAY_PID=$(cat "$PID_FILE")
    if kill -0 "$RELAY_PID" 2>/dev/null; then
        log_info "Stopping code relay (PID: $RELAY_PID)..."
        kill "$RELAY_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
else
    # Fallback: kill by pattern
    pkill -f "code-relay.sh" 2>/dev/null || true
fi

# 2. Stop tunnel
bash "$SCRIPT_DIR/tunnel-stop.sh" 2>&1

# 3. Stop Chrome
bash "$SCRIPT_DIR/chrome-stop.sh" 2>&1
