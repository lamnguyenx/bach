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
    if command -v parallel >/dev/null 2>&1; then
        find "$target_dir" -type f -name "*.rclonelink" | parallel -j $num_procs convert_single_rclonelink
    else
        log_error "GNU parallel not found. Install it with 'brew install parallel' (macOS), 'apt/yum install parallel' (Linux), or 'conda install -c conda-forge parallel' (Conda), or process files individually with convert_single_rclonelink"
        return 1
    fi

    log_ok "Done!"
}

function ln_tree() {
    local source_dir="$1"
    local target_dir="$2"

    # Validation
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ln_tree <source_dir> <target_dir>"
        return 1
    fi

    if [[ ! -e "$source_dir" ]]; then
        log_error "Source directory does not exist: $source_dir"
        return 1
    fi

    if [[ ! -d "$source_dir" ]]; then
        log_error "Source is not a directory: $source_dir"
        return 1
    fi

    # Create target directory if it doesn't exist
    if [[ ! -e "$target_dir" ]]; then
        mkdir -p "$target_dir" || {
            log_error "Failed to create target directory: $target_dir"
            return 1
        }
        log_ok "Created target directory: $target_dir"
    elif [[ ! -d "$target_dir" ]]; then
        log_error "Target exists but is not a directory: $target_dir"
        return 1
    fi

    # Check if source directory is empty
    if [[ -z "$(ls -A "$source_dir" 2>/dev/null)" ]]; then
        log_warning "Source directory is empty: $source_dir"
        return 0
    fi

    local item_count=0
    local success_count=0

    # Iterate through all children in source directory
    for item in "$source_dir"/*; do
        # Handle case where glob doesn't match anything
        [[ -e "$item" ]] || continue

        local basename
        basename=$(basename "$item")
        local target_path="$target_dir/$basename"

        # Calculate relative path from target to source
        local rel_path
        rel_path=$(realpath --relative-to="$target_dir" "$item" 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$item', '$target_dir'))" 2>/dev/null)

        if [[ -z "$rel_path" ]]; then
            log_error "Failed to calculate relative path for: $item"
            continue
        fi

        # Create the symlink using ln -sfnv
        # -s: symbolic link
        # -f: force overwrite
        # -n: don't dereference existing symlinks to directories
        # -v: verbose
        if ln -sfnv "$rel_path" "$target_path" 2>/dev/null; then
            ((success_count++))
        else
            log_error "Failed to create symlink: $target_path -> $rel_path"
        fi

        ((item_count++))
    done

    log_ok "Created $success_count/$item_count symlinks in $target_dir"
    return 0
}

# Export public API functions
export -f get_md5sum_short archive convert_rclonelinks ln_tree

# Export internal helpers (needed by public functions in subshells)
export -f convert_single_rclonelink
