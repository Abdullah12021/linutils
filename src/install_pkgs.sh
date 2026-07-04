# install_pkgs.sh - Package installation wrappers for pacman and AUR helpers.

# Prevent double-sourcing
if [[ -n "${_INSTALL_PKGS_SH_SOURCED}" ]]; then
    return 0
fi
readonly _INSTALL_PKGS_SH_SOURCED=1

# Bootstrap preferred AUR helper (yay or paru) if missing
bootstrap_aur_helper() {
    # Check default/fallback env variable
    AUR_HELPER="${AUR_HELPER:-yay}"

    # If preferred AUR helper is already installed, verify it
    if command_exists "$AUR_HELPER"; then
        return 0
    fi

    # Fallback checks to see if any helper is already present
    if command_exists yay; then
        export AUR_HELPER="yay"
        return 0
    elif command_exists paru; then
        export AUR_HELPER="paru"
        return 0
    fi

    log_info "No AUR helper found. Preparing to bootstrap ${AUR_HELPER}..."

    # Ensure system has base-devel and git before cloning
    log_info "Installing Git and base-devel development headers..."
    if ! sudo pacman -S --needed --noconfirm base-devel git; then
        log_error "Failed to install build dependencies."
        return 1
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    
    log_info "Cloning ${AUR_HELPER}-bin repository..."
    if git clone "https://aur.archlinux.org/${AUR_HELPER}-bin.git" "$temp_dir/${AUR_HELPER}-bin"; then
        log_info "Building and installing ${AUR_HELPER}-bin..."
        (
            cd "$temp_dir/${AUR_HELPER}-bin" || exit 1
            makepkg -si --noconfirm
        )
        local build_status=$?
        rm -rf "$temp_dir"
        
        if [[ $build_status -eq 0 ]]; then
            log_success "${AUR_HELPER} has been bootstrapped and installed successfully."
            return 0
        else
            log_error "Compilation and installation of ${AUR_HELPER} failed."
            return 1
        fi
    else
        rm -rf "$temp_dir"
        log_error "Could not fetch ${AUR_HELPER}-bin repository from AUR."
        return 1
    fi
}

# Install official pacman repository packages
install_official() {
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi
    log_info "Installing official packages via Pacman: ${pkgs[*]}"
    if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
        log_success "Installed official packages successfully."
        return 0
    else
        log_error "Failed to install official packages."
        return 1
    fi
}

# Install packages from the Arch User Repository (AUR)
install_aur() {
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi
    bootstrap_aur_helper || return 1
    log_info "Installing AUR packages via ${AUR_HELPER}: ${pkgs[*]}"
    if "${AUR_HELPER}" -S --needed --noconfirm "${pkgs[@]}"; then
        log_success "Installed AUR packages successfully."
        return 0
    else
        log_error "Failed to install AUR packages."
        return 1
    fi
}

# Read a category file and sort + install packages
install_from_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        log_error "Package list file not found: $file_path"
        return 1
    fi

    local category
    category=$(basename "$file_path" .list)
    log_info "Parsing package category: [${category}]"

    local official_pkgs=()
    local aur_pkgs=()

    # Read and parse packages line-by-line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip comments and leading/trailing whitespaces
        line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$line" ]] && continue

        # Query Pacman sync databases to determine if it is official
        if pacman -Si "$line" >/dev/null 2>&1; then
            official_pkgs+=("$line")
        else
            aur_pkgs+=("$line")
        fi
    done < "$file_path"

    local status=0

    # Batch install official packages
    if [[ ${#official_pkgs[@]} -gt 0 ]]; then
        install_official "${official_pkgs[@]}" || status=1
    fi

    # Batch install AUR packages
    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        install_aur "${aur_pkgs[@]}" || status=1
    fi

    return $status
}

# Prompt user to select specific packages manually before installing
select_and_install_from_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        log_error "File does not exist: $file_path"
        return 1
    fi

    local pkgs=()
    local categories=()
    local pkg_categories=()

    local current_category="General"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^#[[:space:]]*\[(.*)\] ]]; then
            current_category="${BASH_REMATCH[1]}"
            continue
        elif [[ "$line" =~ ^# ]]; then
            continue
        fi

        pkgs+=("$line")
        pkg_categories+=("$current_category")
    done < "$file_path"

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        log_warn "No packages found in $file_path"
        return 0
    fi

    local selected_pkgs=()

    # If GUM mode is enabled, run the selection through gum choose
    if [[ "$GUM_MODE" -eq 1 ]] && command_exists gum; then
        local gum_input=()
        
        # Calculate maximum package name length to align the right-aligned categories
        local max_len=0
        for pkg in "${pkgs[@]}"; do
            if (( ${#pkg} > max_len )); then
                max_len=${#pkg}
            fi
        done
        local pad_width=$((max_len + 4))

        local last_cat=""
        for i in "${!pkgs[@]}"; do
            local pkg="${pkgs[$i]}"
            local cat="${pkg_categories[$i]}"
            
            # Create right-aligned padding
            local pad_len=$((pad_width - ${#pkg}))
            local padding=""
            if ((pad_len > 0)); then
                padding=$(printf '%*s' "$pad_len" "")
            fi
            
            if [[ "$cat" != "$last_cat" ]]; then
                if [[ -n "$last_cat" ]]; then
                    gum_input+=("")
                fi
                gum_input+=("${pkg}${padding}(${cat})")
                last_cat="$cat"
            else
                gum_input+=("${pkg}")
            fi
        done

        local gum_choices
        gum_choices=$(printf "%s\n" "${gum_input[@]}" | gum choose --no-limit --height=20 --header="Select packages [SPACE: Toggle • ENTER: Install • ESC: Cancel]")
        [[ -z "$gum_choices" ]] && { log_info "Selection cancelled."; return 0; }

        while IFS= read -r choice; do
            local trimmed
            trimmed=$(echo "$choice" | sed -E 's/^[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
            [[ -z "$trimmed" ]] && continue
            
            local pkg_name
            pkg_name=$(echo "$choice" | sed -E 's/^[[:space:]]*//' | sed -E 's/[[:space:]]+\(.*$//')
            selected_pkgs+=("$pkg_name")
        done <<< "$gum_choices"
    else
        # Standard CLI manual selection menu
        clear
        echo -e "${MAGENTA}==================================================${RESET}"
        echo -e "           ${BOLD}${CYAN}SELECT PACKAGES TO INSTALL${RESET}"
        echo -e "${MAGENTA}==================================================${RESET}"
        
        local last_cat=""
        for i in "${!pkgs[@]}"; do
            if [[ "${pkg_categories[$i]}" != "$last_cat" ]]; then
                last_cat="${pkg_categories[$i]}"
                echo -e "\n${BOLD}${BLUE}# [$last_cat]${RESET}"
            fi
            printf "  ${CYAN}%02d${RESET} │ %s\n" "$((i+1))" "${pkgs[$i]}"
        done
        echo -e "\n${MAGENTA}==================================================${RESET}"
        echo -e "Enter choices (e.g. ${CYAN}1-3,5${RESET}), '${YELLOW}all${RESET}' to select all, or '${RED}x${RESET}' to cancel."
        read -p "${BOLD}${GREEN}Selection:${RESET} " user_input
        echo ""

        if [[ "$user_input" == "x" || "$user_input" == "X" ]]; then
            log_info "Selection cancelled."
            return 0
        elif [[ "$user_input" == "all" ]]; then
            selected_pkgs=("${pkgs[@]}")
        else
            # CLI Range Parser Logic
            local expanded_indices=()
            IFS=',' read -ra parts <<< "$user_input"
            for part in "${parts[@]}"; do
                part=$(echo "$part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    local start="${BASH_REMATCH[1]}"
                    local end="${BASH_REMATCH[2]}"
                    for ((idx=start; idx<=end; idx++)); do
                        expanded_indices+=("$idx")
                    done
                elif [[ "$part" =~ ^[0-9]+$ ]]; then
                    expanded_indices+=("$part")
                fi
            done

            for idx in "${expanded_indices[@]}"; do
                local real_idx=$((idx-1))
                if (( real_idx >= 0 && real_idx < ${#pkgs[@]} )); then
                    selected_pkgs+=("${pkgs[$real_idx]}")
                else
                    log_warn "Ignored out-of-bounds selection index: $idx"
                fi
            done
        fi
    fi

    if [[ ${#selected_pkgs[@]} -eq 0 ]]; then
        log_info "No packages selected."
        return 0
    fi

    # Hardware-specific auto-filtering (Intel/AMD Microcodes prevention)
    detect_hardware
    local final_install_list=()
    for pkg in "${selected_pkgs[@]}"; do
        if [[ "$pkg" == "intel-ucode" && "$CPU_TYPE" == "amd" ]]; then
            log_warn "Target has AMD processor. Skipping intel-ucode to prevent boot errors."
            continue
        elif [[ "$pkg" == "amd-ucode" && "$CPU_TYPE" == "intel" ]]; then
            log_warn "Target has Intel processor. Skipping amd-ucode to prevent boot errors."
            continue
        fi
        final_install_list+=("$pkg")
    done

    if [[ ${#final_install_list[@]} -eq 0 ]]; then
        log_info "No compatible packages selected for this hardware configuration."
        return 0
    fi

    # Install selected items
    local official_pkgs=()
    local aur_pkgs=()
    for pkg in "${final_install_list[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official_pkgs+=("$pkg")
        else
            aur_pkgs+=("$pkg")
        fi
    done

    local status=0
    if [[ ${#official_pkgs[@]} -gt 0 ]]; then
        install_official "${official_pkgs[@]}" || status=1
    fi
    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        install_aur "${aur_pkgs[@]}" || status=1
    fi

    return $status
}

