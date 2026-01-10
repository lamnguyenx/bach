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

function convert_single_rclonelink() {
    local linkfile="$1"
    # Read the target path from the .rclonelink file
    target=$(cat "$linkfile")

    # Get the original filename (remove .rclonelink extension)
    original="${linkfile%.rclonelink}"

    # Check if target is not empty
    [[ -z "$target" ]] && {
        log_warning "Skipping empty: $linkfile"
        return
    }

    # Create the symlink
    if ln -sf "$target" "$original"; then
        log_ok "Created: $original -> $target"
        # Remove the .rclonelink file
        rm "$linkfile"
    else
        log_error "Failed: $linkfile"
    fi
}
export -f convert_single_rclonelink

alias rcv="convert_rclonelinks"
function convert_rclonelinks() {
    local target_dir="${1:-.}" # Default to current directory if no arg
    local num_procs="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null | awk '{print $2}' || echo 4)}"

    # Cap num_procs at 8 to avoid excessive parallelism
    if ((num_procs > 8)); then
        num_procs=8
    fi

    log_info "Converting .rclonelink files to symlinks in: $target_dir"

    # Find all .rclonelink files recursively and process in parallel
    find "$target_dir" -type f -name "*.rclonelink" | xargs -n1 -P$num_procs bash -c 'convert_single_rclonelink "$1"' _

    log_ok "Done!"
}
