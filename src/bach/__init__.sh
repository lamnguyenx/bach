#!/bin/bash
# ==============================================================
#                         BACH.SH
# ==============================================================
# Modularized bash configuration for development environment
# Sources individual modules for better organization and maintainability

if [ -n "${BACH_SOURCED:-}" ]; then
    return
fi

# Calculate script directory once
bach_dir="$(dirname "${BASH_SOURCE[0]}")"

# Define module arrays for better maintainability
CORE_MODULES=("common.sh" "logging.sh")
APP_MODULES=("docker.sh" "files.sh" "git.sh" "homebrew.sh")
PROJECT_MODULES=("terminal.sh" "lastly.sh")

# Function to source all modules
source_modules() {
    # Core modules - always loaded
    for module in "${CORE_MODULES[@]}"; do
        source "$bach_dir/$module"
    done

    # Application-specific modules
    for module in "${APP_MODULES[@]}"; do
        source "$bach_dir/$module"
    done

    # Project and terminal setup
    for module in "${PROJECT_MODULES[@]}"; do
        source "$bach_dir/$module"
    done
}

# Initial module loading
source_modules
BACH_SOURCED=1

# Reload function to reload all modules
function reload_bach() {
    source_modules
    echo "✅ All bach modules reloaded"
}

function reload_bashrc() {
    source ~/.bashrc
}