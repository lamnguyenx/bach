#!/bin/bash
set -Eeuo pipefail

# Print a deployment banner

CONFIG_NAME="${1:?Config name required}"

echo "==========================================="
echo "$CONFIG_NAME config deployed"
echo "==========================================="
