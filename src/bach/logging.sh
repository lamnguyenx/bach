#!/bin/bash
# ==============================================================
#                          LOGGING
# ==============================================================

        ANSIFmt__reset='\033[00m'
         ANSIFmt__bold='\033[01m'
      ANSIFmt__disable='\033[02m'
    ANSIFmt__underline='\033[04m'
      ANSIFmt__reverse='\033[07m'
ANSIFmt__strikethrough='\033[09m'
    ANSIFmt__invisible='\033[08m'

          ANSIFmt__red='\033[31m'
         ANSIFmt__green='\033[32m'
        ANSIFmt__yellow='\033[33m'
        ANSIFmt__violet='\033[35m'
          ANSIFmt__gray='\033[38;5;243m'
          ANSIFmt__cyan='\033[00;36m'

 ANSIFmt__bright_green='\033[00;92m'
ANSIFmt__bright_yellow='\033[00;93m'
  ANSIFmt__bright_blue='\033[00;94m'


function strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}


function echo_repeat() {
    local string="\\$1"
    local total_count="$2"
    printf "%${total_count}s\n" | sed "s/ /$string/g"
}

function echo_center() {
    local message="$1"
    local room_len="$2"
    message_len=$(echo -n "$message" | wc -m)
    offset_len=$(echo "($room_len - $message_len) / 2" | bc)
    echo "$(echo_repeat " " $offset_len)$message"
}

function echo_banner() {
    local message="$1"
    local pattern="$2"
    local room_len="${3:-"60"}"
    echo_repeat "$pattern" $room_len
    echo_center "$message" $room_len
    echo_repeat "$pattern" $room_len
}

PROCESS_LEVEL=${PROCESS_LEVEL:-"0"}
case "$PROCESS_LEVEL" in
    "1")
        p_level_tag=""
        ;;
    "2")
        p_level_tag="└───"
        ;;
    *)
        p_level_tag="└───$(echo_repeat "└───" "$(($PROCESS_LEVEL-2))")"
        ;;
esac

function log_banner() {
    local message="$1"
    local pattern="${2:-"="}"
    local room_len="${3:-"60"}"
    echo_banner "$message" "$pattern" "$room_len" \
        | while IFS= read line; do log "$line"; done
}

function echo_red()     { printf      "$ANSIFmt__red$*$ANSIFmt__reset\n"; }
function echo_green()   { printf    "$ANSIFmt__green$*$ANSIFmt__reset\n"; }
function echo_yellow()  { printf   "$ANSIFmt__yellow$*$ANSIFmt__reset\n"; }
function echo_gray()    { printf     "$ANSIFmt__gray$*$ANSIFmt__reset\n"; }
function echo_cyan()    { printf     "$ANSIFmt__cyan$*$ANSIFmt__reset\n"; }

function echo_bold()        { printf                 "$ANSIFmt__bold$*$ANSIFmt__reset\n"; }
function echo_bold_red()    { printf    "$ANSIFmt__red$ANSIFmt__bold$*$ANSIFmt__reset\n"; }
function echo_bold_green()  { printf  "$ANSIFmt__green$ANSIFmt__bold$*$ANSIFmt__reset\n"; }
function echo_bold_yellow() { printf "$ANSIFmt__yellow$ANSIFmt__bold$*$ANSIFmt__reset\n"; }
function echo_bold_gray()   { printf   "$ANSIFmt__gray$ANSIFmt__bold$*$ANSIFmt__reset\n"; }
function echo_bold_cyan()   { printf   "$ANSIFmt__cyan$ANSIFmt__bold$*$ANSIFmt__reset\n"; }

# General logging
function log_date()         { printf "$ANSIFmt__gray$(date +"%Y-%m-%d %H:%M:%S,%3N ")$ANSIFmt__reset"; }
function log_gray_simple()  { printf "$(echo_bold_cyan $p_level_tag)$(echo_gray "$(log_date)[$0]")$(echo_gray "$@")\n"; }
function log_fill() {
    local single_char="$1"
    local term_width=$(tput cols)
    local log_level_length=$((($PROCESS_LEVEL - 1) * 4)) # x─── --> 4 spaces occupied
    local log_time_length="22" # [2019.10.22][01:19:19] --> 22 spaces occupied
    local log_script_path_length="$(printf "%s" "[$0]" | wc -c)" # all are ascii characters

    if [[ -z $term_width ]]; then
        fill_count="50"
    else
        fill_count=$(($term_width - $log_level_length - $log_time_length - $log_script_path_length))
    fi

    log_gray_simple "$(echo_repeat "$single_char" "$fill_count")";
}


function separate_heading() {
    local log="$1"

    case "$log" in
        "# "*)
            # Heading 1
            # echo && echo
            log_fill "─"
            ;;
        "## "*)
            # Heading 2
            # echo
            # log_fill "-"
            ;;
        "### "*)
            # Heading 3
            # echo
            ;;
        *)
            printf ""
            ;;
    esac

}

# TODO: Parse message from stdin
function log()         { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$1";                       shift; echo " $*";) >&2; }
function log_bold()    { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold        "$1")"; shift; echo " $*";) >&2; }
function log_red()     { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold_red    "$1")"; shift; echo " $*";) >&2; }
function log_green()   { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold_green  "$1")"; shift; echo " $*";) >&2; }
function log_yellow()  { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold_yellow "$1")"; shift; echo " $*";) >&2; }
function log_gray()    { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold_gray   "$1")"; shift; echo " $*";) >&2; }
function log_cyan()    { (separate_heading "$@"; printf "%s" "$(log_date)$(echo_bold_cyan $p_level_tag)$(echo_bold_cyan   "$1")"; shift; echo " $*";) >&2; }
function log_error()   { log_red    "[ERROR] $*" >&2; }
function log_warning() { log_yellow "[WARNING] $*" >&2; }
function log_info()    { log        "[INFO] $*" >&2; }
function log_debug()   { log_gray   "[DEBUG] $*" >&2; }
function log_ok()      { log_green  "[OK] $*" >&2; }