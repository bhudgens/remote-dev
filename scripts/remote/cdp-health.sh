#!/usr/bin/env bash
# Health check: verify CDP connectivity on the EC2 instance.
# Assumes a reverse SSH tunnel is active from a workstation,
# making Chrome CDP available at localhost:9222.
#
# Usage: cdp-health.sh [cdp_host] [cdp_port]
# Exit: 0 = healthy, 1 = unhealthy

set -euo pipefail

CDP_HOST="${1:-${CDP_HOST:-127.0.0.1}}"
CDP_PORT="${2:-${CDP_PORT:-9222}}"

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

echo "CDP Health Check: ${CDP_HOST}:${CDP_PORT}"
echo "────────────────────────────────────────────────"

# ── Layer 1: Tunnel active (port listening) ──────────────────────────────────

printf "  %-30s" "Tunnel (port ${CDP_PORT})"
if ss -tln 2>/dev/null | grep -q ":${CDP_PORT} " || \
   netstat -tln 2>/dev/null | grep -q ":${CDP_PORT} "; then
    echo "OK"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

# ── Layer 2: HTTP (CDP endpoint) ─────────────────────────────────────────────

check "CDP HTTP (/json/version)" curl -sf --max-time 5 "http://${CDP_HOST}:${CDP_PORT}/json/version"

# ── Layer 3: WebSocket URL discovery ─────────────────────────────────────────

printf "  %-30s" "WebSocket URL"
WS_URL=$(curl -sf --max-time 5 "http://${CDP_HOST}:${CDP_PORT}/json/version" 2>/dev/null \
    | grep -oP '"webSocketDebuggerUrl"\s*:\s*"\K[^"]+' 2>/dev/null || true)

if [[ -n "$WS_URL" ]]; then
    WS_URL=$(echo "$WS_URL" | sed "s|ws://[^:/]*:|ws://${CDP_HOST}:|")
    echo "OK ($WS_URL)"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

# ── Layer 4: Tab listing ─────────────────────────────────────────────────────

check "Tab listing (/json)" curl -sf --max-time 5 "http://${CDP_HOST}:${CDP_PORT}/json"

# ── Summary ──────────────────────────────────────────────────────────────────

echo "────────────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo "Troubleshooting:"
    echo "  1. Is the reverse tunnel running? (workstation: tunnel-start.sh)"
    echo "  2. Is Chrome running on the workstation? (workstation: chrome-launch.sh)"
    echo "  3. Is NetBird connected on both sides? (netbird status)"
    exit 1
fi
