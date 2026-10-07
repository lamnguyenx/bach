#!/bin/bash
# ==============================================================
#                           GIT
# ==============================================================
# -----------------------------------
#         core utilities
# -----------------------------------

function validate_git_repo() {
    # Validate that current directory is a git repository
    # Returns: 0 if valid git repo, 1 if not
    # Sets: GIT_ROOT variable to repository root path
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [ $? -ne 0 ]; then
        log_error "Not in a git repository"
        return 1
    fi

    GIT_ROOT="$git_root"
    return 0
}

function change_directory() {
    # Safely change to a directory with confirmation logging
    # Args: $1 - target directory path
    #       $2 - optional description for logging
    local target_dir="$1"
    local description="${2:-directory}"

    if cd "$target_dir" 2>/dev/null; then
        log_ok "✅ Changed to $description: $target_dir"
        return 0
    else
        log_error "❌ Failed to change to $description: $target_dir"
        return 1
    fi
}

function process_submodules_recursive() {
    # Process all submodules recursively with a given function
    # Args: $1 - function name to call for each repo
    #       $2 - message to pass to the function
    local process_func="$1"
    local message="$2"

    # Store the original directory
    local original_dir=$(pwd)

    # Check if there are submodules
    if [ -f .gitmodules ]; then
        log_info "🔍 Found submodules, processing recursively..."

        # Get all submodule paths
        git submodule foreach --recursive --quiet 'echo $PWD' | while read -r submodule_path; do
            "$process_func" "$submodule_path" "$message"
        done

        # Return to original directory
        cd "$original_dir"
    else
        log_info "ℹ️  No submodules found"
    fi

    # Return to original directory
    cd "$original_dir"
}

function validate_params() {
    # Validate function parameters
    # Args: $1 - expected number of parameters
    #       $2 - function name for error messages
    #       remaining args - parameter descriptions
    local expected_count="$1"
    local func_name="$2"
    shift 2

    if [ $# -ne "$expected_count" ]; then
        echo "$func_name - ${*:1}"
        echo ""
        echo "USAGE:"
        echo "  $func_name ${*:2}"
        echo ""
        if [ $# -gt 0 ]; then
            echo "PARAMETERS:"
            local i=1
            for param_desc in "$@"; do
                echo "  \$$i    $param_desc"
                ((i++))
            done
        fi
        return 1
    fi
    return 0
}

function just_commit_push() {
    # Common logic for just_commit and just_push functions
    # Args: $1 - commit message
    #       $2 - whether to push (true/false)
    local message="$1"
    local should_push="$2"

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    git add .
    git commit -m "/// $message"

    if [ "$should_push" = "true" ]; then
        git push
    fi

    log_ok "🦝: $message"
}

function just_amend() {
    local target="${1:-.}"
	git reset .
    git add "$target"
    git commit --amend --no-edit
}

function git_remember_passwords() {
    git config --global credential.helper store
}

function git_remember_credentials() {
    git config --global credential.helper store
}

function git_trust_current_dir() {
    git config --global --add safe.directory
}

# Git submodule navigation system
# Provides interactive and programmatic navigation through git repository submodules
# Supports quick jumping by number, keyword searching, and interactive browsing

# Global arrays to store submodule information
declare -a GL_PATHS
declare -a GL_RELATIVE_PATHS
declare -a GL_LEVELS

function gl() {
    # Main entry point for git submodule navigation
    #
    # USAGE:
    #   gl                    - Interactive mode: show all submodules with numbered list
    #   gl <number>          - Quick jump: navigate directly to submodule by index number
    #   gl <keyword>         - Search mode: find and jump to first matching submodule
    #   gl -h|--help         - Show this help message
    #
    # EXAMPLES:
    #   gl                   # Show interactive list of all submodules
    #   gl 3                 # Jump directly to submodule #3
    #   gl engine            # Search for submodule containing "engine" in path
    #   gl --help            # Display usage information
    #
    # FEATURES:
    #   - Hierarchical display organized by submodule nesting levels
    #   - Quick numeric navigation for efficiency
    #   - Fuzzy keyword searching within submodule paths
    #   - Recursive submodule discovery and traversal
    #   - Error handling for invalid repositories and selections

    # Handle help requests
    if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
        echo "gl - Git Submodule Navigation System"
        echo ""
        echo "USAGE:"
        echo "  gl                    Interactive mode: show all submodules with numbered list"
        echo "  gl <number>          Quick jump: navigate directly to submodule by index number"
        echo "  gl <keyword>         Search mode: find and jump to first matching submodule"
        echo "  gl -h|--help         Show this help message"
        echo ""
        echo "EXAMPLES:"
        echo "  gl                   # Show interactive list of all submodules"
        echo "  gl 3                 # Jump directly to submodule #3"
        echo "  gl engine            # Search for submodule containing 'engine' in path"
        echo ""
        echo "FEATURES:"
        echo "  • Hierarchical display organized by submodule nesting levels"
        echo "  • Quick numeric navigation for efficiency"
        echo "  • Fuzzy keyword searching within submodule paths"
        echo "  • Recursive submodule discovery and traversal"
        echo "  • Error handling for invalid repositories and selections"
        return 0
    fi

    # Validate argument count
    if [[ $# -gt 1 ]]; then
        log_error "Too many arguments. Expected 0 or 1 argument."
        log_error "Use 'gl --help' for usage information."
        return 1
    fi

    # Quick jump by number if argument provided and is numeric
    if [[ $# -eq 1 && "$1" =~ ^[0-9]+$ ]]; then
        gl_quick_jump "$1"
        return $?
    fi

    # Search by keyword if argument provided and is not numeric
    if [[ $# -eq 1 && ! "$1" =~ ^[0-9]+$ ]]; then
        gl_search "$1"
        return $?
    fi

    # Interactive mode - show all submodules
    gl_interactive
}

function gl_quick_jump() {
    # Navigate directly to a submodule by its index number
    #
    # USAGE:
    #   gl_quick_jump <number>
    #
    # PARAMETERS:
    #   number    - Zero-based index of the submodule to navigate to
    #
    # EXAMPLES:
    #   gl_quick_jump 0      # Jump to root directory (index 0)
    #   gl_quick_jump 5      # Jump to submodule at index 5
    #
    # BEHAVIOR:
    #   - Validates the provided index against available submodules
    #   - Changes current directory to the target submodule path
    #   - Displays confirmation message with the new location
    #   - Returns error code 1 if index is invalid or out of range

    if ! validate_params 1 "gl_quick_jump" "Zero-based index of the submodule to navigate to"; then
        return 1
    fi

    local target_num="$1"

    # Validate numeric input
    if [[ ! "$target_num" =~ ^[0-9]+$ ]]; then
        log_error "Invalid argument '$target_num'. Expected a numeric index."
        log_error "Use 'gl_quick_jump' without arguments for usage information."
        return 1
    fi

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Get all paths using global arrays
    gl_collect_all_submodules "$GIT_ROOT" >/dev/null

    # Validate target number range
    if [ "$target_num" -ge ${#GL_PATHS[@]} ]; then
        log_error "Invalid index $target_num. Available range: 0-$((${#GL_PATHS[@]} - 1))"
        log_error "Use 'gl' to see all available submodules."
        return 1
    fi

    # Jump to target
    change_directory "${GL_PATHS[$target_num]}" "submodule" || return 1
    log_info "📍 Path: ${GL_RELATIVE_PATHS[$target_num]}"
}

function gl_search() {
    # Search for and navigate to the first submodule matching a keyword
    #
    # USAGE:
    #   gl_search <keyword>
    #
    # PARAMETERS:
    #   keyword   - Search term to match against submodule relative paths
    #
    # EXAMPLES:
    #   gl_search engine     # Find submodule with "engine" in its path
    #   gl_search ui/core    # Find submodule with "ui/core" in its path
    #   gl_search test       # Find first submodule containing "test"
    #
    # BEHAVIOR:
    #   - Performs case-sensitive substring matching on relative paths
    #   - Navigates to the first matching submodule found
    #   - Displays both the full path and matched relative path
    #   - Returns error code 1 if no matches are found

    if ! validate_params 1 "gl_search" "Search term to match against submodule relative paths"; then
        return 1
    fi

    local keyword="$1"

    # Validate keyword is not empty
    if [[ -z "$keyword" ]]; then
        log_error "Search keyword cannot be empty."
        log_error "Use 'gl_search' without arguments for usage information."
        return 1
    fi

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Get all paths using global arrays
    gl_collect_all_submodules "$GIT_ROOT" >/dev/null

    # Search for first match
    for i in "${!GL_RELATIVE_PATHS[@]}"; do
        if [[ "${GL_RELATIVE_PATHS[$i]}" == *"$keyword"* ]]; then
            change_directory "${GL_PATHS[$i]}" "submodule" || return 1
            log_info "🔍 Matched: ${GL_RELATIVE_PATHS[$i]}"
            log_info "📍 Index: $i"
            return 0
        fi
    done

    log_error "❌ No submodule found matching keyword: '$keyword'"
    log_info "💡 Use 'gl' to see all available submodules."
    return 1
}

function gl_interactive() {
    # Display interactive list of all submodules for user selection
    #
    # USAGE:
    #   gl_interactive
    #
    # BEHAVIOR:
    #   - Discovers and displays all submodules in hierarchical format
    #   - Organizes display by nesting levels for clarity
    #   - Prompts user for numeric selection or keyword search
    #   - Supports both direct index navigation and keyword searching
    #   - Handles empty repositories gracefully
    #
    # INTERACTIVE COMMANDS:
    #   <number>     - Navigate to submodule by index number
    #   <keyword>    - Search for submodule containing keyword
    #   Ctrl+C       - Cancel and exit
    #
    # DISPLAY FORMAT:
    #   LEVEL - 0
    #   (0) repository-name (root)
    #
    #   LEVEL - 1
    #   (1) submodule/path
    #   (2) another/submodule

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Collect and display all submodules
    log_info "🔍 Scanning for git submodules..."
    gl_collect_all_submodules "$GIT_ROOT"

    # If no submodules found
    if [ ${#GL_PATHS[@]} -eq 1 ]; then
        echo ""
        log_info "ℹ️  No submodules found in this repository."
        log_info "💡 This repository contains only the root directory."
        return 0
    fi

    # Prompt for selection
    echo ""
    echo "📋 Navigation Options:"
    echo "  • Enter a number (0-$((${#GL_PATHS[@]} - 1))) to jump directly"
    echo "  • Enter a keyword to search submodule paths"
    echo "  • Press Ctrl+C to cancel"
    echo ""
    echo -n "Your choice: "

    local selection
    read -r selection

    # Handle empty input
    if [[ -z "$selection" ]]; then
        log_error "❌ No selection made. Operation cancelled."
        return 1
    fi

    # Handle numeric selection
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        if [ "$selection" -lt ${#GL_PATHS[@]} ]; then
            change_directory "${GL_PATHS[$selection]}" "submodule" || return 1
            log_info "📍 Path: ${GL_RELATIVE_PATHS[$selection]}"
        else
            log_error "❌ Invalid selection: $selection (valid range: 0-$((${#GL_PATHS[@]} - 1)))"
            return 1
        fi
    else
        # Handle keyword search
        log_info "🔍 Searching for keyword: '$selection'"
        gl_search "$selection"
    fi
}

function gl_collect_all_submodules() {
    # Recursively discover and collect all git submodules in the repository
    #
    # USAGE:
    #   gl_collect_all_submodules <git_root>
    #
    # PARAMETERS:
    #   git_root  - Root directory of the git repository to scan
    #
    # BEHAVIOR:
    #   - Initializes global arrays (GL_PATHS, GL_RELATIVE_PATHS, GL_LEVELS)
    #   - Recursively traverses all submodules and nested submodules
    #   - Organizes results by nesting level for hierarchical display
    #   - Populates global arrays with discovered submodule information
    #   - Displays formatted output organized by levels
    #
    # GLOBAL ARRAYS POPULATED:
    #   GL_PATHS[]          - Full filesystem paths to each submodule
    #   GL_RELATIVE_PATHS[] - Relative paths from repository root
    #   GL_LEVELS[]         - Nesting level of each submodule (0=root)

    if ! validate_params 1 "gl_collect_all_submodules" "Root directory of the git repository to scan"; then
        return 1
    fi

    local git_root="$1"

    # Validate git_root exists and is a directory
    if [[ ! -d "$git_root" ]]; then
        echo "Error: Git root directory '$git_root' does not exist." >&2
        return 1
    fi

    # Initialize global arrays
    GL_PATHS=()
    GL_RELATIVE_PATHS=()
    GL_LEVELS=()

    # Add root directory
    GL_PATHS[0]="$git_root"
    GL_RELATIVE_PATHS[0]="(root)"
    GL_LEVELS[0]=0

    echo "---------------------------------------------------------------"
    echo "                                LEVEL - 0"
    echo "---------------------------------------------------------------"
    echo "(0) $(basename "$git_root") (root)"

    # Start recursive collection from root
    gl_find_submodules_recursive "$git_root" 1

    # Display organized by levels
    gl_display_by_levels
}

function gl_find_submodules_recursive() {
    # Recursively find submodules in a given directory and its subdirectories
    #
    # USAGE:
    #   gl_find_submodules_recursive <current_dir> <level>
    #
    # PARAMETERS:
    #   current_dir  - Directory to scan for submodules
    #   level        - Current nesting level (used for organization)
    #
    # BEHAVIOR:
    #   - Scans current directory for git submodules using 'git submodule status'
    #   - Recursively processes each discovered submodule
    #   - Populates global arrays with submodule information
    #   - Prevents duplicate entries in the global arrays
    #   - Handles nested submodules by incrementing the level counter

    if ! validate_params 2 "gl_find_submodules_recursive" "Directory to scan for submodules" "Current nesting level"; then
        return 1
    fi

    local current_dir="$1"
    local level="$2"
    local git_root="${GL_PATHS[0]}"

    # Validate parameters
    if [[ ! -d "$current_dir" ]]; then
        echo "Error: Directory '$current_dir' does not exist." >&2
        return 1
    fi

    if [[ ! "$level" =~ ^[0-9]+$ ]]; then
        echo "Error: Level '$level' must be a numeric value." >&2
        return 1
    fi

    # Check if current directory has .git (is a git repo)
    if [ ! -d "$current_dir/.git" ] && [ ! -f "$current_dir/.git" ]; then
        return
    fi

    # Get submodules in current directory
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        # Extract the path from the output
        local submodule_path
        submodule_path=$(echo "$line" | awk '{print $2}')

        if [ -n "$submodule_path" ]; then
            local full_path="$current_dir/$submodule_path"

            # Check if we already have this path
            local already_exists=false
            for existing_path in "${GL_PATHS[@]}"; do
                if [ "$existing_path" = "$full_path" ]; then
                    already_exists=true
                    break
                fi
            done

            if [ "$already_exists" = false ]; then
                # Add to arrays
                local index=${#GL_PATHS[@]}
                GL_PATHS[$index]="$full_path"
                GL_LEVELS[$index]=$level

                # Calculate relative path from git root
                local rel_path="${full_path#$git_root/}"
                GL_RELATIVE_PATHS[$index]="$rel_path"

                # Recursively check this submodule for its own submodules
                if [ -d "$full_path" ]; then
                    gl_find_submodules_recursive "$full_path" $((level + 1))
                fi
            fi
        fi
    done < <(cd "$current_dir" 2>/dev/null && git submodule status 2>/dev/null)
}

function gl_display_by_levels() {
    # Display collected submodules organized by their nesting levels
    #
    # USAGE:
    #   gl_display_by_levels
    #
    # BEHAVIOR:
    #   - Reads from global arrays populated by gl_collect_all_submodules
    #   - Sorts submodules by their nesting level for organized display
    #   - Groups submodules under level headers (LEVEL - 0, LEVEL - 1, etc.)
    #   - Displays each submodule with its index number and relative path
    #   - Skips the root directory (index 0) as it's already displayed
    #
    # DISPLAY FORMAT:
    #   ---------------------------------------------------------------
    #                                LEVEL - 1
    #   ---------------------------------------------------------------
    #   (1) path/to/submodule
    #   (2) another/submodule/path

    local current_level=-1

    # Sort indices by level, then by path
    local -a sorted_indices
    for i in "${!GL_PATHS[@]}"; do
        if [ $i -eq 0 ]; then continue; fi # Skip root
        sorted_indices+=($i)
    done

    # Simple bubble sort by level
    for ((i = 0; i < ${#sorted_indices[@]}; i++)); do
        for ((j = i + 1; j < ${#sorted_indices[@]}; j++)); do
            local idx1=${sorted_indices[i]}
            local idx2=${sorted_indices[j]}
            if [ ${GL_LEVELS[idx1]} -gt ${GL_LEVELS[idx2]} ]; then
                # Swap
                local temp=${sorted_indices[i]}
                sorted_indices[i]=${sorted_indices[j]}
                sorted_indices[j]=$temp
            fi
        done
    done

    # Display sorted by levels
    for idx in "${sorted_indices[@]}"; do
        local level=${GL_LEVELS[idx]}

        # Print level header when level changes
        if [ $level -ne $current_level ]; then
            echo "---------------------------------------------------------------"
            echo "                                LEVEL - $level"
            echo "---------------------------------------------------------------"
            current_level=$level
        fi

        echo "($idx) ${GL_RELATIVE_PATHS[idx]}"
    done
}

function just_commit() {
    local message="${@:-"just committed"}"
    just_commit_push "$message" "false"
}

function just_push() {
    local message="${@:-"just pushed"}"
    just_commit_push "$message" "true"
}

function just_commit_all() {
    message="${@:-"just committed"}"

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Function to commit in a single repository
    commit_repo() {
        local repo_path="$1"
        local commit_message="$2"

        cd "$repo_path" || return 1

        # Always do git add . first to catch untracked files
        git add .

        # Now check if there are any changes (staged or unstaged)
        if git diff --quiet && git diff --staged --quiet; then
            true # No changes to commit
        else
            log_info "📁 Processing: $repo_path"
            git commit -m "/// $commit_message" && log_ok "   🦝: $commit_message"
            echo ""
        fi
    }

    # Store the original directory
    local original_dir=$(pwd)

    # Commit in main repository first
    commit_repo "$original_dir" "$message"

    # Process all submodules
    process_submodules_recursive "commit_repo" "$message"

    # Check if submodule commits created changes in main repo
    if ! git diff --quiet; then
        log_info "📦 Committing submodule updates in main repository..."
        git add . && git commit -m "/// Updated submodules: $message" && log_ok "🦝: Updated submodules: $message"
    fi
}

function just_push_all() {
    local message="${@:-"just pushed"}"

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Function to commit and push in a single repository
    push_repo() {
        local repo_path="$1"
        local push_message="$2"
        local repo_name=$(basename "$repo_path")

        cd "$repo_path" || return 1

        # Always do git add . first to catch untracked files
        git add .

        # Check if there are any changes to commit
        if git diff --quiet && git diff --staged --quiet; then
            # No changes to commit, check if there are unpushed commits
            local unpushed=$(git log --oneline @{u}.. 2>/dev/null | wc -l)
            if [ "$unpushed" -gt 0 ]; then
                log_info "📁 Processing: $repo_name"
                log_info "   📤 Pushing $unpushed unpushed commit(s)..."
                git push && log_ok "   🦝 Pushed: $repo_name"
                echo ""
            fi
        else
            # Commit and push changes
            log_info "📁 Processing: $repo_name"
            git commit -m "/// $push_message" && git push && log_ok "   🦝: $push_message"
            echo ""
        fi
    }

    # Store the original directory
    local original_dir=$(pwd)

    # Process main repository first
    push_repo "$original_dir" "$message"

    # Process all submodules
    process_submodules_recursive "push_repo" "$message"

    # Check if submodule commits created changes in main repo
    if ! git diff --quiet; then
        log_info "📦 Committing and pushing submodule updates in main repository..."
        git add . && git commit -m "/// Updated submodules: $message" && git push && log_ok "🦝: Updated submodules: $message"
    else
        # Check for unpushed commits in main repo
        local unpushed=$(git log --oneline @{u}.. 2>/dev/null | wc -l)
        if [ "$unpushed" -gt 0 ]; then
            log_info "📤 Pushing unpushed commits in main repository..."
            git push && log_ok "🦝 Main repo pushed"
        fi
    fi
}

# -----------------------------------
#      just-committed discovery
# -----------------------------------

# Helpers shared by find_just_committed_all. Matches are stored in parallel
# indexed arrays (bash 3.2 compatible - no associative arrays / mapfile).
# FJC_M_REL[i]    relative path from the scan base ('' means the base itself)
# FJC_M_ABS[i]    absolute repository path
# FJC_M_NAME[i]   display name of the repository
# FJC_M_MSG[i]    HEAD commit subject (always starts with '/// ')
# FJC_M_HASH[i]   short commit hash
# FJC_M_AUTHOR[i] commit author
# FJC_M_DATE[i]   relative commit date
# FJC_M_BRANCH[i] current branch (or 'detached HEAD')
# FJC_NODES[]     every directory/leaf that leads to a match (tree building)

function fjc_reset() {
    # Reset all discovery state used by find_just_committed_all
    FJC_M_REL=()
    FJC_M_ABS=()
    FJC_M_NAME=()
    FJC_M_MSG=()
    FJC_M_HASH=()
    FJC_M_AUTHOR=()
    FJC_M_DATE=()
    FJC_M_BRANCH=()
    FJC_NODES=()
}

function fjc_parse_code_workspace() {
    # Parse a VSCode multi-root .code-workspace file
    # Args: $1 - path to the .code-workspace file
    # Output: one line per folder: "<name>\t<absolute path>"
    local ws_file="$1"

    if [ ! -f "$ws_file" ]; then
        log_error "❌ Workspace file not found: $ws_file"
        return 1
    fi

    local py
    py=$(command -v python3 || command -v python || true)
    if [ -z "$py" ]; then
        log_error "❌ python3 is required to parse code-workspace files"
        return 1
    fi

    "$py" - "$ws_file" <<'PY'
import json
import os
import sys

ws_file = sys.argv[1]
with open(ws_file, "r", encoding="utf-8") as handle:
    workspace = json.load(handle)

base = os.path.dirname(os.path.abspath(ws_file))
for folder in workspace.get("folders", []):
    path = folder.get("path", "")
    if not path:
        continue
    name = folder.get("name") or os.path.basename(os.path.normpath(path))
    abspath = os.path.normpath(os.path.join(base, path))
    sys.stdout.write("%s\t%s\n" % (name, abspath))
PY
}

function fjc_check_and_add() {
    # Record a repository only when its HEAD commit starts with '/// '
    # Args: $1 - relative path from the scan base ('' for the base itself)
    #       $2 - absolute repository path
    #       $3 - display name
    local rel_path="$1"
    local repo_path="$2"
    local repo_name="$3"

    if [ ! -d "$repo_path" ]; then
        return 1
    fi

    if ! git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi

    local head_message
    head_message=$(git -C "$repo_path" log -1 --pretty=format:"%s" HEAD 2>/dev/null)

    if [[ "$head_message" != "/// "* ]]; then
        return 1
    fi

    # Skip duplicates (keeps the first, shallowest entry)
    local existing
    for existing in "${FJC_M_ABS[@]}"; do
        if [ "$existing" = "$repo_path" ]; then
            return 0
        fi
    done

    FJC_M_REL+=("$rel_path")
    FJC_M_ABS+=("$repo_path")
    FJC_M_NAME+=("$repo_name")
    FJC_M_MSG+=("$head_message")
    FJC_M_HASH+=("$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null)")
    FJC_M_AUTHOR+=("$(git -C "$repo_path" log -1 --pretty=format:"%an" HEAD 2>/dev/null)")
    FJC_M_DATE+=("$(git -C "$repo_path" log -1 --pretty=format:"%cr" HEAD 2>/dev/null)")
    FJC_M_BRANCH+=("$(git -C "$repo_path" symbolic-ref --short -q HEAD 2>/dev/null || echo 'detached HEAD')")
    return 0
}

function fjc_collect_submodules() {
    # Recursively scan git submodules below a repository and record matches
    # Args: $1 - repository directory to scan
    #       $2 - base directory used to compute relative paths
    local repo_dir="$1"
    local base_dir="$2"

    if [ ! -d "$repo_dir" ]; then
        return 0
    fi

    if ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi

    local sub_abs rel_path sub_name
    while IFS= read -r sub_abs; do
        [ -z "$sub_abs" ] && continue
        rel_path="${sub_abs#"$base_dir"/}"
        sub_name=$(basename "$sub_abs")
        fjc_check_and_add "$rel_path" "$sub_abs" "$sub_name"
    done < <(cd "$repo_dir" && git submodule foreach --recursive --quiet 'echo "$PWD"' 2>/dev/null)
}

function fjc_collect_workspace() {
    # Collect matching repositories from a VSCode .code-workspace file
    # Args: $1 - path to the .code-workspace file
    local ws_file="$1"
    local base_dir
    base_dir=$(cd "$(dirname "$ws_file")" && pwd)

    local folder_name folder_path rel_path
    while IFS=$'\t' read -r folder_name folder_path; do
        [ -z "$folder_path" ] && continue

        if [ "$folder_path" = "$base_dir" ]; then
            rel_path=""
        else
            rel_path="${folder_path#"$base_dir"/}"
            # Folders outside the workspace base fall back to their basename
            if [ "$rel_path" = "$folder_path" ] || [[ "$rel_path" == /* ]]; then
                rel_path=$(basename "$folder_path")
            fi
        fi

        fjc_check_and_add "$rel_path" "$folder_path" "$folder_name"
        # Folders may themselves contain submodules worth reporting
        fjc_collect_submodules "$folder_path" "$base_dir"
    done < <(fjc_parse_code_workspace "$ws_file")
}

function fjc_collect_current_repo() {
    # Collect matches from a repository and all of its submodules
    # Args: $1 - git repository root
    local git_root="$1"
    fjc_check_and_add "" "$git_root" "$(basename "$git_root")"
    fjc_collect_submodules "$git_root" "$git_root"
}

function fjc_add_node() {
    # Add a tree node path if it is not already present
    local candidate="$1"
    local existing
    for existing in "${FJC_NODES[@]}"; do
        if [ "$existing" = "$candidate" ]; then
            return 0
        fi
    done
    FJC_NODES+=("$candidate")
}

function fjc_build_nodes() {
    # Populate FJC_NODES with match leaves and all of their ancestor directories
    FJC_NODES=()
    local i rel_path node_path
    for i in "${!FJC_M_REL[@]}"; do
        rel_path="${FJC_M_REL[$i]}"
        [ -z "$rel_path" ] && continue
        node_path="$rel_path"
        while [ -n "$node_path" ] && [ "$node_path" != "." ]; do
            fjc_add_node "$node_path"
            node_path=$(dirname "$node_path")
        done
    done
}

function fjc_match_index() {
    # Print the match index for a relative path, or fail when not a match
    local rel_path="$1"
    local i
    for i in "${!FJC_M_REL[@]}"; do
        if [ "${FJC_M_REL[$i]}" = "$rel_path" ]; then
            printf '%s' "$i"
            return 0
        fi
    done
    return 1
}

function fjc_detail_for() {
    # Build the inline commit detail suffix for a tree node
    # Args: $1 - relative path ('' for the root)
    #       $2 - 'true' to include hash/author/date/branch details
    local rel_path="$1"
    local verbose="$2"
    local index

    if ! index=$(fjc_match_index "$rel_path"); then
        return 0
    fi

    local detail=" ${ANSIFmt__bright_green:-}🦝${ANSIFmt__reset:-} ${FJC_M_MSG[$index]}"
    if [[ "$verbose" == "true" || "$verbose" == "-v" ]]; then
        detail+=" ${ANSIFmt__gray:-}[${FJC_M_HASH[$index]} by ${FJC_M_AUTHOR[$index]} (${FJC_M_DATE[$index]})]${ANSIFmt__reset:-}"
        detail+=" ${ANSIFmt__gray:-}🌿 ${FJC_M_BRANCH[$index]}${ANSIFmt__reset:-}"
    fi
    printf '%s' "$detail"
}

function fjc_has_children() {
    # Return 0 when a tree node has at least one child
    local parent="$1"
    local node_path node_parent
    for node_path in "${FJC_NODES[@]}"; do
        node_parent=$(dirname "$node_path")
        [ "$node_parent" = "." ] && node_parent=""
        if [ "$node_parent" = "$parent" ]; then
            return 0
        fi
    done
    return 1
}

function fjc_print_children() {
    # Recursively render the ASCII tree for the children of a node
    # Args: $1 - parent relative path ('' for the root)
    #       $2 - prefix string used for indentation/connectors
    #       $3 - 'true' to include verbose commit details
    local parent="$1"
    local prefix="$2"
    local verbose="$3"

    local -a children=()
    local node_path node_parent
    for node_path in "${FJC_NODES[@]}"; do
        node_parent=$(dirname "$node_path")
        [ "$node_parent" = "." ] && node_parent=""
        if [ "$node_parent" = "$parent" ]; then
            children+=("$node_path")
        fi
    done

    local count=${#children[@]}
    if [ "$count" -eq 0 ]; then
        return 0
    fi

    # Sort children deterministically without mapfile (for bash 3.2 support)
    local sorted line
    sorted=$(printf '%s\n' "${children[@]}" | LC_ALL=C sort)
    children=()
    while IFS= read -r line; do
        children+=("$line")
    done <<<"$sorted"

    local i label connector new_prefix
    for ((i = 0; i < count; i++)); do
        node_path="${children[$i]}"
        label=$(basename "$node_path")

        if [ $((i + 1)) -eq "$count" ]; then
            connector="└── "
            new_prefix="${prefix}    "
        else
            connector="├── "
            new_prefix="${prefix}│   "
        fi

        echo "${prefix}${connector}${label}$(fjc_detail_for "$node_path" "$verbose")"

        if fjc_has_children "$node_path"; then
            fjc_print_children "$node_path" "$new_prefix" "$verbose"
        fi
    done
}

function fjc_render_tree() {
    # Render the full ASCII tree of repositories with '/// ' HEAD commits
    # Args: $1 - root label
    #       $2 - 'true' to include verbose commit details
    local root_label="$1"
    local verbose="$2"

    fjc_build_nodes
    printf '%s\n' "${root_label}$(fjc_detail_for "" "$verbose")"
    fjc_print_children "" "" "$verbose"
}

function find_just_committed_all() {
    # Find repositories whose current HEAD commit starts with '/// '
    #
    # USAGE:
    #   find_just_committed_all [<workspace>|<dir>] [-v|--details]
    #
    # ARGUMENTS:
    #   <workspace>    Path to a VSCode .code-workspace file. When provided,
    #                  its folders (and their submodules) are scanned instead
    #                  of the current repository.
    #   <dir>          A directory inside a git repository to scan.
    #   -v|--details   Show commit hash, author, date and branch inline.
    #
    # OUTPUT:
    #   An ASCII tree of the matching repositories, nested by path. Only
    #   repositories with a '/// ' commit at HEAD are shown.
    local workspace_file=""
    local scan_dir=""
    local show_details="false"

    local arg
    for arg in "$@"; do
        case "$arg" in
        true)
            show_details="true"
            ;;
        false)
            show_details="false"
            ;;
        -v | --details | --verbose)
            show_details="true"
            ;;
        *.code-workspace)
            workspace_file="$arg"
            ;;
        "")
            ;;
        *)
            if [ -d "$arg" ]; then
                scan_dir="$arg"
            else
                workspace_file="$arg"
            fi
            ;;
        esac
    done

    log_info "🔍 Searching for repositories with '/// ' commits at current HEAD..."

    fjc_reset

    local root_label
    if [ -n "$workspace_file" ]; then
        if [ ! -f "$workspace_file" ]; then
            log_error "❌ Workspace file not found: $workspace_file"
            return 1
        fi
        root_label=$(basename "$workspace_file")
        root_label="${root_label%.code-workspace}"
        log_info "🗂️  Reading code-workspace: $workspace_file"
        fjc_collect_workspace "$workspace_file"
    elif [ -n "$scan_dir" ]; then
        if ! git -C "$scan_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
            log_error "❌ Not a git repository: $scan_dir"
            return 1
        fi
        root_label=$(basename "$(git -C "$scan_dir" rev-parse --show-toplevel)")
        fjc_collect_current_repo "$(git -C "$scan_dir" rev-parse --show-toplevel)"
    else
        # Validate git repository and fall back to the current one + submodules
        if ! validate_git_repo; then
            return 1
        fi
        root_label=$(basename "$GIT_ROOT")
        fjc_collect_current_repo "$GIT_ROOT"
    fi

    local found_count=${#FJC_M_REL[@]}

    if [ "$found_count" -eq 0 ]; then
        log_info "📊 Found 0 repositories with '/// ' commits at current HEAD"
        return 0
    fi

    echo ""
    fjc_render_tree "$root_label" "$show_details"
    echo ""
    log_info "📊 Found $found_count repositories with '/// ' commits at current HEAD"
}

function remove_submodule() {
    local submodule_path="$1"

    if [ -z "$submodule_path" ]; then
        log_info "Usage: remove_submodule <submodule_path>"
        return 1
    fi

    if [ ! -d "$submodule_path" ]; then
        log_error "Submodule path '$submodule_path' does not exist"
        return 1
    fi

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    log_info "Removing submodule: $submodule_path"

    # Step 1: Deinitialize the submodule
    git submodule deinit -f "$submodule_path"

    # Step 2: Remove from git index and working tree
    git rm -f "$submodule_path"

    # Step 3: Remove from .git/modules (if exists)
    if [ -d ".git/modules/$submodule_path" ]; then
        rm -rf ".git/modules/$submodule_path"
    fi

    # Step 4: Clean up any remaining config
    git config --remove-section "submodule.$submodule_path" 2>/dev/null || true

    log_ok "Submodule '$submodule_path' removed successfully"
    log_warning "Don't forget to commit the changes!"
}

function git_ls_large_objects() {
    git rev-list --objects --all |
        git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
        sort -k3 -n -r
}

function git_ls_ignored_files() {
    # List ignored directories in the git repository
    # Shows directories that are ignored by .gitignore and not tracked by git
    git ls-files --others --ignored --exclude-standard
}

function git_ls_ignored_directories() {
    # List ignored directories in the git repository
    # Shows directories that are ignored by .gitignore and not tracked by git
    git ls-files --others --ignored --exclude-standard --directory
}

# Export public API functions
export -f gl gl_quick_jump gl_search gl_interactive
export -f just_commit just_push just_commit_all just_push_all
export -f find_just_committed_all remove_submodule
export -f git_ls_large_objects git_ls_ignored_files git_ls_ignored_directories
export -f git_remember_passwords git_remember_credentials git_trust_current_dir just_amend

# Export internal helpers (needed by public functions in subshells)
export -f validate_params validate_git_repo change_directory process_submodules_recursive
export -f gl_collect_all_submodules gl_find_submodules_recursive gl_display_by_levels
export -f just_commit_push

# Export just-committed discovery helpers
export -f fjc_reset fjc_parse_code_workspace fjc_check_and_add fjc_collect_submodules
export -f fjc_collect_workspace fjc_collect_current_repo fjc_add_node fjc_build_nodes
export -f fjc_match_index fjc_detail_for fjc_has_children fjc_print_children fjc_render_tree
