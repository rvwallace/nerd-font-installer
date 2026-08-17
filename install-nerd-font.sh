#!/usr/bin/env bash

set -euo pipefail

FONTS_JSON_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json"
RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

# Determine default font installation directory
if [[ -n "${FONT_DIR:-}" ]]; then
    TARGET_FONT_DIR="$FONT_DIR"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    TARGET_FONT_DIR="${HOME}/Library/Fonts"
else
    TARGET_FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
fi

TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

check_dependencies() {
    local require_fzf="${1:-true}"
    local missing_deps=()
    local deps=("curl" "jq" "unzip")

    if [[ "$require_fzf" == "true" ]]; then
        deps+=("fzf")
    fi

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install them and try again." >&2
        exit 1
    fi
}

fetch_fonts_data() {
    echo "Fetching Nerd Fonts catalog..." >&2
    if ! curl -sSfL "$FONTS_JSON_URL"; then
        echo "Error: Failed to fetch fonts catalog from $FONTS_JSON_URL" >&2
        exit 1
    fi
}

format_fonts_for_fzf() {
    local fonts_data="$1"
    echo "$fonts_data" | jq -r '.fonts[] | [
        .patchedName,
        .version,
        .description,
        .folderName,
        .unpatchedName,
        .licenseId,
        (if .isMonospaced then "Yes" else "No" end)
    ] | @tsv' | awk -F'\t' '{
        ver = ($2 != "-" && $2 != "") ? "v" $2 : "-"
        printf "%-20s\t%-16s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, ver, $3, $4, $1, $5, $6, $7
    }'
}

list_fonts() {
    local fonts_data="$1"
    echo "$fonts_data" | jq -r '.fonts[] | [
        .patchedName,
        .version,
        .folderName,
        .description
    ] | @tsv' | awk -F'\t' 'BEGIN {
        printf "%-20s  %-16s  %-26s  %s\n", "FONT NAME", "VERSION", "RELEASE ASSET", "DESCRIPTION"
        printf "%-20s  %-16s  %-26s  %s\n", "---------", "-------", "-------------", "-----------"
    } {
        ver = ($2 != "-" && $2 != "") ? "v" $2 : "-"
        printf "%-20s  %-16s  %-26s  %s\n", $1, ver, $3, $4
    }'
}

select_fonts() {
    local formatted_data="$1"

    echo "$formatted_data" | fzf \
        --multi \
        --ansi \
        --height=80% \
        --border \
        --delimiter=$'\t' \
        --with-nth=1..3 \
        --prompt="Select Nerd Font(s) > " \
        --header="TAB: Multi-select | ENTER: Install | ESC: Quit
Font Name             Version           Description" \
        --preview='printf "\033[1mFont:\033[0m        %s\n\033[1mOriginal:\033[0m    %s\n\033[1mPackage:\033[0m     %s.zip\n\033[1mVersion:\033[0m     %s\n\033[1mLicense:\033[0m     %s\n\033[1mMonospaced:\033[0m  %s\n\n\033[1mDescription:\033[0m\n%s\n" "{5}" "{6}" "{4}" "{2}" "{7}" "{8}" "{3}"' \
        --preview-window="right:45%:wrap,<100(bottom:45%:wrap)"
}

download_and_install_font() {
    local font_name="$1"
    local folder_name="$2"

    local download_url="${RELEASE_URL}/${folder_name}.zip"
    TEMP_DIR=$(mktemp -d)
    local zip_file="${TEMP_DIR}/${folder_name}.zip"

    echo "==> Downloading ${font_name} (${folder_name}.zip)..."
    if ! curl -fL --progress-bar -o "$zip_file" "$download_url"; then
        echo "Error: Failed to download font from $download_url" >&2
        rm -rf "$TEMP_DIR"
        TEMP_DIR=""
        return 1
    fi

    echo "==> Extracting font files..."
    if ! unzip -q "$zip_file" -d "$TEMP_DIR"; then
        echo "Error: Failed to extract ${folder_name}.zip" >&2
        rm -rf "$TEMP_DIR"
        TEMP_DIR=""
        return 1
    fi

    mkdir -p "$TARGET_FONT_DIR"

    echo "==> Installing font files to $TARGET_FONT_DIR..."
    local count=0
    while IFS= read -r -d '' font_file; do
        cp -f "$font_file" "$TARGET_FONT_DIR/"
        ((count++)) || true
    done < <(find "$TEMP_DIR" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)

    rm -rf "$TEMP_DIR"
    TEMP_DIR=""

    if [[ $count -eq 0 ]]; then
        echo "Warning: No .ttf or .otf font files found in archive." >&2
        return 1
    fi

    echo "Successfully installed ${font_name} ($count font file(s))."
    return 0
}

update_font_cache() {
    echo ""
    echo "Updating system font cache..."
    if command -v fc-cache &> /dev/null; then
        fc-cache -f "$TARGET_FONT_DIR" 2>/dev/null || true
        echo "Font cache updated."
    else
        echo "Note: fc-cache not found; fonts installed in $TARGET_FONT_DIR are ready for use."
    fi
}

show_help() {
    cat << EOF
Nerd Font Installer

Interactive CLI and batch installer for Nerd Fonts.

USAGE:
    ./install-nerd-font.sh [OPTIONS] [FONT_NAMES...]

OPTIONS:
    -h, --help          Show this help message and exit
    -l, --list          List all available Nerd Fonts with versions and descriptions
    -d, --dir DIR       Specify custom font installation directory (overrides FONT_DIR)

ARGUMENTS:
    FONT_NAMES...       One or more font names to install non-interactively (e.g. Hack "JetBrains Mono" FiraCode)
                        If no font names are specified, interactive fzf selection is launched.

INTERACTIVE CONTROLS (fzf):
    Type                Search / filter fonts
    Up / Down           Navigate font list
    Tab / Shift-Tab     Toggle multi-selection
    Enter               Confirm and install selected font(s)
    Esc / Ctrl+C        Cancel and exit

ENVIRONMENT VARIABLES:
    FONT_DIR            Custom font destination directory
                        (Default: macOS: ~/Library/Fonts, Linux: \${XDG_DATA_HOME:-\$HOME/.local/share}/fonts)

EXAMPLES:
    ./install-nerd-font.sh                             # Interactive browser with preview
    ./install-nerd-font.sh Hack                        # Install Hack directly
    ./install-nerd-font.sh Hack JetBrainsMono Cascadia # Install multiple fonts
    ./install-nerd-font.sh --list                      # List available fonts
    ./install-nerd-font.sh -d ~/.fonts Hack            # Install to custom directory
EOF
}

find_font_match() {
    local query="$1"
    local fonts_data="$2"

    echo "$fonts_data" | jq -r --arg q "$query" '
        def norm: ascii_downcase | gsub("[-_ ]"; "");
        .fonts[] | select(
            (.patchedName | norm) == ($q | norm) or
            (.folderName | norm) == ($q | norm) or
            (.unpatchedName | norm) == ($q | norm) or
            ((.caskName // "") | norm) == ($q | norm)
        ) | [.folderName, .patchedName] | @tsv
    ' | head -n 1
}

main() {
    local direct_fonts=()
    local do_list=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                do_list=true
                shift
                ;;
            -d|--dir)
                if [[ $# -lt 2 ]]; then
                    echo "Error: Option $1 requires a directory argument." >&2
                    exit 1
                fi
                TARGET_FONT_DIR="$2"
                shift 2
                ;;
            --dir=*)
                TARGET_FONT_DIR="${1#*=}"
                shift
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Run '$0 --help' for usage." >&2
                exit 1
                ;;
            *)
                direct_fonts+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$do_list" == "true" ]]; then
        check_dependencies false
        local fonts_data
        fonts_data=$(fetch_fonts_data)
        list_fonts "$fonts_data"
        exit 0
    fi

    if [[ ${#direct_fonts[@]} -gt 0 ]]; then
        check_dependencies false
        local fonts_data
        fonts_data=$(fetch_fonts_data)
        local installed_count=0
        local failed_fonts=()

        for query in "${direct_fonts[@]}"; do
            local match
            match=$(find_font_match "$query" "$fonts_data")
            if [[ -z "$match" ]]; then
                echo "Error: Font '$query' not found in Nerd Fonts catalog. Run with --list to view available fonts." >&2
                failed_fonts+=("$query")
                continue
            fi

            local folder_name font_name
            IFS=$'\t' read -r folder_name font_name <<< "$match"

            echo ""
            echo "Selected: $font_name ($folder_name)"
            if download_and_install_font "$font_name" "$folder_name"; then
                ((installed_count++)) || true
            else
                failed_fonts+=("$query")
            fi
        done

        if [[ $installed_count -gt 0 ]]; then
            update_font_cache
            echo ""
            echo "Successfully installed $installed_count font family(ies) to $TARGET_FONT_DIR"
        fi

        if [[ ${#failed_fonts[@]} -gt 0 ]]; then
            echo "" >&2
            echo "Failed to install: ${failed_fonts[*]}" >&2
            exit 1
        fi
        exit 0
    fi

    # Interactive mode
    check_dependencies true

    local fonts_data
    fonts_data=$(fetch_fonts_data)

    local formatted_data
    formatted_data=$(format_fonts_for_fzf "$fonts_data")

    local selections
    selections=$(select_fonts "$formatted_data") || true

    if [[ -z "$selections" ]]; then
        echo "No font selected. Exiting."
        exit 0
    fi

    local installed_count=0
    local failed_fonts=()

    while IFS=$'\t' read -r _display_name _ver _desc folder_name font_name _orig _lic _mono; do
        [[ -z "$folder_name" ]] && continue
        echo ""
        echo "Selected: $font_name"
        if download_and_install_font "$font_name" "$folder_name"; then
            ((installed_count++)) || true
        else
            failed_fonts+=("$font_name")
        fi
    done <<< "$selections"

    if [[ $installed_count -gt 0 ]]; then
        update_font_cache
        echo ""
        echo "Successfully installed $installed_count font family(ies) to $TARGET_FONT_DIR"
        echo "You may need to restart your terminal or application to use the new fonts."
    fi

    if [[ ${#failed_fonts[@]} -gt 0 ]]; then
        echo "" >&2
        echo "Failed to install: ${failed_fonts[*]}" >&2
        exit 1
    fi
}

main "$@"
