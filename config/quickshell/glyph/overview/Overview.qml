import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Nothing OS Floating Application Overview
// Displays running application windows floating in space (GNOME 40+ style)
PanelWindow {
    id: root

    property bool open: false
    property string searchQuery: ""
    property int selectedWorkspaceFilter: -1 // -1 = current workspace, -2 = all workspaces, >= 0 = specific workspace ID

    function toggle() {
        if (open) {
            close();
        } else {
            searchQuery = "";
            open = true;
        }
    }

    function close() {
        open = false;
        searchQuery = "";
    }

    visible: open
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-overview"

    function resolveIcon(icon) {
        if (!icon) return "";
        if (icon.startsWith("/") || icon.startsWith("file://")) return icon;
        return Quickshell.iconPath(icon, true) || "";
    }

    readonly property var glyphMap: [
        ["zen", "\u{F0239}"], ["firefox", "\u{F0239}"], ["chrom", "\u{F059F}"], ["edge", "\u{F0239}"],
        ["kitty", "\u{F018D}"], ["foot", "\u{F018D}"], ["terminal", "\u{F018D}"],
        ["spotify", "\u{F04C7}"], ["telegram", "\u{F2C6}"], ["codium", "\u{F0A1E}"], ["code", "\u{F0A1E}"],
        ["antigravity", "\u{F0A1E}"], ["loaf", "\u{F024B}"], ["files", "\u{F024B}"], ["thunar", "\u{F024B}"],
        ["nautilus", "\u{F024B}"], ["chatgpt", "\u{F059F}"], ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"],
        ["settings", "\u{F0493}"]
    ]

    function getGlyph(key) {
        const k = (key || "").toLowerCase();
        const found = glyphMap.find(g => k.includes(g[0]));
        return found ? found[1] : "\u{F05D7}";
    }

    // Active workspace ID
    readonly property int currentWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // Extract all open toplevel windows from Hyprland
    readonly property var allWindows: !open ? [] : Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject || {};
        const cls = ipc.class ?? "";
        const initCls = ipc.initialClass ?? "";
        const wsId = ipc.workspace?.id ?? 1;
        const wsName = ipc.workspace?.name ?? String(wsId);
        const iconName = DesktopEntries.heuristicLookup(cls)?.icon 
                      || DesktopEntries.heuristicLookup(initCls)?.icon 
                      || cls.toLowerCase();

        return {
            title: t.title || cls || "Window",
            appClass: cls || "Application",
            workspaceId: wsId,
            workspaceName: wsName,
            iconPath: root.resolveIcon(iconName),
            glyphChar: root.getGlyph(cls + " " + (t.title ?? "")),
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

    // Filtered window list based on workspace filter and search query
    readonly property var filteredWindows: {
        const q = searchQuery.trim().toLowerCase();
        return allWindows.filter(w => {
            // Workspace filter
            if (selectedWorkspaceFilter === -1 && w.workspaceId !== currentWsId) {
                // If current workspace has no windows and we have windows elsewhere, don't show empty if there are windows
                if (allWindows.some(x => x.workspaceId === currentWsId)) return false;
            } else if (selectedWorkspaceFilter >= 0 && w.workspaceId !== selectedWorkspaceFilter) {
                return false;
            }
            // Search query filter
            if (q) {
                const haystack = (w.title + " " + w.appClass + " " + w.workspaceName).toLowerCase();
                return haystack.includes(q);
            }
            return true;
        });
    }

    // Dynamic sizing based on window count
    readonly property int winCount: filteredWindows.length
    readonly property real cardW: {
        if (winCount <= 1) return 640;
        if (winCount === 2) return 500;
        if (winCount <= 4) return 420;
        return 360;
    }
    readonly property real cardH: {
        if (winCount <= 1) return 400;
        if (winCount === 2) return 310;
        if (winCount <= 4) return 260;
        return 225;
    }

    // Dimmed dark background with click-outside to dismiss
    Rectangle {
        anchors.fill: parent
        color: "#0a0a0a"
        opacity: root.open ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Main Content
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) {
                root.close();
                e.accepted = true;
            } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && root.filteredWindows.length > 0) {
                root.filteredWindows[0].focus();
                e.accepted = true;
            }
        }

        // Top Control Area: Search Bar + Workspace Filters
        Column {
            id: topBar
            anchors {
                top: parent.top
                topMargin: 42
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 16
            z: 100

            // GNOME-style Pill Search Bar
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 440
                height: 46
                radius: 23
                color: searchInput.activeFocus ? "#1e1e1e" : "#141414"
                border {
                    width: searchInput.activeFocus ? 2 : 1
                    color: searchInput.activeFocus ? "#ffffff" : "#2a2a2a"
                }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 18
                        rightMargin: 18
                    }
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0349}"
                        font.pixelSize: 18
                        color: searchInput.activeFocus ? Theme.fg : Theme.grey
                    }

                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        color: Theme.fg
                        font { family: Theme.ui; pixelSize: 14 }
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "Type to search open apps..."
                            color: Theme.grey
                            font { family: Theme.ui; pixelSize: 14 }
                        }

                        onTextChanged: root.searchQuery = text

                        Component.onCompleted: {
                            if (root.open) forceActiveFocus();
                        }
                    }

                    // Clear button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!searchInput.text
                        width: 20
                        height: 20
                        radius: 10
                        color: Theme.s2

                        Text {
                            anchors.centerIn: parent
                            text: "\u{00D7}"
                            font.pixelSize: 14
                            color: Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.searchQuery = "";
                            }
                        }
                    }
                }
            }

            // Workspace Filter Pills
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // Current Workspace Pill
                Rectangle {
                    width: currentWsLabel.width + 24
                    height: 28
                    radius: 14
                    color: root.selectedWorkspaceFilter === -1 ? "#ffffff" : "#161616"
                    border { width: 1; color: root.selectedWorkspaceFilter === -1 ? "#ffffff" : "#2a2a2a" }

                    Text {
                        id: currentWsLabel
                        anchors.centerIn: parent
                        text: `Workspace ${root.currentWsId}`
                        font { family: Theme.ui; pixelSize: 11; weight: Font.Bold }
                        color: root.selectedWorkspaceFilter === -1 ? "#000000" : Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedWorkspaceFilter = -1
                    }
                }

                // All Workspaces Pill
                Rectangle {
                    width: allWsLabel.width + 24
                    height: 28
                    radius: 14
                    color: root.selectedWorkspaceFilter === -2 ? "#ffffff" : "#161616"
                    border { width: 1; color: root.selectedWorkspaceFilter === -2 ? "#ffffff" : "#2a2a2a" }

                    Text {
                        id: allWsLabel
                        anchors.centerIn: parent
                        text: `All (${root.allWindows.length})`
                        font { family: Theme.ui; pixelSize: 11; weight: Font.Bold }
                        color: root.selectedWorkspaceFilter === -2 ? "#000000" : Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedWorkspaceFilter = -2
                    }
                }
            }
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            visible: root.filteredWindows.length === 0
            spacing: 16

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{F05CE}"
                font.pixelSize: 48
                color: Theme.grey
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.searchQuery ? "No matching application windows" : "No open application windows"
                font { family: Theme.ui; pixelSize: 18 }
                color: Theme.grey
            }
        }

        // Floating Applications Stage (GNOME-Style Floating Cards)
        Item {
            id: stageArea
            anchors {
                top: topBar.bottom
                topMargin: 36
                bottom: parent.bottom
                bottomMargin: 50
                left: parent.left
                leftMargin: 60
                right: parent.right
                rightMargin: 60
            }
            visible: root.filteredWindows.length > 0

            Flickable {
                anchors.fill: parent
                contentWidth: flowGrid.width
                contentHeight: flowGrid.height
                clip: false
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: flowGrid
                    anchors.centerIn: parent
                    spacing: 36
                    flow: Flow.LeftToRight
                    width: {
                        if (root.winCount === 1) return root.cardW;
                        if (root.winCount === 2) return root.cardW * 2 + 36;
                        if (root.winCount <= 4) return root.cardW * 2 + 36;
                        return Math.min(parent.width, root.cardW * 3 + 72);
                    }

                    Repeater {
                        model: root.filteredWindows

                        delegate: Item {
                            id: cardWrapper
                            required property var modelData

                            width: root.cardW
                            height: root.cardH + 26 // Extra vertical space for the floating bottom icon

                            Rectangle {
                                id: card
                                width: root.cardW
                                height: root.cardH
                                radius: 18
                                color: cardHover.containsMouse ? "#1c1c1c" : "#131313"

                                // GNOME active highlight: Pure white border when hovered
                                border {
                                    width: cardHover.containsMouse ? 2 : 1
                                    color: cardHover.containsMouse ? "#ffffff" : "#242424"
                                }

                                scale: cardHover.containsMouse ? 1.03 : 1.0
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on border.width { NumberAnimation { duration: 150 } }

                                MouseArea {
                                    id: cardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.focus()
                                }

                                // Window Top Header
                                Rectangle {
                                    id: cardHeader
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }
                                    height: 38
                                    color: "#181818"
                                    radius: 18

                                    // Flat bottom corners for header
                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                        }
                                        height: 12
                                        color: "#181818"
                                    }

                                    // Window deco dots (Nothing OS style)
                                    Row {
                                        anchors {
                                            left: parent.left
                                            leftMargin: 14
                                            verticalCenter: parent.verticalCenter
                                        }
                                        spacing: 6

                                        Rectangle { width: 8; height: 8; radius: 4; color: "#ff5f56" }
                                        Rectangle { width: 8; height: 8; radius: 4; color: "#ffbd2e" }
                                        Rectangle { width: 8; height: 8; radius: 4; color: "#27c93f" }
                                    }

                                    // Window Title
                                    Text {
                                        anchors {
                                            left: parent.left
                                            leftMargin: 56
                                            right: headerRightArea.left
                                            rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: modelData.title
                                        font { family: Theme.ui; pixelSize: 12; weight: Font.Medium }
                                        color: cardHover.containsMouse ? "#ffffff" : Theme.fg
                                        elide: Text.ElideRight
                                    }

                                    // Header Right: Workspace badge + Close button
                                    Row {
                                        id: headerRightArea
                                        anchors {
                                            right: parent.right
                                            rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        spacing: 8

                                        // Workspace Pill
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: wsBadgeText.width + 12
                                            height: 20
                                            radius: 10
                                            color: "#222222"
                                            border { width: 1; color: "#333333" }

                                            Text {
                                                id: wsBadgeText
                                                anchors.centerIn: parent
                                                text: `WS ${modelData.workspaceName}`
                                                font { family: Theme.ui; pixelSize: 9; weight: Font.Bold }
                                                color: Theme.red
                                            }
                                        }

                                        // Close Button
                                        Rectangle {
                                            id: closeBtn
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: closeHover.containsMouse ? Theme.red : "#222222"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u{00D7}"
                                                font { pixelSize: 14; weight: Font.Bold }
                                                color: closeHover.containsMouse ? "#ffffff" : Theme.grey
                                            }

                                            MouseArea {
                                                id: closeHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.closeWin()
                                            }
                                        }
                                    }
                                }

                                // Window Canvas / Mock Body
                                Item {
                                    anchors {
                                        top: cardHeader.bottom
                                        bottom: parent.bottom
                                        left: parent.left
                                        right: parent.right
                                        bottomMargin: 24
                                    }

                                    // Subtle stylized watermark icon
                                    Icon {
                                        anchors.centerIn: parent
                                        text: modelData.glyphChar
                                        font.pixelSize: 64
                                        color: "#ffffff"
                                        opacity: cardHover.containsMouse ? 0.08 : 0.04
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    // App class subtitle centered
                                    Text {
                                        anchors {
                                            horizontalCenter: parent.horizontalCenter
                                            bottom: parent.bottom
                                            bottomMargin: 8
                                        }
                                        text: modelData.appClass.toUpperCase()
                                        font { family: Theme.ui; pixelSize: 11; weight: Font.Bold; letterSpacing: 1 }
                                        color: cardHover.containsMouse ? "#ffffff" : Theme.grey
                                        opacity: 0.6
                                    }
                                }

                                // Signature GNOME Floating App Icon Badge
                                // Floats at bottom center, half-in and half-out of the window card
                                Rectangle {
                                    id: floatingBadge
                                    anchors {
                                        horizontalCenter: parent.horizontalCenter
                                        verticalCenter: parent.bottom
                                    }
                                    width: 48
                                    height: 48
                                    radius: 24
                                    color: "#1c1c1c"
                                    border {
                                        width: cardHover.containsMouse ? 2 : 1.5
                                        color: cardHover.containsMouse ? "#ffffff" : "#303030"
                                    }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        source: modelData.iconPath
                                        visible: status === Image.Ready
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        text: modelData.glyphChar
                                        font.pixelSize: 22
                                        color: Theme.fg
                                        visible: !modelData.iconPath
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
