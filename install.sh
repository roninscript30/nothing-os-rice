#!/usr/bin/env bash
# Nothing OS (Glyph) Rice - Installer & Deployment Script
# Automatically deploys configurations, binaries, assets, and desktop session.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Deploying Nothing OS Rice from: $REPO_DIR"

# 1. Create target directories
mkdir -p "$HOME/.config/hypr-nothing-os/assets"
mkdir -p "$HOME/.config/quickshell"
mkdir -p "$HOME/.config/demonshot"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/state/rice"
mkdir -p "$HOME/.config/environment.d"

# 2. Deploy Hyprland Nothing OS configuration
echo "==> Syncing Hyprland configuration to ~/.config/hypr-nothing-os..."
rsync -av --delete --exclude="assets/*.mp4" "$REPO_DIR/config/hypr/" "$HOME/.config/hypr-nothing-os/"

# 3. Deploy Quickshell Glyph & Rice
echo "==> Linking Quickshell Glyph shell and rice switcher..."
ln -sfn "$REPO_DIR/config/quickshell/glyph" "$HOME/.config/quickshell/glyph"
ln -sfn "$REPO_DIR/config/quickshell/rice" "$HOME/.config/quickshell/rice"

# 4. Deploy Rofi & Kitty
echo "==> Syncing Rofi launcher and Kitty configs..."
rsync -av "$REPO_DIR/config/rofi/" "$HOME/.config/rofi/"
ln -sfn "$REPO_DIR/config/kitty" "$HOME/.config/kitty"

# 5. Deploy Binaries
echo "==> Installing executables to ~/.local/bin..."
install -m 755 "$REPO_DIR/bin/app-kill-clean" "$HOME/.local/bin/app-kill-clean"
install -m 755 "$REPO_DIR/bin/workspace-kill-clean" "$HOME/.local/bin/workspace-kill-clean"
install -m 755 "$REPO_DIR/bin/rice" "$HOME/.local/bin/rice"

# 6. Deploy Assets
echo "==> Setting up avatar and profile picture..."
install -m 644 "$REPO_DIR/assets/avatar.png" "$HOME/.config/hypr-nothing-os/assets/avatar.png"
cp "$REPO_DIR/assets/avatar.png" "$HOME/.face"
cp "$REPO_DIR/assets/avatar.png" "$HOME/.face.icon" 2>/dev/null || true

# Check for lock screen background video
if [ -f "$HOME/Downloads/RB22.mp4" ] && [ ! -f "$HOME/.config/hypr-nothing-os/assets/RB22.mp4" ]; then
    echo "==> Copying lock screen video RB22.mp4 from ~/Downloads..."
    cp "$HOME/Downloads/RB22.mp4" "$HOME/.config/hypr-nothing-os/assets/RB22.mp4"
fi

# 7. System rules and idle
echo "==> Syncing rules and idle configurations..."
install -m 644 "$REPO_DIR/system/rules.json" "$HOME/.config/demonshot/rules.json"
install -m 644 "$REPO_DIR/system/hypridle.conf" "$HOME/.config/demonshot/hypridle.conf"
[ -f "$REPO_DIR/system/qml_color.json" ] && install -m 644 "$REPO_DIR/system/qml_color.json" "$HOME/.config/quickshell/qml_color.json"

# 8. Environment variables for QtMultimedia
echo 'QML_IMPORT_PATH="${HOME}/.local/lib/qt6/qml:${QML_IMPORT_PATH}"' > "$HOME/.config/environment.d/10-qt6.conf"
echo 'LD_LIBRARY_PATH="${HOME}/.local/lib/qt6:${LD_LIBRARY_PATH}"' >> "$HOME/.config/environment.d/10-qt6.conf"

# 9. Set current active shell to glyph
echo "glyph" > "$HOME/.local/state/rice/shell"

echo "==> Nothing OS Rice deployed successfully!"
echo "    Reload Hyprland with: hyprctl reload"
echo "    Test Lock Screen with: Super + L"
