#!/bin/bash
# --------------------------------------------------------------
#                         setup.sh
# --------------------------------------------------------------
# Setup script for bach bash configuration
# install: Adds sourcing of bach/__init__.sh to ~/.bashrc if not already present
# uninstall: Removes the bach block from ~/.bashrc

set -euo pipefail

# Functions
get_bach_paths() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BACH_INIT_PATH="$(cd "$SCRIPT_DIR/src/bach" && pwd)/__init__.sh"
}

install_bach() {
    get_bach_paths

    # Check if bach init script exists
    if [[ ! -f "$BACH_INIT_PATH" ]]; then
        echo "Error: bach init script not found at $BACH_INIT_PATH"
        exit 1
    fi

    # Block to add
    BACH_BLOCK="# >>> bach initialize >>>
# !! Contents within this block are managed by 'bach setup' !!
source \"$BACH_INIT_PATH\"
# <<< bach initialize <<<"

    # Backup ~/.bashrc
    if [[ -f ~/.bashrc ]]; then
        cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backed up ~/.bashrc"
    fi

    # Replace or add the bach block
    if grep -q "# >>> bach initialize >>>" ~/.bashrc 2>/dev/null; then
        # Delete the old block
        sed -i '.bak' '/# >>> bach initialize >>>/,/# <<< bach initialize <<</d' ~/.bashrc
        echo "Removed existing bach block (backup created as ~/.bashrc.bak)"
    fi
    # Add new block at the end
    echo "" >> ~/.bashrc
    echo "$BACH_BLOCK" >> ~/.bashrc
    echo "Added bach block"

    echo "✅ bach installed successfully! Restart your shell or run 'source ~/.bashrc' to apply changes."
}

uninstall_bach() {
    # Remove the bach block from ~/.bashrc
    if grep -q "# >>> bach initialize >>>" ~/.bashrc 2>/dev/null; then
        # Delete the block
        sed -i '.bak' '/# >>> bach initialize >>>/,/# <<< bach initialize <<</d' ~/.bashrc
        echo "Removed bach block (backup created as ~/.bashrc.bak)"
        echo "✅ bach uninstalled successfully! Restart your shell or run 'source ~/.bashrc' to apply changes."
    else
        echo "bach is not installed."
    fi
}

# Main
ACTION="${1:-install}"

case "$ACTION" in
install)
    install_bach
    ;;
uninstall|clean|remove)
    uninstall_bach
    ;;
*)
    echo "Usage: $0 [install|uninstall|clean|remove]"
    echo "Default action is 'install' if no argument provided."
    exit 1
    ;;
esac