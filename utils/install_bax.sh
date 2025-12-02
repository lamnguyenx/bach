#!/bin/bash
# --------------------------------------------------------------
#                         install_bax.sh
# --------------------------------------------------------------
# Install script for bax bash configuration
# Adds sourcing of bax/__init__.sh to ~/.bashrc if not already present

set -euo pipefail

# Path to the bax init script (resolve to absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAX_INIT_PATH="$(readlink -f "$SCRIPT_DIR/../src/bax/__init__.sh")"

# Check if bax init script exists
if [[ ! -f "$BAX_INIT_PATH" ]]; then
    echo "Error: bax init script not found at $BAX_INIT_PATH"
    exit 1
fi

# Block to add
BAX_BLOCK="# >>> bax initialize >>>
# !! Contents within this block are managed by 'bax install' !!
source \"$BAX_INIT_PATH\"
# <<< bax initialize <<<"

# Backup ~/.bashrc
if [[ -f ~/.bashrc ]]; then
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
    echo "Backed up ~/.bashrc"
fi

# Replace or add the bax block
if grep -q "# >>> bax initialize >>>" ~/.bashrc 2>/dev/null; then
    # Delete the old block
    sed -i '.bak' '/# >>> bax initialize >>>/,/# <<< bax initialize <<</d' ~/.bashrc
    echo "Removed existing bax block (backup created as ~/.bashrc.bak)"
fi
# Add new block at the end
echo "" >> ~/.bashrc
echo "$BAX_BLOCK" >> ~/.bashrc
echo "Added bax block"

echo "✅ bax installed successfully! Restart your shell or run 'source ~/.bashrc' to apply changes."