#!/bin/bash
# ==============================================================
#                         COMMON
# ==============================================================
# Consolidated common utilities for development environment
# Contains essentials, args, proxies, and misc functions

# -----------------------------------
#            essentials
# -----------------------------------

function get_host_ip() {
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: try multiple interfaces
        echo "${HOST_IP:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")}"
    else
        # Linux: use hostname -I
        echo "${HOST_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")}"
    fi
}

function get_host_model() {
    local model
    if [ "$(uname)" = "Darwin" ]; then
        model=$(sysctl -n hw.model 2>/dev/null || echo "Unknown")
    else
        model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
    fi
    # Use slugify_v3 to normalize the model name
    model=$(slugify_v2 "$model")
    # Truncate if longer than 16 characters
    if [ ${#model} -gt 16 ]; then
        echo "${model:0:13}[..]"
    else
        echo "$model"
    fi
}

# Determine the best date command for precision
if command -v gdate >/dev/null 2>&1; then
    DATE_CMD="gdate"
else
    DATE_CMD="date"
fi

function get_timeslug() {
    $DATE_CMD +"%Y.%m.%d__%Hh%Mm%Ss.%3N"
}

function slugify() {
    local value="$1"

    # Remove non-ASCII characters (similar to Python's encode('ascii', 'ignore'))
    # Use tr to delete non-ASCII characters (0x80-0xFF)
    value=$(printf '%s' "$value" | LC_ALL=C tr -d '\200-\377')

    # Remove characters that are not word characters, spaces, or hyphens
    value=$(printf '%s' "$value" | sed 's/[^[:alnum:]_[:space:]-]//g')

    # Strip leading and trailing whitespace and convert to lowercase
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')

    # Replace multiple consecutive hyphens/spaces with single hyphen
    value=$(printf '%s' "$value" | tr -s '[:space:]-' '-')

    printf '%s' "$value"
}

function slugify_v2() {
    local value="$1"

    # Remove non-ASCII characters (similar to Python's encode('ascii', 'ignore'))
    # Use tr to delete non-ASCII characters (0x80-0xFF)
    value=$(printf '%s' "$value" | LC_ALL=C tr -d '\200-\377')

    # Remove characters that are not dots, word characters, spaces, or hyphens
    value=$(printf '%s' "$value" | sed 's/[^.[:alnum:]_[:space:]-]//g')

    # Strip leading and trailing whitespace
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Replace multiple consecutive hyphens/spaces with single hyphen
    value=$(printf '%s' "$value" | tr -s '[:space:]-' '-')

    printf '%s' "$value"
}

function slugify_v2() {
    local value="$1"

    # Remove non-ASCII characters (similar to Python's encode('ascii', 'ignore'))
    # Use tr to delete non-ASCII characters (0x80-0xFF)
    value=$(printf '%s' "$value" | LC_ALL=C tr -d '\200-\377')

    # Remove characters that are not dots, word characters, spaces, or hyphens
    value=$(printf '%s' "$value" | sed 's/[^.[:alnum:]_[:space:]-]//g')

    # Strip leading and trailing whitespace
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Replace multiple hyphens/spaces with single hyphen
    value=$(printf '%s' "$value" | sed 's/[-[:space:]]\{1,\}/-/g')

    printf '%s' "$value"
}

function slugify_v3() {
    local value="$1"

    # Remove non-ASCII characters (similar to Python's encode('ascii', 'ignore'))
    # Use tr to delete non-ASCII characters (0x80-0xFF)
    value=$(printf '%s' "$value" | LC_ALL=C tr -d '\200-\377')

    # Remove characters that are not dots, word characters (including underscore), spaces, or hyphens
    value=$(printf '%s' "$value" | sed 's/[^.[:alnum:]_[:space:]-]//g')

    # Strip leading and trailing whitespace
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    printf '%s' "$value"
}

# -----------------------------------
#              args
# -----------------------------------

function parse_args() {
    local -a remaining_args=()

    # Process all arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry)
            shift
            ;;
        --live)
            shift
            ;;
        --config)
            if [[ -z "$2" || "$2" =~ ^-- ]]; then
                echo "Error: --config requires a filename" >&2
                return 1
            fi
            local config_file="$2"
            if [[ -f "$config_file" ]]; then
                # shellcheck disable=SC1090
                source "$config_file"
            else
                echo "Error: Config file '$config_file' not found" >&2
                return 1
            fi
            shift 2
            ;;
        --help | -h)
            return 1 # This will trigger help display in main function
            ;;
        --*)
            echo "Error: Unknown option $1" >&2
            return 1
            ;;
        *)
            # Positional argument - save it
            remaining_args+=("$1")
            shift 1
            ;;
        esac
    done

    # Replace the original arguments with remaining ones
    set -- "${remaining_args[@]}"
    return 0
}

# -----------------------------------
#            proxies
# -----------------------------------

function urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for ((pos = 0; pos < strlen; pos++)); do
        c=${string:$pos:1}
        case "$c" in
        [-_.~a-zA-Z0-9]) o="${c}" ;;
        *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

function unset_proxy() {

    unset PROXY_NAME
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY
    unset socks_proxy
    unset SOCKS_PROXY
    unset REQUESTS_CA_BUNDLE
    unset NODE_EXTRA_CA_CERTS
    unset NO_PROXY
}

function remove_proxy() { unset_proxy; }

function set_legacy_proxy() {
    unset_proxy
    # legacy proxy, used to install pip, conda packages
    # more restricted that s5 proxy, but might useful on CI/CD servers
    export http_proxy="http://$(get_host_ip):7126"
    export https_proxy="http://$(get_host_ip):7126"
    export HTTP_PROXY="http://$(get_host_ip):7126"
    export HTTPS_PROXY="http://$(get_host_ip):7126"
    export NO_PROXY="localhost,127.0.0.1,0.0.0.0,.local,.internal,.sslip.io"

    print_proxy
}

# -----------------------------------
#             misc
# -----------------------------------

function print_proxy() {

    local parent_func="${FUNCNAME[1]:-<shell>}"

    echo "+---------------------+"
    echo "| > called by         |" "$parent_func"
    echo "| PROXY_NAME          |" "${PROXY_NAME:-"<<unset>>"}"
    echo "| http_proxy          |" "${http_proxy:-"<<unset>>"}"
    echo "| HTTP_PROXY          |" "${HTTP_PROXY:-"<<unset>>"}"
    echo "| https_proxy         |" "${https_proxy:-"<<unset>>"}"
    echo "| HTTPS_PROXY         |" "${HTTPS_PROXY:-"<<unset>>"}"
    echo "| socks_proxy         |" "${socks_proxy:-"<<unset>>"}"
    echo "| SOCKS_PROXY         |" "${SOCKS_PROXY:-"<<unset>>"}"
    echo "| no_proxy            |" "${no_proxy:-"<<unset>>"}"
    echo "| NO_PROXY            |" "${NO_PROXY:-"<<unset>>"}"
    echo "| REQUESTS_CA_BUNDLE  |" "${REQUESTS_CA_BUNDLE:-"<<unset>>"}"
    echo "| NODE_EXTRA_CA_CERTS |" "${NODE_EXTRA_CA_CERTS:-"<<unset>>"}"
    echo "+---------------------+"
}

function accept_all() {
    if [ "$(uname)" != "Linux" ]; then
        echo "accept_all (iptables) is only available on Linux systems"
        return 1
    fi

    local IP=$1

    sudo iptables -I INPUT -p tcp -s "$IP" -j ACCEPT
    sudo iptables -I OUTPUT -p tcp -d "$IP" -j ACCEPT
}

function list_swap() {
    if [ "$(uname)" != "Linux" ]; then
        echo "list_swap is only available on Linux systems"
        return 1
    fi
    find /proc -maxdepth 2 -path "/proc/[0-9]*/status" -readable -exec awk -v FS=":" '{process[$1]=$2;sub(/^[ \t]+/,"",process[$1]);} END {if(process["VmSwap"] && process["VmSwap"] != "0 kB") printf "%10s %-30s %20s\n",process["Pid"],process["Name"],process["VmSwap"]}' '{}' \; |
        awk '{print $(NF-1),$0}' |
        sort -h |
        cut -d " " -f2-

}

function rename_easy() {
    local input_dir="$1"
    local source_string="$2"
    local target_string="$3"

    # Validate inputs
    if [ $# -ne 3 ]; then
        echo "Usage: rename_easy <input_dir> <source_string> <target_string>"
        return 1
    fi

    if [ ! -d "$input_dir" ]; then
        echo "Error: Directory '$input_dir' does not exist"
        return 1
    fi

    if [ -z "$source_string" ]; then
        echo "Error: Source string cannot be empty"
        return 1
    fi

    echo "Starting rename operation..."
    echo "Input directory: $input_dir"
    echo "Source string: $source_string"
    echo "Target string: $target_string"
    echo "----------------------------------------"

    # Function to rename a single item
    rename_item() {
        local item="$1"
        local dirname
        dirname=$(dirname "$item")
        local basename
        basename=$(basename "$item")

        # Check if basename contains source string
        if [[ "$basename" == *"$source_string"* ]]; then
            local new_basename="${basename//$source_string/$target_string}"
            local new_path="$dirname/$new_basename"

            log_info "src:" "$item"
            log_info "tgt:" "$new_path"
            if mv "$item" "$new_path"; then
                log_ok "✓ OK"
            else
                log_error "✗ FAILED"
            fi
        fi
    }

    # Process files first (depth-first approach)
    # Find all files and sort by depth (deepest first)
    find "$input_dir" -type f -name "*$source_string*" |
        awk '{print length($0), $0}' | sort -rn | cut -d' ' -f2- |
        while IFS= read -r file; do
            [ -e "$file" ] && rename_item "$file"
        done

    # Process directories (deepest first to avoid path issues)
    find "$input_dir" -type d -name "*$source_string*" |
        awk '{print length($0), $0}' | sort -rn | cut -d' ' -f2- |
        while IFS= read -r dir; do
            [ -d "$dir" ] && rename_item "$dir"
        done

    # Finally, rename the input directory itself if it contains source string
    local input_dirname
    input_dirname=$(dirname "$input_dir")
    local input_basename
    input_basename=$(basename "$input_dir")

    if [[ "$input_basename" == *"$source_string"* ]]; then
        local new_input_basename="${input_basename//$source_string/$target_string}"
        local new_input_dir="$input_dirname/$new_input_basename"

        log_info "src:" "$input_dir"
        log_info "tgt:" "$new_input_dir"
        if mv "$input_dir" "$new_input_dir"; then
            log_ok "✓ OK"
        else
            log_error "✗ FAILED"
        fi
    fi

}

HOST_IP=$(get_host_ip)
export HOST_IP
HOST_MODEL=$(get_host_model)
export HOST_MODEL
export USER=${USER:-"$(id -un)"}
