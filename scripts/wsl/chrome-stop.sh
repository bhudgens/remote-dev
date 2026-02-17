#!/usr/bin/env bash
# Stop the automation Chrome instance launched by chrome-launch.sh.
# Run from WSL2. Uses taskkill.exe to stop Windows Chrome processes.
#
# Usage: chrome-stop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

# ── Find automation Chrome processes ─────────────────────────────────────────

POWERSHELL_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
TASKKILL_EXE="/mnt/c/Windows/System32/taskkill.exe"

log_info "Looking for automation Chrome processes (user-data-dir: $CHROME_USER_DATA_DIR)..."

# Get PIDs of Chrome processes using the automation profile
PIDS=$("$POWERSHELL_EXE" -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -match '$CHROME_USER_DATA_DIR' } | Select-Object -ExpandProperty ProcessId" 2>/dev/null | tr -d '\r')

if [[ -z "$PIDS" ]]; then
    log_info "No automation Chrome processes found"
    exit 0
fi

# ── Kill processes ───────────────────────────────────────────────────────────

KILLED=0
for pid in $PIDS; do
    pid=$(echo "$pid" | tr -d '[:space:]')
    [[ -z "$pid" ]] && continue
    log_info "Stopping Chrome process PID $pid..."
    "$TASKKILL_EXE" /PID "$pid" /F >/dev/null 2>&1 && ((KILLED++)) || true
done

# Brief pause for processes to exit
sleep 1

# ── Verify ───────────────────────────────────────────────────────────────────

REMAINING=$("$POWERSHELL_EXE" -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -match '$CHROME_USER_DATA_DIR' } | Measure-Object | Select-Object -ExpandProperty Count" 2>/dev/null | tr -d '\r')

if [[ "$REMAINING" == "0" || -z "$REMAINING" ]]; then
    log_info "Stopped $KILLED automation Chrome process(es)"
else
    log_warn "$REMAINING Chrome process(es) still running — may need manual cleanup"
fi
