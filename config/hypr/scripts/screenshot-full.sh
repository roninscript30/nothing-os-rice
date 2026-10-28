#!/usr/bin/env bash
# Instant Fullscreen Screenshot for Nothing OS Hyprland Rice

dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/shots"
mkdir -p "$dir"
file="$dir/shot-$(date +%F_%H-%M-%S).png"

# Ensure WAYLAND_DISPLAY is set
if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="wayland-1"
fi

# Capture instantly to file and clipboard
grim "$file" && wl-copy -t image/png < "$file"

# Notification with preview thumbnail
if [ -f "$file" ]; then
    notify-send -a "Screenshot" -i "$file" "Captured Fullscreen" "Saved to $(basename "$file") & copied to clipboard"
fi
