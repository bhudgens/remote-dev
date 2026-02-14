#!/usr/bin/env bash
# Background listener for VS Code code relay.
# Receives file paths from the EC2 (through reverse SSH tunnel) and opens
# them in VS Code locally using Remote-SSH mode.
#
# Usage: code-relay.sh <ec2_netbird_ip>
#   Runs in foreground (caller should background it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP="${1:?Usage: code-relay.sh <ec2_netbird_ip>}"
CODE_RELAY_PORT="${CODE_RELAY_PORT:-9223}"
LOG_DIR="${TMPDIR:-/tmp}/remote-dev"
PID_FILE="${LOG_DIR}/code-relay.pid"

mkdir -p "$LOG_DIR"
echo $$ > "$PID_FILE"

log_info "Code relay listening on port ${CODE_RELAY_PORT} (EC2: ${EC2_IP})"

cleanup() {
    rm -f "$PID_FILE"
    log_info "Code relay stopped"
}
trap cleanup EXIT

while true; do
    # Listen for one connection, read the path
    # Handle both nc.openbsd (nc -l PORT) and nc.traditional (nc -l -p PORT)
    path=$(nc -l -p "$CODE_RELAY_PORT" -q 1 2>/dev/null || nc -l "$CODE_RELAY_PORT" 2>/dev/null) || continue

    # Trim whitespace/newlines
    path=$(echo "$path" | tr -d '\r\n' | xargs)

    if [[ -n "$path" ]]; then
        log_info "Opening in VS Code: ${path}"
        code --remote "ssh-remote+bhudgens@${EC2_IP}" "$path" &>/dev/null &
    fi
done
