#!/usr/bin/env bash
# One-time setup: Create a Windows Firewall rule allowing inbound CDP traffic
# on the NetBird interface only.
#
# MUST be run from an elevated (Administrator) WSL2 terminal.
#
# Usage: firewall-setup.sh [cdp_port]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

CDP_PORT="${1:-$CDP_PORT}"
RULE_NAME="Remote-Dev-CDP-${CDP_PORT}"

# ── Check for existing rule ──────────────────────────────────────────────────

log_info "Checking for existing firewall rule: $RULE_NAME"

EXISTING=$(powershell.exe -NoProfile -Command \
    "Get-NetFirewallRule -DisplayName '$RULE_NAME' -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count" 2>/dev/null | tr -d '\r')

if [[ "$EXISTING" != "0" && -n "$EXISTING" ]]; then
    log_info "Firewall rule '$RULE_NAME' already exists"

    # Show current rule details
    powershell.exe -NoProfile -Command \
        "Get-NetFirewallRule -DisplayName '$RULE_NAME' | Format-List DisplayName,Enabled,Direction,Action,Profile" 2>/dev/null
    exit 0
fi

# ── Discover NetBird interface ───────────────────────────────────────────────

log_info "Discovering NetBird network interface..."

NETBIRD_IFACE=$(powershell.exe -NoProfile -Command \
    "Get-NetAdapter | Where-Object { \$_.InterfaceDescription -match 'WireGuard|NetBird|wt0' } | Select-Object -First 1 -ExpandProperty Name" 2>/dev/null | tr -d '\r')

if [[ -z "$NETBIRD_IFACE" ]]; then
    log_warn "Could not auto-detect NetBird interface. Falling back to profile-based rule."
    log_warn "The rule will apply to all interfaces but restrict to TCP port $CDP_PORT."

    # Fallback: create rule without interface restriction
    powershell.exe -NoProfile -Command \
        "New-NetFirewallRule -DisplayName '$RULE_NAME' \
            -Direction Inbound \
            -Protocol TCP \
            -LocalPort $CDP_PORT \
            -Action Allow \
            -Profile Private \
            -Description 'Allow Chrome DevTools Protocol on port $CDP_PORT (remote-dev)'" 2>/dev/null || {
        log_error "Failed to create firewall rule. Are you running as Administrator?"
        exit 1
    }
else
    log_info "Found NetBird interface: $NETBIRD_IFACE"

    powershell.exe -NoProfile -Command \
        "New-NetFirewallRule -DisplayName '$RULE_NAME' \
            -Direction Inbound \
            -Protocol TCP \
            -LocalPort $CDP_PORT \
            -Action Allow \
            -InterfaceAlias '$NETBIRD_IFACE' \
            -Description 'Allow Chrome DevTools Protocol on port $CDP_PORT via NetBird (remote-dev)'" 2>/dev/null || {
        log_error "Failed to create firewall rule. Are you running as Administrator?"
        exit 1
    }
fi

# ── Verify ───────────────────────────────────────────────────────────────────

log_info "Verifying firewall rule..."

VERIFY=$(powershell.exe -NoProfile -Command \
    "Get-NetFirewallRule -DisplayName '$RULE_NAME' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Enabled" 2>/dev/null | tr -d '\r')

if [[ "$VERIFY" == "True" ]]; then
    log_info "Firewall rule '$RULE_NAME' created and enabled"
    powershell.exe -NoProfile -Command \
        "Get-NetFirewallRule -DisplayName '$RULE_NAME' | Format-List DisplayName,Enabled,Direction,Action,Profile" 2>/dev/null
else
    log_error "Firewall rule verification failed"
    exit 1
fi
