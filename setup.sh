#!/bin/bash
# ==============================================================
#                          BACH SETUP
# ==============================================================
# Compatibility entry point. Prefer make install and bach init.

set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
case "${1:-install}" in
install)
    make -C "$script_dir" install PREFIX="${PREFIX:-$HOME/.local}"
    "${PREFIX:-$HOME/.local}/bin/bach" init --write
    ;;
uninstall | clean | remove)
    "$script_dir/bin/bach" deinit
    make -C "$script_dir" uninstall PREFIX="${PREFIX:-$HOME/.local}"
    ;;
*)
    echo "Usage: $0 [install|uninstall|clean|remove]" >&2
    exit 1
    ;;
esac
