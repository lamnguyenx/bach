#!/bin/bash
# ==============================================================
#                    CHROME DEVTOOLS PROTOCOL
# ==============================================================
# Helpers to launch browsers with Chrome DevTools Protocol enabled.

# Note: --disable-gpu keeps the browser alive on hosts where the GPU process
# crashes (e.g. the NUC), but on macOS it also disables the only H.264 decoder
# (VideoToolbox), so every H.264 video fails to play. It therefore defaults to
# on for Linux and off for macOS; override with CDP_DISABLE_GPU=0|1.
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

    # Resolve the browser executable for this platform.
    local os bin
    os="$(uname -s)"
    case "$os" in
    Linux)
        bin="$(command -v "$linux_bin" 2>/dev/null || true)"
        if [[ -z "$bin" ]]; then
            echo "cdp: '$linux_bin' not found on PATH" >&2
            return 127
        fi
        ;;
    Darwin)
        bin="$mac_bin"
        if [[ ! -x "$bin" ]]; then
            bin="$HOME/Applications/${mac_app}.app/Contents/MacOS/${mac_app}"
        fi
        if [[ ! -x "$bin" ]]; then
            echo "cdp: ${mac_app}.app not found (looked in /Applications and ~/Applications)" >&2
            return 127
        fi
        ;;
    *)
        echo "Unsupported OS: $os" >&2
        return 1
        ;;
    esac

    # GPU mode: Linux defaults to --disable-gpu (GPU process crashes on the
    # NUC); macOS defaults to GPU on so VideoToolbox can decode H.264.
    local disable_gpu="${CDP_DISABLE_GPU:-auto}"
    case "$disable_gpu" in
    1 | true | yes | on) disable_gpu=1 ;;
    0 | false | no | off) disable_gpu=0 ;;
    auto | "")
        if [[ "$os" == Linux ]]; then
            disable_gpu=1
        else
            disable_gpu=0
        fi
        ;;
    *)
        echo "cdp: CDP_DISABLE_GPU must be 0/1 (got '$disable_gpu')" >&2
        return 2
        ;;
    esac

    local profile_dir="$HOME/.local/share/${profile_root}/cdp-${port}"
    mkdir -p "$profile_dir"

    local log_file="$HOME/${profile_root}-${port}.log"
    local -a args=(
        --remote-debugging-port="$port"
        --user-data-dir="$profile_dir"
        --ignore-certificate-errors
        --remote-allow-origins=*
        --enable-logging
        --log-level=0
        --log-file="$log_file"
    )
    if [[ "$disable_gpu" == 1 ]]; then
        args+=(--disable-gpu)
    fi

    if $fg; then
        "$bin" "${args[@]}"
        return
    fi

    # Background: detach so the browser outlives the launching shell.
    # Linux gets `setsid` (new session), matching vscode_cdp; macOS has no setsid.
    if [[ "$os" == Linux ]] && command -v setsid >/dev/null 2>&1; then
        setsid nohup "$bin" "${args[@]}" </dev/null >"$log_file" 2>&1 &
    else
        nohup "$bin" "${args[@]}" >"$log_file" 2>&1 &
    fi
    disown

    echo "Log: $log_file"
    echo "This is just log tailing -f, you can hit Ctrl+C to stop."
    tail -f "$log_file"
}

function vivaldi_cdp() {
    _cdp_launch "vivaldi" "Vivaldi" "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi" \
        "vivaldi-cdp-profiles" "$@"
}

function vivaldi_snapshot_cdp() {
    _cdp_launch "vivaldi-snapshot" "Vivaldi Snapshot" \
        "/Applications/Vivaldi Snapshot.app/Contents/MacOS/Vivaldi Snapshot" \
        "vivaldi-snapshot-cdp-profiles" "$@"
}

function chrome_cdp() {
    _cdp_launch "google-chrome" "Google Chrome" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "chrome-cdp-profiles" "$@"
}

export -f _cdp_launch vivaldi_cdp vivaldi_snapshot_cdp chrome_cdp
