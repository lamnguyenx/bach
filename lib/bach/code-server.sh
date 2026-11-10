#!/bin/bash
# ==============================================================
#                         CODE-SERVER
# ==============================================================
# code-server CLI shim: adds `code --wait` semantics to code-server.
#
# WHAT IT DOES
#   code_server_wait <file...> opens files in the running code-server
#   instance and blocks until ALL of them are closed in the workbench,
#   then exits 0 -- exactly like `code --wait` / `$EDITOR` for git.
#
# HOW IT WORKS
#   code-server's workbench already implements the wait-marker contract
#   used by upstream VS Code: when the open command carries a
#   `waitMarkerFilePath`, the workbench deletes that file once every
#   requested file's editor is closed. So this shim only has to:
#     1. create a marker file in /tmp
#     2. POST {"type":"open","fileURIs":[...],"waitMarkerFilePath":...}
#        to the running instance's CLI socket (an HTTP server on a
#        unix socket)
#     3. poll until the marker file disappears, then exit
#
# FINDING THE INSTANCE (VSCODE_IPC_HOOK_CLI + discovery)
#   code-server sets VSCODE_IPC_HOOK_CLI per terminal. But:
#     - tmux (and other wrappers) don't propagate the variable
#     - the socket FILE can linger after its CLI server dies (closed
#       terminal, instance reload), so its existence proves nothing
#   Resolution order: use $VSCODE_IPC_HOOK_CLI if a read-only status
#   probe answers; otherwise scan $XDG_RUNTIME_DIR and /tmp for
#   vscode-ipc-*.sock (newest first) and probe each until one answers.
#   Only the per-terminal CLI servers respond to the HTTP status probe,
#   so non-HTTP IPC sockets (extension host, pty host) are skipped.
#
# NON-BASH CALLERS (opencode, git, programs spawning $EDITOR)
#   A bash-exported function cannot be execve()'d by other processes --
#   opencode and friends spawn $EDITOR as a process, so they need a
#   real executable on PATH. Keep the launcher script in sync:
#     /home/lamnt45/.local/bin/code_server_wait   (sources this module)
#   If bach moves, update the source line in that launcher.
#
# SETUP
#   export EDITOR="code_server_wait"          # in ~/.bashrc (bach already has this)
#   reload_bach                               # after editing this module
#   git config --global core.editor "code_server_wait"
#
# USAGE
#   code_server_wait ./tsconfig.json          # blocks until the tab closes
#   code_server_wait --help                   # show usage
#   code_server_wait --version                # passthrough to real code-server
#   (Ctrl-X Ctrl-E in bash and Ctrl-X E in opencode use $EDITOR -> this)
#   (git commit, fc -e, ... all work the same way)
#
# CAVEATS
#   - requires a RUNNING code-server instance (a live CLI socket)
#   - requires a connected browser tab; with none it blocks forever
#   - completes only when the tab is CLOSED (saving alone is not enough)
#   - `--wait` is accepted for compatibility but implied by the name
#
# SEE ALSO
#   Upstream reference implementation of the CLI side:
#     lib/vscode/src/vs/server/node/server.cli.ts (createWaitMarkerFileSync,
#     waitForFileDeleted) and the workbench side:
#     lib/vscode/src/vs/workbench/services/host/browser/browserHostService.ts
#     (deletes the marker via whenEditorClosed).

# -----------------------------------
#            --wait shim
# -----------------------------------
# Called with code-server options (anything starting with `-`) it is
# passed through to the real code-server binary (honoring
# $CODE_SERVER_BIN if set, else the first `code-server` on PATH).
function code_server_wait() {
    local usage='
Usage: code_server_wait <file...>
       code_server_wait [code-server options...]

  <file...>              Open files in the running code-server instance and
                         block until all of them are closed (like `code --wait`).
                         Works from any terminal of a running instance, including
                         tmux (falls back to scanning for live CLI sockets).

  any options            Passed through to the real code-server binary.
                         (`--wait` is accepted but implied by the name.)
'

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$usage"
        return 0
    fi

    # -------------------------------------------
    # parse: --wait flag + positionals + options
    # -------------------------------------------
    local wait_mode=0
    local files=()
    local opts=()
    local ended=0
    local arg=""
    for arg in "$@"; do
        if [[ "$ended" -eq 1 ]]; then
            files+=("$arg")
            continue
        fi
        if [[ "$arg" == "--" ]]; then
            ended=1
            continue
        fi
        if [[ "$arg" == "--wait" ]]; then
            wait_mode=1
            continue
        fi
        if [[ "$arg" == -* ]]; then
            opts+=("$arg")
        else
            files+=("$arg")
        fi
    done

    # Wait mode unless the call looks like the real CLI (has options,
    # or is empty). `--wait` is optional -- the name says it all.
    if [[ "$wait_mode" -eq 0 ]]; then
        if [[ "${#opts[@]}" -gt 0 || "${#files[@]}" -eq 0 ]]; then
            local real_bin="${CODE_SERVER_BIN:-}"
            if [[ -z "$real_bin" ]]; then
                real_bin="$(command -v code-server)"
            fi
            if [[ -z "$real_bin" ]]; then
                echo "ERROR: code-server binary not found on PATH (or set CODE_SERVER_BIN)" >&2
                return 127
            fi
            exec "$real_bin" "$@"
        fi
    fi
    wait_mode=1

    # -------------------------------------------
    # validate wait-mode invocation
    # -------------------------------------------
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "ERROR: at least one file is required" >&2
        echo "Usage: code_server_wait <file...>" >&2
        return 1
    fi
    if [[ "${#opts[@]}" -gt 0 ]]; then
        echo "ERROR: unsupported option(s): ${opts[*]}" >&2
        echo "Usage: code_server_wait <file...>" >&2
        return 1
    fi

    # -------------------------------------------
    # resolve a LIVE CLI socket of the running instance
    # -------------------------------------------
    # VSCODE_IPC_HOOK_CLI is set by code-server in its own terminals, but:
    #   - tmux (and other wrappers) don't propagate it
    #   - its socket file can linger after the CLI server dies (terminal
    #     closed, instance reloaded), so existence alone proves nothing
    # A socket is only considered live if it answers a read-only status
    # probe; otherwise we scan the runtime dirs for another one.
    local probe_status='{"type":"status"}'
    local ipc="${VSCODE_IPC_HOOK_CLI:-}"
    local probe_ok=0
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local tmp_dir="${TMPDIR:-/tmp}"

    _ipc_probe() {
        curl --silent --max-time 1 --unix-socket "$1" \
            -X POST -H 'Content-Type: application/json' \
            -d "$probe_status" http://localhost/ >/dev/null 2>&1
    }

    if [[ -n "$ipc" && -e "$ipc" ]] && _ipc_probe "$ipc"; then
        probe_ok=1
    else
        local dir=""
        local sock=""
        for dir in "$runtime_dir" "$tmp_dir"; do
            [[ -d "$dir" ]] || continue
            # Newest first: most likely to belong to the current session.
            while IFS= read -r sock; do
                [[ -n "$sock" && -e "$sock" ]] || continue
                if _ipc_probe "$sock"; then
                    ipc="$sock"
                    probe_ok=1
                    break 2
                fi
            done < <(ls -t "$dir"/vscode-ipc-*.sock 2>/dev/null)
        done
    fi
    if [[ "$probe_ok" -eq 0 ]]; then
        echo "ERROR: could not find a live code-server instance." >&2
        echo "Probed VSCODE_IPC_HOOK_CLI and $runtime_dir / $tmp_dir for CLI sockets." >&2
        return 1
    fi

    # -------------------------------------------
    # wait marker + open command
    # -------------------------------------------
    # NOTE: global (no `local`) so the INT/TERM trap can still see it.
    # Cleanup is done explicitly on every exit path because a function-set
    # EXIT trap only fires at shell exit, not when the function returns.
    _code_server_wait_marker="$(mktemp /tmp/code-server-wait.XXXXXX 2>/dev/null)"
    if [[ -z "$_code_server_wait_marker" || ! -e "$_code_server_wait_marker" ]]; then
        echo "ERROR: could not create wait marker file" >&2
        return 1
    fi
    trap 'rm -f "$_code_server_wait_marker"' EXIT INT TERM

    local uris=()
    local f=""
    local p=""
    local enc=""
    local c=""
    local i=0
    for f in "${files[@]}"; do
        p="$(realpath -m "$f")"
        enc=""
        for ((i = 0; i < ${#p}; i++)); do
            c="${p:i:1}"
            case "$c" in
                [a-zA-Z0-9/._~-]) enc+="$c" ;;
                *) printf -v enc '%s%%%02X' "$enc" "'$c" ;;
            esac
        done
        uris+=("file://$enc")
    done

    local payload='{"type":"open","fileURIs":['
    local sep=""
    for u in "${uris[@]}"; do
        payload+="${sep}\"${u}\""
        sep=","
    done
    payload+="],\"waitMarkerFilePath\":\"${_code_server_wait_marker}\"}"

    if ! curl --silent --show-error --fail \
        --unix-socket "$ipc" \
        -X POST -H 'Content-Type: application/json' \
        -d "$payload" http://localhost/ >/dev/null 2>&1; then
        echo "ERROR: could not reach running code-server instance" >&2
        echo "  socket: $ipc" >&2
        rm -f "$_code_server_wait_marker"
        return 1
    fi

    echo "Opened in code-server; close the tab(s) to continue." >&2

    # -------------------------------------------
    # block until the workbench closes the files
    # -------------------------------------------
    while [[ -e "$_code_server_wait_marker" ]]; do
        sleep 1
    done

    rm -f "$_code_server_wait_marker"
    return 0
}

# Export public API functions
export -f code_server_wait
