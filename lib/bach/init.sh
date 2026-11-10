#!/bin/bash
# ==============================================================
#                         BACH.SH
# ==============================================================
# Modularized bash configuration for development environment
# Sources individual modules for better organization and maintainability

# Anchor reloads before the working directory or shell globals can change.
bach_dir="$(builtin cd -- "$(dirname "${BASH_SOURCE[0]}")" && builtin pwd -P)" || return 1
export _BACH_INIT_FILE="$bach_dir/init.sh"

# Define module arrays for better maintainability.
CORE_MODULES=("common.sh" "logging.sh")
APP_MODULES=("docker.sh" "files.sh" "git.sh" "homebrew.sh" "android.sh" "ssh.sh" "apis.sh" "code-server.sh" "cdp.sh" "vscode.sh" "audio.sh" "display.sh" "video.sh")
PROJECT_MODULES=("terminal.sh" "lastly.sh")

# Check syntax before sourcing: a broken module must not look like success.
_bach_check_source() {
    local file=$1
    if [ ! -r "$file" ]; then
        printf 'Bach: cannot read %s\n' "$file" >&2
        return 1
    fi
    if ! "$BASH" -n "$file"; then
        printf 'Bach: syntax check failed for %s\n' "$file" >&2
        return 1
    fi
}

source_modules() {
    local module
    local -a modules
    modules=("${CORE_MODULES[@]}" "${APP_MODULES[@]}" "${PROJECT_MODULES[@]}")

    # Readline bindings only belong in interactive shells.
    if [[ $- == *i* ]] && type -t __fzfcmd >/dev/null 2>&1; then
        modules+=("fzf_tools.sh")
    fi
    for module in "${modules[@]}"; do
        _bach_check_source "$bach_dir/$module" || return 1
    done
    for module in "${modules[@]}"; do
        if ! source "$bach_dir/$module"; then
            printf 'Bach: loading %s failed\n' "$bach_dir/$module" >&2
            return 1
        fi
    done
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
        source "$config_file" || {
            printf 'Bach: loading %s failed\n' "$config_file" >&2
            return 1
        }
    fi

    for module in "$@"; do
        module="${module%.sh}"
        config_file="$config_dir/config-$module.sh"
        if [ -f "$config_file" ]; then
            # shellcheck disable=SC1090
            source "$config_file" || {
                printf 'Bach: loading %s failed\n' "$config_file" >&2
                return 1
            }
        fi
    done
}

# Source every config file that exists (shared + per-module)
function load_all_bach_configs() {
    local config_dir config_file
    config_dir="$(bach_config_dir)"

    # Validate every config before applying any of them.
    for config_file in "$config_dir/config.sh" "$config_dir"/config-*.sh; do
        [ ! -f "$config_file" ] || _bach_check_source "$config_file" || return 1
    done
    load_bach_config || return 1

    for config_file in "$config_dir"/config-*.sh; do
        if [ -f "$config_file" ]; then
            # shellcheck disable=SC1090
            source "$config_file" || {
                printf 'Bach: loading %s failed\n' "$config_file" >&2
                return 1
            }
        fi
    done
}

# Re-read the entry point as well as modules: loader/config helpers can change
# between versions. Sourcing runs in this shell so definitions take effect here.
function bach_reload() {
    local _bach_reload_init=${_BACH_INIT_FILE:-}
    if [ -z "$_bach_reload_init" ]; then
        echo 'Bach: no entry point recorded; run eval "$(bach init)" first.' >&2
        return 1
    fi
    _bach_check_source "$_bach_reload_init" || return 1
    if ! source "$_bach_reload_init"; then
        echo 'Bach reload failed; fix the reported file and retry.' >&2
        return 1
    fi
    echo "✅ All bach modules reloaded"
}

# Preserve the existing spelling.
function reload_bach() {
    bach_reload "$@"
}

function reload_bashrc() {
    source ~/.bashrc
}

# Export the entry path with the functions, so a child Bash can rebuild state.
export -f _bach_check_source source_modules bach_config_dir load_bach_config load_all_bach_configs bach_reload reload_bach reload_bashrc

source_modules || return 1
load_all_bach_configs || return 1

if [[ $- == *i* ]]; then
    _bach_check_source "$bach_dir/completion.bash" || return 1
    source "$bach_dir/completion.bash" || return 1
fi
return 0
