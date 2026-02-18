#!/usr/bin/env bash
# VS Code code relay: creates a dedicated reverse tunnel and listens for
# file paths from the EC2. When a path is received, opens VS Code locally
# in Remote-SSH mode.
#
# Note: Uses a SEPARATE SSH connection for the code relay port because
# NetBird's SSH server doesn't support multiple -R ports on one connection.
#
# Usage: code-relay.sh <ec2_netbird_ip>
#   Runs in foreground (caller should background it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP="${1:?Usage: code-relay.sh <ec2_netbird_ip>}"
SSH_USER="${EC2_SSH_USER:-ubuntu}"
CODE_RELAY_PORT="${CODE_RELAY_PORT:-9223}"
LOG_DIR="${TMPDIR:-/tmp}/remote-dev"
PID_FILE="${LOG_DIR}/code-relay.pid"

mkdir -p "$LOG_DIR"
echo $$ > "$PID_FILE"

cleanup() {
    # Kill the dedicated tunnel
    if [[ -n "${TUNNEL_PID:-}" ]]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    log_info "Code relay stopped"
}
trap cleanup EXIT

# ── Create dedicated reverse tunnel for code relay ───────────────────────────

log_info "Creating code relay tunnel (port ${CODE_RELAY_PORT})..."
ssh -o StrictHostKeyChecking=no -f -N \
    -R "${CODE_RELAY_PORT}:localhost:${CODE_RELAY_PORT}" \
    "${SSH_USER}@${EC2_IP}" || {
    log_error "Failed to create code relay tunnel"
    exit 1
}

sleep 1
TUNNEL_PID=$(pgrep -f "ssh.*-R.*${CODE_RELAY_PORT}:localhost:${CODE_RELAY_PORT}.*${EC2_IP}" | head -1 || true)
log_info "Code relay listening on port ${CODE_RELAY_PORT} (EC2: ${EC2_IP}, tunnel PID: ${TUNNEL_PID:-unknown})"

# ── Listen for paths and open in VS Code ─────────────────────────────────────

while true; do
    # Listen for one connection (OpenBSD netcat syntax)
    path=$(nc -l "$CODE_RELAY_PORT" 2>/dev/null) || continue

    # Trim whitespace/newlines
    path=$(echo "$path" | tr -d '\r\n' | xargs)

    if [[ -n "$path" ]]; then
        log_info "Opening in VS Code: ${path}"
        VSCODE_EXE="${VSCODE_EXE:-/mnt/c/Users/benja/AppData/Local/Programs/Microsoft VS Code/bin/code}"
        "$VSCODE_EXE" --folder-uri "vscode-remote://ssh-remote+bhudgens@${EC2_IP}${path}" &>/dev/null &
    fi
done
