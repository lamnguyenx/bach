#!/bin/bash
# ==============================================================
#                           FZF TOOLS
# ==============================================================

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
