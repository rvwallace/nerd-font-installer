# Nerd Font Installer

An interactive bash script to browse and install Nerd Fonts using fzf.

## Features

- Browse all available Nerd Fonts with descriptions
- View font version information
- Interactive selection with fzf
- Automatic download and installation
- Installs to the appropriate system font directory
- Updates font cache

## Requirements

The script requires the following tools to be installed:

- `fzf` - Fuzzy finder for interactive selection
- `curl` - For downloading fonts
- `jq` - For parsing JSON data
- `unzip` - For extracting font archives

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install fzf curl jq unzip
```

**Fedora:**
```bash
sudo dnf install fzf curl jq unzip
```

**Arch Linux:**
```bash
sudo pacman -S fzf curl jq unzip
```

**macOS:**
```bash
brew install fzf curl jq unzip
```

## Usage

Simply run the script:

```bash
./install-nerd-font.sh
```

The script will:
1. Fetch the latest list of available Nerd Fonts
2. Display an interactive list with font names, versions, and descriptions
3. Allow you to select a font using fzf
4. Download and install the selected font
5. Update the font cache

### Navigation in fzf

- Type to search/filter fonts
- Use arrow keys or `Ctrl-j`/`Ctrl-k` to navigate
- Press `Enter` to select a font
- Press `Esc` or `Ctrl-c` to cancel

## Installation Locations

- **Linux:** `~/.local/share/fonts`
- **macOS:** `~/Library/Fonts`

## License

This script is provided as-is. The Nerd Fonts themselves are licensed under their respective licenses. See the [Nerd Fonts repository](https://github.com/ryanoasis/nerd-fonts) for more information.
