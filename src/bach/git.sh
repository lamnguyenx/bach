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
    git add .
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

function find_just_committed_all() {
    local show_details="${1:-false}"

    # Validate git repository
    if ! validate_git_repo; then
        return 1
    fi

    # Function to check current commit in a repository
    check_repo() {
        local repo_path="$1"
        local repo_name=$(basename "$repo_path")

        cd "$repo_path" || return 1

        # Get the current commit (HEAD) message
        local head_message=$(git log -1 --pretty=format:"%s" HEAD 2>/dev/null)

        if [[ "$head_message" == "/// "* ]]; then
            local commit_hash=$(git rev-parse --short HEAD)
            local commit_date=$(git log -1 --pretty=format:"%cr" HEAD)
            local author=$(git log -1 --pretty=format:"%an" HEAD)

            log_info "🦝 $repo_name"
            log_info "   💬 $head_message"
            log_info "   📍 $commit_hash by $author ($commit_date)"

            if [[ "$show_details" == "true" || "$show_details" == "-v" ]]; then
                log_info "   📂 $repo_path"
                log_info "   🌿 $(git branch --show-current 2>/dev/null || echo 'detached HEAD')"
            fi
            echo ""
            return 0
        fi
        return 1
    }

    local original_dir=$(pwd)
    local found_count=0

    log_info "🔍 Searching for repositories with '/// ' commits at current HEAD..."
    echo ""

    # Check main repository
    if check_repo "$original_dir"; then
        ((found_count++))
    fi

    # Check all submodules recursively
    check_submodule_repo() {
        local repo_path="$1"
        if check_repo "$repo_path"; then
            ((found_count++))
        fi
    }

    process_submodules_recursive "check_submodule_repo" ""

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
