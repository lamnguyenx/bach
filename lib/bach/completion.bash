#!/bin/bash
# ==============================================================
#                         BACH COMPLETION
# ==============================================================
# Static CLI completion, compatible with Bash 3.2+.

_bach_complete() {
    local current=${COMP_WORDS[COMP_CWORD]} candidate
    COMPREPLY=()
    if [ "$COMP_CWORD" -eq 1 ]; then
        while IFS= read -r candidate; do
            COMPREPLY+=("$candidate")
        done < <(compgen -W 'init deinit reload update install uninstall clean --help --version' -- "$current")
    elif [ "${COMP_WORDS[1]}" = init ] || [ "${COMP_WORDS[1]}" = deinit ]; then
        while IFS= read -r candidate; do
            COMPREPLY+=("$candidate")
        done < <(compgen -W '--write --rc' -- "$current")
    fi
}
complete -F _bach_complete bach
