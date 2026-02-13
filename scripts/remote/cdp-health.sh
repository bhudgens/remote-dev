#!/usr/bin/env bash
# Health check: verify CDP connectivity from the remote EC2 instance.
# Tests network, HTTP, and WebSocket layers.
#
# Usage: cdp-health.sh <WINDOWS_NETBIRD_IP> [cdp_port]
# Exit: 0 = healthy, 1 = unhealthy (with diagnostic message)

set -euo pipefail

WINDOWS_NETBIRD_IP="${1:-${WINDOWS_NETBIRD_IP:-}}"
CDP_PORT="${2:-${CDP_PORT:-9222}}"

if [[ -z "$WINDOWS_NETBIRD_IP" ]]; then
    echo "[ERROR] Usage: cdp-health.sh <WINDOWS_NETBIRD_IP> [cdp_port]" >&2
    exit 1
fi

PASS=0
FAIL=0

check() {
    local label="$1"
    shift
    printf "  %-30s" "$label"
    if "$@" >/dev/null 2>&1; then
        echo "OK"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

echo "CDP Health Check: ${WINDOWS_NETBIRD_IP}:${CDP_PORT}"
echo "────────────────────────────────────────────────"

# ── Layer 1: Network (ping) ──────────────────────────────────────────────────

check "Network (ping)" ping -c 1 -W 2 "$WINDOWS_NETBIRD_IP"

# ── Layer 2: HTTP (CDP endpoint) ─────────────────────────────────────────────

check "CDP HTTP (/json/version)" curl -sf --max-time 5 "http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}/json/version"

# ── Layer 3: WebSocket URL discovery ─────────────────────────────────────────

printf "  %-30s" "WebSocket URL"
WS_URL=$(curl -sf --max-time 5 "http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}/json/version" 2>/dev/null \
    | grep -oP '"webSocketDebuggerUrl"\s*:\s*"\K[^"]+' 2>/dev/null || true)

if [[ -n "$WS_URL" ]]; then
    # Fix localhost to actual IP
    WS_URL=$(echo "$WS_URL" | sed "s|ws://[^:/]*:|ws://${WINDOWS_NETBIRD_IP}:|")
    echo "OK ($WS_URL)"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

# ── Layer 4: Tab listing ─────────────────────────────────────────────────────

check "Tab listing (/json)" curl -sf --max-time 5 "http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}/json"

# ── Summary ──────────────────────────────────────────────────────────────────

echo "────────────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo "Troubleshooting:"
    echo "  1. Is Chrome running with --remote-debugging-port=${CDP_PORT}?"
    echo "  2. Is Chrome bound to the NetBird IP (--remote-debugging-address)?"
    echo "  3. Is Windows Firewall allowing TCP ${CDP_PORT} on the NetBird interface?"
    echo "  4. Is NetBird connected on both sides? (netbird status)"
    exit 1
fi
