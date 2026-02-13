#!/usr/bin/env bash
# Dashboard: Show status of NetBird, Chrome automation, and CDP connectivity.
# Run from WSL2.
#
# Usage: status.sh [cdp_port]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

CDP_PORT="${1:-$CDP_PORT}"

echo "══════════════════════════════════════════════════"
echo "  Remote Dev Status"
echo "══════════════════════════════════════════════════"
echo ""

# ── NetBird ──────────────────────────────────────────────────────────────────

printf "%-20s" "NetBird:"

NETBIRD_IP=$(get_netbird_ip 2>/dev/null) && {
    echo "Connected  (IP: $NETBIRD_IP)"
} || {
    echo "NOT CONNECTED"
    NETBIRD_IP=""
}

# Show connected peers
if [[ -n "$NETBIRD_IP" ]]; then
    PEER_COUNT=$("${NETBIRD_EXE:-/mnt/c/Program Files/NetBird/netbird.exe}" status 2>/dev/null \
        | grep -c "Connected" || echo "0")
    printf "%-20s%s\n" "" "Peers connected: $PEER_COUNT"
fi

echo ""

# ── Chrome Automation ────────────────────────────────────────────────────────

printf "%-20s" "Chrome:"

CHROME_RUNNING=$(powershell.exe -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -match '$CHROME_USER_DATA_DIR' } | Measure-Object | Select-Object -ExpandProperty Count" 2>/dev/null | tr -d '\r')

if [[ -n "$CHROME_RUNNING" && "$CHROME_RUNNING" != "0" ]]; then
    echo "Running  ($CHROME_RUNNING process(es), profile: $CHROME_USER_DATA_DIR)"
else
    echo "NOT RUNNING"
    CHROME_RUNNING=0
fi

echo ""

# ── CDP Endpoint ─────────────────────────────────────────────────────────────

printf "%-20s" "CDP Endpoint:"

if [[ -z "$NETBIRD_IP" ]]; then
    echo "SKIPPED  (NetBird not connected)"
elif [[ "$CHROME_RUNNING" == "0" ]]; then
    echo "SKIPPED  (Chrome not running)"
elif check_cdp_responding "$NETBIRD_IP" "$CDP_PORT"; then
    echo "Responding  (http://${NETBIRD_IP}:${CDP_PORT})"

    WS_URL=$(get_cdp_ws_url "$NETBIRD_IP" "$CDP_PORT" 2>/dev/null) && {
        printf "%-20s%s\n" "" "WS: $WS_URL"
    }

    # Show open tabs
    TAB_COUNT=$(curl -sf --max-time 2 "http://${NETBIRD_IP}:${CDP_PORT}/json" 2>/dev/null \
        | grep -c '"id"' || echo "0")
    printf "%-20s%s\n" "" "Open tabs: $TAB_COUNT"
else
    echo "NOT RESPONDING  (http://${NETBIRD_IP}:${CDP_PORT})"
    echo "  Check: Windows Firewall rule for TCP $CDP_PORT on NetBird interface"
fi

echo ""
echo "══════════════════════════════════════════════════"
