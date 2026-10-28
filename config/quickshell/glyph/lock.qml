import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// блокировка — отдельный процесс: qs -p …/glyph/lock.qml (его зовёт `rice lock`). Разблокировались — выходим.
ShellRoot {
    id: shell
    settings.watchFiles: false

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // пароль принят: поверхность доигрывает уход, потом unlockT снимает лок
        readonly property bool busy: pam.active
        function submit() {
            if (!buffer || pam.active || leaving) return;
            pamWatchdog.restart();
            pam.start();
        }
    }

    Timer {
        id: pamWatchdog
        interval: 3500
        repeat: false
        onTriggered: {
            if (pam.active && !gate.leaving) {
                console.warn("PAM watchdog triggered, resetting state");
                gate.fail = true;
                gate.buffer = "";
            }
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: if (responseRequired) respond(gate.buffer)
        onCompleted: res => {
            pamWatchdog.stop();
            gate.buffer = "";
            if (res === PamResult.Success) {
                gate.leaving = true;
                unlockT.start();
            } else {
                gate.fail = true;
            }
        }
    }
    Timer { id: unlockT; interval: 470; onTriggered: lock.locked = false }

    property string layout: "en"
    function shortLayout(name) { return name.slice(0, 2).toLowerCase(); }
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) shell.layout = shell.shortLayout(text.trim()) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") shell.layout = shell.shortLayout(e.data.split(",").pop()); }
    }

    WlSessionLock {
        id: lock
        locked: true
        onSecureChanged: if (!secure) Qt.quit()

        LockSurface { auth: gate; layout: shell.layout }
    }
}
