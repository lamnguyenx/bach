#!/bin/bash
# ==============================================================
#                     ITERACTIVE TERMINAL
# ==============================================================

export COLORTERM=truecolor
function is_docker_container() {
    # Check if PID 1 is NOT init/systemd
    local pid1_cmd=$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')

    if [[ "$pid1_cmd" != "init" && "$pid1_cmd" != "systemd" && "$pid1_cmd" != "/sbin/launchd" ]]; then
        return 0 # true - likely in container
    else
        return 1 # false - likely on host
    fi
}

if is_docker_container; then
    TERMINAL_ID="docker"
else
    TERMINAL_ID="native"
fi

if [[ "$TERMINAL_ID" == "native" ]]; then
    if [[ "$USER" == "root" ]]; then
        PS_COLOR_1=$'\033[31m'
        PS_COLOR_2=$'\033[00m'

    else
        PS_COLOR_1=$'\033[00;92m'
        PS_COLOR_2=$'\033[00;93m'
    fi

elif [[ "$TERMINAL_ID" == "docker" ]]; then
    PS_COLOR_1=$'\033[00;36m'
    PS_COLOR_2=$'\033[00;94m'
fi

function get_git_branch_tag() {
    [[ "$PWD" == /mnt/* ]] && return
    local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ ! -z "$branch" ]]; then
        if git log --oneline -1 >/dev/null 2>&1; then
            local info=""
            local hash=" ($(git rev-parse --short HEAD))"
            if git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
                local aheadd="$(git rev-list --count @{u}..HEAD 2>/dev/null)"
                local behind="$(git rev-list --count HEAD..@{u} 2>/dev/null)"
                [[ "$aheadd" -gt 0 ]] && info+=" ↑$aheadd "
                [[ "$behind" -gt 0 ]] && info+=" ↓$behind "
            fi
            echo -e " ⊢ $branch$info$hash"
        else
            echo -e " ⊢ $branch"
        fi
    fi
}

function get_subbranch_tag() {
    if [[ -s "$PWD/configs" ]]; then
        subbranch_tag="$(readlink -f "$PWD/configs")"
        subbranch_tag="${subbranch_tag#$PWD/}"
        echo -n " ($subbranch_tag)"
    fi

    if [[ -s "$PWD/voice2text._checkout_.yml" ]]; then
        f_checkout_basename="$(basename "$(readlink -f "$PWD/voice2text._checkout_.yml")")"
        f_checkout_basename="${f_checkout_basename#voice2text._checkout_.}"
        f_checkout_basename="${f_checkout_basename%.yml}"
        echo -n " (server:${f_checkout_basename})"
    fi
}

function get_jobs_indicator() {
    local jobs_output=$(jobs)
    local running_jobs=$(echo "$jobs_output" | grep -c 'Running' | tr -d ' ')
    local stopped_jobs=$(echo "$jobs_output" | grep -c 'Stopped' | tr -d ' ')
    local output=""

    if [[ "$running_jobs" -gt 0 ]]; then
        output=" ⚙${running_jobs}"
    fi
    if [[ "$stopped_jobs" -gt 0 ]]; then
        output="${output} ⏸${stopped_jobs}"
    fi

    echo "$output"
}

function get_proxy_indicator() {
    local proxies=""
    if [[ -n "${http_proxy:-}" || -n "${HTTP_PROXY:-}" ]]; then
        proxies="http"
    fi
    if [[ -n "${socks_proxy:-}" || -n "${SOCKS_PROXY:-}" ]]; then
        if [[ -n "$proxies" ]]; then
            proxies="${proxies},socks"
        else
            proxies="socks"
        fi
    fi
    if [[ -n "$proxies" ]]; then
        local name_part="${PROXY_NAME:+ ${PROXY_NAME}}"
        echo " [set $proxies${name_part} proxy]"
    fi
}

export HOST_ID="$USER${HOST_IP:+ @ }${HOST_IP}${HOST_MODEL:+ / }${HOST_MODEL}"
PS1="\
\n\
\[\e[2m\](\$(basename "${0#-}")) (\$(date +%T))\[\e[0m\]\[\e[35m\]\$(get_proxy_indicator)\[\e[0m\] \
${debian_chroot:+($debian_chroot)}\
\[\e[1m\]\[$PS_COLOR_1\]${debian_chroot:+($debian_chroot)}\
${HOST_ID}\[\e[0m\] \
\[\e[3m\]($TERMINAL_ID)\[\e[0m\] \[\e[4m\]\[$PS_COLOR_2\]\
\$PWD\[\e[0m\]\$(get_git_branch_tag)\$(get_subbranch_tag)\$(get_jobs_indicator)\n\[\e[1m\]>> \[\e[0m\]"
