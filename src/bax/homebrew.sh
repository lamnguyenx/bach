#!/bin/bash
# --------------------------------------------------------------
#                          homebrew
# --------------------------------------------------------------
function set_brew_envs() {
    export CONDA_BACKUP_PATH="$PATH"

    if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        echo "✅ Homebrew activated"
        echo "📍 Brew path: $(which brew)"
        echo "🔧 Use 'remove_brew_envs' to restore conda-only environment"
    else
        echo "❌ Homebrew not found at /home/linuxbrew/.linuxbrew/bin/brew"
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