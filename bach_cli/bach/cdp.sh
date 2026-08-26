#!/bin/bash
# ==============================================================
#                    CHROME DEVTOOLS PROTOCOL
# ==============================================================
# Helpers to launch browsers with Chrome DevTools Protocol enabled.

_cdp_launch() {
    local linux_bin="$1"
    local mac_app="$2"
    local mac_bin="$3"
    local profile_root="$4"
    local fg=false
    local port

    if [[ $5 == --fg ]]; then
        fg=true
        port="${6:?Usage: <func> [--fg] <CDP_PORT>}"
    else
        port="${5:?Usage: <func> [--fg] <CDP_PORT>}"
    fi

    local profile_dir="$HOME/.local/share/${profile_root}/cdp-${port}"
    mkdir -p "$profile_dir"

    case "$(uname -s)" in
        Linux)
            if $fg; then
                "$linux_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors
            else
                nohup "$linux_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors >/dev/null 2>&1 &
                disown
            fi
            ;;
        Darwin)
            if $fg; then
                "$mac_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors
            else
                open -a "$mac_app" --args \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors
            fi
            ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
    esac
}

function vivaldi_cdp() {
    _cdp_launch "vivaldi" "Vivaldi" "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi" \
        "vivaldi-cdp-profiles" "$@"
}

function chrome_cdp() {
    _cdp_launch "google-chrome" "Google Chrome" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "chrome-cdp-profiles" "$@"
}

export -f vivaldi_cdp chrome_cdp