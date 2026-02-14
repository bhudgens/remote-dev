#!/usr/bin/env bash
# Sync local $HOME/reverts to the remote EC2's /home/bhudgens/reverts.
# Run from WSL2 on any workstation. Auto-discovers EC2 via NetBird.
#
# SSH is via ubuntu, files are written as root (sudo rsync) then chowned to bhudgens.
#
# Usage: sync.sh [ec2_netbird_ip]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP="${1:-}"
LOCAL_DIR="$HOME/reverts"
REMOTE_USER="$EC2_SSH_USER"
REMOTE_DIR="/home/bhudgens/reverts"

# ── Discover EC2 ─────────────────────────────────────────────────────────────

if [[ -z "$EC2_IP" ]]; then
    log_info "Discovering $EC2_PEER_NAME peer..."
    EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1
    log_info "Found $EC2_PEER_NAME at $EC2_IP"
fi

# ── Validate local dir ───────────────────────────────────────────────────────

if [[ ! -d "$LOCAL_DIR" ]]; then
    log_error "$LOCAL_DIR does not exist"
    exit 1
fi

# ── Sync ─────────────────────────────────────────────────────────────────────

log_info "Syncing $LOCAL_DIR -> ${REMOTE_USER}@${EC2_IP}:${REMOTE_DIR}"

rsync -avz --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '.next' \
    --exclude '__pycache__' \
    --exclude '.venv' \
    --exclude 'venv' \
    --exclude '.terraform' \
    --exclude '*.tfstate' \
    --exclude '*.tfstate.backup' \
    --exclude '.terraform.lock.hcl' \
    -e "ssh -o StrictHostKeyChecking=no" \
    --rsync-path="sudo rsync" \
    "$LOCAL_DIR/" \
    "${REMOTE_USER}@${EC2_IP}:${REMOTE_DIR}/"

# ── Fix ownership ───────────────────────────────────────────────────────────

log_info "Fixing ownership to bhudgens..."
ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${EC2_IP}" \
    "sudo chown -R bhudgens:bhudgens ${REMOTE_DIR}"

log_info "Sync complete: ${REMOTE_DIR} on $EC2_PEER_NAME"
