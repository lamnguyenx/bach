#!/bin/bash
# ==============================================================
#                          ANDROID
# ==============================================================
function get_android_app_name() {
    sed -n "s/.*namespace *=* ['\"]\(.*\)['\"].*/\1/p" app/build.gradle
}

# Extract package name from build.gradle or build.gradle.kts
# Checks applicationId first, then falls back to namespace
# Usage: _android_get_package_name <build_file>
function _android_get_package_name() {
    local build_file="$1"
    local package_name=""

    # Try applicationId first
    package_name=$(grep "applicationId" "$build_file" 2>/dev/null |
        grep -v "//" |
        head -1 |
        sed -E 's/.*applicationId[= ]*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' |
        tr -d ' ')

    # Fallback to namespace
    if [[ -z "$package_name" ]]; then
        package_name=$(grep -E '^[[:space:]]*namespace[[:space:]]+' "$build_file" 2>/dev/null |
            grep -v "//" |
            head -1 |
            sed -E 's/.*namespace[[:space:]]+["'"'"']([^"'"'"']*)["'"'"'].*/\1/' |
            sed -E 's/.*namespace[[:space:]]+([a-zA-Z0-9._-]+).*/\1/' |
            tr -d ' ')
    fi

    echo "$package_name"
}

# Find the debug APK for a module
# Handles custom outputFileName and split APKs
# Usage: _android_find_apk <project_dir> <app_module>
function _android_find_apk() {
    local project_dir="$1"
    local app_module="$2"
    local apk_dir="${project_dir}/${app_module}/build/outputs/apk/debug"

    if [[ ! -d "$apk_dir" ]]; then
        return 1
    fi

    local apk_path
    # Prefer universal APK if available
    apk_path=$(find "$apk_dir" -maxdepth 1 -name "*.apk" | grep -i "universal" | head -1)

    # Otherwise, pick any single APK
    if [[ -z "$apk_path" ]]; then
        apk_path=$(find "$apk_dir" -maxdepth 1 -name "*.apk" | head -1)
    fi

    echo "$apk_path"
}

# -----------------------------------
#            device selection
# -----------------------------------

# Select an Android device from connected devices.
# Priority: explicit serial > ADBID env > ANDROID_SERIAL env > auto-select (1 device) > interactive prompt
# Usage: _android_select_device [serial]
# Returns: selected device serial (echoed to stdout)
function _android_select_device() {
    local explicit_serial="$1"
    local devices_list
    local selected_serial=""

    # 1. Explicit serial takes highest priority
    if [[ -n "$explicit_serial" ]]; then
        if adb devices | grep -q "^${explicit_serial}[[:space:]]"; then
            echo "$explicit_serial"
            return 0
        else
            echo "ERROR: Device '$explicit_serial' not found in adb devices" >&2
            return 1
        fi
    fi

    # 2. ADBID environment variable
    if [[ -n "$ADBID" ]]; then
        if adb devices | grep -q "^${ADBID}[[:space:]]"; then
            echo "$ADBID"
            return 0
        else
            echo "WARNING: ADBID='$ADBID' not found, falling back..." >&2
        fi
    fi

    # 3. ANDROID_SERIAL environment variable
    if [[ -n "$ANDROID_SERIAL" ]]; then
        if adb devices | grep -q "^${ANDROID_SERIAL}[[:space:]]"; then
            echo "$ANDROID_SERIAL"
            return 0
        else
            echo "WARNING: ANDROID_SERIAL='$ANDROID_SERIAL' not found, falling back..." >&2
        fi
    fi

    # 4. Auto-select if exactly one device
    devices_list=$(adb devices -l | sed '1d' | grep -v '^$' | awk '$2 == "device" {print}')

    if [[ -z "$devices_list" ]]; then
        echo "ERROR: No devices connected" >&2
        return 1
    fi

    local device_count=0
    while IFS= read -r _; do
        device_count=$((device_count + 1))
    done <<<"$devices_list"

    if [[ "$device_count" -eq 1 ]]; then
        selected_serial=$(echo "$devices_list" | awk '{print $1}')
        echo "$selected_serial"
        return 0
    fi

    # 5. Interactive prompt
    echo "Multiple devices connected:" >&2
    local i=1
    while IFS= read -r line; do
        local serial model
        serial=$(echo "$line" | awk '{print $1}')
        model=$(echo "$line" | grep -o 'model:[^ ]*' | cut -d: -f2 || echo "unknown")
        echo "  $i) $serial ($model)" >&2
        i=$((i + 1))
    done <<<"$devices_list"

    local choice
    read -rp "Select device [1-$((i - 1))]: " choice >&2
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$i" ]]; then
        selected_serial=$(echo "$devices_list" | sed -n "${choice}p" | awk '{print $1}')
        echo "$selected_serial"
        return 0
    else
        echo "ERROR: Invalid selection" >&2
        return 1
    fi
}

# Wrapper for adb that uses selected device serial.
# Set _ANDROID_SERIAL before calling this function.
function _adb() {
    if [[ -n "${_ANDROID_SERIAL:-}" ]]; then
        command adb -s "$_ANDROID_SERIAL" "$@"
    else
        command adb "$@"
    fi
}

function atermux() {
    local serial=""
    local cmd_args=()

    # Parse flags and collect command
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: atermux [-s serial] [-- command ...]"
            echo ""
            echo "  -s serial       Target specific device serial"
            echo "  -- command ...  Execute command in Termux (default: interactive shell)"
            echo ""
            echo "Opens a Termux shell on the device, or runs a command."
            echo ""
            echo "Examples:"
            echo "  atermux                    # Interactive shell"
            echo "  atermux -- pkg install htop # Run pkg install htop"
            return 0
            ;;
        --)
            shift
            cmd_args+=("$@")
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            cmd_args+=("$1")
            shift
            ;;
        esac
    done

    local _ANDROID_SERIAL
    _ANDROID_SERIAL=$(_android_select_device "$serial") || return 1

    # Check if Termux is installed
    if ! _adb shell pm list packages 2>/dev/null | grep -q "package:com.termux"; then
        echo "Error: Termux is not installed on device '${_ANDROID_SERIAL}'" >&2
        return 1
    fi

    local uid=""
    # Try to get numeric UID of Termux bash binary (works if adb shell is root)
    # Using numeric UID avoids quote-mangling issues with adb shell and is
    # more reliable across different su implementations (Magisk, etc.).
    uid=$(_adb shell "stat -c %u /data/data/com.termux/files/usr/bin/bash 2>/dev/null" | tr -d '\r')

    # Fallback: try ls -n to get numeric UID
    if [ -z "$uid" ] || ! [[ "$uid" =~ ^[0-9]+$ ]]; then
        uid=$(_adb shell "ls -n /data/data/com.termux/files/usr/bin/bash 2>/dev/null | awk '{print \$3}'" | tr -d '\r')
    fi

    # Fallback: try to infer from package userId
    if [ -z "$uid" ] || ! [[ "$uid" =~ ^[0-9]+$ ]]; then
        uid=$(_adb shell "dumpsys package com.termux 2>/dev/null | sed -n 's/.*userId=\\([0-9]*\\).*/\\1/p' | head -1" | tr -d '\r')
    fi

    if [ -z "$uid" ] || ! [[ "$uid" =~ ^[0-9]+$ ]]; then
        echo "Warning: Could not determine Termux UID. ADB shell may not have permission to access Termux files." >&2
        echo "         Will try run-as fallback (requires debuggable app)." >&2
    fi

    # Build quoted command string
    local quoted_cmd=""
    if [[ ${#cmd_args[@]} -gt 0 ]]; then
        for arg in "${cmd_args[@]}"; do
            local escaped
            escaped=$(printf '%s' "$arg" | sed "s/'/'\"'\"'/g")
            quoted_cmd="$quoted_cmd '$escaped'"
        done
        quoted_cmd="${quoted_cmd# }"
    fi

    # Check if su is available
    if _adb shell "command -v su >/dev/null 2>&1"; then
        # Rooted path: switch to app user via su
        if [[ ${#cmd_args[@]} -eq 0 ]]; then
            if [[ "$uid" =~ ^[0-9]+$ ]]; then
                _adb shell -t -t "su ${uid} sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
            else
                _adb shell -t -t "su 0 sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
            fi
        else
            if [[ "$uid" =~ ^[0-9]+$ ]]; then
                _adb shell "su ${uid} sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; cd /data/data/com.termux/files/home; $quoted_cmd'"
            else
                _adb shell "su 0 sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; cd /data/data/com.termux/files/home; $quoted_cmd'"
            fi
        fi
    else
        # Non-rooted path: try run-as (only works if app is debuggable)
        if _adb shell "run-as com.termux true >/dev/null 2>&1"; then
            if [[ ${#cmd_args[@]} -eq 0 ]]; then
                _adb shell -t -t "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
            else
                _adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; cd /data/data/com.termux/files/home; $quoted_cmd'"
            fi
        else
            echo "Error: Cannot open Termux shell on this device." >&2
            echo "       - Device is not rooted (su not available)" >&2
            echo "       - Termux is not debuggable (run-as failed)" >&2
            echo "" >&2
            echo "Solutions:" >&2
            echo "  1. Root the device, or" >&2
            echo "  2. Build a debuggable Termux APK, or" >&2
            echo "  3. Use Termux's own SSH server instead of adb" >&2
            return 1
        fi
    fi
}

function termux_root() {
    local serial=""
    local cmd_args=()

    # Parse flags and collect command
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: termux_root [-s serial] [-- command ...]"
            echo ""
            echo "  -s serial       Target specific device serial"
            echo "  -- command ...  Execute command as root (default: interactive shell)"
            echo ""
            echo "Opens a root Termux shell on the device, or runs a command."
            return 0
            ;;
        --)
            shift
            cmd_args+=("$@")
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            cmd_args+=("$1")
            shift
            ;;
        esac
    done

    local _ANDROID_SERIAL
    _ANDROID_SERIAL=$(_android_select_device "$serial") || return 1

    # Check if Termux is installed
    if ! _adb shell pm list packages 2>/dev/null | grep -q "package:com.termux"; then
        echo "Error: Termux is not installed on device '${_ANDROID_SERIAL}'" >&2
        return 1
    fi

    if ! _adb shell "command -v su >/dev/null 2>&1"; then
        echo "Error: Device is not rooted (su not available). termux_root requires root access." >&2
        return 1
    fi

    # Build quoted command string
    local quoted_cmd=""
    if [[ ${#cmd_args[@]} -gt 0 ]]; then
        for arg in "${cmd_args[@]}"; do
            local escaped
            escaped=$(printf '%s' "$arg" | sed "s/'/'\"'\"'/g")
            quoted_cmd="$quoted_cmd '$escaped'"
        done
        quoted_cmd="${quoted_cmd# }"
    fi

    if [[ ${#cmd_args[@]} -eq 0 ]]; then
        _adb shell -t -t "su 0 sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
    else
        _adb shell "su 0 sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export HOME=/data/data/com.termux/files/home; cd /data/data/com.termux/files/home; $quoted_cmd'"
    fi
}

# Shared core function for ahotbuild and ahotload
# Usage: _android_hot_core <project_dir> <do_build>
function _android_hot_core() {
    local project_dir="$1"
    local do_build="$2"
    local serial="$3"

    local _ANDROID_SERIAL
    _ANDROID_SERIAL=$(_android_select_device "$serial") || return 1

    # Resolve project directory
    if [[ ! -d "$project_dir" ]]; then
        echo "ERROR: Directory '$project_dir' does not exist" >&2
        return 1
    fi
    project_dir="$(cd "$project_dir" && pwd)"

    # Find the app module (directory with build.gradle containing applicationId or namespace)
    local app_module=""
    local build_gradle_file=""

    # First, try the standard 'app' module
    if [[ -f "$project_dir/app/build.gradle" ]] || [[ -f "$project_dir/app/build.gradle.kts" ]]; then
        app_module="app"
    else
        # Search for other modules with applicationId or namespace in their build.gradle
        for dir in "$project_dir"/*/; do
            if [[ -d "$dir" ]]; then
                local module_name
                module_name=$(basename "$dir")
                # Skip hidden directories and common non-module directories
                [[ "$module_name" == .* ]] && continue
                [[ "$module_name" == "gradle" ]] && continue
                [[ "$module_name" == "build" ]] && continue

                local bg_file="$dir/build.gradle"
                local bg_kts_file="$dir/build.gradle.kts"

                if [[ -f "$bg_file" ]] && { grep -q "applicationId" "$bg_file" 2>/dev/null || grep -qE '^\s*namespace\s+' "$bg_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                elif [[ -f "$bg_kts_file" ]] && { grep -q "applicationId" "$bg_kts_file" 2>/dev/null || grep -qE '^\s*namespace\s+' "$bg_kts_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                fi
            fi
        done
    fi

    if [[ -z "$app_module" ]]; then
        echo "ERROR: Could not find an Android app module (no build.gradle with applicationId or namespace found)" >&2
        return 1
    fi
    echo "📱 Module: $app_module"

    # Determine build.gradle file path
    if [[ -f "$project_dir/$app_module/build.gradle" ]]; then
        build_gradle_file="$project_dir/$app_module/build.gradle"
    elif [[ -f "$project_dir/$app_module/build.gradle.kts" ]]; then
        build_gradle_file="$project_dir/$app_module/build.gradle.kts"
    else
        echo "ERROR: build.gradle not found for module '$app_module'" >&2
        return 1
    fi

    # Fetch package name from build.gradle
    local package_name
    package_name=$(_android_get_package_name "$build_gradle_file")

    if [[ -z "$package_name" ]]; then
        echo "ERROR: Could not determine package name from $build_gradle_file" >&2
        return 1
    fi
    echo "📦 Package: $package_name"

    # Build (if requested)
    if [[ "$do_build" == true ]]; then
        echo "🔨 Building..."
        local gradle_cmd
        if [[ -x "$project_dir/gradlew" ]]; then
            gradle_cmd="./gradlew"
        elif command -v gradle >/dev/null 2>&1; then
            gradle_cmd="gradle"
        else
            echo "ERROR: Neither gradlew nor gradle found in project directory" >&2
            return 1
        fi
        (cd "$project_dir" && $gradle_cmd :"${app_module}":assembleDebug) || {
            echo "ERROR: Build failed" >&2
            return 1
        }
    fi

    # Find the APK
    local apk_path
    apk_path=$(_android_find_apk "$project_dir" "$app_module")

    if [[ -z "$apk_path" ]] || [[ ! -f "$apk_path" ]]; then
        echo "ERROR: APK not found in ${project_dir}/${app_module}/build/outputs/apk/debug/" >&2
        return 1
    fi

    # Check Play Protect setting
    local verifier_setting
    verifier_setting=$(_adb shell settings get global verifier_verify_adb_installs 2>/dev/null | tr -d '\r')
    if [[ "$verifier_setting" != "0" ]]; then
        echo "⚠️  WARNING: Google Play Protect may block installation"
        echo "    Current setting: verifier_verify_adb_installs=${verifier_setting:-'not set'}"
        echo ""
        echo "    To disable Play Protect checks for adb installs, run:"
        echo "      adb shell settings put global verifier_verify_adb_installs 0"
        echo ""
        echo "    Press Ctrl+C to cancel, or wait 3 seconds to continue anyway..."
        sleep 3
    fi

    # Install & launch
    echo "📲 Installing..."
    _adb install -r -t "$apk_path" || {
        echo "ERROR: Install failed" >&2
        return 1
    }

    echo "🚀 Launching..."
    _adb shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

    echo "📋 Tailing logs (package: $package_name)..."
    _adb logcat -v threadtime | grep "$package_name"
}

function ahotbuild() {
    local project_dir=""
    local serial=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: ahotbuild [-s serial] [project_dir]"
            echo ""
            echo "  -s serial     Target specific device serial"
            echo "  project_dir   Path to Android project root (default: current dir)"
            echo ""
            echo "Builds, installs, and launches the Android app."
            return 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            project_dir="$1"
            shift
            ;;
        esac
    done

    project_dir="${project_dir:-"$(pwd)"}"

    _android_hot_core "$project_dir" true "$serial"
}

function ahotload() {
    local project_dir=""
    local serial=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: ahotload [-s serial] [project_dir]"
            echo ""
            echo "  -s serial     Target specific device serial"
            echo "  project_dir   Path to Android project root (default: current dir)"
            echo ""
            echo "Skips build, just installs existing APK and launches the app."
            return 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            project_dir="$1"
            shift
            ;;
        esac
    done

    project_dir="${project_dir:-"$(pwd)"}"

    _android_hot_core "$project_dir" false "$serial"
}

function ahotload2() {
    local project_dir=""
    local serial=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: ahotload2 [-s serial] [project_dir]"
            echo ""
            echo "  -s serial     Target specific device serial"
            echo "  project_dir   Path to Android project root (default: current dir)"
            echo ""
            echo "Restarts the app without reinstalling (kill + launch)."
            return 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            project_dir="$1"
            shift
            ;;
        esac
    done

    project_dir="${project_dir:-"$(pwd)"}"

    local _ANDROID_SERIAL
    _ANDROID_SERIAL=$(_android_select_device "$serial") || return 1

    # Resolve project directory
    if [[ ! -d "$project_dir" ]]; then
        echo "ERROR: Directory '$project_dir' does not exist" >&2
        return 1
    fi
    project_dir="$(cd "$project_dir" && pwd)"

    # Find the app module
    local app_module=""

    if [[ -f "$project_dir/app/build.gradle" ]] || [[ -f "$project_dir/app/build.gradle.kts" ]]; then
        app_module="app"
    else
        for dir in "$project_dir"/*/; do
            if [[ -d "$dir" ]]; then
                local module_name
                module_name=$(basename "$dir")
                [[ "$module_name" == .* ]] && continue
                [[ "$module_name" == "gradle" ]] && continue
                [[ "$module_name" == "build" ]] && continue

                local bg_file="$dir/build.gradle"
                local bg_kts_file="$dir/build.gradle.kts"

                if [[ -f "$bg_file" ]] && { grep -q "applicationId" "$bg_file" 2>/dev/null || grep -qE '^[[:space:]]*namespace[[:space:]]+' "$bg_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                elif [[ -f "$bg_kts_file" ]] && { grep -q "applicationId" "$bg_kts_file" 2>/dev/null || grep -qE '^[[:space:]]*namespace[[:space:]]+' "$bg_kts_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                fi
            fi
        done
    fi

    if [[ -z "$app_module" ]]; then
        echo "ERROR: Could not find an Android app module" >&2
        return 1
    fi

    # Determine build.gradle file path
    local build_gradle_file=""
    if [[ -f "$project_dir/$app_module/build.gradle" ]]; then
        build_gradle_file="$project_dir/$app_module/build.gradle"
    elif [[ -f "$project_dir/$app_module/build.gradle.kts" ]]; then
        build_gradle_file="$project_dir/$app_module/build.gradle.kts"
    else
        echo "ERROR: build.gradle not found for module '$app_module'" >&2
        return 1
    fi

    # Fetch package name
    local package_name
    package_name=$(_android_get_package_name "$build_gradle_file")

    if [[ -z "$package_name" ]]; then
        echo "ERROR: Could not determine package name from $build_gradle_file" >&2
        return 1
    fi

    echo "📦 Package: $package_name"
    echo "🔪 Stopping app..."
    _adb shell am force-stop "$package_name" 2>/dev/null || true

    echo "🚀 Launching..."
    _adb shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

    echo "📋 Tailing logs (package: $package_name)..."
    _adb logcat -v threadtime | grep "$package_name"
}

function awipe() {
    local project_dir=""
    local package_name=""
    local serial=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: awipe [-s serial] [project_dir|package_name]"
            echo ""
            echo "  -s serial     Target specific device serial"
            echo "  project_dir   Path to Android project root (default: current dir)"
            echo "  package_name  Directly specify package name (must contain a dot)"
            echo ""
            echo "Wipes app data: backup removal, force-stop, and pm clear."
            return 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            project_dir="$1"
            shift
            ;;
        esac
    done

    project_dir="${project_dir:-"$(pwd)"}"

    local _ANDROID_SERIAL
    _ANDROID_SERIAL=$(_android_select_device "$serial") || return 1

    # Check if first arg looks like a package name (contains a dot, no slashes)
    if [[ "$project_dir" == *.* ]] && [[ "$project_dir" != */* ]]; then
        package_name="$project_dir"
    else
        # Resolve project directory
        if [[ ! -d "$project_dir" ]]; then
            echo "ERROR: Directory '$project_dir' does not exist" >&2
            return 1
        fi
        project_dir="$(cd "$project_dir" && pwd)"

        # Find the app module
        local app_module=""

        if [[ -f "$project_dir/app/build.gradle" ]] || [[ -f "$project_dir/app/build.gradle.kts" ]]; then
            app_module="app"
        else
            for dir in "$project_dir"/*/; do
                if [[ -d "$dir" ]]; then
                    local module_name
                    module_name=$(basename "$dir")
                    [[ "$module_name" == .* ]] && continue
                    [[ "$module_name" == "gradle" ]] && continue
                    [[ "$module_name" == "build" ]] && continue

                    local bg_file="$dir/build.gradle"
                    local bg_kts_file="$dir/build.gradle.kts"

                if [[ -f "$bg_file" ]] && { grep -q "applicationId" "$bg_file" 2>/dev/null || grep -qE '^[[:space:]]*namespace[[:space:]]+' "$bg_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                elif [[ -f "$bg_kts_file" ]] && { grep -q "applicationId" "$bg_kts_file" 2>/dev/null || grep -qE '^[[:space:]]*namespace[[:space:]]+' "$bg_kts_file" 2>/dev/null; }; then
                    app_module="$module_name"
                    break
                fi
                fi
            done
        fi

        if [[ -z "$app_module" ]]; then
            echo "ERROR: Could not find an Android app module" >&2
            return 1
        fi

        # Determine build.gradle file path
        local build_gradle_file=""
        if [[ -f "$project_dir/$app_module/build.gradle" ]]; then
            build_gradle_file="$project_dir/$app_module/build.gradle"
        elif [[ -f "$project_dir/$app_module/build.gradle.kts" ]]; then
            build_gradle_file="$project_dir/$app_module/build.gradle.kts"
        else
            echo "ERROR: build.gradle not found for module '$app_module'" >&2
            return 1
        fi

        # Fetch package name
        package_name=$(_android_get_package_name "$build_gradle_file")

        if [[ -z "$package_name" ]]; then
            echo "ERROR: Could not determine package name from $build_gradle_file" >&2
            return 1
        fi
    fi

    echo "📦 Package: $package_name"

    # Prompt for confirmation
    local confirm
    read -rp "⚠️  Wipe all data for $package_name? [y/N] " confirm
    case "$confirm" in
    [yY] | [yY][eE][sS])
        echo "🧹 Wiping backup transport..."
        _adb shell bmgr wipe com.google.android.gms/.backup.BackupTransportService "$package_name" 2>/dev/null || true

        echo "🛑 Force-stopping app..."
        _adb shell am force-stop "$package_name" 2>/dev/null || true

        echo "🗑️  Clearing app data..."
        _adb shell pm clear "$package_name"

        echo "✅ Wipe complete."
        ;;
    *)
        echo "❌ Cancelled."
        return 1
        ;;
    esac
}

function adbfs_reload() {
    local mount_point=""
    local serial=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        --help | -h)
            echo "Usage: adbfs_reload [-s serial] [mount_point]"
            echo ""
            echo "  -s serial     Target specific device serial"
            echo "  mount_point   Path to mount point (default: ~/a)"
            echo ""
            echo "Force unmount and remount adbfs."
            return 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            return 1
            ;;
        *)
            mount_point="$1"
            shift
            ;;
        esac
    done

    mount_point="${mount_point:-"$HOME/a"}"

    local selected_serial
    selected_serial=$(_android_select_device "$serial") || return 1
    export ANDROID_SERIAL="$selected_serial"

    # Ensure mount point exists
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
    fi

    # Check if already mounted and unmount
    if mount | grep -q "$(realpath "$mount_point")"; then
        echo "📤 Unmounting $mount_point..."
        umount "$mount_point" 2>/dev/null || umount -f "$mount_point" 2>/dev/null
        # Give it a moment to unmount
        sleep 1
    fi

    # Try macOS-specific unmount if available
    if command -v diskutil >/dev/null 2>&1; then
        diskutil unmount force "$mount_point" 2>/dev/null
    fi

    # Kill any hanging adbfs processes
    pkill -f "adbfs.*$(realpath "$mount_point")" 2>/dev/null || true

    # Ensure mount point is clean
    rmdir "$mount_point" 2>/dev/null && mkdir -p "$mount_point"

    # Remount
    echo "📱 Mounting adbfs to $mount_point..."
    adbfs "$mount_point"
}

# Export public API functions
export -f get_android_app_name
export -f atermux termux_root
export -f ahotbuild ahotload ahotload2 awipe adbfs_reload

# Export internal helpers (needed by public functions in subshells)
export -f _android_select_device _adb _android_hot_core
export -f _android_get_package_name _android_find_apk
