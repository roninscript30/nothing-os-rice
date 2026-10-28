#!/usr/bin/env bash
# Nothing OS (Glyph) Rofi Application Launcher - Grid & Window Switcher Mode

# Toggle: If rofi is already active, close it instantly
if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

# Ensure WAYLAND_DISPLAY is available
if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="wayland-1"
fi

# Launch Rofi with drun and window modes
exec rofi \
    -show drun \
    -modi drun,window \
    -theme "$HOME/.config/rofi/themes/nothing-os.rasi"
