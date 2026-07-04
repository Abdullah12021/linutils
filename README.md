# linutils

A modular, cozy, and highly customizable post-installation setup script for Arch Linux. Choose between a clean, customized 256-color CLI menu or a modern TUI checklist powered by `gum`.

---

## Usage

### Remote Run (Instantly from GitHub)
Run the script on any fresh Arch Linux install without downloading files manually:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abdullah12021/linutils/main/linutils.sh) remote
```

### Local Run
Clone the repository, make the script executable, and run it:
```bash
git clone https://github.com/Abdullah12021/linutils.git
cd linutils
chmod +x linutils.sh
./linutils.sh
```

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
