#!/bin/bash
# ==============================================================
#                    CHROME DEVTOOLS PROTOCOL
# ==============================================================
# Helpers to launch browsers with Chrome DevTools Protocol enabled.

# Note: --disable-gpu is intentional. On some hosts (e.g. the NUC) a crashing
# GPU process takes the whole browser down a couple of seconds after launch;
# CDP automation does not need GPU acceleration.
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
                    --ignore-certificate-errors \
                    --remote-allow-origins=* \
                    --disable-gpu
            else
                local log_file="${profile_dir}.log"
                nohup "$linux_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    --remote-allow-origins=* \
                    --disable-gpu >"$log_file" 2>&1 &
                disown
                echo "logging to $log_file"
            fi
            ;;
        Darwin)
            if $fg; then
                "$mac_bin" \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    --remote-allow-origins=* \
                    --disable-gpu
            else
                open -a "$mac_app" --args \
                    --remote-debugging-port="$port" \
                    --user-data-dir="$profile_dir" \
                    --ignore-certificate-errors \
                    --remote-allow-origins=* \
                    --disable-gpu
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