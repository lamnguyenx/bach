#!/bin/bash
# ==============================================================
#                           DOCKER
# ==============================================================
alias dc="docker-compose"

# -----------------------------------
#         core utilities
# -----------------------------------

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

function filter_docker_services() {
    # Filter docker-compose services based on patterns
    # Args: patterns to match (if none provided, returns all services)
    # Returns: space-separated list of matched service names
    # Sets: FILTERED_SERVICES array with matched services
    local patterns=("$@")

    # Get all services from docker-compose
    local profile_flag=""
    if [ -n "$COMPOSE_PROFILES" ]; then
        for p in $(echo "$COMPOSE_PROFILES" | tr ',' ' '); do
            profile_flag="$profile_flag --profile $p"
        done
    fi
    if [ -z "$profile_flag" ]; then
        profile_flag="--profile dev"
    fi
    local all_services
    all_services=$(docker-compose $profile_flag config --services 2>/dev/null | sort | uniq)
    if [ $? -ne 0 ]; then
        log_error "Failed to get docker-compose services. Are you in a directory with docker-compose.yml?"
        return 1
    fi

    # Filter services based on patterns
    FILTERED_SERVICES=()
    if [ ${#patterns[@]} -eq 0 ]; then
        # If no patterns provided, match all services
        for service in $all_services; do
            FILTERED_SERVICES+=("$service")
        done
    else
        for service in $all_services; do
            local matched=false
            for pattern in "${patterns[@]}"; do
                # Auto-add ^ and $ for exact matching if not present
                local regex_pattern="$pattern"
                if [[ $regex_pattern != ^* ]]; then
                    regex_pattern="^$regex_pattern"
                fi
                if [[ $regex_pattern != *$ ]]; then
                    regex_pattern="$regex_pattern$"
                fi
                if [[ $service =~ $regex_pattern ]]; then
                    matched=true
                    break
                fi
            done
            if $matched; then
                FILTERED_SERVICES+=("$service")
            fi
        done
    fi

    # Check if any services matched
    if [ ${#FILTERED_SERVICES[@]} -eq 0 ]; then
        if [ ${#patterns[@]} -eq 0 ]; then
            log_error "No services found in docker-compose configuration"
        else
            log_error "No services matched patterns: ${patterns[*]}"
        fi
        return 1
    fi

    return 0
}

function docker_compose_operation() {
    # Perform docker-compose operations with proper error handling
    # Args: $1 - operation name for logging
    #       remaining args - docker-compose command and arguments
    local operation="$1"
    shift

    log_info "🔄 $operation: $*"
    if docker-compose "$@"; then
        log_ok "✅ $operation completed successfully"
        return 0
    else
        log_error "❌ $operation failed"
        return 1
    fi
}






# -----------------------------------
#         utility functions
# -----------------------------------

function slugify_docker() {
    # Convert docker image names to filesystem-safe slugs
    # Args: $1 - docker image name (e.g., "nginx:latest")
    # Returns: slugified version (e.g., "nginx__latest")
    if ! validate_params 1 "slugify_docker" "docker image name"; then
        return 1
    fi

    local image_name="$1"
    # Replace problematic characters but keep structure recognizable
    # Replace '/' with '_' and ':' with '__'
    local slug=$(echo "$image_name" | sed 's|/|_|g' | sed 's|:|__|g')
    echo "$slug"
}

function validate_docker_image_for_extraction() {
    local func_name="$1"
    local image="$2"
    if ! validate_params 1 "$func_name" "docker image name"; then
        return 1
    fi
    if ! docker image inspect "$image" &>/dev/null; then
        log_error "❌ Image '$image' not found locally"
        return 1
    fi
    log_info "🔍 Extracting Dockerfile content from: $image"
    return 0
}

# -----------------------------------
#         docker operations
# -----------------------------------

function enter() {
    # Enter a running docker container with bash or sh fallback
    # Args: $1 - container ID or name
    if ! validate_params 1 "enter" "container ID or name"; then
        return 1
    fi

    local container_id="$1"
    log_info "🔗 Entering container: $container_id"

    if docker exec -it "$container_id" bash 2>/dev/null; then
        log_ok "✅ Exited container successfully"
    elif docker exec -it "$container_id" sh 2>/dev/null; then
        log_ok "✅ Exited container successfully (using sh)"
    else
        log_error "❌ Failed to enter container '$container_id'"
        return 1
    fi
}

function dcl() {
    # Follow docker-compose logs with default tail of 100 lines
    # Args: service names (optional - follows all if none provided)
    log_info "📋 Following docker-compose logs (tail 100)"
    docker-compose logs --no-log-prefix -f --tail 100 "$@"
}

# -----------------------------------
#     docker-compose operations
# -----------------------------------

function hotloadl() {
    $DC kill "$@" && \
    $DC up -d --no-deps --force-recreate "$@" && \
    $DC logs --no-log-prefix -f --tail 100 "$@"
}

function hotload() {
    # Hot reload docker-compose services with pattern matching
    # Args: patterns to match service names (optional - matches all if none provided)
    local patterns=("$@")

    # Filter services based on patterns
    if ! filter_docker_services "${patterns[@]}"; then
        return 1
    fi

    # Display which services will be restarted
    log_info "🔄 Restarting services: ${FILTERED_SERVICES[*]}"

    # Restart the matched services
    docker_compose_operation "Killing services" kill "${FILTERED_SERVICES[@]}" && \
    docker_compose_operation "Starting services" up -d --no-deps --force-recreate "${FILTERED_SERVICES[@]}" && \
    docker_compose_operation "Following logs" logs -f "${FILTERED_SERVICES[@]}"
}

function coldload() {
    # Cold start docker-compose services with pattern matching
    # Args: patterns to match service names (optional - matches all if none provided)
    local patterns=("$@")

    # Filter services based on patterns
    if ! filter_docker_services "${patterns[@]}"; then
        return 1
    fi

    # Display which services will be restarted
    log_info "🚀 Starting services: ${FILTERED_SERVICES[*]}"

    # Start the matched services
    docker_compose_operation "Starting services" up -d "${FILTERED_SERVICES[@]}" && \
    docker_compose_operation "Following logs" logs -f "${FILTERED_SERVICES[@]}"
}

function hotkill() {
    # Kill docker-compose services with pattern matching
    # Args: patterns to match service names (optional - matches all if none provided)
    local patterns=("$@")

    # Filter services based on patterns
    if ! filter_docker_services "${patterns[@]}"; then
        return 1
    fi

    # Kill the matched services
    docker_compose_operation "Killing services" kill "${FILTERED_SERVICES[@]}"
}


function hotlogs() {
    # Follow logs for docker-compose services with pattern matching
    # Args: patterns to match service names (optional - matches all if none provided)
    local patterns=("$@")

    # Filter services based on patterns
    if ! filter_docker_services "${patterns[@]}"; then
        return 1
    fi

    # Follow logs for matched services
    log_info "📋 Following logs for services: ${FILTERED_SERVICES[*]}"
    docker_compose_operation "Following logs" logs -f --tail 500 "${FILTERED_SERVICES[@]}"
}




function send_docker_image_via_pipe() {
    # Send a docker image to a remote server via SSH pipe
    # Args: $1 - image name, $2 - SSH server alias
    if ! validate_params 2 "send_docker_image_via_pipe" "docker image name" "SSH server alias"; then
        return 1
    fi

    local image_name="$1"
    local server_alias="$2"

    # Check if image exists locally
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        log_error "❌ Image '$image_name' not found locally"
        return 1
    fi

    # Test SSH connection
    if ! ssh -o ConnectTimeout=5 "$server_alias" "echo 'OK'" >/dev/null 2>&1; then
        log_error "❌ Cannot connect to $server_alias via SSH"
        return 1
    fi

    log_info "📦 Sending $image_name to $server_alias..."

    # Get image size for progress bar
    local image_size=$(docker image inspect "$image_name" --format='{{.Size}}')

    # Send with compression and progress
    if docker save "$image_name" | pv -s "$image_size" 2>/dev/null | gzip | ssh "$server_alias" 'gunzip | docker load'; then
        log_ok "✅ Successfully sent $image_name to $server_alias"
    else
        log_error "❌ Transfer failed"
        return 1
    fi
}


# -----------------------------------
#         image operations
# -----------------------------------
function get_dockerfile_content() {
    # Extract Dockerfile content from a docker image
    # Args: $1 - image name
    if ! validate_docker_image_for_extraction "get_dockerfile_content" "$1"; then
        return 1
    fi

    local image="$1"
    dfimage "$image"
}

function get_dockerfile_content_legacy() {
    # Extract Dockerfile content from a docker image
    # Args: $1 - image name
    if ! validate_docker_image_for_extraction "get_dockerfile_content_legacy" "$1"; then
        return 1
    fi

    local image="$1"
    docker history --no-trunc "$image" \
        | sed '1!G;h;$!d' \
        | tr -s ' ' \
        | cut -d " " -f 5- \
        | sed 's,^/bin/sh -c #(nop) ,,g' \
        | sed 's,^/bin/sh -c,RUN,g' \
        | sed 's, && ,\n  & ,g' \
        | sed 's,\s*[0-9]*[\.]*[0-9]*\s*[kMG]*B\s*$,,g' \
        | sed '$d'
}

# -----------------------------------
#       advanced operations
# -----------------------------------

function dc_replace_tag() {
    # Tag Docker images with new tags based on existing image names in docker-compose
    # Define options as variables (dry run disabled by default)
    local dry=false
    local live=false
    local profile=""

    # Define help message with proper indentation
    local help_message="\
    Usage: dc_replace_tag [options] <source_string> <target_string>

    Tag Docker images with new tags based on existing image names in docker-compose.

    Options:
        --dry [true|false]      Show what would be tagged without actually tagging (default: false)
                                   Can be used as flag: --dry (same as --dry true)
        --live [true|false]     Check only running services, not all configured (default: false)
                                   Can be used as flag: --live (same as --live true)
        --config <file>         Load options from config file
        --help|-h               Show this help message

    Arguments:
        source_string           String to search for in image names
        target_string           String to replace with for new tags

    Examples:
        dc_replace_tag v1.0.0 v1.1.0
        dc_replace_tag --dry v1.0.0 v1.1.0
        dc_replace_tag --live --dry v1.0.0 v1.1.0
        dc_replace_tag --config my-config.sh v1.0.0 v1.1.0

    Config file example:
        dry=true
        live=false
    "

    # Store original arguments for processing
    local -a original_args=("$@")

    # Parse arguments
    parse_args "${original_args[@]}" || {
        printf "%s\n" "$help_message" >&2
        return 1
    }

    # After parse_args, we need to get the remaining positional arguments
    # We'll reprocess to extract them
    local -a positional_args=()
    local skip_next=false

    for arg in "${original_args[@]}"; do
        if [[ $skip_next == true ]]; then
            skip_next=false
            continue
        fi

        case $arg in
            --dry)
                if [[ ${original_args[*]} =~ --dry[[:space:]]+(true|false) ]]; then
                    skip_next=true
                fi
                ;;
            --live)
                if [[ ${original_args[*]} =~ --live[[:space:]]+(true|false) ]]; then
                    skip_next=true
                fi
                ;;
            --config)
                skip_next=true
                ;;
            --help|-h)
                ;;
            --*)
                ;;
            *)
                positional_args+=("$arg")
                ;;
        esac
    done

    # Get remaining arguments (source and target strings)
    local source_string="${positional_args[0]}"
    local target_string="${positional_args[1]}"

    # Validate required arguments - show help if missing
    if [ -z "$source_string" ] || [ -z "$target_string" ]; then
        printf "%s\n" "$help_message" >&2
        return 1
    fi

    # Get profile flag
    local profile_flag=""
    if [ -n "$COMPOSE_PROFILES" ]; then
        for p in $(echo "$COMPOSE_PROFILES" | tr ',' ' '); do
            profile_flag="$profile_flag --profile $p"
        done
    fi
    if [ -z "$profile_flag" ]; then
        profile_flag="--profile dev"
    fi

    # Get list of images based on mode
    local images_list=""
    if [ "$live" = "true" ]; then
        echo "=== Checking running services ==="
        images_list=$(docker-compose $profile_flag ps --format "table {{.Service}}\t{{.Image}}" \
            | tail -n +2)
    else
        echo "=== Checking all configured services ==="
        images_list=$(docker-compose $profile_flag config \
            | grep -E '^\s*image:' \
            | sed 's/.*image: //' \
            | sort \
            | uniq \
            | awk '{print "service\t" $0}')
    fi

    # Filter images that contain the source string
    local matching_images=$(echo "$images_list" \
        | grep "$source_string")

    if [ -z "$matching_images" ]; then
        log_info "ℹ️ No images found containing: $source_string"
        return 0
    fi

    # Always show dry run first (preview)
    echo ""
    echo "--------------------------------------------------------------"
    echo "                          dry-run"
    echo "--------------------------------------------------------------"
    echo ""
    echo "=== Docker tag commands that would be executed ==="
    echo "$matching_images" \
        | while read service_name image_name; do
            local new_image_name=$(echo "$image_name" | sed "s|${source_string}|${target_string}|g")
            echo "    docker tag \\"
            echo "        $image_name \\"
            echo "        $new_image_name"
            echo ""
        done

    # If dry run mode, exit after showing preview
    if [ "$dry" = "true" ]; then
        return 0
    fi

    # Ask for confirmation before proceeding
    echo ""
    echo "--------------------------------------------------------------"
    read -p "Do you want to proceed with tagging? (y/N): " -n 1 -r
    echo ""
    echo "--------------------------------------------------------------"

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "ℹ️ Operation cancelled by user"
        return 0
    fi

    # Actually tag the images
    echo ""
    echo "=== Tagging images ==="
    local success_count=0
    local total_count=0

    echo "$matching_images" \
        | while read service_name image_name; do
            local new_image_name=$(echo "$image_name" | sed "s|${source_string}|${target_string}|g")
            total_count=$((total_count + 1))

            echo "Tagging: $image_name -> $new_image_name"
            if docker tag "$image_name" "$new_image_name"; then
                success_count=$((success_count + 1))
                echo "    ✓ Success"
            else
                echo "    ✗ Failed"
            fi
            echo ""
        done

    log_ok "✅ Tagged $success_count/$total_count images successfully"
    echo ""
    log_info "📋 Next steps:"
    echo "1. Update your docker-compose.yml manually if needed"
    echo "2. Push new tags: docker push <new_image_name>"
    echo "3. Update services: docker-compose pull && docker-compose up -d"
}