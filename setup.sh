#!/bin/bash
# --------------------------------------------------------------
#                         setup.sh
# --------------------------------------------------------------
# Setup script for bax bash configuration
# install: Adds sourcing of bax/__init__.sh to ~/.bashrc if not already present
# uninstall: Removes the bax block from ~/.bashrc

set -euo pipefail

# Functions
get_bax_paths() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BAX_INIT_PATH="$(cd "$SCRIPT_DIR/src/bax" && pwd)/__init__.sh"
}

install_bax() {
    get_bax_paths

    # Check if bax init script exists
    if [[ ! -f "$BAX_INIT_PATH" ]]; then
        echo "Error: bax init script not found at $BAX_INIT_PATH"
        exit 1
    fi

    # Block to add
    BAX_BLOCK="# >>> bax initialize >>>
# !! Contents within this block are managed by 'bax setup' !!
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
}

uninstall_bax() {
    # Remove the bax block from ~/.bashrc
    if grep -q "# >>> bax initialize >>>" ~/.bashrc 2>/dev/null; then
        # Delete the block
        sed -i '.bak' '/# >>> bax initialize >>>/,/# <<< bax initialize <<</d' ~/.bashrc
        echo "Removed bax block (backup created as ~/.bashrc.bak)"
        echo "✅ bax uninstalled successfully! Restart your shell or run 'source ~/.bashrc' to apply changes."
    else
        echo "bax is not installed."
    fi
}

# Main
ACTION="${1:-install}"

case "$ACTION" in
install)
    install_bax
    ;;
uninstall|clean|remove)
    uninstall_bax
    ;;
*)
    echo "Usage: $0 [install|uninstall|clean|remove]"
    echo "Default action is 'install' if no argument provided."
    exit 1
    ;;
esac