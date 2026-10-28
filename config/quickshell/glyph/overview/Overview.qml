import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Nothing OS Application Overview: Floats all running windows when pressing Super key
PanelWindow {
    id: root

    property bool open: false
    function toggle() { open = !open; }
    function close() { open = false; }

    visible: open
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-overview"

    // Gather running windows from Hyprland
    readonly property var windowList: !open ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        const icon = DesktopEntries.heuristicLookup(cls)?.icon ?? "";
        const ws = t.lastIpcObject?.workspace?.name ?? (t.lastIpcObject?.workspace?.id ?? "");
        return {
            title: t.title || cls || "Window",
            appClass: cls || "Application",
            workspace: ws ? `Workspace ${ws}` : "",
            iconName: icon,
            address: t.address,
            focus: () => {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`);
                root.close();
            },
            closeWin: () => {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${t.address}" })`);
            }
        };
    })

    // Dimmed background with click-to-exit
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.78 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) {
                root.close();
                e.accepted = true;
            }
        }

        // Header
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 50 }
            spacing: 8

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F05D7}"
                    font.pixelSize: 22
                    color: Theme.red
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RUNNING APPS OVERVIEW"
                    font { family: Theme.ui; pixelSize: 22; weight: Font.Bold; letterSpacing: 2 }
                    color: Theme.fg
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: countText.width + 16
                    height: 24
                    radius: 12
                    color: Theme.s2
                    border { width: 1; color: Theme.s3 }

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: `${root.windowList.length} ACTIVE`
                        font { family: Theme.ui; pixelSize: 11; weight: Font.Medium }
                        color: Theme.fg
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Click any window to focus · Esc or Super to exit"
                font { family: Theme.ui; pixelSize: 13 }
                color: Theme.grey
            }
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            visible: root.windowList.length === 0
            spacing: 16

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{F05CE}"
                font.pixelSize: 48
                color: Theme.grey
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No active application windows"
                font { family: Theme.ui; pixelSize: 18 }
                color: Theme.grey
            }
        }

        // Window Cards Grid (Floating overview)
        Flickable {
            id: scrollArea
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                topMargin: 150
                bottomMargin: 60
                leftMargin: 80
                rightMargin: 80
            }
            contentWidth: flowLayout.width
            contentHeight: flowLayout.height
            clip: true

            Flow {
                id: flowLayout
                width: scrollArea.width
                spacing: 24
                flow: Flow.LeftToRight

                Repeater {
                    model: root.windowList

                    delegate: Rectangle {
                        id: card
                        required property var modelData

                        width: 320
                        height: 200
                        radius: 18
                        color: cardMouse.containsMouse ? "#1c1c1c" : "#121212"
                        // Pure white border highlight on hover matching user's border theme
                        border {
                            width: cardMouse.containsMouse ? 2 : 1
                            color: cardMouse.containsMouse ? "#ffffff" : "#2a2a2a"
                        }
                        scale: cardMouse.containsMouse ? 1.04 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.focus()
                        }

                        // Top bar of card
                        Row {
                            anchors { left: parent.left; leftMargin: 16; right: closeBtn.left; rightMargin: 8; top: parent.top; topMargin: 16 }
                            spacing: 12

                            // App Icon
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: Theme.s2
                                border { width: 1; color: Theme.s3 }

                                Image {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: modelData.iconName ? Quickshell.iconPath(modelData.iconName, true) : ""
                                    visible: status === Image.Ready
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    text: "\u{F05D7}"
                                    font.pixelSize: 18
                                    color: Theme.fg
                                    visible: !modelData.iconName
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 52
                                spacing: 2

                                Text {
                                    text: modelData.appClass.toUpperCase()
                                    font { family: Theme.ui; pixelSize: 14; weight: Font.Bold }
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: modelData.workspace
                                    font { family: Theme.ui; pixelSize: 11 }
                                    color: Theme.red
                                }
                            }
                        }

                        // Close button on card
                        Rectangle {
                            id: closeBtn
                            anchors { top: parent.top; topMargin: 16; right: parent.right; rightMargin: 16 }
                            width: 28
                            height: 28
                            radius: 14
                            color: closeMouse.containsMouse ? Theme.red : Theme.s2
                            border { width: 1; color: closeMouse.containsMouse ? Theme.red : Theme.s3 }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Icon {
                                anchors.centerIn: parent
                                text: "\u{F0156}"
                                font.pixelSize: 12
                                color: closeMouse.containsMouse ? "#ffffff" : Theme.grey
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.closeWin()
                            }
                        }

                        // Window Title body
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                            height: 90
                            radius: 10
                            color: "#0a0a0a"
                            border { width: 1; color: "#1e1e1e" }

                            Text {
                                anchors { fill: parent; margins: 12 }
                                text: modelData.title
                                font { family: Theme.ui; pixelSize: 13 }
                                color: Theme.fg
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 3
                            }
                        }
                    }
                }
            }
        }
    }
}
