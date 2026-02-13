#!/usr/bin/env bash
# Dashboard: Show status of NetBird, Chrome automation, CDP, and tunnel.
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

# ── CDP Endpoint (localhost) ─────────────────────────────────────────────────

printf "%-20s" "CDP Endpoint:"

if [[ "$CHROME_RUNNING" == "0" ]]; then
    echo "SKIPPED  (Chrome not running)"
elif check_cdp_responding "127.0.0.1" "$CDP_PORT"; then
    echo "Responding  (http://127.0.0.1:${CDP_PORT})"

    TAB_COUNT=$(curl -sf --max-time 2 "http://127.0.0.1:${CDP_PORT}/json" 2>/dev/null \
        | grep -c '"id"' || echo "0")
    printf "%-20s%s\n" "" "Open tabs: $TAB_COUNT"
else
    echo "NOT RESPONDING  (http://127.0.0.1:${CDP_PORT})"
fi

echo ""

# ── Reverse SSH Tunnel ───────────────────────────────────────────────────────

printf "%-20s" "Tunnel:"

TUNNEL_PID=$(pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}" 2>/dev/null | head -1 || true)

if [[ -n "$TUNNEL_PID" ]]; then
    # Extract the target IP from the process command line
    TUNNEL_TARGET=$(ps -p "$TUNNEL_PID" -o args= 2>/dev/null | grep -oP '\S+@\S+' || echo "unknown")
    echo "Active  (PID: $TUNNEL_PID, target: $TUNNEL_TARGET)"
else
    echo "NOT RUNNING  (use tunnel-start.sh)"
fi

echo ""
echo "══════════════════════════════════════════════════"
