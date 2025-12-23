#!/usr/bin/env bash
# Disposable Plymouth Test Script
# Installs 'exanor-glow', previews it, and offers to Revert to 'arch-glow'.

THEME_NAME="exanor-glow"
ORIGINAL_THEME="arch-glow" # Or whatever was default before
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$REPO_ROOT/configs/usr/share/plymouth/themes/$THEME_NAME"
DEST_DIR="/usr/share/plymouth/themes/$THEME_NAME"

echo "=== Plymouth Theme Tester ==="
echo "Target Theme: $THEME_NAME"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR not found!"
    exit 1
fi

echo "[1/3] Installing $THEME_NAME..."
sudo mkdir -p "$DEST_DIR"
sudo cp -rf "$SOURCE_DIR"/* "$DEST_DIR/"

echo "[2/3] Setting default theme..."
sudo plymouth-set-default-theme -R "$THEME_NAME"

echo "[3/3] Launching Preview (5 seconds)..."
if command -v plymouthd &>/dev/null; then
  sudo plymouth --quit &>/dev/null
  sudo plymouthd
  sudo plymouth --show-splash
  sleep 5
  sudo plymouth --quit
else
  echo "Plymouth not found. Skipping preview."
fi

echo ""
echo "=== Test Complete ==="
echo "Did the theme look correct?"
read -p "Press 'r' to REVERT to '$ORIGINAL_THEME' and delete '$THEME_NAME' system files, or ENTER to keep it: " choice

if [[ "$choice" == "r" || "$choice" == "R" ]]; then
    echo "Reverting to $ORIGINAL_THEME..."
    sudo plymouth-set-default-theme -R "$ORIGINAL_THEME"
    echo "Removing $DEST_DIR..."
    sudo rm -rf "$DEST_DIR"
    echo "Reverted successfully."
else
    echo "Theme kept. You can verify/install again later."
fi
