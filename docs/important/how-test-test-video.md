#!/bin/bash
# ==============================================================
#   HOW TO TEST cam_forward (webcam forwarding)
# ==============================================================
# Manual verification procedure for bach_cli/bach/video.sh
#
# Verifies the full chain end-to-end:
#   1. the remote v4l2loopback device exists
#   2. the local writer is fully detached from the shell
#   3. real camera frames (not black) reach the remote host
#   4. stop cleans up every artifact
#
# Replace HOST with the ssh alias you forward to (e.g. pp).

HOST="${1:-pp}"
STATE_FILE="$HOME/.bach/cam_forward.state"
PIDFILE="/tmp/cam_forward_${HOST}.pid"
LOGFILE="/tmp/cam_forward_${HOST}.log"
VIDEO="/dev/video10"

echo "== 0. Sanity: local capture device must exist =="
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/video devices:/,/audio devices:/p'
echo "   (the OS default camera is used via 'default' unless --device is given)"

echo
echo "== 1. Start forwarding =="
source bach_cli/bach/audio.sh 2>/dev/null
source bach_cli/bach/video.sh
cam_forward start "$HOST"

echo
echo "== 2. Local: writer must be detached (new session, no controlling tty) =="
WRITER_PID=$(cat "$PIDFILE")
echo "writer pid: $WRITER_PID (from $PIDFILE)"
ps -o pid,ppid,sess,stat,command -p "$WRITER_PID"
echo "   expected: PPID=1 and stat contains 's' (session leader), not 'T' (stopped)"
echo "children (ffmpeg + ssh):"
pgrep -P "$WRITER_PID"

echo
echo "== 3. Remote: v4l2loopback module and device must exist =="
ssh "$HOST" "lsmod | grep v4l2loopback || echo 'module not loaded'"
ssh "$HOST" "ls -la $VIDEO"

echo
echo "== 4. Remote: capture and measure the brightness =="
echo "   (point the webcam at something non-black while this runs)"
ssh "$HOST" "timeout 5 ffmpeg -hide_banner -f v4l2 -i $VIDEO -frames:v 10 \
    -vf signalstats,metadata=print:file=- -f null - 2>/dev/null | grep -m1 YAVG"
echo "   expected: YAVG well above black. A dead/black stream reads ~16;"
echo "   a real scene is typically 60-180."

echo
echo "== 5. Stop: every artifact must be gone =="
cam_forward stop "$HOST"
ps -p "$WRITER_PID" >/dev/null 2>&1 && echo "FAIL: writer still running" || echo "OK: writer gone"
[ -e "$PIDFILE" ] && echo "FAIL: pidfile still present" || echo "OK: pidfile removed"
ssh "$HOST" "test -e /tmp/cam_forward_${HOST}.log && echo 'FAIL: remote log still present' || echo 'OK: remote log removed'"
grep -qF "$HOST" "$STATE_FILE" 2>/dev/null && echo "FAIL: state entry remains" || echo "OK: state cleaned"
echo "note: the v4l2loopback module stays loaded (apps keep their device);"
echo "      remove it on $HOST with: sudo modprobe -r v4l2loopback"