# pacman_conf.sh - Arch Linux repository setup (mirrors, keyrings, multilib).

# Prevent double-sourcing
if [[ -n "${_PACMAN_CONF_SH_SOURCED}" ]]; then
    return 0
fi
readonly _PACMAN_CONF_SH_SOURCED=1

# Enable [multilib] repository for 32-bit package support
enable_multilib() {
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        log_info "Enabling [multilib] repository in /etc/pacman.conf..."
        if sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf; then
            log_success "Successfully enabled [multilib] repository."
        else
            log_error "Failed to enable [multilib] repository."
            return 1
        fi
    elif grep -q "^\[multilib\]" /etc/pacman.conf; then
        log_info "[multilib] repository is already enabled."
    else
        log_warn "[multilib] section not found in /etc/pacman.conf"
    fi
    return 0
}

# Refresh pacman keyring to prevent GPG signature errors
refresh_keyring() {
    log_info "Refreshing Arch Linux keyring..."
    if sudo pacman -Sy archlinux-keyring --noconfirm; then
        log_success "Arch Linux keyring refreshed successfully."
    else
        log_error "Failed to refresh Arch Linux keyring."
        return 1
    fi
    return 0
}

# Rank mirrors with reflector
rank_mirrors() {
    log_info "This will rank your Pacman mirrors using 'reflector' and save the 10 fastest HTTPS mirrors."
    
    if ! command_exists reflector; then
        log_info "reflector is not installed. Installing reflector..."
        if ! sudo pacman -S reflector --needed --noconfirm; then
            log_error "Failed to install reflector."
            return 1
        fi
    fi

    log_info "Reflector is running. Please wait..."
    if sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist; then
        log_success "Successfully updated /etc/pacman.d/mirrorlist with the 10 fastest HTTPS mirrors."
    else
        log_error "Reflector failed to update the mirrorlist."
        return 1
    fi
    return 0
}
