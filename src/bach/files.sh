#!/bin/bash
# ==============================================================
#                         FILES
# ==============================================================
# File manipulation utilities

function get_md5sum_short() {
    md5sum "$1" | cut -d' ' -f1 | cut -c1-7
}

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

alias rcv="convert_rclonelinks"
function convert_rclonelinks() {
    local target_dir="${1:-.}"  # Default to current directory if no arg

    log_info "Converting .rclonelink files to symlinks in: $target_dir"

    # Find all .rclonelink files recursively
    find "$target_dir" -type f -name "*.rclonelink" | while IFS= read -r linkfile; do
        # Read the target path from the .rclonelink file
        target=$(cat "$linkfile")

        # Get the original filename (remove .rclonelink extension)
        original="${linkfile%.rclonelink}"

        # Check if target is not empty
        [[ -z "$target" ]] && {
            log_warning "Skipping empty: $linkfile"
            continue
        }

        # Create the symlink
        if ln -sf "$target" "$original"; then
            log_ok "Created: $original -> $target"
            # Remove the .rclonelink file
            rm "$linkfile"
        else
            log_error "Failed: $linkfile"
        fi
    done

    log_ok "Done!"
}
