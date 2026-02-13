#!/usr/bin/env bash
# Source-able script: discover CDP WebSocket URL and export env vars for AI tools.
# Run on the REMOTE EC2 instance.
#
# Usage: source cdp-env.sh <WINDOWS_NETBIRD_IP>
#    or: export WINDOWS_NETBIRD_IP=x.x.x.x && source cdp-env.sh

# Don't set -e in source-able scripts (would exit the caller's shell)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CDP_PORT="${CDP_PORT:-9222}"
WINDOWS_NETBIRD_IP="${1:-${WINDOWS_NETBIRD_IP:-}}"

if [[ -z "$WINDOWS_NETBIRD_IP" ]]; then
    echo "[ERROR] Usage: source cdp-env.sh <WINDOWS_NETBIRD_IP>" >&2
    echo "[ERROR]    or: export WINDOWS_NETBIRD_IP=x.x.x.x && source cdp-env.sh" >&2
    return 1 2>/dev/null || exit 1
fi

# ── Query CDP endpoint ───────────────────────────────────────────────────────

echo "[INFO] Querying CDP at http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}/json/version ..."

VERSION_JSON=$(curl -sf --max-time 5 "http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}/json/version") || {
    echo "[ERROR] Failed to reach CDP at ${WINDOWS_NETBIRD_IP}:${CDP_PORT}" >&2
    echo "[ERROR] Is Chrome running with --remote-debugging-port=${CDP_PORT}?" >&2
    return 1 2>/dev/null || exit 1
}

# ── Extract and fix WebSocket URL ────────────────────────────────────────────

WS_RAW=$(echo "$VERSION_JSON" | grep -oP '"webSocketDebuggerUrl"\s*:\s*"\K[^"]+')

if [[ -z "$WS_RAW" ]]; then
    echo "[ERROR] Could not extract webSocketDebuggerUrl from CDP response" >&2
    return 1 2>/dev/null || exit 1
fi

# CDP returns localhost — replace with actual NetBird IP
BROWSER_WS_ENDPOINT=$(echo "$WS_RAW" | sed "s|ws://[^:/]*:|ws://${WINDOWS_NETBIRD_IP}:|")

# ── Export environment variables ─────────────────────────────────────────────

export WINDOWS_NETBIRD_IP
export CDP_PORT
export CHROME_CDP_URL="http://${WINDOWS_NETBIRD_IP}:${CDP_PORT}"
export BROWSER_WS_ENDPOINT

echo "[INFO] CDP environment configured:"
echo "[INFO]   CHROME_CDP_URL      = $CHROME_CDP_URL"
echo "[INFO]   BROWSER_WS_ENDPOINT = $BROWSER_WS_ENDPOINT"
