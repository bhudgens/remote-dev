#!/usr/bin/env bash
# Source-able script: export CDP env vars for Playwright/automation tools.
# Run on the EC2 instance after a reverse tunnel is active from a workstation.
#
# Usage: source cdp-env.sh [cdp_host] [cdp_port]

# Don't set -e in source-able scripts (would exit the caller's shell)

CDP_HOST="${1:-${CDP_HOST:-127.0.0.1}}"
CDP_PORT="${2:-${CDP_PORT:-9222}}"

# ── Verify tunnel is active ──────────────────────────────────────────────────

if ! ss -tln 2>/dev/null | grep -q ":${CDP_PORT} " && \
   ! netstat -tln 2>/dev/null | grep -q ":${CDP_PORT} "; then
    echo "[WARN] Port ${CDP_PORT} is not listening. Is the reverse tunnel active?" >&2
    echo "[WARN] A workstation should run: tunnel-start.sh" >&2
fi

# ── Query CDP endpoint ───────────────────────────────────────────────────────

echo "[INFO] Querying CDP at http://${CDP_HOST}:${CDP_PORT}/json/version ..."

VERSION_JSON=$(curl -sf --max-time 5 "http://${CDP_HOST}:${CDP_PORT}/json/version") || {
    echo "[ERROR] Failed to reach CDP at ${CDP_HOST}:${CDP_PORT}" >&2
    echo "[ERROR] Is the reverse tunnel running? (workstation: tunnel-start.sh)" >&2
    return 1 2>/dev/null || exit 1
}

# ── Extract and fix WebSocket URL ────────────────────────────────────────────

WS_RAW=$(echo "$VERSION_JSON" | grep -oP '"webSocketDebuggerUrl"\s*:\s*"\K[^"]+')

if [[ -z "$WS_RAW" ]]; then
    echo "[ERROR] Could not extract webSocketDebuggerUrl from CDP response" >&2
    return 1 2>/dev/null || exit 1
fi

BROWSER_WS_ENDPOINT=$(echo "$WS_RAW" | sed "s|ws://[^:/]*:|ws://${CDP_HOST}:|")

# ── Export environment variables ─────────────────────────────────────────────

export CDP_HOST
export CDP_PORT
export CHROME_CDP_URL="http://${CDP_HOST}:${CDP_PORT}"
export BROWSER_WS_ENDPOINT

echo "[INFO] CDP environment configured:"
echo "[INFO]   CHROME_CDP_URL      = $CHROME_CDP_URL"
echo "[INFO]   BROWSER_WS_ENDPOINT = $BROWSER_WS_ENDPOINT"
