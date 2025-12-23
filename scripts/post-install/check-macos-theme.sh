#!/bin/bash

# Check if we are in KDE
if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    exit 0
fi

# Function to find the correct kwriteconfig executable
get_kwriteconfig() {
    if command -v kwriteconfig6 &> /dev/null; then
        echo "kwriteconfig6"
    elif command -v kwriteconfig5 &> /dev/null; then
        echo "kwriteconfig5"
    elif command -v kwriteconfig &> /dev/null; then
        echo "kwriteconfig"
    else
        return 1
    fi
}

KWRITECONFIG=$(get_kwriteconfig)

# Ensure WhiteSur is the applied global theme
# This command applies the global theme (Look and Feel)
# Try plasma-apply-lookandfeel (Plasma 5/6 standard)
if command -v plasma-apply-lookandfeel &> /dev/null; then
    plasma-apply-lookandfeel -a WhiteSur
fi

if [ -n "$KWRITECONFIG" ]; then
    # Enforce Cursor Theme
    $KWRITECONFIG --file kcminputrc --group Mouse --key cursorTheme WhiteSur-cursors

    # Enforce Icon Theme
    $KWRITECONFIG --file kdeglobals --group Icons --key Theme WhiteSur
fi

# Apply GTK Theme for consistency
if command -v gsettings &> /dev/null; then
    # Try setting common variants if the base name doesn't work, but usually "WhiteSur" is the metapackage name
    # We will attempt to set it to "WhiteSur-Dark" or "WhiteSur" depending on preference, defaulting to WhiteSur
    gsettings set org.gnome.desktop.interface gtk-theme "WhiteSur"
    gsettings set org.gnome.desktop.interface icon-theme "WhiteSur"
    gsettings set org.gnome.desktop.interface cursor-theme "WhiteSur-cursors"
fi
