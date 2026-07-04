# linutils Project Instructions & Context

This document captures the context, architectural decisions, and next steps for building the custom Arch Linux installer script.

---

## 1. Project Context & Reference Analysis

Based on the exploration of your friend's repositories (`~/read_here/linutils` and `~/read_here/dotfiles`), we identified two main evolution patterns:
- **Distro focus shift:** The older `linutils` attempted cross-distro package mapping (Debian/Ubuntu, Fedora, Arch, NixOS), leading to massive wrapper complexities. This custom version is **strictly specialized for Arch Linux**, stripping out all non-Arch distro compatibility rules.
- **Architectural separation:** The newer `dotfiles` (Hub V2) moved to a matrix-driven, decoupled system where installer scripts are placed directly inside independent sub-repositories. We are adopting this clean decoupling: `linutils` handles the system bootstrap and packages, while the dotfiles configurations (and their symlinking) will remain in a separate repository to be connected later.

---

## 2. Directory Architecture

The workspace is initialized as follows:

```text
~/dev/linutils/
├── linutils.sh             # Main entry point (bootstrap loader)
├── config.env              # Environment/default configuration variables
├── instructions.md         # This document (Project context and roadmap)
│
├── packages/               # Category-based package lists (Arch only)
│   ├── system.list
│   ├── desktop.list
│   ├── apps.list
│   ├── cli.list
│   ├── media.list
│   ├── dev.list
│   └── aesthetics.list
│
└── src/                    # Non-interactive backend logic
    ├── core.sh             # Helper functions, sudo, logging
    ├── pacman_conf.sh      # Arch repository setup (multilib, mirrors)
    └── install_pkgs.sh     # Official & AUR installer wrappers
```

---

## 3. Module Breakdown & Responsibilities

### `src/core.sh`
- **Output Styling:** Initialize colors (`$GREEN`, `$RED`, `$RESET`) and status prefixes (`[ OK ]`, `[ERROR]`, `[WARN]`).
- **Helpers:** Functions like `command_exists` and `check_sudo` (verifying/caching sudo permissions cleanly).
- **Logging:** Standardized logging output.

### `src/pacman_conf.sh`
- **Keyrings:** Routines to verify system keyrings before starting packages installations to avoid signature errors.
- **Multilib:** Uncommenting `[multilib]` repositories in `/etc/pacman.conf` if not already present.
- **Mirrors:** Ranking mirror lists with `reflector`.

### `src/install_pkgs.sh`
- **AUR Helper Bootstrap:** Checking for `yay` or `paru`. If missing, clone from AUR, compile with `makepkg -si`, and set it up automatically.
- **Pacman Wrapper:** Installs official packages using `pacman -S --needed --noconfirm`.
- **AUR Wrapper:** Installs AUR packages using the discovered helper.
- **List Processor:** Parses the `packages/*.list` files (ignoring comments/empty lines) and routes packages to Pacman or the AUR helper.

### `linutils.sh`
- **Remote Sourcing:** Implements a loader that downloads and sources `src/*.sh` modules into memory on the fly when executed remotely (e.g. via `curl`).
- **Local Sourcing:** Sourced directly from local `./src/` path if run from a clone.
- **CLI Options:** Basic command-line argument parser (to allow running silent/headless installs).

---

## 4. Next Steps

1.  **Implement `src/core.sh`:** Code the essential helpers, color indicators, and error exits.
2.  **Implement `src/pacman_conf.sh`:** Code the pacman configuration adjustments, mirror rankings, and keyring refreshes.
3.  **Implement `src/install_pkgs.sh`:** Write the package parsing engine and the AUR bootstrapper.
4.  **Implement `linutils.sh`:** Code the bootstrap loader to tie the modules together.
5.  **Dotfiles Connection (Future Phase):** Create the dotfiles installer in your separate dotfiles repository, and hook it up to a menu item or configuration option inside `linutils.sh`.
