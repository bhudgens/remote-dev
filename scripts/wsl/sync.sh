#!/usr/bin/env bash
# Sync this workstation's code and config to the remote EC2.
# Each machine gets its own directory to avoid collisions:
#   /home/bhudgens/machines/<machine-name>/reverts/
#   /home/bhudgens/machines/<machine-name>/dotfiles/
#
# Run from WSL2 on any workstation. Auto-discovers EC2 via NetBird.
#
# Usage: sync.sh [ec2_netbird_ip]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP="${1:-}"
REMOTE_USER="$EC2_SSH_USER"

# ── Identify this machine ────────────────────────────────────────────────────

MACHINE_NAME=$(hostname | tr '[:upper:]' '[:lower:]')
REMOTE_BASE="/home/bhudgens/machines/${MACHINE_NAME}"

log_info "Machine: $MACHINE_NAME"

# ── Discover EC2 ─────────────────────────────────────────────────────────────

if [[ -z "$EC2_IP" ]]; then
    log_info "Discovering $EC2_PEER_NAME peer..."
    EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1
    log_info "Found $EC2_PEER_NAME at $EC2_IP"
fi

SSH_CMD="ssh -o StrictHostKeyChecking=no"
SSH_TARGET="${REMOTE_USER}@${EC2_IP}"

# ── Create remote directories ────────────────────────────────────────────────

$SSH_CMD "$SSH_TARGET" "sudo mkdir -p ${REMOTE_BASE}/{reverts,dotfiles} && sudo chown -R bhudgens:bhudgens /home/bhudgens/machines"

# ── Common rsync excludes ────────────────────────────────────────────────────

EXCLUDES=(
    --exclude 'node_modules'
    --exclude '.next'
    --exclude '__pycache__'
    --exclude '.venv'
    --exclude 'venv'
    --exclude '.terraform'
    --exclude '*.tfstate'
    --exclude '*.tfstate.backup'
    --exclude '.terraform.lock.hcl'
    --exclude '.cache'
    --exclude 'dist'
    --exclude 'build'
)

# ── Sync code ────────────────────────────────────────────────────────────────

if [[ -d "$HOME/reverts" ]]; then
    log_info "Syncing ~/reverts -> ${REMOTE_BASE}/reverts/"
    rsync -avz --delete \
        "${EXCLUDES[@]}" \
        -e "$SSH_CMD" \
        --rsync-path="sudo rsync" \
        "$HOME/reverts/" \
        "${SSH_TARGET}:${REMOTE_BASE}/reverts/"
fi

# ── Sync dotfiles / configs ──────────────────────────────────────────────────

DOTFILES=(
    .claude
)

log_info "Syncing dotfiles -> ${REMOTE_BASE}/dotfiles/"

for dotfile in "${DOTFILES[@]}"; do
    src="$HOME/$dotfile"
    if [[ -e "$src" ]]; then
        # Preserve directory structure
        dest_dir="${REMOTE_BASE}/dotfiles/$(dirname "$dotfile")"
        $SSH_CMD "$SSH_TARGET" "sudo mkdir -p '$dest_dir'"
        rsync -avz \
            -e "$SSH_CMD" \
            --rsync-path="sudo rsync" \
            "$src" \
            "${SSH_TARGET}:${REMOTE_BASE}/dotfiles/${dotfile}"
    fi
done

# ── Fix ownership ────────────────────────────────────────────────────────────

log_info "Fixing ownership..."
$SSH_CMD "$SSH_TARGET" "sudo chown -R bhudgens:bhudgens /home/bhudgens/machines"

# ── Summary ──────────────────────────────────────────────────────────────────

log_info "Sync complete: ${REMOTE_BASE}/"
log_info ""
log_info "On the EC2 as bhudgens:"
log_info "  ls ~/machines/                    # see all synced machines"
log_info "  ls ~/machines/${MACHINE_NAME}/reverts/  # this machine's code"
log_info "  ls ~/machines/${MACHINE_NAME}/dotfiles/ # this machine's configs"
