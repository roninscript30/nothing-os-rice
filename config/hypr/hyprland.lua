-- Monitor: native 1080p, scale 1 (no fractional zoom)
hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "highres", position = "auto", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- unscale XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})

-- toolkit-specific scale (strictly 1:1, no zoom)
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("ELM_SCALE", "1")
hl.env("XFT_DPI", "96")

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")
