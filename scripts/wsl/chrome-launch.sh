#!/usr/bin/env bash
# Launch Chrome with CDP on localhost.
# Run from WSL2. Chrome opens on Windows, CDP accessible at 127.0.0.1:<port>.
# Remote machines reach CDP via SSH tunnel through the NetBird mesh.
#
# Usage: chrome-launch.sh [cdp_port]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

CDP_PORT="${1:-$CDP_PORT}"

# ── Pre-flight checks ───────────────────────────────────────────────────────

# Check if automation Chrome is already running
if powershell.exe -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -match '$CHROME_USER_DATA_DIR' }" 2>/dev/null | grep -q .; then
    log_warn "Automation Chrome is already running (user-data-dir: $CHROME_USER_DATA_DIR)"
    log_info "Use chrome-stop.sh to stop it first, or connect to the existing instance"
    exit 1
fi

# ── Resolve Windows paths ───────────────────────────────────────────────────

log_info "Resolving Windows LOCALAPPDATA..."
LOCALAPPDATA=$(get_chrome_localappdata) || exit 1
USER_DATA_PATH="${LOCALAPPDATA}\\${CHROME_USER_DATA_DIR}"
log_info "Chrome user data dir: $USER_DATA_PATH"

# ── Launch Chrome ────────────────────────────────────────────────────────────

log_info "Launching Chrome (CDP on 127.0.0.1:${CDP_PORT})..."

"$CHROME_PATH" \
    --remote-debugging-port="$CDP_PORT" \
    --user-data-dir="$USER_DATA_PATH" \
    --no-first-run \
    --no-default-browser-check &

# ── Wait for CDP to respond ─────────────────────────────────────────────────

log_info "Waiting for CDP endpoint..."
MAX_WAIT=10
for i in $(seq 1 "$MAX_WAIT"); do
    if check_cdp_responding "127.0.0.1" "$CDP_PORT"; then
        echo ""
        log_info "Chrome DevTools Protocol is ready"
        log_info "  CDP HTTP : http://127.0.0.1:${CDP_PORT}"
        log_info "  CDP JSON : http://127.0.0.1:${CDP_PORT}/json/version"

        NETBIRD_IP=$(get_netbird_ip 2>/dev/null) && \
            log_info "  NetBird  : $NETBIRD_IP (remote machines tunnel via SSH)"

        exit 0
    fi
    printf "."
    sleep 1
done

echo ""
log_error "CDP did not respond within ${MAX_WAIT}s at 127.0.0.1:${CDP_PORT}"
exit 1
