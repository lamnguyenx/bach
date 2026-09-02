#!/bin/bash
# ==============================================================
#   HOW TO TEST mic_forward (audio forwarding)
# ==============================================================
# Manual verification procedure for bach_cli/bach/audio.sh
#
# Verifies the full chain end-to-end:
#   1. the remote PulseAudio source exists
#   2. the local writer is fully detached from the shell
#   3. real microphone audio (not silence) reaches the remote host
#   4. stop cleans up every artifact
#
# Replace HOST with the ssh alias you forward to (e.g. pp).

HOST="${1:-pp}"
STATE_FILE="$HOME/.bach/mic_forward.state"
PIDFILE="/tmp/mic_forward_${HOST}.pid"
LOGFILE="/tmp/mic_forward_${HOST}.log"
FIFO="/tmp/mic.pcm"
NAME="macmic"

echo "== 0. Sanity: default capture device must follow macOS Sound settings =="
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/audio devices:/,$p'
echo "   (the OS default input — set in Sound settings — is used via :default)"

echo
echo "== 1. Start forwarding =="
source bach_cli/bach/audio.sh
mic_forward start "$HOST"

echo
echo "== 2. Local: writer must be detached (new session, no controlling tty) =="
WRITER_PID=$(cat "$PIDFILE")
echo "writer pid: $WRITER_PID (from $PIDFILE)"
ps -o pid,ppid,sess,stat,command -p "$WRITER_PID"
echo "   expected: PPID=1 and stat contains 's' (session leader), not 'T' (stopped)"
echo "children (ffmpeg + ssh):"
pgrep -P "$WRITER_PID"

echo
echo "== 3. Remote: PulseAudio source must exist =="
ssh "$HOST" "pactl list short sources | grep $NAME"
ssh "$HOST" "ls -la $FIFO"

echo
echo "== 4. Remote: capture and measure the audio level =="
echo "   (speak into the mic while this runs)"
ssh "$HOST" "timeout 5 parecord -d $NAME /tmp/mictest.wav 2>/dev/null; \
    ffmpeg -hide_banner -i /tmp/mictest.wav -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume'"
echo "   expected: max_volume well above silence. A dead/BlackHole source reads"
echo "   approximately -91 dB; real mic signal is typically -30..0 dB."

echo
echo "== 5. Stop: every artifact must be gone =="
mic_forward stop "$HOST"
ps -p "$WRITER_PID" >/dev/null 2>&1 && echo "FAIL: writer still running" || echo "OK: writer gone"
[ -e "$PIDFILE" ] && echo "FAIL: pidfile still present" || echo "OK: pidfile removed"
ssh "$HOST" "pactl list short sources | grep $NAME && echo 'FAIL: source still loaded' || echo 'OK: source unloaded'"
ssh "$HOST" "test -e $FIFO && echo 'FAIL: fifo still present' || echo 'OK: fifo removed'"
grep -qF "$HOST" "$STATE_FILE" 2>/dev/null && echo "FAIL: state entry remains" || echo "OK: state cleaned"