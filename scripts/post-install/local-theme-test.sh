#!/bin/bash
# Description: Automated script to specificially test/apply the theme on an existing install
# without running the full installer. Handles paths and python dependencies automatically.

# 1. Determine the absolute path of the repository root based on this script's location
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Detected Repo Root: $REPO_ROOT"

# 2. Add local bin to PATH for the duration of this script (for pipx/konsave)
export PATH=$PATH:$HOME/.local/bin

# 3. Install konsole if not present (required for konsave sometimes, or assumed)
# The user asked for maximum reliability.
echo "Checking dependencies..."

if ! command -v pipx &> /dev/null; then
    echo "• pipx not found. Installing python-pipx..."
    sudo pacman -S --noconfirm python-pipx
    pipx ensurepath
else
    echo "• pipx is already installed."
fi

if ! command -v konsave &> /dev/null; then
    echo "• konsave not found. Installing via pipx..."
    pipx install konsave
    pipx inject konsave setuptools
else
    echo "• konsave is already installed."
    # Ensure setuptools is there even if already installed
    pipx inject konsave setuptools
fi

# 4. Copy configuration files
echo "Copying config files from $REPO_ROOT/configs/.config to $HOME/.config..."
cp -r "$REPO_ROOT/configs/.config/"* "$HOME/.config/"

# 5. Apply the KDE Rice using Konsave
echo "Importing KDE profile..."
# Overwrite if exists to ensure we get the latest
if konsave -l | grep -q "kde"; then
    echo "• Removing old 'kde' profile to ensure clean import..."
    konsave -r kde
fi
konsave -i "$REPO_ROOT/configs/kde.knsv"

echo "Applying KDE profile..."
konsave -a kde

echo "Done! Theme applied."
