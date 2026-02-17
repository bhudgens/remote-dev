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

# Discover a NetBird peer's IP by name
# Usage: get_peer_ip <peer_name>
get_peer_ip() {
    local peer_name="$1"
    local netbird_exe="${NETBIRD_EXE:-/mnt/c/Program Files/NetBird/netbird.exe}"

    local ip
    ip=$("$netbird_exe" status --detail 2>/dev/null \
        | grep -A1 "$peer_name" \
        | grep -oP 'NetBird IP:\s*\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1) || true

    if [[ -z "$ip" ]]; then
        log_error "Could not find peer '$peer_name' in NetBird mesh"
        return 1
    fi

    echo "$ip"
}

# ── Chrome / Windows Paths ───────────────────────────────────────────────────

# Resolve Windows %LOCALAPPDATA% from WSL2
get_chrome_localappdata() {
    local localappdata
    local CMD_EXE="/mnt/c/Windows/System32/cmd.exe"

    # Try via cmd.exe first (direct path, not relying on PATH)
    # Note: cmd.exe may output UNC warnings to stderr, the actual value is on the last line
    if [[ -f "$CMD_EXE" ]]; then
        localappdata=$("$CMD_EXE" /C "echo %LOCALAPPDATA%" 2>&1 | tail -1 | tr -d '\r\n')
    fi

    # If that fails or returns unexpanded variable, try fallbacks
    if [[ -z "$localappdata" || "$localappdata" == "%LOCALAPPDATA%" ]]; then
        log_warn "Could not resolve LOCALAPPDATA via cmd.exe, trying fallbacks..."

        # Try getting Windows username
        local win_username
        if [[ -f "$CMD_EXE" ]]; then
            win_username=$("$CMD_EXE" /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
        fi

        if [[ -n "$win_username" && "$win_username" != "%USERNAME%" ]]; then
            localappdata="C:\\Users\\${win_username}\\AppData\\Local"
            log_info "Using fallback LOCALAPPDATA: $localappdata"
        else
            # Last resort: construct from WSL home
            local wsl_home_win
            wsl_home_win=$(wslpath -w ~ 2>/dev/null | tr -d '\r\n')
            if [[ -n "$wsl_home_win" ]]; then
                # Extract username from path like C:\Users\username\... or \\wsl.localhost\...
                win_username=$(echo "$wsl_home_win" | grep -oP 'C:\\\\Users\\\K[^\\]+' | head -1)
                if [[ -z "$win_username" ]]; then
                    # Try \\wsl.localhost\distro\home\username format
                    # Just use the Linux username as a guess
                    win_username=$(whoami)
                fi
                if [[ -n "$win_username" ]]; then
                    localappdata="C:\\Users\\${win_username}\\AppData\\Local"
                    log_info "Using fallback LOCALAPPDATA (from user: $win_username): $localappdata"
                fi
            fi
        fi

        if [[ -z "$localappdata" ]]; then
            log_error "Could not resolve Windows LOCALAPPDATA"
            log_error "Tried: cmd.exe, USERNAME, wslpath"
            return 1
        fi
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
