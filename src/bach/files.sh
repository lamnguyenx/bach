#!/bin/bash
# ==============================================================
#                         FILES
# ==============================================================
# File manipulation utilities

function archive() {
    for source in "$@"; do
        timestamp="$(get_timeslug)"
        target="$(dirname "$source")/__archived__/$timestamp---$(basename "$source")"

        [[ ! -e "$source" ]] && {
            log_ok "Skipped"
            continue
        }

        [[ -e "$target" ]] && {
            log_error "Detected pre-existing target:" "$target"
            continue
        }

        mkdir -p "$(dirname "$target")"
        mv "$source" "$target" || {
            log_error "Something went wrong"
            log_error "Perhaps due to file permission.."
        }

        log_ok "Archived" "'$source'" "--moved->" "'$target'"
    done
}