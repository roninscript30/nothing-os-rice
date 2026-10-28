import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: Theme.t
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.glide
        }
    }

    function open() {
        shown = true;
        Qt.callLater(function() {
            stage.forceActiveFocus();
        });
    }

    function close() {
        shown = false;
    }

    function toggle() {
        if (shown) close();
        else open();
    }

    visible: shown || t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-cheatsheet"

    // Dimmed Scrim Background
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Stage {
        id: stage
        focus: true
        Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Escape) {
                root.close();
                e.accepted = true;
            }
        }

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 + 16 * (1 - root.t)
            width: Math.min(1740, stage.width - 40)
            height: Math.min(960, stage.height - 40)
            radius: 32
            color: Theme.s1
            border { width: 1.5; color: Theme.s3 }
            opacity: root.t
            clip: true

            MouseArea { anchors.fill: parent } // Prevent click-through to scrim

            Column {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 18

                // Top Header Bar
                Item {
                    width: parent.width
                    height: 44

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        // Pulsing red dot indicator
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: Theme.red
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Dot Matrix Title
                        Text {
                            text: "SHORTCUTS & GESTURES"
                            font { family: Theme.dot; pixelSize: 30; bold: true }
                            color: Theme.fg
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Subtitle badge
                        Rectangle {
                            height: 26
                            width: subText.implicitWidth + 18
                            radius: 13
                            color: Theme.s2
                            border { width: 1; color: Theme.s3 }
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: subText
                                anchors.centerIn: parent
                                text: "NOTHING OS · HYPRLAND CHEATSHEET"
                                font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 1.2 }
                                color: Theme.grey
                            }
                        }
                    }

                    // Esc / Close button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: closeRow.implicitWidth + 24
                        height: 36
                        radius: 18
                        color: Theme.s2
                        border { width: 1.5; color: Theme.s3 }

                        Row {
                            id: closeRow
                            anchors.centerIn: parent
                            spacing: 10

                            Rectangle {
                                width: 34
                                height: 22
                                radius: 5
                                color: Theme.s3
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    font { family: Theme.mono; pixelSize: 11; bold: true }
                                    color: Theme.fg
                                }
                            }

                            Text {
                                text: "SUPER + H"
                                font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.1 }
                                color: Theme.grey
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                // 3-Column Bento Grid Container
                Row {
                    width: parent.width
                    height: parent.height - 62
                    spacing: 18

                    // ================= COLUMN 1 =================
                    Column {
                        width: (parent.width - 36) / 3
                        height: parent.height
                        spacing: 16

                        // Card: SYSTEM & SHELL
                        Card {
                            width: parent.width
                            height: 480
                            title: "SYSTEM & SHELL"
                            badge: "CORE"

                            ShortcutRow { title: "Windows Overview"; desc: "Card switcher"; keys: ["SUPER (TAP)"] }
                            ShortcutRow { title: "App Launcher"; desc: "Search & run"; keys: ["SUPER", "D"] }
                            ShortcutRow { title: "Cheatsheet"; desc: "This panel"; keys: ["SUPER", "H"] }
                            ShortcutRow { title: "Nothing Deck"; desc: "Bottom dashboard"; keys: ["SUPER", "SPACE"] }
                            ShortcutRow { title: "Quick Settings"; desc: "System controls"; keys: ["SUPER", "A"] }
                            ShortcutRow { title: "Preferences"; desc: "Rice & home bento"; keys: ["SUPER", "I"] }
                            ShortcutRow { title: "Clipboard"; desc: "History & paste"; keys: ["SUPER", "V"] }
                            ShortcutRow { title: "Wallpaper"; desc: "Picker live"; keys: ["SUPER", "SHIFT", "W"] }
                            ShortcutRow { title: "Instant Sleep"; desc: "Low-power suspend"; keys: ["SUPER", "SHIFT", "L"] }
                            ShortcutRow { title: "Power Menu"; desc: "Reboot / Poweroff"; keys: ["SUPER", "SHIFT", "ESC"] }
                        }

                        // Card: APPLICATIONS
                        Card {
                            width: parent.width
                            height: parent.height - 480 - 16
                            title: "APPLICATIONS"
                            badge: "QUICK LAUNCH"

                            ShortcutRow { title: "Terminal Kitty"; desc: "Single instance ~40ms"; keys: ["SUPER", "T"] }
                            ShortcutRow { title: "Zen Browser"; desc: "Web browser"; keys: ["SUPER", "B"] }
                            ShortcutRow { title: "Antigravity IDE"; desc: "Code editor"; keys: ["SUPER", "E"] }
                            ShortcutRow { title: "File Manager"; desc: "Thunar"; keys: ["SUPER", "SHIFT", "E"] }
                            ShortcutRow { title: "System Monitor"; desc: "Btop workspace"; keys: ["SUPER", "ESC"] }
                            ShortcutRow { title: "Audio Mixer"; desc: "Pavucontrol"; keys: ["CTRL", "ALT", "V"] }
                        }
                    }

                    // ================= COLUMN 2 =================
                    Column {
                        width: (parent.width - 36) / 3
                        height: parent.height
                        spacing: 16

                        // Card: WINDOW CONTROL
                        Card {
                            width: parent.width
                            height: 480
                            title: "WINDOW CONTROL"
                            badge: "TILES & FOCUS"

                            ShortcutRow { title: "Close Window"; desc: "Graceful quit"; keys: ["SUPER", "Q"] }
                            ShortcutRow { title: "True Fullscreen"; desc: "Edge-to-edge"; keys: ["SUPER", "F"] }
                            ShortcutRow { title: "Bordered Full"; desc: "Maximized border"; keys: ["SUPER", "ALT", "F"] }
                            ShortcutRow { title: "Toggle Floating"; desc: "Float or tile"; keys: ["SUPER", "ALT", "SPACE"] }
                            ShortcutRow { title: "Pin Window"; desc: "Sticky all spaces"; keys: ["SUPER", "SHIFT", "P"] }
                            ShortcutRow { title: "Picture-in-Pic"; desc: "Floating corner"; keys: ["SUPER", "ALT", "\\"] }
                            ShortcutRow { title: "Center Window"; desc: "Display center"; keys: ["CTRL", "SUPER", "\\"] }
                            ShortcutRow { title: "Focus Window"; desc: "Directional jump"; keys: ["SUPER", "ARROWS"] }
                            ShortcutRow { title: "Swap Position"; desc: "Move active tile"; keys: ["SUPER", "SHIFT", "ARROWS"] }
                            ShortcutRow { title: "Resize Border"; desc: "Shrink / expand"; keys: ["SUPER", "ALT", "ARROWS"] }
                        }

                        // Card: WORKSPACES
                        Card {
                            width: parent.width
                            height: parent.height - 480 - 16
                            title: "WORKSPACES"
                            badge: "VIRTUAL DESKTOPS"

                            ShortcutRow { title: "Go to Workspace"; desc: "Switch 1 through 10"; keys: ["SUPER", "1 .. 9, 0"] }
                            ShortcutRow { title: "Move to Workspace"; desc: "Send window 1–10"; keys: ["SUPER", "SHIFT", "1 .. 0"] }
                            ShortcutRow { title: "Next / Prev Space"; desc: "Cycle spaces"; keys: ["CTRL + SUPER", "← / →"] }
                            ShortcutRow { title: "Scroll Spaces"; desc: "Mouse wheel cycle"; keys: ["SUPER + SCROLL"] }
                            ShortcutRow { title: "Scratchpad"; desc: "Toggle hidden space"; keys: ["SUPER", "S"] }
                            ShortcutRow { title: "Send to Scratchpad"; desc: "Hide focused window"; keys: ["SUPER", "ALT", "S"] }
                        }
                    }

                    // ================= COLUMN 3 =================
                    Column {
                        width: (parent.width - 36) / 3
                        height: parent.height
                        spacing: 16

                        // Card: TOUCHPAD GESTURES
                        Card {
                            width: parent.width
                            height: 480
                            title: "TOUCHPAD GESTURES"
                            badge: "HARDWARE EVDEV"

                            ShortcutRow { title: "Switch Workspaces"; desc: "Natural 3-finger swipe"; keys: ["3-FINGER SWIPE ↔"]; isGesture: true }
                            ShortcutRow { title: "Running Windows"; desc: "3-finger swipe UP"; keys: ["3-FINGER SWIPE ↑"]; isGesture: true }
                            ShortcutRow { title: "Close Overview"; desc: "3-finger swipe DOWN"; keys: ["3-FINGER SWIPE ↓"]; isGesture: true }
                            ShortcutRow { title: "Open App Launcher"; desc: "4-finger swipe UP"; keys: ["4-FINGER SWIPE ↑"]; isGesture: true }
                            ShortcutRow { title: "Close Launcher"; desc: "4-finger swipe DOWN"; keys: ["4-FINGER SWIPE ↓"]; isGesture: true }
                            ShortcutRow { title: "Kinetic Scroll"; desc: "2-finger smooth drag"; keys: ["2-FINGER SCROLL"]; isGesture: true }
                            ShortcutRow { title: "Instant Sleep"; desc: "Bottom-Left to Top-Right"; keys: ["CORNER ↗ (BL→TR)"]; isGesture: true }
                            ShortcutRow { title: "Instant Shutdown"; desc: "Bottom-Right to Top-Left"; keys: ["CORNER ↖ (BR→TL)"]; isGesture: true }
                            ShortcutRow { title: "Tap to Click"; desc: "Natural left tap"; keys: ["1-FINGER TAP"]; isGesture: true }
                        }

                        // Card: MEDIA & UTILITIES
                        Card {
                            width: parent.width
                            height: parent.height - 480 - 16
                            title: "MEDIA & UTILITIES"
                            badge: "SYSTEM TOOLS"

                            ShortcutRow { title: "Screenshot Tool"; desc: "Area / editor"; keys: ["PRINT", "SUPER+SHIFT+S"] }
                            ShortcutRow { title: "Color Picker"; desc: "Hyprpicker HEX"; keys: ["SUPER", "SHIFT", "C"] }
                            ShortcutRow { title: "Screen Record"; desc: "Video capture"; keys: ["SUPER", "ALT", "R"] }
                            ShortcutRow { title: "Media Play / Pause"; desc: "Toggle audio stream"; keys: ["CTRL + SUPER", "SPACE"] }
                            ShortcutRow { title: "Next / Prev Track"; desc: "Skip / replay"; keys: ["CTRL + SUPER", "= / -"] }
                            ShortcutRow { title: "Volume / Mute"; desc: "Speaker control"; keys: ["VOL KEYS", "SHIFT+M"] }
                        }
                    }
                }
            }
        }
    }

    // Reusable Bento Card Component
    component Card: Rectangle {
        id: cardRoot
        property string title: ""
        property string badge: ""
        default property alias content: cardCol.children

        radius: 22
        color: Theme.s2
        border { width: 1; color: Theme.s3 }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 11

            // Card Header
            Row {
                width: parent.width
                height: 26
                spacing: 10

                Rectangle {
                    width: 4
                    height: 16
                    radius: 2
                    color: Theme.red
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: cardRoot.title
                    font { family: Theme.mono; pixelSize: 13; bold: true; letterSpacing: 1.3 }
                    color: Theme.fg
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Rectangle {
                    height: 22
                    width: bText.implicitWidth + 14
                    radius: 11
                    color: Theme.s3
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: bText
                        anchors.centerIn: parent
                        text: cardRoot.badge
                        font { family: Theme.mono; pixelSize: 9; bold: true; letterSpacing: 0.9 }
                        color: Theme.grey
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.s3
                opacity: 0.6
            }

            // Items Column
            Column {
                id: cardCol
                width: parent.width
                spacing: 6
            }
        }
    }

    // High-Legibility Shortcut Row Component
    component ShortcutRow: Item {
        id: sRow
        property string title: ""
        property string desc: ""
        property var keys: []
        property bool isGesture: false

        width: parent.width
        height: 33

        // Left: Title and Description
        Row {
            anchors.left: parent.left
            anchors.right: keycapsRow.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: sRow.title
                font { family: Theme.ui; pixelSize: 14; bold: true }
                color: Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "· " + sRow.desc
                font { family: Theme.ui; pixelSize: 12 }
                color: "#9E9E9E"
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Right: Keycaps
        Row {
            id: keycapsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Repeater {
                model: sRow.keys

                Rectangle {
                    id: kCap
                    required property string modelData
                    height: 26
                    width: Math.max(28, kText.implicitWidth + 14)
                    radius: 6
                    color: sRow.isGesture ? Theme.fade(Theme.red, 0.22) : "#0B0B0B"
                    border {
                        width: 1
                        color: sRow.isGesture ? Theme.red : Theme.s3
                    }

                    Text {
                        id: kText
                        anchors.centerIn: parent
                        text: kCap.modelData
                        font { family: Theme.mono; pixelSize: 11; bold: true }
                        color: sRow.isGesture ? "#FF4A50" : Theme.fg
                    }
                }
            }
        }
    }
}
