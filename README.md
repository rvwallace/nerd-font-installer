# Nerd Font Installer

A bash script to search, preview, and install [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts).

## Features

- **Interactive Search**: Search the Nerd Fonts catalog with `fzf`.
- **Details Preview**: View font versions, license data, and descriptions before download.
- **Batch Selection**: Select multiple fonts with `Tab` to install them in one pass.
- **Direct CLI Mode**: Pass font names as arguments for dotfiles and scripts.
- **Catalog List**: Print all available fonts and versions with `--list`.
- **System Detection**: Installs fonts to standard user font folders on macOS and Linux.
- **Cache Refresh**: Updates fontconfig cache after installation.
- **Clean Teardown**: Removes temporary download files on completion or exit.

## Requirements

Install these command-line tools:

- `curl` - Download fonts and catalog data
- `jq` - Parse font metadata
- `unzip` - Extract font archives
- `fzf` - Interactive fuzzy search (optional for direct CLI mode)

### Install Dependencies

**macOS (Homebrew):**
```bash
brew install fzf curl jq unzip
```

**Ubuntu / Debian:**
```bash
sudo apt update && sudo apt install fzf curl jq unzip
```

**Fedora:**
```bash
sudo dnf install fzf curl jq unzip
```

**Arch Linux:**
```bash
sudo pacman -S fzf curl jq unzip
```

## Usage

### Interactive Mode

Run the script without arguments:

```bash
./install-nerd-font.sh
```

| Key | Action |
| --- | --- |
| `Type` | Search fonts |
| `Up` / `Down` or `Ctrl-k` / `Ctrl-j` | Move selection |
| `Tab` / `Shift-Tab` | Select or deselect multiple fonts |
| `Enter` | Install selected font(s) |
| `Esc` / `Ctrl-c` | Cancel |

---

### Command-Line Mode

Install fonts directly by name:

```bash
# Install a single font
./install-nerd-font.sh Hack

# Install multiple fonts
./install-nerd-font.sh Hack "JetBrains Mono" CascadiaCode FiraCode
```

Font names are case-insensitive. You can pass patched names, package names, or original family names.

---

### List Fonts

Print all available fonts:

```bash
./install-nerd-font.sh --list
```

---

### Custom Target Directory

Specify an install path with `-d` or the `FONT_DIR` variable:

```bash
# With command line option
./install-nerd-font.sh -d ~/.local/share/custom-fonts Hack

# With environment variable
FONT_DIR=/opt/custom/fonts ./install-nerd-font.sh
```

## Target Directories

- **macOS:** `~/Library/Fonts`
- **Linux:** `${XDG_DATA_HOME:-$HOME/.local/share}/fonts`

## Options

```
OPTIONS:
    -h, --help          Show help message and exit
    -l, --list          List all available Nerd Fonts with versions and descriptions
    -d, --dir DIR       Specify custom font installation directory (overrides FONT_DIR)
```

## License

This project uses the MIT License. Upstream font licenses apply to individual font files. See the [Nerd Fonts repository](https://github.com/ryanoasis/nerd-fonts) for details.
