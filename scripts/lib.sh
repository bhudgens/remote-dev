#!/usr/bin/env bash
# Shared functions for remote-dev scripts
# Source this file from other scripts: source "$(dirname "$0")/../lib.sh"

set -euo pipefail

# ── Logging ──────────────────────────────────────────────────────────────────

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

# ── Validation ───────────────────────────────────────────────────────────────

# Validate that a value is a valid TCP port number
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "Invalid port: $port (must be 1-65535)"
        return 1
    fi
}

# Check that required commands are available
require_commands() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            ((missing++))
        fi
    done
    [[ "$missing" -eq 0 ]]
}

# ── NetBird ──────────────────────────────────────────────────────────────────

# Discover the local NetBird IP address (runs netbird.exe on Windows side)
get_netbird_ip() {
    local netbird_exe="${NETBIRD_EXE:-/mnt/c/Program Files/NetBird/netbird.exe}"

    if [[ ! -f "$netbird_exe" ]]; then
        log_error "NetBird executable not found at: $netbird_exe"
        return 1
    fi

    local status_output
    status_output=$("$netbird_exe" status 2>/dev/null) || {
        log_error "Failed to run netbird status"
        return 1
    }

    local ip
    ip=$(echo "$status_output" | grep -oP 'NetBird IP:\s*\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [[ -z "$ip" ]]; then
        # Try alternate format: "IP: x.x.x.x/xx"
        ip=$(echo "$status_output" | grep -oP 'IP:\s*\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi

    if [[ -z "$ip" ]]; then
        log_error "Could not parse NetBird IP from status output"
        return 1
    fi

    echo "$ip"
}

# ── Chrome / Windows Paths ───────────────────────────────────────────────────

# Resolve Windows %LOCALAPPDATA% from WSL2
get_chrome_localappdata() {
    local localappdata
    localappdata=$(cmd.exe /C "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')

    if [[ -z "$localappdata" || "$localappdata" == "%LOCALAPPDATA%" ]]; then
        log_error "Could not resolve Windows LOCALAPPDATA"
        return 1
    fi

    echo "$localappdata"
}

# ── CDP Health ───────────────────────────────────────────────────────────────

# Check if CDP endpoint is responding
# Usage: check_cdp_responding <host> [port]
check_cdp_responding() {
    local host="$1"
    local port="${2:-$CDP_PORT}"

    curl -sf --max-time 2 "http://${host}:${port}/json/version" >/dev/null 2>&1
}

# Get the WebSocket debugger URL from CDP, fixing the host to the actual IP
# Usage: get_cdp_ws_url <host> [port]
get_cdp_ws_url() {
    local host="$1"
    local port="${2:-$CDP_PORT}"

    local version_json
    version_json=$(curl -sf --max-time 5 "http://${host}:${port}/json/version") || {
        log_error "Failed to query CDP /json/version at ${host}:${port}"
        return 1
    }

    local ws_url
    ws_url=$(echo "$version_json" | grep -oP '"webSocketDebuggerUrl"\s*:\s*"\K[^"]+')

    if [[ -z "$ws_url" ]]; then
        log_error "Could not extract webSocketDebuggerUrl from CDP response"
        return 1
    fi

    # Fix the host — CDP returns localhost, we need the actual NetBird IP
    ws_url=$(echo "$ws_url" | sed "s|ws://[^:/]*:|ws://${host}:|")

    echo "$ws_url"
}
