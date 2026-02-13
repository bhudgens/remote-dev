#!/usr/bin/env bash
# Launch Chrome with CDP bound to the local NetBird IP.
# Run from WSL2. Chrome opens on Windows, accessible only via NetBird overlay.
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

# ── Discover NetBird IP ──────────────────────────────────────────────────────

log_info "Discovering NetBird IP..."
NETBIRD_IP=$(get_netbird_ip) || exit 1
log_info "NetBird IP: $NETBIRD_IP"

# ── Resolve Windows paths ───────────────────────────────────────────────────

log_info "Resolving Windows LOCALAPPDATA..."
LOCALAPPDATA=$(get_chrome_localappdata) || exit 1
USER_DATA_PATH="${LOCALAPPDATA}\\${CHROME_USER_DATA_DIR}"
log_info "Chrome user data dir: $USER_DATA_PATH"

# ── Launch Chrome ────────────────────────────────────────────────────────────

log_info "Launching Chrome (CDP on ${NETBIRD_IP}:${CDP_PORT})..."

"$CHROME_PATH" \
    --remote-debugging-port="$CDP_PORT" \
    --remote-debugging-address="$NETBIRD_IP" \
    --user-data-dir="$USER_DATA_PATH" \
    --no-first-run \
    --no-default-browser-check &

# ── Wait for CDP to respond ─────────────────────────────────────────────────

log_info "Waiting for CDP endpoint..."
MAX_WAIT=10
for i in $(seq 1 "$MAX_WAIT"); do
    if check_cdp_responding "$NETBIRD_IP" "$CDP_PORT"; then
        echo ""
        log_info "Chrome DevTools Protocol is ready"
        log_info "  CDP HTTP : http://${NETBIRD_IP}:${CDP_PORT}"
        log_info "  CDP JSON : http://${NETBIRD_IP}:${CDP_PORT}/json/version"

        WS_URL=$(get_cdp_ws_url "$NETBIRD_IP" "$CDP_PORT" 2>/dev/null) && \
            log_info "  CDP WS   : $WS_URL"

        exit 0
    fi
    printf "."
    sleep 1
done

echo ""
log_error "CDP did not respond within ${MAX_WAIT}s at ${NETBIRD_IP}:${CDP_PORT}"
log_error "Check that Windows Firewall allows inbound TCP ${CDP_PORT} on the NetBird interface"
exit 1
