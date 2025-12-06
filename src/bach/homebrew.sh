#!/bin/bash
# ==============================================================
#                          HOMEBREW
# ==============================================================
function set_brew_envs() {
    export CONDA_BACKUP_PATH="$PATH"

    local brew_path=""
    if [ "$(uname)" = "Darwin" ]; then
        brew_path="/usr/local/bin/brew"  # Intel macOS
        [ -f "/opt/homebrew/bin/brew" ] && brew_path="/opt/homebrew/bin/brew"  # Apple Silicon
    else
        brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
    fi

    if [ -f "$brew_path" ]; then
        eval "$("$brew_path" shellenv)"
        echo "✅ Homebrew activated"
        echo "📍 Brew path: $(which brew)"
        echo "🔧 Use 'remove_brew_envs' to restore conda-only environment"
    else
        echo "❌ Homebrew not found at $brew_path"
        return 1
    fi
}

function remove_brew_envs() {
    if [[ -n "$CONDA_BACKUP_PATH" ]]; then
        export PATH="$CONDA_BACKUP_PATH"
        unset CONDA_BACKUP_PATH
        unset HOMEBREW_PREFIX
        unset HOMEBREW_CELLAR
        unset HOMEBREW_REPOSITORY
        echo "✅ Homebrew deactivated, original PATH restored"
    else
        echo "⚠️  No backup PATH found"
    fi
}