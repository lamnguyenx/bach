#!/bin/bash
# ==============================================================
#                          ANDROID
# ==============================================================
function get_android_app_name() {
	sed -n "s/.*namespace *=* ['\"]\(.*\)['\"].*/\1/p" app/build.gradle
}

function termux() {
	local user
	user=$(adb shell "stat -c '%U' /data/data/com.termux/files/usr/bin/bash" 2>/dev/null | tr -d '\r')
	if [ -z "$user" ]; then
		echo "Error: Could not determine Termux user"
		return 1
	fi
	adb shell -t -t "su ${user} sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\\\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
}

function termux_root() {
	adb shell -t -t "su 0 sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\\\$PATH; export HOME=/data/data/com.termux/files/home; exec /data/data/com.termux/files/usr/bin/bash'"
}

# Shared core function for ahotbuild and ahotload
# Usage: _android_hot_core <project_dir> <do_build>
function _android_hot_core() {
	local project_dir="$1"
	local do_build="$2"

	# Resolve project directory
	if [[ ! -d "$project_dir" ]]; then
		echo "ERROR: Directory '$project_dir' does not exist" >&2
		return 1
	fi
	project_dir="$(cd "$project_dir" && pwd)"

	# Find the app module (directory with build.gradle containing applicationId)
	local app_module=""
	local build_gradle_file=""

	# First, try the standard 'app' module
	if [[ -f "$project_dir/app/build.gradle" ]] || [[ -f "$project_dir/app/build.gradle.kts" ]]; then
		app_module="app"
	else
		# Search for other modules with applicationId in their build.gradle
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

				if [[ -f "$bg_file" ]] && grep -q "applicationId" "$bg_file" 2>/dev/null; then
					app_module="$module_name"
					break
				elif [[ -f "$bg_kts_file" ]] && grep -q "applicationId" "$bg_kts_file" 2>/dev/null; then
					app_module="$module_name"
					break
				fi
			fi
		done
	fi

	if [[ -z "$app_module" ]]; then
		echo "ERROR: Could not find an Android app module (no build.gradle with applicationId found)" >&2
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
	package_name=$(grep "applicationId" "$build_gradle_file" 2>/dev/null |
		grep -v "//" |
		head -1 |
		sed -E 's/.*applicationId[= ]*["'\'']([^"'\'']*)["'\''].*/\1/' |
		tr -d ' ')

	if [[ -z "$package_name" ]]; then
		echo "ERROR: Could not determine applicationId from $build_gradle_file" >&2
		return 1
	fi
	echo "📦 Package: $package_name"

	# APK path (module-specific)
	local apk_path="${project_dir}/${app_module}/build/outputs/apk/debug/${app_module}-debug.apk"

	# Build (if requested)
	if [[ "$do_build" == true ]]; then
		echo "🔨 Building..."
		(cd "$project_dir" && ./gradlew :"${app_module}":assembleDebug) || {
			echo "ERROR: Build failed" >&2
			return 1
		}
	fi

	# Verify APK exists
	if [[ ! -f "$apk_path" ]]; then
		echo "ERROR: APK not found at $apk_path" >&2
		return 1
	fi

	# Check Play Protect setting
	local verifier_setting
	verifier_setting=$(adb shell settings get global verifier_verify_adb_installs 2>/dev/null | tr -d '\r')
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
	adb install -r -t "$apk_path" || {
		echo "ERROR: Install failed" >&2
		return 1
	}

	echo "🚀 Launching..."
	adb shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

	echo "📋 Tailing logs (package: $package_name)..."
	adb logcat -v threadtime | grep "$package_name"
}

function ahotbuild() {
	local project_dir="${1:-"$(pwd)"}"

	# Parse flags
	for arg in "$@"; do
		case "$arg" in
		--help | -h)
			echo "Usage: ahotbuild [project_dir]"
			echo ""
			echo "  project_dir   Path to Android project root (default: current dir)"
			echo ""
			echo "Builds, installs, and launches the Android app."
			return 0
			;;
		esac
	done

	_android_hot_core "$project_dir" true
}

function ahotload() {
	local project_dir="${1:-"$(pwd)"}"

	# Parse flags
	for arg in "$@"; do
		case "$arg" in
		--help | -h)
			echo "Usage: ahotload [project_dir]"
			echo ""
			echo "  project_dir   Path to Android project root (default: current dir)"
			echo ""
			echo "Skips build, just installs existing APK and launches the app."
			return 0
			;;
		esac
	done

	_android_hot_core "$project_dir" false
}
