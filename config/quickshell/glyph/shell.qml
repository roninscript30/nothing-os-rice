import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "buds"
import "cal"
import "cheatsheet"
import "clip"
import "deck"
import "glyph"
import "home"
import "launcher"
import "overview"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "vpn"
import "wall"

// glyph: Nothing OS inspired rice. Wallpaper home widgets, bar, launcher, quick settings,
// Glyph lightbars as OSD, notification island, power menu, settings, bottom deck, clipboard, screenshot, vpn, wallpapers. Lockscreen is a separate process (lock.qml).
// Can switch via `rice switch` / Rice app - Hyprland binds are shared (shell:*), each shell claims its own
ShellRoot {
    id: shell

    Overview { id: overview }
    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.open(); onSettingsRequested: prefs.open() }
    Power { id: power }
    Prefs { id: prefs; onWallRequested: walls.open() }
    Glyph {}
    Buds {}
    Cal { id: cal }
    Clip { id: clip }
    Deck { id: deck }
    Shot { id: shot }
    Cheatsheet { id: cheatsheet }
    Vpn { id: vpn }
    Walls { id: walls }

    property bool barVisible: false

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            Home { screen: s.modelData }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Bar {
                visible: shell.barVisible
                screen: s.modelData
                onMarkClicked: Quickshell.execDetached(["/home/marudhu/.config/rofi/scripts/nothing-launcher.sh"])
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
                onClockClicked: cal.toggle()
            }
        }
    }

    // Hyprland rules apply monitor, input, motion, nightlight and hypridle; Theme.apply applies custom border colors, rounding and kitty
    Component.onCompleted: {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Rules.night();
        Rules.idle();
        Theme.apply();
    }
    Connections {
        target: Theme
        function onLightChanged() { Theme.apply(); }
    }
    Connections {
        target: Theme.state
        function onRoundingChanged() { Theme.apply(); }
    }
    // Ultra mode toggles blur and shadows over settings - recolors windows
    Connections {
        target: Rules.store
        function onUltraChanged() { Theme.apply(); }
    }

    Shortcut {
        name: "windows"
        description: "Zoom-out overview of running apps (Super tap)"
        onPressed: overview.toggle()
    }
    Shortcut {
        name: "cycle_windows"
        description: "Cycle open windows (Super+Tab)"
        onPressed: overview.cycleNext()
    }
    Shortcut {
        name: "launcher"
        description: "Application launcher (Super+D)"
        onPressed: Quickshell.execDetached(["/home/marudhu/.config/rofi/scripts/nothing-launcher.sh"])
    }
    Shortcut {
        name: "help"
        description: "Hotkeys cheatsheet (Super+H)"
        onPressed: cheatsheet.toggle()
    }
    Shortcut { name: "altar"; description: "Deck dashboard"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "Quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "Quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "settings"; description: "Preferences"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "Power menu"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "Screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "VPN: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "Clipboard"; onPressed: clip.toggle() }
    Shortcut { name: "wall"; description: "Wallpapers"; onPressed: walls.toggle() }
    Shortcut { name: "bar"; description: "Side bar"; onPressed: shell.barVisible = !shell.barVisible }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
