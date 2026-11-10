#!/bin/bash
# ==============================================================
#                            APIS
# ==============================================================

function asyncapi_yaml_to_md() {
    # Generate markdown documentation from AsyncAPI spec files
    # Args: path(s) to AsyncAPI YAML spec files
    if [ $# -lt 1 ]; then
        echo "Usage: asyncapi_yaml_to_md /path/to/spec.yml [...]" >&2
        return 1
    fi

    local spec_file spec_dir spec_basename tmpdir output_file

    for spec_file in "$@"; do
        if [ ! -f "$spec_file" ]; then
            log_error "Spec file not found: $spec_file"
            return 1
        fi

        spec_dir="$(dirname "$spec_file")"
        spec_basename="$(basename "$spec_file" .yml)"
        tmpdir="$spec_dir/.asyncapi-tmp-$spec_basename"

        mkdir -p "$tmpdir"

        log_info "Generating docs for: $spec_file"
        asyncapi generate fromTemplate \
            "$spec_file" \
            @asyncapi/markdown-template@2.0.0 \
            -o "$tmpdir" \
            --force-write

        output_file="$spec_dir/$spec_basename.md"
        mv "$tmpdir/asyncapi.md" "$output_file"

        rm -rf "$tmpdir"

        log_ok "Generated: $output_file"
    done
}

# Export public API functions
export -f asyncapi_yaml_to_md
