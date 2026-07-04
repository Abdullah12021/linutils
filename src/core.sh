# core.sh - Helper utilities, environment detection, and output logging.

# Prevent double-sourcing
if [[ -n "${_CORE_SH_SOURCED}" ]]; then
    return 0
fi
readonly _CORE_SH_SOURCED=1

# Output Styling & Colors
setup_colors() {
    # Check if stdout is a terminal
    if [[ -t 1 ]]; then
        # Cozy 256-Color Palette (Vibrant yet eye-comfy)
        RED=$'\e[38;5;203m'       # Soft Coral (warnings/errors)
        GREEN=$'\e[38;5;115m'     # Mint Green (success/actions)
        YELLOW=$'\e[38;5;215m'    # Pastel Gold/Amber (highlights)
        BLUE=$'\e[38;5;111m'      # Soft Sky Blue (subcategories)
        MAGENTA=$'\e[38;5;176m'   # Lavender Rose (borders/decorations)
        CYAN=$'\e[38;5;80m'       # Cozy Teal (titles)
        WHITE=$'\e[38;5;253m'     # Warm Off-white (main text)
        RESET=$'\e[0m'
        BOLD=$'\e[1m'
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        MAGENTA=""
        CYAN=""
        WHITE=""
        RESET=""
        BOLD=""
    fi

    # Status Indicators
    OK="${GREEN}[ OK ]${RESET}"
    ERROR="${RED}[ERROR]${RESET}"
    WARN="${YELLOW}[WARN]${RESET}"
    INFO="${CYAN}[INFO]${RESET}"
}

# Run color setup immediately
setup_colors

# Logging Helpers
log_info() {
    echo -e "${INFO} ${CYAN}$1${RESET}"
}

log_success() {
    echo -e "${OK} ${GREEN}$1${RESET}"
}

log_warn() {
    echo -e "${WARN} ${YELLOW}$1${RESET}"
}

log_error() {
    echo -e "${ERROR} ${RED}$1${RESET}" >&2
}

# Check if command exists in system PATH
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if the user has cached sudo permissions
check_sudo() {
    if sudo -n true 2>/dev/null; then
        export HAS_SUDO=1
    else
        export HAS_SUDO=0
    fi
}

# Auto-detect CPU and GPU hardware layout
detect_hardware() {
    export CPU_TYPE="unknown"
    export GPU_TYPE="unknown"

    # CPU Detection
    if [[ -f /proc/cpuinfo ]]; then
        if grep -qi "intel" /proc/cpuinfo; then
            export CPU_TYPE="intel"
        elif grep -qi "amd" /proc/cpuinfo; then
            export CPU_TYPE="amd"
        fi
    fi

    # GPU Detection
    local gpu_info=""
    if command_exists lspci; then
        gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display')
    fi

    if [[ -n "$gpu_info" ]]; then
        if echo "$gpu_info" | grep -qi "nvidia"; then
            export GPU_TYPE="nvidia"
        elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
            export GPU_TYPE="amd"
        elif echo "$gpu_info" | grep -qi "intel"; then
            export GPU_TYPE="intel"
        fi
    fi
}

