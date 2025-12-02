#!/bin/bash
# --------------------------------------------------------------
#                     iteractive terminal
# --------------------------------------------------------------

export COLORTERM=truecolor
function is_docker_container() {
    # Check if PID 1 is NOT init/systemd
    local pid1_cmd=$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')

    if [[ "$pid1_cmd" != "init" && "$pid1_cmd" != "systemd"  && "$pid1_cmd" != "/sbin/launchd" ]]; then
        return 0  # true - likely in container
    else
        return 1  # false - likely on host
    fi
}

if is_docker_container;
then TERMINAL_ID="docker"
else TERMINAL_ID="native"
fi

if [[ "$TERMINAL_ID" == "native" ]]; then
    if [[ "$USER" == "root" ]]; then
        PS_COLOR_1="$ANSIFmt__red"
        PS_COLOR_2="$ANSIFmt__reset"

    else
        PS_COLOR_1="$ANSIFmt__bright_green"
        PS_COLOR_2="$ANSIFmt__bright_yellow"
    fi

elif [[ "$TERMINAL_ID" == "docker" ]]; then
    PS_COLOR_1="$ANSIFmt__cyan"
    PS_COLOR_2="$ANSIFmt__bright_blue"
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
        f_checkout_basename="$(basename "$(readlink  -f "$PWD/voice2text._checkout_.yml")")"
        f_checkout_basename="${f_checkout_basename#voice2text._checkout_.}"
        f_checkout_basename="${f_checkout_basename%.yml}"
        echo -n " (server:${f_checkout_basename})"
    fi
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

PS1="\
(\$(basename "${0#-}")) (\$(date +%T.%3Ns))\[$ANSIFmt__violet\]\$(get_proxy_indicator)\[$ANSIFmt__reset\] \
${debian_chroot:+($debian_chroot)}\
\[$PS_COLOR_1\[${debian_chroot:+($debian_chroot)}\
\u @ ${HOST_IP}$ANSIFmt__reset ($TERMINAL_ID) \[$PS_COLOR_2\[\
\$PWD$ANSIFmt__reset\$(get_git_branch_tag)\$(get_subbranch_tag)\n>> "


# alias rc="rclone sync --progress --stats=1s --stats-log-level=INFO --verbose --update --checksum"
alias  rc='rclone sync --progress --stats 10s --links --copy-links=false --transfers=4 --checkers=8 --verbose --metadata --fast-list'