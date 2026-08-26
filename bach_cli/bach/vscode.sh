#!/bin/bash
# ==============================================================
#                           VSCODE
# ==============================================================
# Launch/kill the desktop VS Code with Chrome DevTools Protocol enabled
# (Extension Development Host mode). Cross-platform (macOS + Linux).
# Run `vscode_cdp --help` / `vscode_cdp_kill --help` for details.

# -----------------------------------
#            launch
# -----------------------------------
function vscode_cdp() {
    local usage='
Usage: vscode_cdp [options] [port]

  Launch the desktop VS Code with Chrome DevTools Protocol on <port>
  (default 9335). Defaults to Extension Development Host mode and the
  background. All user extensions are disabled by default; pass
  --with-extensions to load your real ones.

Options:
  --fg                  Run in the foreground (block until exit).
  --ext <path>          Extension Development Path (default: "$PWD").
  --no-ext              Plain launch; do NOT pass --extensionDevelopmentPath.
  --profile <dir>       --user-data-dir (default: ~/.local/share/vscode-cdp/cdp-<port>).
  --file <path>         File or folder to open in the new window.
  --with-extensions     Load real user extensions. Default: --disable-extensions.
  --port <port>         CDP port (default 9335). A bare number is also accepted.
  -h, --help            Show this help.

On Linux:
  - $DISPLAY must be set (no auto-detection, no X-socket probing).
  - `code` on PATH must be the native desktop binary, not the Remote-SSH
    / vscode-server CLI wrapper (it rejects --extensionDevelopmentPath,
    --user-data-dir and --remote-debugging-port).

Notes:
  - Launched detached (Darwin: nohup; Linux: `systemd-run --user` when
    available, else setsid+nohup) so it survives the launching shell.
  - `--user-data-dir` with a separate profile forces a separate VS Code
    instance; without it the window would join an already-running one
    and ignore the port.
  - Not idempotent: it kills any prior host on the same port first.

Examples:
  vscode_cdp                                  # ext-dev at $PWD, port 9335, bg
  vscode_cdp --fg                             # foreground (block)
  vscode_cdp 9337                             # custom port (positional)
  vscode_cdp --ext "$PWD" --file main.ts      # extension dev at a path
  vscode_cdp --no-ext                         # plain launch
  vscode_cdp --with-extensions --profile ~/p
'
    local fg=0
    local no_ext=0
    local with_ext=0
    local ext_path="$PWD"
    local profile=""
    local file=""
    local port=9335

    while [ $# -gt 0 ]; do
        case "$1" in
        --fg)
            fg=1
            shift
            ;;
        --ext)
            ext_path="${2:?--ext needs a path}"
            shift 2
            ;;
        --no-ext)
            no_ext=1
            shift
            ;;
        --profile)
            profile="${2:?--profile needs a path}"
            shift 2
            ;;
        --file)
            file="${2:?--file needs a path}"
            shift 2
            ;;
        --with-extensions)
            with_ext=1
            shift
            ;;
        --port)
            port="${2:?--port needs a value}"
            shift 2
            ;;
        -h | --help)
            printf '%s\n' "$usage"
            return 0
            ;;
        --*)
            printf 'unknown option: %s\n' "$1" >&2
            printf '%s\n' "$usage" >&2
            return 1
            ;;
        [0-9]*)
            port="$1"
            shift
            ;;
        *)
            printf 'unknown argument: %s\n' "$1" >&2
            printf '%s\n' "$usage" >&2
            return 1
            ;;
        esac
    done

    # Resolve paths to absolute (VS Code flags require absolute paths).
    case "$ext_path" in
    /*) ;;
    *) ext_path="$PWD/$ext_path" ;;
    esac
    [ -n "$file" ] && case "$file" in
    /*) ;;
    *) file="$PWD/$file" ;;
    esac
    [ -n "$profile" ] || profile="$HOME/.local/share/vscode-cdp/cdp-$port"
    mkdir -p "$profile" || {
        log_error "cannot create profile dir: $profile"
        return 1
    }

    local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/bach"
    mkdir -p "$log_dir" 2>/dev/null || log_dir="${TMPDIR:-/tmp}"
    local log_file="$log_dir/vscode-cdp-$port.log"

    # The `code` on PATH must be the native desktop binary (first on PATH).
    # On Linux the user must also supply $DISPLAY (no auto-detection).
    local code_bin="code"
    command -v "$code_bin" >/dev/null 2>&1 || {
        log_error "VS Code 'code' not found on PATH"
        return 127
    }
    local os
    os="$(uname -s)"
    case "$os" in
    Darwin | Linux) ;;
    *)
        log_error "unsupported OS: $os"
        return 1
        ;;
    esac
    if [ "$os" = "Linux" ] && [ -z "${DISPLAY:-}" ]; then
        log_error "DISPLAY is not set; set it (or run under Xvfb)"
        return 1
    fi

    # Kill any prior host on the port so the new one can bind.
    log_info "stopping any prior VS Code CDP host on port $port..."
    vscode_cdp_kill "$port" >/dev/null 2>&1 || true
    sleep 1

    # Build the launch arguments.
    local -a args=()
    [ "$no_ext" = 1 ] || args+=(--extensionDevelopmentPath="$ext_path")
    args+=(--user-data-dir="$profile")
    args+=(--remote-debugging-port="$port")
    args+=(--new-window)
    [ "$with_ext" = 0 ] && args+=(--disable-extensions)
    [ -n "$file" ] && args+=("$file")

    log_info "launch: $code_bin ${args[*]}"

    # Foreground: run synchronously and return its status.
    if [ "$fg" = 1 ]; then
        "$code_bin" "${args[@]}"
        return $?
    fi

    # --- background launch ------------------------------------------------
    case "$os" in
    Darwin)
        nohup "$code_bin" "${args[@]}" >"$log_file" 2>&1 &
        disown
        ;;
    Linux)
        if command -v systemd-run >/dev/null 2>&1 &&
            [ -n "${XDG_RUNTIME_DIR:-}" ] &&
            systemctl --user is-system-running >/dev/null 2>&1; then
            systemctl --user stop "bach-vscode-$port.service" 2>/dev/null
            systemctl --user reset-failed "bach-vscode-$port.service" 2>/dev/null
            systemd-run --user --unit="bach-vscode-$port" --collect \
                --setenv=DISPLAY="$DISPLAY" \
                --property=StandardOutput=append:"$log_file" \
                --property=StandardError=append:"$log_file" \
                "$code_bin" "${args[@]}" >/dev/null 2>&1
        else
            setsid nohup "$code_bin" "${args[@]}" >"$log_file" 2>&1 </dev/null &
            disown
        fi
        ;;
    esac

    # Wait for the CDP port to answer.
    local up=0 i
    for i in $(seq 1 45); do
        if curl -s -m 1 "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
            up=1
            break
        fi
        sleep 1
    done
    if [ "$up" != 1 ]; then
        log_error "VS Code CDP host did not come up on port $port (see $log_file)"
        return 1
    fi
    sleep 2

    log_ok "VS Code CDP host up ($code_bin, port $port):"
    curl -s -m 2 "http://127.0.0.1:$port/json/version" | head -c 60
    printf '\n'
}

# -----------------------------------
#               kill
# -----------------------------------
# Linux: free orphaned fd holders left by Chromium's dconf helper -- see
# the vscode_cdp_kill --help for the full rationale.
function _vscode_free_port_holders() {
    local port="$1"
    [ "$(uname -s)" = "Linux" ] || return 0
    command -v ss >/dev/null 2>&1 || return 0
    sleep 1
    local holder
    holder="$(ss -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -1)"
    if [ -n "$holder" ]; then
        log_info "freeing fd holder on port $port (pid $holder)"
        kill "$holder" 2>/dev/null || true
        sleep 1
    fi
}

function vscode_cdp_kill() {
    local usage='
Usage: vscode_cdp_kill [port]

  Gracefully shut down the VS Code CDP host on <port> (default 9335).

How it works:
  - SIGTERM the MAIN process only (VS Code then shuts its helper
    processes itself), so macOS does NOT pop the "Closed ... Reopen?"
    dialog that a plain `pkill -f remote-debugging-port=` triggers.
  - Helpers are excluded: macOS helpers are named "Code Helper
    (Renderer)..."; Linux helpers carry --type=.
  - Waits for the CDP port to free, then SIGKILLs as a last resort
    after 15s.
  - On Linux, frees the port from orphaned fd holders: the Chromium
    `dconf watch /system/proxy/` helper (GLib proxy watching) inherits
    the CDP listening socket fd and survives the main process, leaving
    the port in a zombie LISTEN state (curl hangs, next launch fails to
    bind). Detected via `ss` and killed.

Examples:
  vscode_cdp_kill         # stop the host on 9335
  vscode_cdp_kill 9337    # stop the host on 9337
'
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        printf '%s\n' "$usage"
        return 0
    fi
    local port="${1:-9335}"

    local main_pids
    main_pids="$(pgrep -f "remote-debugging-port=$port" | while read -r pid; do
        if ! ps -p "$pid" -o command= 2>/dev/null | grep -qE 'Code Helper|--type='; then
            printf '%s\n' "$pid"
        fi
    done)"

    if [ -z "$main_pids" ]; then
        log_info "no VS Code CDP host on port $port"
        _vscode_free_port_holders "$port"
        return 0
    fi

    log_info "SIGTERM to VS Code CDP main process(es): $(printf '%s ' $main_pids)"
    # shellcheck disable=SC2086
    kill -TERM $main_pids

    local i
    for i in $(seq 1 15); do
        if ! curl -s -m 1 "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
            _vscode_free_port_holders "$port"
            log_ok "VS Code CDP host on port $port shut down"
            return 0
        fi
        sleep 1
    done

    log_error "still up after 15s; SIGKILL"
    # shellcheck disable=SC2086
    kill -KILL $main_pids 2>/dev/null || true
    sleep 1
    _vscode_free_port_holders "$port"
    return 1
}

# Export public API functions
export -f vscode_cdp vscode_cdp_kill

# Export internal helpers (needed by public functions in subshells)
export -f _vscode_free_port_holders
