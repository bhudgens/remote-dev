#!/usr/bin/env bash
# Stop everything: tunnel + Chrome.
#
# Usage: stop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$SCRIPT_DIR/tunnel-stop.sh" 2>&1
bash "$SCRIPT_DIR/chrome-stop.sh" 2>&1
