#!/bin/bash
# ==============================================================
#                           SSH
# ==============================================================
# SSH and SSHFS utilities for remote filesystem mounting

# -----------------------------------
#            sshfs helpers
# -----------------------------------

function sshfs_reload() {
    local hostname="$1"
    local remote_path="${2:-}"

    if [[ "$hostname" == "--help" || "$hostname" == "-h" ]]; then
        cat <<'EOF'
Usage: sshfs_reload <hostname> [remote_path]

  hostname      SSH host alias (from ~/.ssh/config or any valid SSH target)
  remote_path   Absolute remote path to mount (default: /home/<ssh_user>)

Mounts <hostname>:<remote_path> to $HOME/<hostname><remote_path> via SSHFS.
If already mounted, force-unmounts and remounts.

Examples:
  sshfs_reload pp                  # mounts pp:/home/<ssh_user> → ~/pp/home/<ssh_user>
  sshfs_reload pp /data            # mounts pp:/data → ~/pp/data
  sshfs_reload pp /mnt/storage     # mounts pp:/mnt/storage → ~/pp/mnt/storage

Requirements:
  - $HOME/<hostname><remote_path> directory must already exist
  - $HOME/<hostname><remote_path> must be empty when not already mounted
  - <ssh_user> is resolved from ~/.ssh/config, falling back to $USER
EOF
        return 0
    fi

    if [[ -z "$hostname" ]]; then
        echo "ERROR: hostname is required" >&2
        echo "Usage: sshfs_reload <hostname> [remote_path]" >&2
        return 1
    fi

    # Resolve SSH user from ~/.ssh/config, fallback to local $USER
    local ssh_user
    ssh_user=$(ssh -G "$hostname" 2>/dev/null | awk '/^user / {print $2}')
    ssh_user="${ssh_user:-$USER}"

    # Default remote path is the remote user's home
    if [[ -z "$remote_path" ]]; then
        remote_path="/home/$ssh_user"
    fi

    # Ensure remote path starts with /
    if [[ "$remote_path" != /* ]]; then
        echo "ERROR: remote_path must be absolute (start with /)" >&2
        return 1
    fi

    local mount_point="$HOME/$hostname$remote_path"

    if [[ ! -d "$mount_point" ]]; then
        echo "ERROR: Mount point '$mount_point' does not exist" >&2
        echo "Please create it first: mkdir -p '$mount_point'" >&2
        return 1
    fi

    # Force unmount if already mounted
    if mount | grep -q "$(realpath "$mount_point")"; then
        echo "📤 Unmounting $mount_point..."
        umount "$mount_point" 2>/dev/null || umount -f "$mount_point" 2>/dev/null || true

        if command -v diskutil >/dev/null 2>&1; then
            diskutil unmount force "$mount_point" 2>/dev/null || true
        fi

        if command -v fusermount3 >/dev/null 2>&1; then
            fusermount3 -u "$mount_point" 2>/dev/null || true
        elif command -v fusermount >/dev/null 2>&1; then
            fusermount -u "$mount_point" 2>/dev/null || true
        fi

        pkill -f "sshfs.*$(realpath "$mount_point")" 2>/dev/null || true
        sleep 1
    fi

    # Safety: directory must be empty when not mounted
    if [[ -n "$(ls -A "$mount_point" 2>/dev/null)" ]]; then
        echo "ERROR: '$mount_point' is not empty. Refusing to mount over existing files." >&2
        return 1
    fi

    # Check sshfs is available
    if ! command -v sshfs >/dev/null 2>&1; then
        echo "ERROR: sshfs command not found. Please install sshfs (macFUSE/SSHFS on macOS, fuse-sshfs on Linux)." >&2
        return 1
    fi

    echo "📡 Mounting $hostname:$remote_path → $mount_point..."
    if ! sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
        -o idmap=user,uid="$(id -u)",gid="$(id -g)" \
        -o default_permissions \
        "$hostname:$remote_path" "$mount_point"; then
        echo "ERROR: sshfs mount command failed for $hostname:$remote_path" >&2
        return 1
    fi

    # Verify mount actually succeeded
    sleep 1
    if ! mount | grep -q "$(realpath "$mount_point")" 2>/dev/null; then
        # Fallback: try checking if directory is accessible
        if ! ls "$mount_point" >/dev/null 2>&1; then
            echo "WARNING: Mount may have failed — $mount_point is not accessible" >&2
            return 1
        fi
    fi

    echo "✅ Mounted $hostname:$remote_path → $mount_point"
}

# Export public API functions
export -f sshfs_reload
