#!/bin/bash
# ==============================================================
#                          DISPLAY
# ==============================================================
# Interactive xrandr wizard to set display resolution

function display_set_resolution() {
    local output width height mode_line mode_name

    if [[ "$(uname)" != "Linux" ]]; then
        echo "display_set_resolution is only available on Linux systems with X11"
        return 1
    fi
    if ! command -v xrandr &>/dev/null; then
        echo "ERROR: xrandr not found"
        return 1
    fi

    if [[ $# -ge 3 ]]; then
        output="$1"
        width="$2"
        height="$3"
    elif [[ $# -eq 0 ]]; then
        local outputs=() name
        while IFS= read -r name; do
            outputs+=("$name")
        done < <(xrandr --current | awk '/ connected / {print $1}')

        if [[ ${#outputs[@]} -eq 0 ]]; then
            echo "No connected displays found"
            return 1
        fi

        if [[ ${#outputs[@]} -eq 1 ]]; then
            output="${outputs[0]}"
            echo "Detected display: $output"
        else
            echo "Select a display:"
            select output in "${outputs[@]}"; do
                if [[ -n "$output" ]]; then
                    break
                fi
                echo "Invalid selection, try again."
            done
        fi

        local current
        current=$(xrandr --current | awk -v out="$output" '
            $0 ~ "^" out " connected" {c=1; next}
            c && /^\s/ {if (/\*/) {print $1; exit}}
            c && !/^\s/ {exit}
        ')

        echo "Current: $output @ ${current:-unknown}"
        echo ""
        echo "--- Available modes ---"
        xrandr --current | awk -v out="$output" '
            $0 ~ "^" out " connected" {c=1; next}
            c && /^\s/ {print "  " $0; if ($1 != "" && $1 != "+") avail[m++]=$1}
            c && !/^\s/ {exit}
        '
        echo ""

        local input
        read -r -p "Enter desired width x height (e.g. 1920x1080): " input
        if [[ "$input" == *"x"* ]]; then
            width="${input%%x*}"
            height="${input##*x}"
        else
            read -r -p "Enter width: " width
            read -r -p "Enter height: " height
        fi
    else
        echo "Usage: display_set_resolution [<output> <width> <height>]"
        return 1
    fi

    if [[ ! "$width" =~ ^[0-9]+$ ]] || [[ ! "$height" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Width and height must be numbers"
        return 1
    fi

    local suggested_w="$width" suggested_h="$height"
    if (( width % 8 != 0 )); then
        local nearest=$(( (width + 4) / 8 * 8 ))
        echo "Width $width is not divisible by 8. Suggested: $nearest"
        local yn
        read -r -p "Use $nearest instead? [Y/n]: " yn
        if [[ ! "$yn" =~ ^[Nn] ]]; then
            suggested_w=$nearest
        fi
    fi
    if (( height % 8 != 0 )); then
        local nearest=$(( (height + 4) / 8 * 8 ))
        echo "Height $height is not divisible by 8. Suggested: $nearest"
        local yn
        read -r -p "Use $nearest instead? [Y/n]: " yn
        if [[ ! "$yn" =~ ^[Nn] ]]; then
            suggested_h=$nearest
        fi
    fi
    width=$suggested_w
    height=$suggested_h

    mode_line=$(xrandr --current | awk -v out="$output" -v res="${width}x${height}" '
        $0 ~ "^" out " connected" {c=1; next}
        c && /^\s/ {if ($1 == res) {found=$1; exit}}
        c && !/^\s/ {exit}
        END {print found}
    ')
    mode_name="${width}x${height}"

    if [[ -n "$mode_line" ]]; then
        echo "Mode ${width}x${height} already exists — applying..."
        xrandr --output "$output" --mode "$mode_name" || {
            echo "ERROR: Failed to set resolution ${width}x${height}"
            return 1
        }
    else
        echo "Custom mode ${width}x${height} — generating modeline..."
        local gtf_out modeline
        gtf_out=$(gtf "$width" "$height" 60 2>/dev/null)
        if [[ -z "$gtf_out" ]]; then
            echo "ERROR: gtf command failed or not found"
            return 1
        fi
        modeline=$(printf '%s\n' "$gtf_out" | grep 'Modeline' | sed 's/^  Modeline //')
        if [[ -z "$modeline" ]]; then
            echo "ERROR: Could not parse modeline from gtf output"
            return 1
        fi
        mode_name=$(printf '%s\n' "$modeline" | awk '{print $1}' | tr -d '"')
        modeline=$(printf '%s\n' "$modeline" | tr -d '"')

        xrandr --newmode $modeline 2>&1 | grep -v "already exists" || true
        xrandr --addmode "$output" "$mode_name" 2>/dev/null || {
            echo "WARNING: Mode '$mode_name' could not be added to $output"
            return 1
        }
        xrandr --output "$output" --mode "$mode_name" || {
            echo "ERROR: Failed to set resolution ${width}x${height}"
            return 1
        }
    fi

    echo "Display $output set to ${width}x${height}"
    xrandr --listmonitors | grep -w "$output"
}

export -f display_set_resolution