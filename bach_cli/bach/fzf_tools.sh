#!/bin/bash
# ==============================================================
#                           FZF TOOLS
# ==============================================================

# Fix: fzf dir completion hangs in bash 3.2 + VS Code terminal
# Remove fzf's cd completion and restore normal directory completion
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    complete -r cd 2>/dev/null
    complete -o bashdefault -o dirnames cd
fi

bind -x '"\C-e": __fzf_file_widget --absolute'

__fzf_file_widget() {
    local selected
    selected=$(find . -type f 2>/dev/null | fzf --height 40% --reverse --border)

    if [[ -n "$selected" ]]; then
        # Convert to absolute path if flag is set
        [[ "$1" == "--absolute" ]] && selected=$(realpath "$selected")

        # Insert the selected path at cursor position
        READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
        READLINE_POINT=$((READLINE_POINT + ${#selected}))
    fi
}
