#!/usr/bin/env bash
# @file Exanor Theme Enforcement
# @brief Applies Exanor OS theming (MacTahoe/WhiteSur) to an existing install.
# Can be run by installer or directly by user on live system.

echo "-------------------------------------------------------------------------"
echo "    Exanor Theme Enforcement"
echo "-------------------------------------------------------------------------"

# -------------------------------------------------------------------------
# 1. Context Detection
# -------------------------------------------------------------------------
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Try to find REPO_ROOT
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    REPO_ROOT="$SCRIPT_DIR"
elif [[ -d "$HOME/ArchTitus" ]]; then
    REPO_ROOT="$HOME/ArchTitus"
else
    echo "Error: Cannot find ArchTitus repository."
    exit 1
fi

# Load config if available
if [[ -f "$REPO_ROOT/configs/setup.conf" ]]; then
    source "$REPO_ROOT/configs/setup.conf"
fi

# Determine target user
if [[ -n "$SUDO_USER" ]]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
elif [[ -n "$USERNAME" ]]; then
    REAL_USER="$USERNAME"
    REAL_HOME="/home/$USERNAME"
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

echo "Target User: $REAL_USER"
echo "Home: $REAL_HOME"

# Detect Desktop Environment
if [[ -z "$DESKTOP_ENV" ]]; then
    if [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
        DESKTOP_ENV="kde"
    elif [[ "$XDG_CURRENT_DESKTOP" == "GNOME" ]]; then
        DESKTOP_ENV="gnome"
    else
        echo "Warning: Could not detect desktop environment."
        DESKTOP_ENV="unknown"
    fi
fi

echo "Desktop Environment: $DESKTOP_ENV"

# -------------------------------------------------------------------------
# 2. Helper Functions
# -------------------------------------------------------------------------
run_as_user() {
    if [[ $EUID -eq 0 ]]; then
        sudo -u "$REAL_USER" "$@"
    else
        "$@"
    fi
}

install_theme_repo() {
    local repo_url="$1"
    local repo_name="$2"
    local install_script="${3:-install.sh}"
    
    local temp_dir="/tmp/exanor-themes/$repo_name"
    
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
    
    echo "Cloning $repo_name..."
    git clone --depth=1 "$repo_url" "$temp_dir"
    
    if [[ -f "$temp_dir/$install_script" ]]; then
        echo "Installing $repo_name..."
        cd "$temp_dir" && chmod +x "$install_script" && ./"$install_script"
    else
        echo "Warning: Install script not found for $repo_name"
    fi
    
    cd - > /dev/null
}

# -------------------------------------------------------------------------
# 3. KDE Theming
# -------------------------------------------------------------------------
apply_kde_themes() {
    echo "-------------------------------------------------------------------------"
    echo "    Applying KDE Themes"
    echo "-------------------------------------------------------------------------"
    
    mkdir -p /tmp/exanor-themes
    
    # MacTahoe Icons
    if [[ ! -d "/usr/share/icons/MacTahoe" ]] && [[ ! -d "$REAL_HOME/.local/share/icons/MacTahoe" ]]; then
        install_theme_repo "https://github.com/vinceliuice/MacTahoe-icon-theme.git" "icons"
    else
        echo "[OK] MacTahoe icons already installed"
    fi
    
    # MacTahoe KDE Theme
    if [[ ! -d "/usr/share/themes/MacTahoe-Dark" ]] && [[ ! -d "$REAL_HOME/.local/share/plasma/look-and-feel/com.github.vinceliuice.MacTahoe" ]]; then
        install_theme_repo "https://github.com/vinceliuice/MacTahoe-kde.git" "theme"
    else
        echo "[OK] MacTahoe theme already installed"
    fi
    
    # WhiteSur Cursors
    if [[ ! -d "/usr/share/icons/WhiteSur-cursors" ]] && [[ ! -d "$REAL_HOME/.local/share/icons/WhiteSur-cursors" ]]; then
        install_theme_repo "https://github.com/vinceliuice/WhiteSur-cursors.git" "cursors"
    else
        echo "[OK] WhiteSur cursors already installed"
    fi
    
    # Cleanup
    rm -rf /tmp/exanor-themes
    
    # Apply themes
    echo "Applying theme settings..."
    
    # Try plasma-apply-lookandfeel (needs DBus, works only in live session)
    if command -v plasma-apply-lookandfeel &> /dev/null && [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
        run_as_user plasma-apply-lookandfeel -a com.github.vinceliuice.MacTahoe-Dark 2>/dev/null || true
        run_as_user plasma-apply-cursortheme WhiteSur-cursors 2>/dev/null || true
    fi
    
    # Fallback: Write to config files
    local kwriteconfig=""
    if command -v kwriteconfig6 &> /dev/null; then
        kwriteconfig="kwriteconfig6"
    elif command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig="kwriteconfig5"
    fi
    
    if [[ -n "$kwriteconfig" ]]; then
        run_as_user $kwriteconfig --file kdeglobals --group Icons --key Theme "MacTahoe"
        run_as_user $kwriteconfig --file kdeglobals --group General --key ColorScheme "MacTahoe"
        run_as_user $kwriteconfig --file kcminputrc --group Mouse --key cursorTheme "WhiteSur-cursors"
    fi
    
    echo "[OK] KDE theming complete"
}

# -------------------------------------------------------------------------
# 4. GNOME Theming (Placeholder)
# -------------------------------------------------------------------------
apply_gnome_themes() {
    echo "-------------------------------------------------------------------------"
    echo "    Applying GNOME Themes"
    echo "-------------------------------------------------------------------------"
    
    # TODO: Implement GNOME theming if needed
    echo "GNOME theming not yet implemented."
}

# -------------------------------------------------------------------------
# 5. SDDM Theme
# -------------------------------------------------------------------------
apply_sddm_theme() {
    echo "-------------------------------------------------------------------------"
    echo "    Checking SDDM Theme"
    echo "-------------------------------------------------------------------------"
    
    local THEME_NAME="redrock"
    local AUR_PACKAGE="sddm-theme-redrock"
    
    # Show current SDDM theme configuration
    echo "[i] Current SDDM theme status:"
    if [[ -f "/etc/sddm.conf.d/theme.conf" ]]; then
        local current_theme=$(grep "^Current=" /etc/sddm.conf.d/theme.conf 2>/dev/null | cut -d'=' -f2)
        echo "    Configured: ${current_theme:-'(none)'}"
    elif [[ -f "/etc/sddm.conf" ]]; then
        local current_theme=$(grep "^Current=" /etc/sddm.conf 2>/dev/null | cut -d'=' -f2)
        echo "    Configured: ${current_theme:-'(default)'}"
    else
        echo "    Configured: (default - no custom theme)"
    fi
    
    # Check if theme package is installed
    if pacman -Qi "$AUR_PACKAGE" &>/dev/null; then
        echo "[OK] SDDM theme package '$AUR_PACKAGE' already installed"
        
        # Verify SDDM is configured to use it
        if [[ -f "/etc/sddm.conf.d/theme.conf" ]] && grep -q "Current=$THEME_NAME" /etc/sddm.conf.d/theme.conf 2>/dev/null; then
            echo "[OK] SDDM configured to use '$THEME_NAME'"
            return 0
        else
            echo "[..] Configuring SDDM to use '$THEME_NAME'..."
        fi
    else
        echo "[..] Installing SDDM theme via AUR..."
        
        # Install Qt dependencies required for SDDM themes (requires root)
        if [[ $EUID -eq 0 ]]; then
            echo "[..] Installing Qt graphical effects dependencies..."
            pacman -S --noconfirm --needed qt5-graphicaleffects qt6-5compat
        else
            echo "[..] Checking Qt dependencies..."
            if ! pacman -Qi qt5-graphicaleffects &>/dev/null; then
                echo "[!] Missing qt5-graphicaleffects - run: sudo pacman -S qt5-graphicaleffects qt6-5compat"
            fi
        fi
        
        # Install via AUR helper (run as real user, not root)
        if command -v yay &>/dev/null; then
            run_as_user yay -S --noconfirm "$AUR_PACKAGE"
        elif command -v paru &>/dev/null; then
            run_as_user paru -S --noconfirm "$AUR_PACKAGE"
        else
            echo "[!] No AUR helper found (yay/paru). Cannot install SDDM theme."
            echo "    Install manually: yay -S $AUR_PACKAGE"
            return 1
        fi
    fi
    
    # Configure SDDM to use the theme (requires root)
    if [[ $EUID -eq 0 ]]; then
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/theme.conf << EOF
[Theme]
Current=$THEME_NAME
EOF
        echo "[OK] SDDM theme '$THEME_NAME' configured"
    else
        echo "[!] Need root to configure SDDM. Run:"
        echo "    sudo mkdir -p /etc/sddm.conf.d"
        echo "    echo -e '[Theme]\nCurrent=$THEME_NAME' | sudo tee /etc/sddm.conf.d/theme.conf"
    fi
}

# -------------------------------------------------------------------------
# 6. Dock Setup
# -------------------------------------------------------------------------
setup_dock() {
    echo "-------------------------------------------------------------------------"
    echo "    Setting up Dock"
    echo "-------------------------------------------------------------------------"
    
    # Check for latte-dock or plank
    if command -v latte-dock &> /dev/null; then
        echo "Latte Dock detected. Importing config..."
        # TODO: Import latte layout from configs/
    elif command -v plank &> /dev/null; then
        echo "Plank detected."
        # TODO: Configure plank
    else
        echo "No dock found. Consider installing latte-dock or plank."
    fi
}

# -------------------------------------------------------------------------
# 8. Plymouth Theme
# -------------------------------------------------------------------------
check_plymouth_theme() {
    echo "-------------------------------------------------------------------------"
    echo "    Plymouth Boot Splash"
    echo "-------------------------------------------------------------------------"
    
    local THEME_NAME="exanor-glow"
    local SOURCE_DIR="$REPO_ROOT/configs/usr/share/plymouth/themes/$THEME_NAME"
    local DEST_DIR="/usr/share/plymouth/themes/$THEME_NAME"

    # Check if we are potentially already running this theme
    if plymouth-set-default-theme | grep -q "$THEME_NAME"; then
         echo "[OK] Plymouth theme '$THEME_NAME' is already active."
         return 0
    fi

    echo "Would you like to install and activate the '$THEME_NAME' Plymouth boot splash?"
    echo "  (This requires sudo privileges to rebuild initramfs)"
    read -p "Install Plymouth theme? [y/N]: " choice
    
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        echo "Installing $THEME_NAME..."
        
        if [[ ! -d "$SOURCE_DIR" ]]; then
             echo "Error: Source theme directory not found at $SOURCE_DIR"
             return 1
        fi
        
        # We need root access for this
        if [[ $EUID -eq 0 ]]; then
            mkdir -p "$DEST_DIR"
            cp -rf "$SOURCE_DIR"/* "$DEST_DIR/"
            echo "Setting default theme and rebuilding initramfs (this may take a minute)..."
            plymouth-set-default-theme -R "$THEME_NAME"
        else
            echo "Requesting root access to install theme..."
            sudo mkdir -p "$DEST_DIR"
            sudo cp -rf "$SOURCE_DIR"/* "$DEST_DIR/"
            echo "Setting default theme and rebuilding initramfs (this may take a minute)..."
            sudo plymouth-set-default-theme -R "$THEME_NAME"
        fi
        
        echo "[OK] Plymouth theme installed."
    else
        echo "Skipping Plymouth theme."
    fi
}

# -------------------------------------------------------------------------
# 7. Main
# -------------------------------------------------------------------------
main() {
    echo ""
    
    case "$DESKTOP_ENV" in
        kde)
            apply_kde_themes
            apply_sddm_theme
            ;;
        gnome)
            apply_gnome_themes
            ;;
        *)
            echo "Unsupported desktop environment: $DESKTOP_ENV"
            echo "Skipping theme application."
            ;;
    esac
    
    check_plymouth_theme
    setup_dock
    
    echo ""
    echo "-------------------------------------------------------------------------"
    echo "    Exanor Theme Enforcement Complete!"
    echo "-------------------------------------------------------------------------"
    echo "Please log out and back in (or reboot) to see all changes."
}

main "$@"
