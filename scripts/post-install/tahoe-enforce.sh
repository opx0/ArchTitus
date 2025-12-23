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

    # Check for dock (plank as fallback check)
    if ! pacman -Qi plank &> /dev/null; then
         PACKAGES+=("plank")
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

    # 4.4 Open Settings for User Selection
    echo "  [..] Opening KDE System Settings for manual theme selection..."
    echo "       Please select 'MacTahoe-Light' (or Dark) from the window that appears."
    
    # Open the Global Theme settings page
    if command -v kcmshell6 &>/dev/null; then
         run_as_user kcmshell6 kcm_lookandfeel &>/dev/null &
    elif command -v kcmshell5 &>/dev/null; then
         run_as_user kcmshell5 kcm_lookandfeel &>/dev/null &
    else
         run_as_user systemsettings kcm_lookandfeel &>/dev/null &
    fi
}

# ------------------------------------------------------------------------------
# 5. Enforce Panel Settings (Dimensions/Layout)
# ------------------------------------------------------------------------------
enforce_panel_settings() {
    echo "Enforcing Panel Settings..."
    
    # Define the JS script to set panel height
    # Target height: 30px (typical for macOS menu bar look)
    read -r -d '' JS_SCRIPT <<'EOF'
var allPanels = panels();
var foundTop = false;
for (var i = 0; i < allPanels.length; i++) {
    var p = allPanels[i];
    if (p.location == "top") {
        p.height = 30;
        foundTop = true;
    }
}
if (!foundTop) {
    // Optional: Create top panel if missing? 
    // For now, we assume one exists as per standard layout.
}
EOF

    # Helper to run as user (re-defined locally if needed, but we can reuse if in scope or redefine)
    # We'll just define the specific execution logic here using the variables from main or global scope
    # Accessing REAL_USER from global scope
    
    echo "  [..] Setting panel height to 30px..."
    
    # Detect qdbus executable
    QDBUS_CMD=""
    if command -v qdbus6 &>/dev/null; then
        QDBUS_CMD="qdbus6"
    elif command -v qdbus-qt5 &>/dev/null; then
        QDBUS_CMD="qdbus-qt5"
    elif command -v qdbus &>/dev/null; then
        QDBUS_CMD="qdbus"
    fi

    if [ -n "$QDBUS_CMD" ]; then
        # We need to run this command as the user, with their DBus session environment
        # We rely on finding the user's bus address.
        USER_ID=$(id -u "$REAL_USER")
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
        
        # Run the script via qdbus
        # Note: We need to use sudo -u to run as the user
        if sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" "$QDBUS_CMD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_SCRIPT" >/dev/null; then
            echo "  [OK] Panel height updated."
        else
            echo "  [!] Warning: Failed to update panel settings via $QDBUS_CMD."
        fi
    else
        echo "  [!] Error: qdbus not found. Cannot script panel settings."
    fi
}

# ------------------------------------------------------------------------------
# 6. Enforce Plymouth (Boot Animation)
# ------------------------------------------------------------------------------
enforce_plymouth() {
    echo "Enforcing Plymouth..."

    # 5.1 Install Plymouth Theme -> 6.1
    # ... (logic remains same, just comments) ...
    # ...
    
    if ! pacman -Qi plymouth-theme-macos-git &> /dev/null; then
        echo "  [..] Installing plymouth-theme-macos-git..."
        sudo -u "$REAL_USER" "$AUR_HELPER" -S --noconfirm --needed plymouth-theme-macos-git
    fi

    # 6.2 Configure Plymouth
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

    # 6.3 Configure mkinitcpio hooks
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
    enforce_panel_settings
    enforce_plymouth

    echo "========================================"
    echo " Tahoe Enforcement Complete!"
    echo " Please reboot to see all changes."
    echo "========================================"
}

main
