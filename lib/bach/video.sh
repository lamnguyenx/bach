#!/bin/bash
# ==============================================================
#                           VIDEO
# ==============================================================
# Forward the local webcam to any SSH-able Linux host as a
# v4l2loopback device, streamed over SSH via ffmpeg.

# -----------------------------------
#          cam forwarding
# -----------------------------------

CAM_STATE_DIR="$HOME/.bach"
CAM_STATE_FILE="$CAM_STATE_DIR/cam_forward.state"

function cam_forward_help() {
    cat <<'EOF'
Usage: cam_forward <subcommand> [args]

Subcommands:
  start <host> [options]   Forward this machine's webcam to <host>
  stop <host>              Stop forwarding to <host>
  status                   List active forwards

'start' options:
  --device <d>   Local video device (ffmpeg avfoundation index/name, default: default)
  --video <v>    Remote v4l2loopback device (default: /dev/video10)
  --size <WxH>   Resolution (default: 1280x720)
  --fps <n>      Frame rate (default: 30)
  --quality <q>  MJPEG quality, 2-31 lower is better (default: 5)
  --no-compress  Disable SSH compression

Forwards this machine's webcam to <host> as a v4l2loopback device.
Apps on <host> can record from it, e.g.:
  ffplay /dev/video10
  ffmpeg -f v4l2 -i /dev/video10 out.mp4

Requires ffmpeg on both ends and the v4l2loopback kernel module on
<host> (loaded via sudo; the module stays loaded after 'stop' so
apps keep their device). On <host> to remove it later:
  sudo modprobe -r v4l2loopback

Examples:
  cam_forward start pp
  cam_forward start pp --device "0" --size 640x480 --fps 24
  cam_forward stop pp
  cam_forward status
EOF
}

function cam_forward_start() {
    local host=""
    local device="default"
    local video="/dev/video10"
    local size="1280x720"
    local fps=30
    local quality=5
    local compress="-C"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        cam_forward_help
        return 0
    fi

    host="$1"
    shift
    if [[ -z "$host" ]]; then
        echo "ERROR: host is required" >&2
        echo "Usage: cam_forward start <host> [options]" >&2
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --device)
            device="$2"
            shift 2
            ;;
        --video)
            video="$2"
            shift 2
            ;;
        --size)
            size="$2"
            shift 2
            ;;
        --fps)
            fps="$2"
            shift 2
            ;;
        --quality)
            quality="$2"
            shift 2
            ;;
        --no-compress)
            compress=""
            shift
            ;;
        *)
            echo "ERROR: Unknown option $1" >&2
            return 1
            ;;
        esac
    done

    if [[ ! "$fps" =~ ^[0-9]+$ || ! "$quality" =~ ^[0-9]+$ || ! "$size" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "ERROR: --fps and --quality must be numbers, --size must be WxH" >&2
        return 1
    fi
    if [[ "$video" != /dev/video* ]]; then
        echo "ERROR: --video must be a /dev/videoN path" >&2
        return 1
    fi

    # Reject double-forwarding to the same host
    local state_pat="${host}"$'\t'
    if [[ -f "$CAM_STATE_FILE" ]] && grep -qF "$state_pat" "$CAM_STATE_FILE"; then
        echo "ERROR: cam already forwarded to $host (use 'cam_forward stop $host' first)" >&2
        return 1
    fi

    # Local capture toolchain (ffmpeg is required; sox cannot capture video)
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "ERROR: need ffmpeg for local webcam capture" >&2
        return 1
    fi
    local input="$device"
    local -a capture_cmd=()
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ "$input" != *:* ]]; then
            input="${input}:none"
        fi
        capture_cmd=(ffmpeg -hide_banner -loglevel error -f avfoundation -framerate "$fps" -video_size "$size" -pixel_format uyvy422 -i "$input" -c:v mjpeg -q:v "$quality" -f mjpeg -)
    else
        capture_cmd=(ffmpeg -hide_banner -loglevel error -f v4l2 -framerate "$fps" -video_size "$size" -i "$input" -c:v mjpeg -q:v "$quality" -f mjpeg -)
    fi
    local capture_str
    printf -v capture_str '%q ' "${capture_cmd[@]}"

    # Remote: need ffmpeg and the v4l2loopback kernel module, which is
    # loaded with sudo (works without a password when sudo -n succeeds).
    echo "📡 Connecting to $host..."
    local probe
    probe=$(ssh "$host" '
        command -v ffmpeg >/dev/null 2>&1 || { echo NO_FFMPEG; exit 0; }
        [ -d /sys/module/v4l2loopback ] && { echo MODULE_LOADED; exit 0; }
        modinfo v4l2loopback >/dev/null 2>&1 || { echo NO_MODULE; exit 0; }
        sudo -n true 2>/dev/null && { echo CAN_LOAD; exit 0; }
        echo NO_SUDO
    ')
    case "$probe" in
    MODULE_LOADED | CAN_LOAD) ;;
    NO_FFMPEG)
        echo "ERROR: ffmpeg not installed on $host." >&2
        echo "       Install it there, e.g: sudo apt install ffmpeg" >&2
        return 1
        ;;
    NO_MODULE)
        echo "ERROR: v4l2loopback kernel module not found on $host." >&2
        echo "       Install it there, e.g: sudo apt install v4l2loopback-dkms" >&2
        return 1
        ;;
    NO_SUDO)
        echo "ERROR: cannot sudo on $host to load v4l2loopback." >&2
        echo "       Run there: sudo modprobe v4l2loopback exclusive_caps=1 video_nr=10" >&2
        return 1
        ;;
    *)
        echo "ERROR: cannot reach $host via ssh (or unexpected response)." >&2
        return 1
        ;;
    esac

    # Remote: load v4l2loopback if not already loaded, creating the device.
    if [[ "$probe" == "CAN_LOAD" ]]; then
        echo "🛠  Loading v4l2loopback on $host..."
        local video_nr="${video#/dev/video}"
        if ! ssh "$host" "sudo modprobe v4l2loopback exclusive_caps=1 video_nr=$video_nr card_label=bachcam"; then
            echo "ERROR: modprobe v4l2loopback failed on $host" >&2
            return 1
        fi
    fi

    # Verify the target device exists and is a v4l2loopback device (virtual,
    # unlike a real camera that happens to have the same number).
    echo "🛠  Checking $video on $host..."
    local dev_name dev_check
    dev_name="${video#/dev/video}"
    dev_check=$(ssh "$host" "
        if [ ! -e $video ]; then echo MISSING; exit 0; fi
        [ -d /sys/devices/virtual/video4linux/video${dev_name} ] && { echo OK; exit 0; }
        echo OTHER_DEVICE
    ")
    case "$dev_check" in
    OK) ;;
    MISSING)
        echo "ERROR: $video does not exist on $host." >&2
        echo "       Existing devices there: $(ssh "$host" 'ls /dev/video* 2>/dev/null || echo none')" >&2
        echo "       Pick one with --video <path>" >&2
        return 1
        ;;
    OTHER_DEVICE)
        echo "ERROR: $video on $host is not a v4l2loopback device." >&2
        echo "       Pick a free number with --video <path>" >&2
        return 1
        ;;
    esac

    # Local: stream webcam into the v4l2 device over SSH. The remote ffmpeg
    # writes its stderr to a log so failures are easy to diagnose.
    echo "📹 Streaming webcam to $host..."
    mkdir -p "$CAM_STATE_DIR"
    local logfile="/tmp/cam_forward_${host}.log"
    local remote_log="/tmp/cam_forward_${host}.log"
    local pidfile="/tmp/cam_forward_${host}.pid"
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
    nohup ${detach}bash -c "echo \$\$ > '${pidfile}'; ${capture_str}| ssh -C -o ServerAliveInterval=30 -o ServerAliveCountMax=3 ${compress} ${host} \"ffmpeg -hide_banner -loglevel error -f mjpeg -i pipe:0 -pix_fmt yuyv422 -f v4l2 ${video} 2>${remote_log}\"" >"$logfile" 2>&1 </dev/null &
    if [[ -z "$detach" ]]; then
        disown 2>/dev/null
    fi

    sleep 2
    # Reject dead OR stopped jobs (stopped = SIGTTIN from background tty read)
    writer_pid=$(cat "$pidfile" 2>/dev/null)
    local proc_stat
    proc_stat=$(ps -p "$writer_pid" -o stat= 2>/dev/null)
    if [[ -z "$proc_stat" ]] || [[ "$proc_stat" == *T* ]]; then
        echo "ERROR: cam capture died. See $logfile" >&2
        return 1
    fi

    # Remote ffmpeg must be alive and quiet (any stderr means failure).
    local remote_ok
    remote_ok=$(ssh "$host" "pgrep -f 'f v4l2 ${video}' >/dev/null && test ! -s ${remote_log} && echo OK || echo BROKEN")
    if [[ "$remote_ok" != "OK" ]]; then
        echo "ERROR: remote stream broken. $(ssh "$host" "cat ${remote_log} 2>/dev/null")" >&2
        pkill -P "$writer_pid" 2>/dev/null
        kill "$writer_pid" 2>/dev/null
        rm -f "$pidfile" 2>/dev/null
        return 1
    fi

    echo -e "${host}\t${writer_pid}\t${video}\t${size}@${fps}fps\t${logfile}" >>"$CAM_STATE_FILE"
    echo "✅ Cam forwarded: $host device '$video' ($size @ ${fps}fps)"
    echo "   On $host: ffplay $video  |  ffmpeg -f v4l2 -i $video out.mp4"
}

function cam_forward_stop() {
    local host="$1"

    if [[ "$host" == "--help" || "$host" == "-h" ]]; then
        cam_forward_help
        return 0
    fi

    if [[ -z "$host" ]]; then
        echo "ERROR: host is required" >&2
        echo "Usage: cam_forward stop <host>" >&2
        return 1
    fi

    if [[ ! -f "$CAM_STATE_FILE" ]]; then
        echo "No active cam forwards"
        return 1
    fi

    local state_pat="${host}"$'\t'
    local line
    line=$(grep -F "$state_pat" "$CAM_STATE_FILE")
    if [[ -z "$line" ]]; then
        echo "No active cam forward to $host"
        return 1
    fi

    local pid video logfile
    pid=$(printf '%s\n' "$line" | cut -f2)
    video=$(printf '%s\n' "$line" | cut -f3)
    logfile=$(printf '%s\n' "$line" | cut -f5)

    # Kill children (ffmpeg/ssh) first so killing the bash -c wrapper
    # doesn't orphan them, then the wrapper itself.
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
    rm -f "/tmp/cam_forward_${host}.pid" 2>/dev/null
    ssh "$host" "rm -f /tmp/cam_forward_${host}.log" 2>/dev/null
    grep -vF "$state_pat" "$CAM_STATE_FILE" >"$CAM_STATE_FILE.tmp" 2>/dev/null
    mv "$CAM_STATE_FILE.tmp" "$CAM_STATE_FILE" 2>/dev/null
    echo "✅ Stopped cam forward to $host"
}

function cam_forward_status() {
    if [[ ! -f "$CAM_STATE_FILE" || ! -s "$CAM_STATE_FILE" ]]; then
        echo "No active cam forwards"
        return 0
    fi

    printf '%-20s %-8s %-10s %-16s %s\n' "HOST" "PID" "STATE" "DEVICE" "SIZE"
    local host pid video size logfile
    while IFS=$'\t' read -r host pid video size logfile; do
        local alive="dead"
        kill -0 "$pid" 2>/dev/null && alive="running"
        printf '%-20s %-8s %-10s %-16s %s\n' "$host" "$pid" "$alive" "$video" "$size"
    done <"$CAM_STATE_FILE"
}

function cam_forward() {
    local cmd="${1:-}"

    case "$cmd" in
    "" | --help | -h)
        cam_forward_help
        return 0
        ;;
    start)
        shift
        cam_forward_start "$@"
        ;;
    stop)
        shift
        cam_forward_stop "$@"
        ;;
    status)
        cam_forward_status
        ;;
    *)
        echo "ERROR: Unknown subcommand '$cmd'" >&2
        cam_forward_help >&2
        return 1
        ;;
    esac
}

# Export public API functions
export -f cam_forward
