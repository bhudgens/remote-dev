#!/usr/bin/env bash
# SSH to the remote EC2 instance as bhudgens. Auto-discovers the NetBird IP.
# Connects as ubuntu and runs become-bhudgens.sh for a proper systemd session.
#
# Usage: ssh.sh [command...]
#   No args: interactive shell as bhudgens
#   With args: runs command as ubuntu (for scripting)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../lib.sh"

EC2_IP=$(get_peer_ip "$EC2_PEER_NAME") || exit 1

if [[ $# -eq 0 ]]; then
    # Interactive: become bhudgens via machinectl (proper logind session)
    exec ssh -o StrictHostKeyChecking=no -t "${EC2_SSH_USER}@${EC2_IP}" "./become-bhudgens.sh"
else
    # Command mode: run as ubuntu (for scripting/automation)
    exec ssh -o StrictHostKeyChecking=no "${EC2_SSH_USER}@${EC2_IP}" "$@"
fi
