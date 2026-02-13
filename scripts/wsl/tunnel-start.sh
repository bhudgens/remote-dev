#!/usr/bin/env bash
# Create a reverse SSH tunnel from this workstation to the EC2 instance.
# Forwards local Chrome CDP (localhost:9222) so it appears at localhost:9222 on the EC2.
#
# Usage: tunnel-start.sh [ec2_netbird_ip] [ssh_user]
#   ec2_netbird_ip: NetBird IP of the EC2 instance (default: discovers cloud-development peer)
#   ssh_user: SSH username on the EC2 (default: ubuntu)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP="${1:-}"
SSH_USER="${2:-$EC2_SSH_USER}"
CDP_PORT="${CDP_PORT:-9222}"

# ── Discover EC2 NetBird IP if not provided ──────────────────────────────────

if [[ -z "$EC2_IP" ]]; then
    log_info "Discovering $EC2_PEER_NAME peer..."
    EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1
    log_info "Found $EC2_PEER_NAME at $EC2_IP"
fi

# ── Check Chrome CDP is running locally ──────────────────────────────────────

if ! check_cdp_responding "127.0.0.1" "$CDP_PORT"; then
    log_error "Chrome CDP is not responding at 127.0.0.1:${CDP_PORT}"
    log_error "Run chrome-launch.sh first"
    exit 1
fi

# ── Check for existing tunnel ────────────────────────────────────────────────

if pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}.*${EC2_IP}" >/dev/null 2>&1; then
    EXISTING_PID=$(pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}.*${EC2_IP}" | head -1)
    log_warn "Tunnel to ${EC2_IP} already running (PID: $EXISTING_PID)"
    log_info "Use tunnel-stop.sh to stop it first"
    exit 1
fi

# ── Create reverse SSH tunnel ────────────────────────────────────────────────

log_info "Creating reverse tunnel: EC2(localhost:${CDP_PORT}) -> local Chrome CDP"
log_info "  ssh -R ${CDP_PORT}:localhost:${CDP_PORT} ${SSH_USER}@${EC2_IP}"

ssh -o StrictHostKeyChecking=no -f -N \
    -R "${CDP_PORT}:localhost:${CDP_PORT}" \
    "${SSH_USER}@${EC2_IP}" || {
    log_error "Failed to create tunnel to ${SSH_USER}@${EC2_IP}"
    exit 1
}

sleep 1
TUNNEL_PID=$(pgrep -f "ssh.*-R.*${CDP_PORT}:localhost:${CDP_PORT}.*${EC2_IP}" | head -1 || true)

if [[ -z "$TUNNEL_PID" ]]; then
    log_error "Tunnel started but could not find its PID"
    exit 1
fi

log_info "Tunnel established (PID: $TUNNEL_PID)"
log_info "  EC2 can now access CDP at localhost:${CDP_PORT}"
log_info "  To stop: tunnel-stop.sh"
