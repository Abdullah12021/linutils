#!/usr/bin/env bash
# linutils.sh - Main entry point and bootstrap loader for Arch Linux installer.

# Define Remote Repository Defaults
export REMOTE_REPO_URL="https://raw.githubusercontent.com/Abdullah12021/linutils/main"

# Sourcing mode detection (local vs remote)
export SOURCING_MODE="local"
if [[ "$1" == "remote" || "$2" == "remote" || "$3" == "remote" ]]; then
    export SOURCING_MODE="remote"
fi

# 1. Load Configurations
if [[ "$SOURCING_MODE" == "local" ]]; then
    if [[ -f "./config.env" ]]; then
        source "./config.env"
    fi
else
    # Try fetching config.env remotely, otherwise use fallback variables
    tmp_config=$(mktemp)
    if curl -fsSL "${REMOTE_REPO_URL}/config.env" -o "$tmp_config" 2>/dev/null; then
        source "$tmp_config"
    fi
    rm -f "$tmp_config"
fi

# Fallback Configuration Defaults
export AUR_HELPER="${AUR_HELPER:-yay}"


# 2. Source Backend Modules
modules=(core.sh pacman_conf.sh install_pkgs.sh)

if [[ "$SOURCING_MODE" == "local" ]]; then
    for mod in "${modules[@]}"; do
        if [[ -f "./src/$mod" ]]; then
            source "./src/$mod"
        else
            echo -e "[ERROR] Failed to load local module: ./src/$mod" >&2
            exit 1
        fi
    done
else
    # Remote execution: Download and source from GitHub raw URL
    for mod in "${modules[@]}"; do
        tmp_mod=$(mktemp)
        if curl -fsSL "${REMOTE_REPO_URL}/src/$mod" -o "$tmp_mod" 2>/dev/null; then
            source "$tmp_mod"
        else
            echo -e "[ERROR] Failed to fetch remote module: ${REMOTE_REPO_URL}/src/$mod" >&2
            rm -f "$tmp_mod"
            exit 1
        fi
        rm -f "$tmp_mod"
    done
fi

# 3. Helper to resolve package lists locally or remotely
get_list_path() {
    local cat_name="$1"
    if [[ "$SOURCING_MODE" == "local" ]]; then
        if [[ -f "./packages/${cat_name}.list" ]]; then
            echo "./packages/${cat_name}.list"
            return 0
        fi
    else
        local remote_dir="/tmp/linutils-remote"
        mkdir -p "$remote_dir"
        if curl -fsSL "${REMOTE_REPO_URL}/packages/${cat_name}.list" -o "$remote_dir/${cat_name}.list" 2>/dev/null; then
            echo "$remote_dir/${cat_name}.list"
            return 0
        fi
    fi
    return 1
}

# Track if pacman optimizations have been run in this session
export PACMAN_OPTIMIZED=0

optimize_pacman_once() {
    if [[ "$PACMAN_OPTIMIZED" -ne 1 ]]; then
        log_info "Optimizing package manager repository speeds & keyrings..."
        enable_multilib
        refresh_keyring
        rank_mirrors
        export PACMAN_OPTIMIZED=1
    fi
}

## 4. Package Installation Sub-menu (Style A - Category Selector)
show_package_menu() {
    local categories=(hardware system desktop user cli dev)
    while true; do
        clear
        echo -e "${MAGENTA}==================================================${RESET}"
        echo -e "           ${BOLD}${CYAN}SELECT PACKAGE CATEGORY${RESET}"
        echo -e "${MAGENTA}==================================================${RESET}"
        echo -e "  ${CYAN}[1]${RESET} Hardware Packages"
        echo -e "  ${CYAN}[2]${RESET} System Packages"
        echo -e "  ${CYAN}[3]${RESET} Desktop Packages"
        echo -e "  ${CYAN}[4]${RESET} User Packages"
        echo -e "  ${CYAN}[5]${RESET} Cli Packages"
        echo -e "  ${CYAN}[6]${RESET} Dev Packages"
        echo -e "${MAGENTA}--------------------------------------------------${RESET}"
        echo -e "  ${YELLOW}[a]${RESET} Install ALL Packages"
        echo -e "  ${BLUE}[b]${RESET} Back to Main Menu"
        echo -e "  ${RED}[x]${RESET} Exit"
        echo -e "${MAGENTA}--------------------------------------------------${RESET}"
        read -p "${BOLD}${GREEN}Selection:${RESET} " choice
        echo ""

        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            break
        elif [[ "$choice" == "x" || "$choice" == "X" ]]; then
            log_success "Thank you for using linutils!"
            exit 0
        elif [[ "$choice" == "all" || "$choice" == "a" || "$choice" == "A" ]]; then
            for cat in "${categories[@]}"; do
                if path=$(get_list_path "$cat"); then
                    select_and_install_from_file "$path"
                fi
            done
            echo -e "\nPress any key to return to menu..."
            read -n 1 -r -s
            break
        elif [[ "$choice" =~ ^[1-6]$ ]]; then
            local index=$((choice-1))
            local selected="${categories[$index]}"
            if path=$(get_list_path "$selected"); then
                select_and_install_from_file "$path"
                echo -e "\nPress any key to return to menu..."
                read -n 1 -r -s
            else
                log_error "Failed to locate list for: $selected"
                sleep 1.5
            fi
        else
            log_warn "Invalid selection."
            sleep 1
        fi
    done
}

# Gum-specific Package Installation Sub-menu (Category Selector)
show_package_menu_gum() {
    local categories=(hardware system desktop user cli dev)
    while true; do
        clear
        local options=(
            "1) Hardware Packages"
            "2) System Packages"
            "3) Desktop Packages"
            "4) User Packages"
            "5) Cli Packages"
            "6) Dev Packages"
            "a) Install ALL Packages"
            "b) Back to Main Menu"
            "x) Exit"
        )

        local choice
        choice=$(gum choose "${options[@]}" --height=10)

        if [[ "$choice" == "b)"* || -z "$choice" ]]; then
            break
        elif [[ "$choice" == "x)"* ]]; then
            log_success "Thank you for using linutils!"
            exit 0
        elif [[ "$choice" == "a)"* ]]; then
            for cat in "${categories[@]}"; do
                if path=$(get_list_path "$cat"); then
                    select_and_install_from_file "$path"
                fi
            done
            echo -e "\nPress any key to return to menu..."
            read -n 1 -r -s
            break
        else
            if [[ "$choice" =~ ^([1-6])\) ]]; then
                local index=$((${BASH_REMATCH[1]}-1))
                local selected="${categories[$index]}"
                if path=$(get_list_path "$selected"); then
                    select_and_install_from_file "$path"
                    echo -e "\nPress any key to return to menu..."
                    read -n 1 -r -s
                else
                    log_error "Failed to locate list for: $selected"
                    sleep 1.5
                fi
            fi
        fi
    done
}




# Deploy Dotfiles via external dotfiles repository installer
deploy_dotfiles() {
    log_info "Checking dotfiles repository..."
    local dotfiles_dir="$HOME/dev/dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        log_info "Cloning dotfiles repository to $dotfiles_dir..."
        mkdir -p "$(dirname "$dotfiles_dir")"
        # Using placeholder username, user can replace this in config.env
        local dotfiles_url="https://github.com/Abdullah12021/dotfiles.git"
        if ! git clone "$dotfiles_url" "$dotfiles_dir"; then
            log_error "Failed to clone dotfiles repository."
            return 1
        fi
    else
        log_info "Updating dotfiles repository at $dotfiles_dir..."
        (
            cd "$dotfiles_dir" || exit 1
            git pull
        )
    fi

    if [[ -f "$dotfiles_dir/deploy.sh" ]]; then
        log_info "Starting dotfiles installer..."
        bash "$dotfiles_dir/deploy.sh"
    elif [[ -f "$dotfiles_dir/installer.sh" ]]; then
        log_info "Starting dotfiles installer..."
        bash "$dotfiles_dir/installer.sh"
    else
        log_error "No deploy.sh or installer.sh found inside $dotfiles_dir"
        return 1
    fi
}

# Deploy Wallpapers (Placeholders/Implementation Hooks)
deploy_wallpapers() {
    log_info "Installing wallpapers..."
    # Wallpapers can also be cloned or linked here
    log_success "Wallpapers downloaded & processed."
}

# 5. Main Interactive Loop (Standard CLI)
show_main_menu() {
    check_sudo
    while true; do
        clear
        echo -e "${MAGENTA}=========================================${RESET}"
        echo -e "    ${BOLD}${CYAN}linutils${RESET} - ${WHITE}Arch Linux Setup${RESET}"
        echo -e "${MAGENTA}=========================================${RESET}"
        echo -e "  ${CYAN}[1]${RESET} Install System Packages"
        echo -e "  ${CYAN}[2]${RESET} Install Program Dotfiles"
        echo -e "  ${CYAN}[3]${RESET} Install Wallpapers"
        echo -e "  ${RED}[x]${RESET} Exit"
        echo -e "${MAGENTA}-----------------------------------------${RESET}"
        read -p "${BOLD}${GREEN}Selection:${RESET} " choice
        echo ""


        case "$choice" in
            1)
                show_package_menu
                ;;
            2)
                deploy_dotfiles
                ;;
            3)
                deploy_wallpapers
                ;;
            x|X)
                log_success "Thank you for using linutils!"
                exit 0
                ;;
            *)
                log_warn "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# Gum-specific Main Interactive Loop
show_main_menu_gum() {
    check_sudo
    while true; do
        clear
        local choice
        choice=$(gum choose "1) Install System Packages" "2) Install Program Dotfiles" "3) Install Wallpapers" "x) Exit" --height=10)

        case "$choice" in
            "1)"*)
                show_package_menu_gum
                ;;
            "2)"*)
                deploy_dotfiles
                ;;
            "3)"*)
                deploy_wallpapers
                ;;
            "x)"*|"")
                log_success "Thank you for using linutils!"
                exit 0
                ;;
        esac
    done
}


# 6. Command line arguments / Non-interactive triggers
usage() {
    echo -e "Usage: $0 [local|remote] [options]"
    echo -e "Options:"
    echo -e "  --gum               Use modern Gum TUI interfaces if installed"
    echo -e "  --sys-conf          Configure multilib, refresh keyring, and rank mirrors"
    echo -e "  --install-all       Install all category lists non-interactively"
    echo -e "  --category <name>   Install packages from a specific category list"
    echo -e "  --help              Show this help menu"
    exit 0
}

# Parse CLI parameters
PARAMS=""
# Auto-detect if gum is installed to set default GUM_MODE
if command_exists gum; then
    export GUM_MODE=1
else
    export GUM_MODE=0
fi

while (( "$#" )); do
    case "$1" in
        remote|local)
            shift
            ;;
        --gum)
            export GUM_MODE=1
            shift
            ;;
        --sys-conf)
            optimize_pacman_once
            shift
            exit 0
            ;;
        --install-all)
            optimize_pacman_once
            categories=(hardware system desktop user cli dev)
            for cat in "${categories[@]}"; do
                if path=$(get_list_path "$cat"); then
                    install_from_file "$path"
                fi
            done
            shift
            exit 0
            ;;
        --category)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                optimize_pacman_once
                if path=$(get_list_path "$2"); then
                    install_from_file "$2"
                else
                    log_error "Category list '$2' could not be resolved."
                fi
                shift 2
                exit 0
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            ;;
        --help)
            usage
            ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done

# Boot interactive menu if no silent arguments were executed
# Ask the user which mode they want to run
clear
echo -e "${MAGENTA}=========================================${RESET}"
echo -e "    ${BOLD}${CYAN}linutils${RESET} - ${WHITE}Interface Selection${RESET}"
echo -e "${MAGENTA}=========================================${RESET}"
echo -e "  ${CYAN}[1]${RESET} Standard CLI Mode"
echo -e "  ${CYAN}[2]${RESET} Modern TUI Mode (Gum)"
echo -e "${MAGENTA}-----------------------------------------${RESET}"
read -p "${BOLD}${GREEN}Selection [1-2] (Default: 2):${RESET} " mode_choice
echo ""

if [[ "$mode_choice" == "1" ]]; then
    export GUM_MODE=0
else
    export GUM_MODE=1
fi

if [[ "$GUM_MODE" -eq 1 ]]; then
    if ! command_exists gum; then
        log_info "Bootstrapping 'gum' TUI library silently..."
        if sudo pacman -S --needed --noconfirm gum >/dev/null 2>&1; then
            log_success "'gum' installed successfully."
        else
            log_warn "Failed to install 'gum' silently. Falling back to standard CLI."
            export GUM_MODE=0
        fi
    fi
fi


if [[ "$GUM_MODE" -eq 1 ]] && command_exists gum; then
    show_main_menu_gum
else
    show_main_menu
fi




