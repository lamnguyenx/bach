#!/bin/bash
# ==============================================================
#                         BACH.SH
# ==============================================================
# Modularized bash configuration for development environment
# Sources individual modules for better organization and maintainability

# if [ -n "${BACH_SOURCED:-}" ]; then
#     return
# fi

# Calculate script directory once
bach_dir="$(dirname "${BASH_SOURCE[0]}")"

# Define module arrays for better maintainability
CORE_MODULES=("common.sh" "logging.sh")
APP_MODULES=("docker.sh" "files.sh" "git.sh" "homebrew.sh" "android.sh" "ssh.sh" "apis.sh" "code-server.sh" "cdp.sh" "vscode.sh" "audio.sh" "display.sh" "video.sh")
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

    # Conditionally source fzf_tools if fzf shell integration is loaded
    if type -t __fzfcmd >/dev/null 2>&1; then
        source "$bach_dir/fzf_tools.sh"
    fi
}

# Directory holding the optional user configuration (not tracked by bach)
function bach_config_dir() {
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/bach"
}

# Function to load optional user configuration (not tracked by bach)
#
#   load_bach_config              - shared config.sh only
#   load_bach_config git docker   - shared config.sh, then config-git.sh and
#                                   config-docker.sh (module files win)
#
# Commands call this before reading their settings, so edits to a config file
# apply on the next command without restarting the shell or running reload_bach.
# Config files must be idempotent: they are sourced repeatedly.
function load_bach_config() {
    local config_dir config_file module
    config_dir="$(bach_config_dir)"

    # Shared settings first so module files can override them.
    config_file="$config_dir/config.sh"
    if [ -f "$config_file" ]; then
        # shellcheck disable=SC1090
        source "$config_file"
    fi

    for module in "$@"; do
        module="${module%.sh}"
        config_file="$config_dir/config-$module.sh"
        if [ -f "$config_file" ]; then
            # shellcheck disable=SC1090
            source "$config_file"
        fi
    done
}

# Source every config file that exists (shared + per-module)
function load_all_bach_configs() {
    local config_dir config_file
    config_dir="$(bach_config_dir)"

    load_bach_config

    for config_file in "$config_dir"/config-*.sh; do
        if [ -f "$config_file" ]; then
            # shellcheck disable=SC1090
            source "$config_file"
        fi
    done
}

# Initial module loading
source_modules
# Load every config file at startup so the values are visible immediately;
# module commands re-source their own files before reading them.
load_all_bach_configs
# BACH_SOURCED=1

# Reload function to reload all modules
function reload_bach() {
    source_modules
    load_all_bach_configs
    echo "✅ All bach modules reloaded"
}

function reload_bashrc() {
    source ~/.bashrc
}

# Export public API functions
export -f source_modules bach_config_dir load_bach_config load_all_bach_configs reload_bach reload_bashrc
