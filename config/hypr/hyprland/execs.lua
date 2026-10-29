local vars = require("variables")
local fn   = require("hyprland.functions")

hl.on("hyprland.start", function()
    -- Sync environment with systemd and dbus
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QML_IMPORT_PATH LD_LIBRARY_PATH")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QML_IMPORT_PATH LD_LIBRARY_PATH")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal")

    -- Shell: тот, что выбран в rice
    hl.exec_cmd(vars.rice .. " start")
    hl.exec_cmd("sh -c 'sleep 0.5 && " .. vars.rice .. " lock'")

    -- во вложенной сессии системные демоны уже работают снаружи
    if vars.nested then return end

    -- Keyring and auth (gnome-keyring-daemon is managed by systemd --user)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Auto delete trash 30 days old
    hl.exec_cmd("trash-empty 30")

    -- Cursors
    hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

    -- Location provider
    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")

    -- hypridle поднимает шелл (Rules.idle): тайминги из house rules → ~/.config/demonshot/hypridle.conf

    -- фоновый kitty без окна: первый Super+Q тоже открывается мгновенно
    hl.exec_cmd(vars.terminal .. " --start-as=hidden")
end)

-- Resizer listener
hl.on("window.title", function(win)
    local d = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, d, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)

hl.on("window.open", function(win)
    local d = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, d, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)
