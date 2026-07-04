# linutils

A modular, cozy, and highly customizable post-installation setup script for Arch Linux. Choose between a clean, customized 256-color CLI menu or a modern TUI checklist powered by `gum`.

---

## Features

- **Dual Interfaces:**
  - **Cozy CLI Mode:** A custom 256-color terminal design with clear single-column listing and vertical bar separators (`│`).
  - **Modern TUI Mode (Gum):** An interactive multi-selection checklist displaying group categories with neat spacing.
- **Hardware-Aware Safety:** Automatically detects CPU (`intel`/`amd`) and GPU (`intel`/`amd`/`nvidia`) types to filter out incorrect microcodes (e.g. preventing `intel-ucode` install on an AMD CPU) and ensure correct graphics drivers.
- **Silent Bootstrapping:** Automatically installs `gum` if you choose TUI mode and it's missing on the target machine (using cached credentials to keep it silent).
- **Decoupled Architecture:** Built to separate package lists, installer routines, dotfiles configuration management, and wallpapers.
- **Zero-Footprint Remote Run:** Sourced and executed directly from GitHub via a single `curl` command. Temporary files are cleared automatically upon exiting.

---

## Usage

### Remote Run (Instantly from GitHub)
Run the script on any fresh Arch Linux install without downloading files manually:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abdullah12021/linutils/main/linutils.sh) remote
```

### Local Run
Clone the repository and run it locally:
```bash
git clone https://github.com/Abdullah12021/linutils.git
cd linutils
bash linutils.sh
```

---

## CLI Flags
Customize execution behavior using command line flags:

| Flag | Description |
| :--- | :--- |
| `--gum` | Force launch in TUI mode (installs `gum` automatically if missing) |
| `--sys-conf` | Configure multilib, refresh keyring, and rank pacman mirrors via `reflector` |
| `--install-all` | Run non-interactive installations for all category lists |
| `--category <name>` | Install packages from a specific category list non-interactively |
| `--help` | Display the help menu |

---

## Repository Structure

```text
linutils/
├── linutils.sh           # Main entry point and interactive menu loader
├── config.env            # User configuration defaults
├── src/
│   ├── core.sh           # Environment detection, colors, and logging utilities
│   ├── pacman_conf.sh    # Pacman multilib, reflector mirror-ranking, keyring sync
│   └── install_pkgs.sh   # Package list parser, selection engine, and installation hooks
└── packages/             # Text files containing package lists grouped by subcategory
    ├── hardware.list     # CPU microcode, GPU drivers, firmware
    ├── system.list       # System daemons, audio, security, CLI network tools
    ├── desktop.list      # Window managers, applets, lockers, display managers
    ├── user.list         # User-facing applications (browsers, editors)
    ├── cli.list          # Shell enhancements, CLI utilities, archive tools
    └── dev.list          # Development headers, runtimes, compilers
```

---

## Customization

To modify which packages get installed:
1. Open any `.list` file inside the `packages/` directory.
2. Group your packages under brackets like `# [Web Browsers]`.
3. Put each package name on its own line.
4. Save the file and push it to your GitHub repository to update your online remote installer!
