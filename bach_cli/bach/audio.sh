#!/bin/bash
# ==============================================================
#                           AUDIO
# ==============================================================
# Forward the local microphone to any SSH-able host as a
# PulseAudio source, using module-pipe-source + a FIFO tunnel.

# -----------------------------------
#          mic forwarding
# -----------------------------------

AUDIO_STATE_DIR="$HOME/.bach"
AUDIO_STATE_FILE="$AUDIO_STATE_DIR/mic_forward.state"

function mic_forward_help() {
    cat <<'EOF'
Usage: mic_forward <subcommand> [args]

Subcommands:
  start <host> [options]   Forward this machine's mic to <host>
  stop <host>              Stop forwarding to <host>
  status                   List active forwards

'start' options:
  --device <d>   Local input device (ffmpeg avfoundation index/name, default: :default)
  --name <n>     Remote PulseAudio source name (default: macmic)
  --fifo <f>     Remote FIFO path (default: /tmp/mic.pcm)
  --rate <r>     Sample rate (default: 48000)
  --channels <c> Number of channels (default: 1)
  --no-compress  Disable SSH compression

Forwards this machine's microphone to <host> as a PulseAudio source.
Apps on <host> can record from it, e.g.:
  parecord -d <name> test.wav
  pactl set-default-source <name>

Examples:
  mic_forward start pp
  mic_forward start pp --device ":1" --name mymic
  mic_forward stop pp
  mic_forward status
EOF
}

function mic_forward_start() {
    local host=""
    local device=":default"
    local name="macmic"
    local fifo="/tmp/mic.pcm"
    local rate=48000
    local channels=1
    local compress="-C"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        mic_forward_help
        return 0
    fi

    host="$1"
    shift
    if [[ -z "$host" ]]; then
        echo "ERROR: host is required" >&2
        echo "Usage: mic_forward start <host> [options]" >&2
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --device) device="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --fifo) fifo="$2"; shift 2 ;;
        --rate) rate="$2"; shift 2 ;;
        --channels) channels="$2"; shift 2 ;;
        --no-compress) compress=""; shift ;;
        *)
            echo "ERROR: Unknown option $1" >&2
            return 1
            ;;
        esac
    done

    if [[ ! "$rate" =~ ^[0-9]+$ || ! "$channels" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --rate and --channels must be numbers" >&2
        return 1
    fi

    # Reject double-forwarding to the same host
    local state_pat="${host}"$'\t'
    if [[ -f "$AUDIO_STATE_FILE" ]] && grep -qF "$state_pat" "$AUDIO_STATE_FILE"; then
        echo "ERROR: mic already forwarded to $host (use 'mic_forward stop $host' first)" >&2
        return 1
    fi

    # Local capture toolchain
    local -a capture_cmd=()
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v ffmpeg >/dev/null 2>&1; then
            capture_cmd=(ffmpeg -hide_banner -loglevel error -f avfoundation -i "$device" -ar "$rate" -ac "$channels" -f s16le -)
        elif command -v sox >/dev/null 2>&1; then
            capture_cmd=(sox -d -t raw -b 16 -c "$channels" -r "$rate" -e signed -)
        else
            echo "ERROR: need ffmpeg or sox for local mic capture" >&2
            return 1
        fi
    else
        if command -v ffmpeg >/dev/null 2>&1; then
            capture_cmd=(ffmpeg -hide_banner -loglevel error -f alsa -i default -ar "$rate" -ac "$channels" -f s16le -)
        elif command -v sox >/dev/null 2>&1; then
            capture_cmd=(sox -d -t raw -b 16 -c "$channels" -r "$rate" -e signed -)
        else
            echo "ERROR: need ffmpeg or sox for local mic capture" >&2
            return 1
        fi
    fi
    local capture_str
    printf -v capture_str '%q ' "${capture_cmd[@]}"

    # Remote: need a PulseAudio-compatible daemon reachable via pactl.
    # Works with either classic PulseAudio or PipeWire's pipewire-pulse,
    # and reports *which* prerequisite is missing instead of a vague error.
    echo "📡 Connecting to $host..."
    local probe
    probe=$(ssh "$host" '
        command -v pactl >/dev/null 2>&1 || { echo NO_PACTL; exit 0; }
        pactl info >/dev/null 2>&1 && { echo OK; exit 0; }
        # Daemon present but not responding — start one. Prefer the
        # PipeWire unit when configured (modern default), else PulseAudio.
        if systemctl --user list-unit-files pipewire-pulse.service >/dev/null 2>&1; then
            systemctl --user start pipewire-pulse >/dev/null 2>&1
        elif command -v pulseaudio >/dev/null 2>&1; then
            pulseaudio --start >/dev/null 2>&1 || systemctl --user start pulseaudio >/dev/null 2>&1
        fi
        sleep 1
        pactl info >/dev/null 2>&1 && { echo OK; exit 0; }
        echo NO_DAEMON
    ')
    case "$probe" in
        OK) ;;
        NO_PACTL)
            echo "ERROR: 'pactl' not installed on $host." >&2
            echo "       Install it there, e.g:" >&2
            echo "         sudo apt install pulseaudio-utils     # Debian/Ubuntu" >&2
            echo "         sudo dnf install pulseaudio-utils     # Fedora" >&2
            return 1
            ;;
        NO_DAEMON)
            echo "ERROR: no PulseAudio/PipeWire-Pulse daemon on $host." >&2
            echo "       Start one there:" >&2
            echo "         systemctl --user start pipewire-pulse  # PipeWire (modern)" >&2
            echo "         pulseaudio --start                     # classic PulseAudio" >&2
            return 1
            ;;
        *)
            echo "ERROR: cannot reach $host via ssh (or unexpected response)." >&2
            return 1
            ;;
    esac

    # Remote: load pipe-source module (it creates the FIFO itself).
    # Reclaim any stale module already owning this FIFO (e.g. from a crash).
    echo "🛠  Loading pipe-source on $host..."
    local remote_cmd mod_out mod_id
    ssh "$host" "pactl list modules short 2>/dev/null | grep -F 'file=$fifo' | awk '{print \$1}' | while read -r m; do pactl unload-module \"\$m\" 2>/dev/null; done; rm -f $fifo" 2>/dev/null
    printf -v remote_cmd '%q ' pactl load-module module-pipe-source "file=$fifo" format=s16le rate="$rate" channels="$channels" source_name="$name"
    mod_out=$(ssh "$host" "$remote_cmd" 2>&1)
    mod_id=$(printf '%s\n' "$mod_out" | grep -E '^[0-9]+$' | tail -1)
    if [[ -z "$mod_id" ]]; then
        echo "ERROR: module load failed on $host: $mod_out" >&2
        return 1
    fi

    # Local: stream mic into the FIFO over SSH
    echo "🎤 Streaming mic to $host..."
    mkdir -p "$AUDIO_STATE_DIR"
    local logfile="/tmp/mic_forward_${host}.log"
    local pidfile="/tmp/mic_forward_${host}.pid"
    local writer_pid
    # Detach fully: setsid puts the pipeline in a new session without a
    # controlling tty. Fall back to nohup + disown when setsid is unavailable
    # (e.g. macOS without util-linux). Some setsid builds fork and the parent
    # exits immediately, so have the pipeline record its own PID in a pidfile
    # instead of relying on $!.
    local detach=""
    if command -v setsid >/dev/null 2>&1; then
        detach="setsid "
    fi
    rm -f "$pidfile"
    nohup ${detach}bash -c "echo \$\$ > '${pidfile}'; ${capture_str}| ssh -C -o ServerAliveInterval=30 -o ServerAliveCountMax=3 ${compress} ${host} \"cat > ${fifo}\"" >"$logfile" 2>&1 </dev/null &
    if [[ -z "$detach" ]]; then
        disown 2>/dev/null
    fi

    sleep 2
    # Reject dead OR stopped jobs (stopped = SIGTTIN from background tty read)
    writer_pid=$(cat "$pidfile" 2>/dev/null)
    local proc_stat
    proc_stat=$(ps -p "$writer_pid" -o stat= 2>/dev/null)
    if [[ -z "$proc_stat" ]] || [[ "$proc_stat" == *T* ]]; then
        echo "ERROR: mic capture died. See $logfile" >&2
        ssh "$host" "pactl unload-module $mod_id" 2>/dev/null
        return 1
    fi

    echo -e "${host}\t${writer_pid}\t${name}\t${mod_id}\t${fifo}\t${logfile}" >>"$AUDIO_STATE_FILE"
    echo "✅ Mic forwarded: $host source '$name' ($rate Hz, $channels ch)"
    echo "   On $host: parecord -d $name test.wav  |  pactl set-default-source $name"
}

function mic_forward_stop() {
    local host="$1"

    if [[ "$host" == "--help" || "$host" == "-h" ]]; then
        mic_forward_help
        return 0
    fi

    if [[ -z "$host" ]]; then
        echo "ERROR: host is required" >&2
        echo "Usage: mic_forward stop <host>" >&2
        return 1
    fi

    if [[ ! -f "$AUDIO_STATE_FILE" ]]; then
        echo "No active mic forwards"
        return 1
    fi

    local state_pat="${host}"$'\t'
    local line
    line=$(grep -F "$state_pat" "$AUDIO_STATE_FILE")
    if [[ -z "$line" ]]; then
        echo "No active mic forward to $host"
        return 1
    fi

    local pid name mod_id fifo logfile
    pid=$(printf '%s\n' "$line" | cut -f2)
    name=$(printf '%s\n' "$line" | cut -f3)
    mod_id=$(printf '%s\n' "$line" | cut -f4)
    fifo=$(printf '%s\n' "$line" | cut -f5)
    logfile=$(printf '%s\n' "$line" | cut -f6)

    # Kill children (ffmpeg/ssh) first so killing the bash -c wrapper
    # doesn't orphan them, then the wrapper itself.
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
    rm -f "/tmp/mic_forward_${host}.pid" 2>/dev/null
    ssh "$host" "pactl unload-module $mod_id; rm -f $fifo" 2>/dev/null
    grep -vF "$state_pat" "$AUDIO_STATE_FILE" >"$AUDIO_STATE_FILE.tmp" 2>/dev/null
    mv "$AUDIO_STATE_FILE.tmp" "$AUDIO_STATE_FILE" 2>/dev/null
    echo "✅ Stopped mic forward to $host"
}

function mic_forward_status() {
    if [[ ! -f "$AUDIO_STATE_FILE" || ! -s "$AUDIO_STATE_FILE" ]]; then
        echo "No active mic forwards"
        return 0
    fi

    printf '%-20s %-8s %-10s %-16s %s\n' "HOST" "PID" "STATE" "SOURCE" "FIFO"
    local host pid name mod_id fifo logfile
    while IFS=$'\t' read -r host pid name mod_id fifo logfile; do
        local alive="dead"
        kill -0 "$pid" 2>/dev/null && alive="running"
        printf '%-20s %-8s %-10s %-16s %s\n' "$host" "$pid" "$alive" "$name" "$fifo"
    done <"$AUDIO_STATE_FILE"
}

function mic_forward() {
    local cmd="${1:-}"

    case "$cmd" in
    "" | --help | -h)
        mic_forward_help
        return 0
        ;;
    start)
        shift
        mic_forward_start "$@"
        ;;
    stop)
        shift
        mic_forward_stop "$@"
        ;;
    status)
        mic_forward_status
        ;;
    *)
        echo "ERROR: Unknown subcommand '$cmd'" >&2
        mic_forward_help >&2
        return 1
        ;;
    esac
}

# Export public API functions
export -f mic_forward