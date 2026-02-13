#!/usr/bin/env bash
# Stop reverse SSH tunnel(s) to the EC2 instance.
#
# Usage: tunnel-stop.sh [cdp_port]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

CDP_PORT="${1:-$CDP_PORT}"

# ── Find tunnel processes ────────────────────────────────────────────────────

log_info "Looking for reverse tunnel processes on port ${CDP_PORT}..."

TUNNEL_PIDS=$(pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}" 2>/dev/null || true)

if [[ -z "$TUNNEL_PIDS" ]]; then
    log_info "No tunnel processes found"
    exit 0
fi

# ── Kill tunnel processes ────────────────────────────────────────────────────

for pid in $TUNNEL_PIDS; do
    log_info "Stopping tunnel PID $pid..."
    kill "$pid" 2>/dev/null || log_warn "Could not kill PID $pid"
done

sleep 1

REMAINING=$(pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}" 2>/dev/null || true)
if [[ -n "$REMAINING" ]]; then
    log_warn "Force killing remaining processes..."
    for pid in $REMAINING; do
        kill -9 "$pid" 2>/dev/null || true
    done
fi

log_info "Tunnel stopped"
