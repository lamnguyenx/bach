#!/bin/bash
set -Eeuo pipefail

# Archive existing config directory/file with timestamp
#
# Logic:
# - If path doesn't exist: skip with warning
# - If path is already a symlink: skip with info (don't archive symlinks)
# - If path exists and is not a symlink: archive to ~/.config/__archives__ with timestamp

CONFIG_DIR="${1:?Config directory required}"
ARCHIVE_DIR="$HOME/.config/__archives__"

# Skip if path doesn't exist - no need to archive non-existent files
if [ ! -e "$CONFIG_DIR" ]; then
    DISPLAY_DIR="${CONFIG_DIR//$HOME/~}"
    echo "Warning: $DISPLAY_DIR does not exist, skipping archive"
    exit 0
fi

# Archive even if it's a symlink

# Archive the file/directory: create archive dir, generate timestamp, move to archive
mkdir -p "$ARCHIVE_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mv "$CONFIG_DIR" "$ARCHIVE_DIR/$(basename "$CONFIG_DIR")--$TIMESTAMP.bk"
