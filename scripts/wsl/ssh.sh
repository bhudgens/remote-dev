#!/usr/bin/env bash
# SSH to the remote EC2 instance. Auto-discovers the NetBird IP.
#
# Usage: ssh.sh [command...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1

exec ssh -o StrictHostKeyChecking=no "${EC2_SSH_USER}@${EC2_IP}" "$@"
