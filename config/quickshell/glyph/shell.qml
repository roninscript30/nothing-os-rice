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

// glyph: rice в духе nothing os. Дом на обоях, бар, лаунчер, быстрые настройки,
// Glyph-полосы по краям вместо OSD, остров уведомлений, меню питания, настройки, deck (дашборд снизу), буфер обмена, скриншоты, vpn, обои. Блокировка — отдельный процесс (lock.qml).
// Переключается с demonshot через `rice switch` / приложение Rice — бинды hypr общие (shell:*), каждый шелл берёт свои
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

    // hypr как у demonshot: его Rules (settings/Rules.qml, тот же ~/.config/demonshot/rules.json) ставит монитор, ввод,
    // движение, ночник и hypridle; сверху Theme.apply — свои цвета рамок, скругление и kitty. Его же зовём при смене темы
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
    // режим ultra включает/снимает blur и тени поверх настроек — окна перекрасить (герцы и движение ставит сам Rules.setMode)
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
        name: "launcher"
        description: "лаунчер приложений (Super+D)"
        onPressed: Quickshell.execDetached(["/home/marudhu/.config/rofi/scripts/nothing-launcher.sh"])
    }
    Shortcut {
        name: "help"
        description: "панель горячих клавиш (Super+H)"
        onPressed: cheatsheet.toggle()
    }
    // Super+Space (алтарь у demonshot) — deck, дашборд снизу: лаунчер и так на тапе Super
    Shortcut { name: "altar"; description: "deck: дашборд снизу"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "быстрые настройки"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "быстрые настройки"; onPressed: quick.toggle() } // Super+N у demonshot — те же тумблеры
    Shortcut { name: "settings"; description: "настройки"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "меню питания"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "скриншот"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "буфер обмена"; onPressed: clip.toggle() }
    Shortcut { name: "wall"; description: "обои"; onPressed: walls.toggle() }
    Shortcut { name: "bar"; description: "боковая панель"; onPressed: shell.barVisible = !shell.barVisible }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
