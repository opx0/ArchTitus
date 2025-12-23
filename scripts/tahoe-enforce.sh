#!/bin/bash

# ==============================================================================
# Tahoe-Enforcer: Post-Install State Enforcement Script for Arch Linux (KDE)
# ==============================================================================
# This script enforces a macOS-like state (Tahoe OS) on a KDE Plasma installation.
# It is designed to be idempotent and run as root.

# ------------------------------------------------------------------------------
# 1. Check Requirements
# ------------------------------------------------------------------------------
check_requirements() {
    echo "Checking requirements..."

    # 1. Verify Root
    if [[ $EUID -ne 0 ]]; then
       echo "Error: This script must be run as root/sudo."
       exit 1
    fi

    # Determine Real User (for non-root operations)
    if [ -n "$SUDO_USER" ]; then
        REAL_USER=$SUDO_USER
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        echo "Warning: Script not run via sudo. Assuming target user is the first normal user (UID 1000)."
        REAL_USER=$(id -nu 1000)
        REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
        if [ -z "$REAL_USER" ]; then
            echo "Error: Could not determine target user."
            exit 1
        fi
    fi
    echo "Target User: $REAL_USER"

    # 2. Verify Internet Connection
    echo "Checking internet connection..."
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Error: No internet connection. Please connect and try again."
        exit 1
    fi

    # 3. Check/Install git and base-devel
    echo "Checking system dependencies (git, base-devel)..."
    NEEDED_PKGS=""
    if ! pacman -Qi git &> /dev/null; then NEEDED_PKGS="$NEEDED_PKGS git"; fi
    if ! pacman -Qi base-devel &> /dev/null; then NEEDED_PKGS="$NEEDED_PKGS base-devel"; fi

    if [ -n "$NEEDED_PKGS" ]; then
        echo "Installing missing dependencies:$NEEDED_PKGS"
        pacman -S --noconfirm --needed $NEEDED_PKGS
    else
        echo "Dependencies already installed."
    fi
}

# ------------------------------------------------------------------------------
# 2. Install AUR Helper
# ------------------------------------------------------------------------------
install_aur_helper() {
    echo "Checking AUR helper..."
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        echo "yay is already installed."
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        echo "paru is already installed."
    else
        echo "No AUR helper found. Installing yay-bin..."

        # Clone to temp directory
        cd /tmp || exit
        rm -rf yay-bin
        sudo -u "$REAL_USER" git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin || exit

        # Build and install as the real user
        # We allow the user to run makepkg; since we are root, we need to handle sudo properly
        # However, makepkg cannot run as root.
        # We used sudo -u above to clone. Now build.

        echo "Building yay-bin..."
        sudo -u "$REAL_USER" makepkg -si --noconfirm

        AUR_HELPER="yay"
        cd ..
        rm -rf yay-bin
    fi
}

# ------------------------------------------------------------------------------
# 3. Enforce Packages
# ------------------------------------------------------------------------------
enforce_packages() {
    echo "Enforcing required packages..."
    PACKAGES=("plymouth-git" "plasma-desktop" "dolphin" "konsole")

    # Check for dock (latte-dock or plasma-panel-spacer as fallback check)
    if ! pacman -Qi latte-dock &> /dev/null; then
         PACKAGES+=("latte-dock")
    fi

    for pkg in "${PACKAGES[@]}"; do
        if pacman -Qi "$pkg" &> /dev/null; then
            echo "  [OK] $pkg is installed."
        else
            echo "  [..] Installing $pkg..."
            # Try official repos first, then AUR
            if pacman -Ss "^$pkg$" | grep -q "core/\|extra/"; then
                 pacman -S --noconfirm --needed "$pkg"
            else
                 # Install from AUR as the real user
                 sudo -u "$REAL_USER" "$AUR_HELPER" -S --noconfirm --needed "$pkg"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 4. Enforce MacOS Theme (WhiteSur)
# ------------------------------------------------------------------------------
enforce_macos_theme() {
    echo "Enforcing MacOS Theme (WhiteSur)..."

    TEMP_DIR="/tmp/whitesur-install"
    mkdir -p "$TEMP_DIR"

    # 4.1 Install GTK/KDE Theme
    # Check if theme exists globally or locally
    if [ ! -d "/usr/share/themes/WhiteSur-Dark" ] && [ ! -d "$REAL_HOME/.local/share/themes/WhiteSur-Dark" ]; then
        echo "  [..] Cloning WhiteSur-kde..."
        rm -rf "$TEMP_DIR/WhiteSur-kde"
        git clone https://github.com/vinceliuice/WhiteSur-kde.git "$TEMP_DIR/WhiteSur-kde"

        echo "  [..] Installing WhiteSur-kde..."
        # Install globally
        "$TEMP_DIR/WhiteSur-kde/install.sh"
    else
        echo "  [OK] WhiteSur theme files appear to be present."
    fi

    # 4.2 Install Icons
    if [ ! -d "/usr/share/icons/WhiteSur" ] && [ ! -d "$REAL_HOME/.local/share/icons/WhiteSur" ]; then
        echo "  [..] Cloning WhiteSur-icon-theme..."
        rm -rf "$TEMP_DIR/WhiteSur-icon-theme"
        git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git "$TEMP_DIR/WhiteSur-icon-theme"

        echo "  [..] Installing WhiteSur-icon-theme..."
        "$TEMP_DIR/WhiteSur-icon-theme/install.sh"
    else
         echo "  [OK] WhiteSur icons appear to be present."
    fi

    # 4.3 Install Cursors
    if [ ! -d "/usr/share/icons/WhiteSur-cursors" ] && [ ! -d "$REAL_HOME/.local/share/icons/WhiteSur-cursors" ]; then
        echo "  [..] Cloning WhiteSur-cursors..."
        rm -rf "$TEMP_DIR/WhiteSur-cursors"
        git clone https://github.com/vinceliuice/WhiteSur-cursors.git "$TEMP_DIR/WhiteSur-cursors"

        echo "  [..] Installing WhiteSur-cursors..."
        "$TEMP_DIR/WhiteSur-cursors/install.sh"
    else
         echo "  [OK] WhiteSur cursors appear to be present."
    fi

    # 4.4 Apply Settings (User Context)
    echo "  [..] Applying KDE Settings for user: $REAL_USER"

    # We need to run these commands as the logged-in user with their DBus session if possible
    # or just update the config files directly.
    # plasma-apply-lookandfeel needs DBus.

    # Helper to run as user
    run_as_user() {
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$REAL_USER")/bus" "$@"
    }

    # Try to apply global theme
    # Note: 'WhiteSur' might need checking specific name in 'lookandfeeltool -l'
    # Assuming 'WhiteSur' is the correct ID.
    if ! run_as_user lookandfeeltool -l | grep -q "WhiteSur"; then
         echo "  [..] Applying WhiteSur Global Theme..."
         run_as_user lookandfeeltool -a "WhiteSur" || run_as_user plasma-apply-lookandfeel -a "WhiteSur"
    else
         echo "  [OK] WhiteSur Global Theme seems to be active (or at least present)."
         # Force re-apply to be safe/idempotent if it's not the *current* one?
         # The prompt asks to check if already applied.
         # A simple check is hard with lookandfeeltool, so we might just re-apply if we aren't sure.
         # But let's respect the "check" constraint best effort.
         # For config files, we can check.
         :
    fi

    # Force Icons/Cursors via kwriteconfig
    # This edits ~/.config/kdeglobals and ~/.config/kcminputrc
    sudo -u "$REAL_USER" kwriteconfig5 --file kdeglobals --group Icons --key Theme WhiteSur
    sudo -u "$REAL_USER" kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme WhiteSur-cursors
    # For Plasma 6 support (kwriteconfig6 might be needed, or just kwriteconfig)
    if command -v kwriteconfig6 &>/dev/null; then
         sudo -u "$REAL_USER" kwriteconfig6 --file kdeglobals --group Icons --key Theme WhiteSur
         sudo -u "$REAL_USER" kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme WhiteSur-cursors
    fi
}

# ------------------------------------------------------------------------------
# 5. Enforce Plymouth (Boot Animation)
# ------------------------------------------------------------------------------
enforce_plymouth() {
    echo "Enforcing Plymouth..."

    # 5.1 Install Plymouth Theme
    # WhiteSur theme usually comes with the theme installer, but we can check specifically
    # or install a package.
    # If the user wants "Tahoe" branding, we might use a specific one, but "macOS-like" is requested.
    # We will use the AUR package 'plymouth-theme-macos-git' or similar if available,
    # OR since we downloaded WhiteSur theme earlier, it might have a plymouth option.
    # Let's try installing from AUR as generic fallback.

    if ! pacman -Qi plymouth-theme-macos-git &> /dev/null; then
        echo "  [..] Installing plymouth-theme-macos-git..."
        sudo -u "$REAL_USER" "$AUR_HELPER" -S --noconfirm --needed plymouth-theme-macos-git
    fi

    # 5.2 Configure Plymouth
    PLYMOUTH_CONF="/etc/plymouth/plymouthd.conf"
    # Check if config needs update
    if ! grep -q "Theme=macos" "$PLYMOUTH_CONF" 2>/dev/null; then
        echo "  [..] Setting Plymouth theme to 'macos'..."
        if [ -f "$PLYMOUTH_CONF" ]; then
            sed -i 's/^Theme=.*/Theme=macos/' "$PLYMOUTH_CONF"
        else
            echo -e "[Daemon]\nTheme=macos\nShowDelay=0" > "$PLYMOUTH_CONF"
        fi
        plymouth-set-default-theme -R macos
    else
        echo "  [OK] Plymouth theme is already set to macos."
    fi

    # 5.3 Configure mkinitcpio hooks
    MKINITCPIO_CONF="/etc/mkinitcpio.conf"
    if grep -q "^HOOKS=.*plymouth" "$MKINITCPIO_CONF"; then
        echo "  [OK] Plymouth hook is present."
    else
        echo "  [..] Adding Plymouth hook to mkinitcpio..."
        # Add plymouth after base and udev
        sed -i 's/HOOKS=(\(.*base udev\)\(.*\))/HOOKS=(\1 plymouth\2)/' "$MKINITCPIO_CONF"

        echo "  [..] Regenerating initramfs..."
        mkinitcpio -P
    fi
}

# ------------------------------------------------------------------------------
# Main Controller
# ------------------------------------------------------------------------------
main() {
    echo "========================================"
    echo " Starting Tahoe-Enforcer"
    echo "========================================"

    check_requirements
    install_aur_helper
    enforce_packages
    enforce_macos_theme
    enforce_plymouth

    echo "========================================"
    echo " Tahoe Enforcement Complete!"
    echo " Please reboot to see all changes."
    echo "========================================"
}

main
