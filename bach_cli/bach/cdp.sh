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

    local log_file="$HOME/vivaldi_cdp_${port}.log"
    local chromium_log_flags=(
        --enable-logging
        --log-level=0
        --log-file="$log_file"
    )

    case "$(uname -s)" in
        Linux)
            if $fg; then
                "$linux_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    "${chromium_log_flags[@]}"
            else
                nohup "$linux_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    "${chromium_log_flags[@]}" >"$log_file" 2>&1 &
                disown
            fi
            ;;
        Darwin)
            if $fg; then
                "$mac_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    "${chromium_log_flags[@]}"
            else
                nohup "$mac_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    "${chromium_log_flags[@]}" >"$log_file" 2>&1 &
                disown
            fi
            ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
    esac

    if ! $fg; then
        echo "Log: $log_file"
        echo "This is just log tailing -f, you can hit Ctrl+C to stop."
        tail -f "$log_file"
    fi
}

function vivaldi_cdp() {
    _cdp_launch "vivaldi" "Vivaldi" "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi" \
        "vivaldi-cdp-profiles" "$@"
}

function chrome_cdp() {
    _cdp_launch "google-chrome" "Google Chrome" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "chrome-cdp-profiles" "$@"
}

export -f _cdp_launch vivaldi_cdp chrome_cdp