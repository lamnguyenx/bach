#!/bin/bash
# ==============================================================
#                         ALIASES
# ==============================================================
# Common shell aliases, functions, and misc for productivity

# Enable color support for ls and add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias oc="opencode"
alias occ="opencode --continue"

alias a="amp"
alias ac="amp threads continue"

alias lg="lazygit"
alias gu="gituit"

alias tb="SHELL=/bin/bash tmux"

# Check if running in VS Code terminal and set editor accordingly
if [ "$TERM_PROGRAM" = "vscode" ]; then
    export EDITOR="code --wait"
fi

# -----------------------------------
#            just one
# -----------------------------------
function just_one_tensorboard() {

    local logdir="$1"
    local port=$2

    pgrep -U $USER -f "tensorboard.*$port" | xargs kill
    setsid nohup \
        tensorboard \
        --host 0.0.0.0 \
        --logdir "$logdir" \
        --port $port \
        >>~/$port.log 2>&1 &
    sleep 1 && log_ok "Ran just_one_tensorboard in bg, you can Ctrl + C now" &
    tail -f ~/$port.log
}

function just_one_grip() {
    local file="$1"

    pgrep -U $USER -f "$(which grip)" | xargs kill
    setsid nohup grip "$file" &>~/grip.log &
    sleep 1 && log_ok "Ran just_one_grip in bg, you can Ctrl + C now" &
    tail -f ~/grip.log
}

# -----------------------------------
#            projects
# -----------------------------------

if [[ -f .project.sh ]]; then
    source .project.sh
fi

if [[ -f .project-untracked.sh ]]; then
    source .project-untracked.sh
fi

# -----------------------------------
#            misc
# -----------------------------------
alias ap="set_pp_proxy && amp"
alias cl="set_pp_proxy && claude --verbose"
export EDITOR="vim"

if command -v fzf > /dev/null 2>&1; then
    [ -n "$BASH_VERSION" ] && source <(fzf --bash)
    [ -n "$ZSH_VERSION" ] && source <(fzf --zsh)
fi

export EDITOR="hx"

alias ggx="cd /data/cheese/git/lamnguyenx"
alias gg5="cd /data/cheese/git/lamnt45"
alias tmux='tmux attach || tmux new'

if command -v afplay &>/dev/null; then
    alias noti="(afplay /System/Library/Sounds/Submarine.aiff &>/dev/null &)"
elif command -v paplay &>/dev/null; then
    alias noti="(paplay /usr/share/sounds/freedesktop/stereo/complete.oga &>/dev/null &)"
elif command -v aplay &>/dev/null; then
    alias noti="(aplay /usr/share/sounds/alsa/Front_Center.wav &>/dev/null &)"
fi
