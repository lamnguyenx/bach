#!/bin/bash
# --------------------------------------------------------------
#                         bax.sh
# --------------------------------------------------------------
# Modularized bash configuration for development environment
# Sources individual modules for better organization and maintainability

if [ -n "${BAX_SOURCED:-}" ]; then
    return
fi

# Calculate script directory once
bax_dir="$(dirname "${BASH_SOURCE[0]}")"

# Define module arrays for better maintainability
CORE_MODULES=("common.sh" "logging.sh")
APP_MODULES=("docker.sh" "git.sh" "homebrew.sh")
PROJECT_MODULES=("terminal.sh" "lastly.sh")

# Function to source all modules
source_modules() {
    # Core modules - always loaded
    for module in "${CORE_MODULES[@]}"; do
        source "$bax_dir/$module"
    done

    # Application-specific modules
    for module in "${APP_MODULES[@]}"; do
        source "$bax_dir/$module"
    done

    # Project and terminal setup
    for module in "${PROJECT_MODULES[@]}"; do
        source "$bax_dir/$module"
    done
}

# Initial module loading
source_modules
BAX_SOURCED=1

# Reload function to reload all modules
function reload_bax() {
    source_modules
    echo "✅ All bax modules reloaded"
}

function reload_bashrc() {
    source ~/.bashrc
}