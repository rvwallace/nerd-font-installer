#!/usr/bin/env bash

set -euo pipefail

FONTS_JSON_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json"
RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
FONT_DIR="${HOME}/.local/share/fonts"

if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="${HOME}/Library/Fonts"
fi

check_dependencies() {
    local missing_deps=()
    
    for cmd in fzf curl jq unzip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

fetch_fonts_data() {
    echo "Fetching Nerd Fonts data..." >&2
    curl -sL "$FONTS_JSON_URL"
}

format_for_fzf() {
    jq -r '.fonts[] | 
        "\(.patchedName)|\(.description)|\(.version)|\(.folderName)"' | 
        awk -F'|' '{
            name = $1
            desc = $2
            ver = $3
            folder = $4
            printf "%-25s  v%-10s  %s\n", name, ver, desc
        }'
}

select_font() {
    local fonts_data="$1"

    echo "$fonts_data" | format_for_fzf | \
        fzf --height=80% \
            --border \
            --exact \
            --prompt="Select a Nerd Font to install: " \
            --header="Font Name                  Version     Description" \
}

extract_font_name() {
    echo "$1" | awk '{print $1}'
}

get_folder_name() {
    local font_name="$1"
    local fonts_data="$2"
    
    echo "$fonts_data" | jq -r --arg name "$font_name" \
        '.fonts[] | select(.patchedName == $name) | .folderName'
}

download_and_install() {
    local font_name="$1"
    local folder_name="$2"
    
    local download_url="${RELEASE_URL}/${folder_name}.zip"
    local temp_dir=$(mktemp -d)
    local zip_file="${temp_dir}/${folder_name}.zip"
    
    echo "Downloading ${font_name}..."
    if ! curl -L --progress-bar -o "$zip_file" "$download_url"; then
        echo "Error: Failed to download font from $download_url"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    echo "Extracting font files..."
    unzip -q "$zip_file" -d "$temp_dir"
    
    mkdir -p "$FONT_DIR"
    
    echo "Installing font files to $FONT_DIR..."
    find "$temp_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) \
        -exec cp {} "$FONT_DIR/" \;
    
    rm -rf "$temp_dir"
    
    echo "Updating font cache..."
    if command -v fc-cache &> /dev/null; then
        fc-cache -f "$FONT_DIR"
    fi
    
    echo ""
    echo "Successfully installed ${font_name}!"
    echo "Location: $FONT_DIR"
    echo ""
    echo "You may need to restart your terminal or application to use the new font."
}

main() {
    check_dependencies
    
    local fonts_data
    fonts_data=$(fetch_fonts_data)
    
    if [ -z "$fonts_data" ]; then
        echo "Error: Failed to fetch fonts data"
        exit 1
    fi
    
    local selection
    selection=$(select_font "$fonts_data")
    
    if [ -z "$selection" ]; then
        echo "No font selected. Exiting."
        exit 0
    fi
    
    local font_name
    font_name=$(extract_font_name "$selection")
    
    local folder_name
    folder_name=$(get_folder_name "$font_name" "$fonts_data")
    
    if [ -z "$folder_name" ]; then
        echo "Error: Could not determine folder name for $font_name"
        exit 1
    fi
    
    echo ""
    echo "Selected: $font_name"
    echo ""
    
    download_and_install "$font_name" "$folder_name"
}

main "$@"
