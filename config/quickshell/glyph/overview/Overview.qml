import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Nothing OS Enhanced Application & Workspace Overview
// Provides real window previews, live CPU/RAM metrics, workspace management,
// integrated app launcher, and full keyboard-first navigation.
PanelWindow {
    id: root

    property bool open: false
    property string searchQuery: ""
    property int selectedWorkspaceId: -1 // -1 = show active workspace, 0 = all workspaces, >0 = specific workspace
    property int activeSection: 1 // 0: Search, 1: Workspaces, 2: Windows, 3: Launcher
    property int selectedWinIndex: 0
    property int selectedWsIndex: 0
    property int selectedAppIndex: 0
    property var windowStats: ({})

    function toggle() {
        if (open) close();
        else openOverview();
    }

    function openOverview() {
        searchQuery = "";
        selectedWorkspaceId = currentWsId;
        selectedWinIndex = 0;
        selectedAppIndex = 0;
        activeSection = 2; // Default to windows section
        open = true;
        refreshStats();
    }

    function close() {
        open = false;
        searchQuery = "";
        cleanProc.exec(["python3", "/home/marudhu/REPOS/nothing-os-rice/config/quickshell/glyph/overview/overview_stats.py", "--clean"]);
    }

    function cycleNext() {
        if (!open) {
            openOverview();
            return;
        }
        if (filteredWindows.length > 0) {
            activeSection = 2;
            selectedWinIndex = (selectedWinIndex + 1) % filteredWindows.length;
        }
    }

    visible: open
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-overview"

    // Periodic stats collection when overview is open (every 3 seconds)
    Timer {
        id: statsTimer
        interval: 3000
        running: root.open
        repeat: true
        onTriggered: root.refreshStats()
    }

    function refreshStats() {
        if (!root.open) return;
        statsProc.exec(["python3", "/home/marudhu/REPOS/nothing-os-rice/config/quickshell/glyph/overview/overview_stats.py"]);
    }

    Process {
        id: statsProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                try {
                    root.windowStats = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process { id: cleanProc }

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
        ["btop", "\u{F035B}"], ["settings", "\u{F0493}"]
    ]

    function getGlyph(key) {
        const k = (key || "").toLowerCase();
        const found = glyphMap.find(g => k.includes(g[0]));
        return found ? found[1] : "\u{F05D7}";
    }

    // Active workspace ID from Hyprland
    readonly property int currentWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // Workspaces model (1 to 5+)
    readonly property var workspaceList: {
        const activeIds = Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0 && id <= 10);
        const maxWs = Math.max(5, ...activeIds, currentWsId);
        const list = [];
        for (let i = 1; i <= Math.min(10, maxWs); i++) {
            const occ = activeIds.includes(i);
            const winCount = allWindows.filter(w => w.workspaceId === i).length;
            list.push({
                id: i,
                name: `WS ${i}`,
                active: i === currentWsId,
                occupied: occ || winCount > 0,
                winCount: winCount
            });
        }
        return list;
    }

    // All running toplevel windows
    readonly property var allWindows: !open ? [] : Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject || {};
        const cls = ipc.class ?? "";
        const initCls = ipc.initialClass ?? "";
        const wsId = ipc.workspace?.id ?? 1;
        const wsName = ipc.workspace?.name ?? String(wsId);
        const iconName = DesktopEntries.heuristicLookup(cls)?.icon 
                      || DesktopEntries.heuristicLookup(initCls)?.icon 
                      || cls.toLowerCase();

        const st = root.windowStats[t.address] || {};
        const cpuStr = st.cpu || "0.0%";
        const memStr = st.mem || "N/A";
        const statusStr = st.status || (ipc.floating ? "Floating" : "Tiled");
        const previewPath = st.preview || "";

        return {
            title: t.title || cls || "Window",
            appClass: cls || "Application",
            workspaceId: wsId,
            workspaceName: wsName,
            iconPath: root.resolveIcon(iconName),
            glyphChar: root.getGlyph(cls + " " + (t.title ?? "")),
            address: t.address,
            cpu: cpuStr,
            mem: memStr,
            status: statusStr,
            preview: previewPath,
            focus: () => {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`);
                root.close();
            },
            closeWin: () => {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${t.address}" })`);
                root.refreshStats();
            },
            moveToWs: (targetWs) => {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, window = "address:${t.address}" })`);
                root.refreshStats();
            }
        };
    })

    // Filtered windows based on workspace filter and search query
    readonly property var filteredWindows: {
        const q = searchQuery.trim().toLowerCase();
        return allWindows.filter(w => {
            // Workspace filter (0 means ALL workspaces)
            if (selectedWorkspaceId > 0 && w.workspaceId !== selectedWorkspaceId) {
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

    // Installed desktop applications for launcher
    readonly property var installedApps: !open ? [] : DesktopEntries.applications.values
        .filter(e => !e.noDisplay && e.name)
        .map(e => {
            const iconPath = root.resolveIcon(e.icon);
            const isRunning = allWindows.some(w => {
                const cls = (w.appClass || "").toLowerCase();
                const id = (e.id || "").toLowerCase();
                const name = (e.name || "").toLowerCase();
                return id.includes(cls) || cls.includes(id) || name.includes(cls) || cls.includes(name);
            });
            return {
                id: e.id,
                name: e.name,
                genericName: e.genericName || "",
                iconPath: iconPath,
                glyphChar: root.getGlyph(e.id + " " + e.name),
                isRunning: isRunning,
                execute: () => {
                    try {
                        if (typeof e.execute === "function") {
                            e.execute();
                        } else {
                            Quickshell.execDetached(["sh", "-c", e.execString || e.id]);
                        }
                    } catch (err) {
                        Quickshell.execDetached(["sh", "-c", e.execString || e.id]);
                    }
                    root.close();
                }
            };
        })
        .filter(app => {
            if (!searchQuery) return true;
            const q = searchQuery.trim().toLowerCase();
            return (app.name + " " + app.genericName + " " + app.id).toLowerCase().includes(q);
        })
        .sort((a, b) => (b.isRunning - a.isRunning) || a.name.localeCompare(b.name))

    // Dynamic sizing based on window count
    readonly property int winCount: filteredWindows.length
    readonly property real cardW: {
        if (winCount <= 1) return 560;
        if (winCount === 2) return 460;
        if (winCount <= 4) return 380;
        return 330;
    }
    readonly property real cardH: {
        if (winCount <= 1) return 340;
        if (winCount === 2) return 280;
        if (winCount <= 4) return 240;
        return 210;
    }

    // Dimmed background with click-to-exit
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.88 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Container item receiving focus and keyboard events
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            // Close on Escape or Super tap
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) {
                root.close();
                e.accepted = true;
                return;
            }

            // Tab / Shift+Tab cycles activeSection
            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                if (e.modifiers & Qt.ShiftModifier || e.key === Qt.Key_Backtab) {
                    root.activeSection = (root.activeSection + 3) % 4;
                } else {
                    root.activeSection = (root.activeSection + 1) % 4;
                }
                if (root.activeSection === 0) searchInput.forceActiveFocus();
                e.accepted = true;
                return;
            }

            // Workspace Direct Jump 1-9
            if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && !(e.modifiers & Qt.ControlModifier)) {
                const wsNum = e.key - Qt.Key_0;
                if (e.modifiers & Qt.ShiftModifier) {
                    // Move current selected window to this workspace
                    if (root.filteredWindows.length > 0 && root.selectedWinIndex < root.filteredWindows.length) {
                        root.filteredWindows[root.selectedWinIndex].moveToWs(wsNum);
                    }
                } else {
                    // Switch to workspace
                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsNum} })`);
                    root.selectedWorkspaceId = wsNum;
                }
                e.accepted = true;
                return;
            }

            // Move selected window with Super+Shift+Left/Right
            if ((e.modifiers & Qt.ShiftModifier) && (e.modifiers & Qt.MetaModifier || e.modifiers & Qt.AltModifier)) {
                if (root.filteredWindows.length > 0 && root.selectedWinIndex < root.filteredWindows.length) {
                    const currentWin = root.filteredWindows[root.selectedWinIndex];
                    if (e.key === Qt.Key_Left) {
                        const targetWs = Math.max(1, currentWin.workspaceId - 1);
                        currentWin.moveToWs(targetWs);
                        e.accepted = true;
                        return;
                    } else if (e.key === Qt.Key_Right) {
                        const targetWs = currentWin.workspaceId + 1;
                        currentWin.moveToWs(targetWs);
                        e.accepted = true;
                        return;
                    }
                }
            }

            // Navigation within Section 1 (Workspaces)
            if (root.activeSection === 1) {
                if (e.key === Qt.Key_Left) {
                    root.selectedWsIndex = Math.max(0, root.selectedWsIndex - 1);
                    root.selectedWorkspaceId = root.selectedWsIndex === 0 ? 0 : root.workspaceList[root.selectedWsIndex - 1].id;
                    e.accepted = true;
                } else if (e.key === Qt.Key_Right) {
                    root.selectedWsIndex = Math.min(root.workspaceList.length, root.selectedWsIndex + 1);
                    root.selectedWorkspaceId = root.selectedWsIndex === 0 ? 0 : root.workspaceList[root.selectedWsIndex - 1].id;
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (root.selectedWorkspaceId > 0) {
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${root.selectedWorkspaceId} })`);
                        root.close();
                    }
                    e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    root.activeSection = 2; // Move to windows
                    e.accepted = true;
                }
                return;
            }

            // Navigation within Section 2 (Windows)
            if (root.activeSection === 2) {
                if (e.key === Qt.Key_Left) {
                    if (root.filteredWindows.length > 0) {
                        root.selectedWinIndex = Math.max(0, root.selectedWinIndex - 1);
                    }
                    e.accepted = true;
                } else if (e.key === Qt.Key_Right) {
                    if (root.filteredWindows.length > 0) {
                        root.selectedWinIndex = Math.min(root.filteredWindows.length - 1, root.selectedWinIndex + 1);
                    }
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    root.activeSection = 1; // Move up to workspaces
                    e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    root.activeSection = 3; // Move down to launcher
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (root.filteredWindows.length > 0 && root.selectedWinIndex < root.filteredWindows.length) {
                        root.filteredWindows[root.selectedWinIndex].focus();
                    }
                    e.accepted = true;
                } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Back) {
                    if (root.filteredWindows.length > 0 && root.selectedWinIndex < root.filteredWindows.length) {
                        root.filteredWindows[root.selectedWinIndex].closeWin();
                    }
                    e.accepted = true;
                }
                return;
            }

            // Navigation within Section 3 (Launcher)
            if (root.activeSection === 3) {
                if (e.key === Qt.Key_Left) {
                    root.selectedAppIndex = Math.max(0, root.selectedAppIndex - 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Right) {
                    root.selectedAppIndex = Math.min(root.installedApps.length - 1, root.selectedAppIndex + 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    root.activeSection = 2; // Move up to windows
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (root.installedApps.length > 0 && root.selectedAppIndex < root.installedApps.length) {
                        root.installedApps[root.selectedAppIndex].execute();
                    }
                    e.accepted = true;
                }
                return;
            }
        }

        // --- TOP HEADER & SEARCH ---
        Column {
            id: headerArea
            anchors {
                top: parent.top
                topMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 12
            z: 200

            // Title & Dot Indicator
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.red
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOTHING OS OVERVIEW"
                    font { family: Theme.mono; pixelSize: 13; weight: Font.Bold; letterSpacing: 2 }
                    color: Theme.fg
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: winBadgeText.width + 14
                    height: 20
                    radius: 10
                    color: Theme.s2
                    border { width: 1; color: Theme.s3 }

                    Text {
                        id: winBadgeText
                        anchors.centerIn: parent
                        text: `${root.allWindows.length} RUNNING`
                        font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                        color: Theme.grey
                    }
                }
            }

            // Search Bar (Section 0)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 460
                height: 42
                radius: 21
                color: root.activeSection === 0 || searchInput.activeFocus ? "#1a1a1a" : "#121212"
                border {
                    width: root.activeSection === 0 || searchInput.activeFocus ? 2 : 1
                    color: root.activeSection === 0 || searchInput.activeFocus ? "#ffffff" : "#262626"
                }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0349}"
                        font.pixelSize: 16
                        color: searchInput.activeFocus ? Theme.fg : Theme.grey
                    }

                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 55
                        color: Theme.fg
                        font { family: Theme.ui; pixelSize: 13 }
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "Type to search windows & applications..."
                            color: Theme.grey
                            font { family: Theme.ui; pixelSize: 13 }
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.selectedWinIndex = 0;
                            root.selectedAppIndex = 0;
                        }
                    }

                    // Clear button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!searchInput.text
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.s2

                        Text {
                            anchors.centerIn: parent
                            text: "\u{00D7}"
                            font.pixelSize: 13
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

            // --- WORKSPACE NAVIGATOR (Section 1) ---
            Row {
                id: workspaceBar
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // ALL Workspaces Pill
                Rectangle {
                    width: allWsLabel.width + 22
                    height: 30
                    radius: 15
                    color: root.selectedWorkspaceId === 0 ? "#ffffff" : (root.activeSection === 1 && root.selectedWsIndex === 0 ? "#242424" : "#141414")
                    border {
                        width: root.activeSection === 1 && root.selectedWsIndex === 0 ? 2 : 1
                        color: root.selectedWorkspaceId === 0 ? "#ffffff" : (root.activeSection === 1 && root.selectedWsIndex === 0 ? "#ffffff" : "#2a2a2a")
                    }

                    Text {
                        id: allWsLabel
                        anchors.centerIn: parent
                        text: `ALL (${root.allWindows.length})`
                        font { family: Theme.mono; pixelSize: 11; weight: Font.Bold }
                        color: root.selectedWorkspaceId === 0 ? "#000000" : Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedWorkspaceId = 0;
                            root.selectedWsIndex = 0;
                            root.activeSection = 1;
                        }
                    }
                }

                // Workspace Cards Repeater
                Repeater {
                    model: root.workspaceList

                    delegate: Rectangle {
                        id: wsCard
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.selectedWorkspaceId === modelData.id
                        readonly property bool isFocusedByKeyboard: root.activeSection === 1 && root.selectedWsIndex === (index + 1)
                        readonly property bool isActiveInHyprland: modelData.active

                        width: wsContent.width + 24
                        height: 30
                        radius: 15
                        color: isSelected ? "#ffffff" : (isFocusedByKeyboard ? "#222222" : "#121212")
                        border {
                            width: isSelected || isFocusedByKeyboard ? 2 : 1
                            color: isSelected || isFocusedByKeyboard ? "#ffffff" : (modelData.occupied ? "#333333" : "#202020")
                        }

                        Row {
                            id: wsContent
                            anchors.centerIn: parent
                            spacing: 6

                            // Red dot for active Hyprland workspace
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.red
                                visible: isActiveInHyprland
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font { family: Theme.mono; pixelSize: 11; weight: Font.Bold }
                                color: isSelected ? "#000000" : Theme.fg
                            }

                            // Window count badge
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: wsCountText.width + 8
                                height: 16
                                radius: 8
                                color: isSelected ? "#e0e0e0" : (modelData.occupied ? "#222222" : "#1a1a1a")

                                Text {
                                    id: wsCountText
                                    anchors.centerIn: parent
                                    text: modelData.occupied ? `${modelData.winCount}` : "·"
                                    font { family: Theme.mono; pixelSize: 9; weight: Font.Bold }
                                    color: isSelected ? "#000000" : (modelData.occupied ? Theme.grey : Theme.mute)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedWorkspaceId = modelData.id;
                                root.selectedWsIndex = index + 1;
                                root.activeSection = 1;
                                // Click switches Hyprland workspace directly
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData.id} })`);
                            }
                        }
                    }
                }
            }
        }

        // --- SECTION 2: WINDOW PREVIEWS STAGE ---
        Item {
            id: windowStageArea
            anchors {
                top: headerArea.bottom
                topMargin: 20
                bottom: launcherArea.top
                bottomMargin: 16
                left: parent.left
                leftMargin: 40
                right: parent.right
                rightMargin: 40
            }

            // Empty Workspace Indicator
            Rectangle {
                anchors.centerIn: parent
                visible: root.filteredWindows.length === 0
                width: 440
                height: 200
                radius: 20
                color: "#121212"
                border { width: 1; color: "#2a2a2a" }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u{F05CE}"
                        font.pixelSize: 42
                        color: Theme.mute
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.selectedWorkspaceId > 0 ? `WORKSPACE ${root.selectedWorkspaceId} IS EMPTY` : "NO RUNNING APPLICATIONS"
                        font { family: Theme.mono; pixelSize: 13; weight: Font.Bold; letterSpacing: 1 }
                        color: Theme.grey
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: switchWsBtnText.width + 24
                        height: 32
                        radius: 16
                        color: Theme.s2
                        border { width: 1; color: Theme.s3 }

                        Text {
                            id: switchWsBtnText
                            anchors.centerIn: parent
                            text: root.selectedWorkspaceId > 0 ? `SWITCH TO WORKSPACE ${root.selectedWorkspaceId}` : "LAUNCH APPLICATION BELOW"
                            font { family: Theme.mono; pixelSize: 11; weight: Font.Bold }
                            color: Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedWorkspaceId > 0) {
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${root.selectedWorkspaceId} })`);
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }

            // Flickable Flow Grid of Window Previews
            Flickable {
                anchors.fill: parent
                contentWidth: windowFlow.width
                contentHeight: windowFlow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.filteredWindows.length > 0

                Flow {
                    id: windowFlow
                    anchors.centerIn: parent
                    spacing: 24
                    flow: Flow.LeftToRight
                    width: {
                        if (root.winCount === 1) return root.cardW;
                        if (root.winCount === 2) return root.cardW * 2 + 24;
                        if (root.winCount <= 4) return root.cardW * 2 + 24;
                        return Math.min(parent.width, root.cardW * 3 + 48);
                    }

                    Repeater {
                        model: root.filteredWindows

                        delegate: Rectangle {
                            id: windowCard
                            required property var modelData
                            required property int index

                            readonly property bool isSelectedByKeyboard: root.activeSection === 2 && root.selectedWinIndex === index

                            width: root.cardW
                            height: root.cardH
                            radius: 16
                            color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#181818" : "#101010"
                            border {
                                width: isSelectedByKeyboard || cardMouseArea.containsMouse ? 2 : 1
                                color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#ffffff" : "#242424"
                            }
                            scale: isSelectedByKeyboard || cardMouseArea.containsMouse ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.focus()
                            }

                            // 1. Card Top Header: Dots, Title, App, Status, Close
                            Rectangle {
                                id: cardTopHeader
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: 34
                                radius: 16
                                color: "#161616"

                                // Flat bottom corner
                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                    height: 10
                                    color: "#161616"
                                }

                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 8

                                    // Window deco dots
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 5
                                        Rectangle { width: 7; height: 7; radius: 3.5; color: "#ff5f56" }
                                        Rectangle { width: 7; height: 7; radius: 3.5; color: "#ffbd2e" }
                                        Rectangle { width: 7; height: 7; radius: 3.5; color: "#27c93f" }
                                    }

                                    // App title
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: windowCard.width - 150
                                        text: modelData.title
                                        font { family: Theme.ui; pixelSize: 11; weight: Font.Medium }
                                        color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#ffffff" : Theme.fg
                                        elide: Text.ElideRight
                                    }
                                }

                                // Header Right: Status badge & Close button
                                Row {
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    spacing: 6

                                    // Status Pill
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: statusText.width + 10
                                        height: 18
                                        radius: 9
                                        color: "#222222"
                                        border { width: 1; color: "#333333" }

                                        Text {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: modelData.status.toUpperCase()
                                            font { family: Theme.mono; pixelSize: 8; weight: Font.Bold }
                                            color: Theme.grey
                                        }
                                    }

                                    // Close Button
                                    Rectangle {
                                        id: closeButton
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: closeMouse.containsMouse ? Theme.red : "#222222"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{00D7}"
                                            font { pixelSize: 13; weight: Font.Bold }
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
                                }
                            }

                            // 2. Real Window Preview Canvas
                            Rectangle {
                                id: previewCanvas
                                anchors {
                                    top: cardTopHeader.bottom
                                    left: parent.left
                                    right: parent.right
                                    bottom: resourceFooter.top
                                }
                                color: "#0c0c0c"
                                clip: true

                                // Thumbnail Image
                                Image {
                                    anchors.fill: parent
                                    source: modelData.preview ? `file://${modelData.preview}` : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    visible: status === Image.Ready && !!modelData.preview
                                }

                                // Fallback Dot Matrix Watermark if window is not on current screen
                                Column {
                                    anchors.centerIn: parent
                                    visible: !modelData.preview
                                    spacing: 8

                                    Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyphChar
                                        font.pixelSize: 48
                                        color: "#ffffff"
                                        opacity: isSelectedByKeyboard || cardMouseArea.containsMouse ? 0.25 : 0.12
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: `WS ${modelData.workspaceName}`
                                        font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                                        color: Theme.mute
                                    }
                                }
                            }

                            // 3. Bottom Resource & Identity Bar
                            Rectangle {
                                id: resourceFooter
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 38
                                radius: 16
                                color: "#141414"

                                // Flat top corner
                                Rectangle {
                                    anchors { top: parent.top; left: parent.left; right: parent.right }
                                    height: 10
                                    color: "#141414"
                                }

                                Row {
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 8

                                    // App Icon / Logo
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: "#202020"
                                        border { width: 1; color: "#333333" }

                                        Image {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: modelData.iconPath
                                            visible: status === Image.Ready
                                        }

                                        Icon {
                                            anchors.centerIn: parent
                                            text: modelData.glyphChar
                                            font.pixelSize: 12
                                            color: Theme.fg
                                            visible: !modelData.iconPath
                                        }
                                    }

                                    // App Name
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.appClass.toUpperCase()
                                        font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                                        color: Theme.fg
                                    }
                                }

                                // Resource Metrics: CPU & Memory Usage
                                Row {
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 8

                                    // CPU Metric
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: Theme.red
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: `CPU ${modelData.cpu}`
                                            font { family: Theme.mono; pixelSize: 9; weight: Font.Bold }
                                            color: Theme.grey
                                        }
                                    }

                                    // RAM Metric
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: "#ffffff"
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: `RAM ${modelData.mem}`
                                            font { family: Theme.mono; pixelSize: 9; weight: Font.Bold }
                                            color: Theme.grey
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- SECTION 3: COMPACT APPLICATION LAUNCHER ---
        Rectangle {
            id: launcherArea
            anchors {
                bottom: cheatsheetBar.top
                bottomMargin: 10
                left: parent.left
                leftMargin: 40
                right: parent.right
                rightMargin: 40
            }
            height: 74
            radius: 18
            color: root.activeSection === 3 ? "#181818" : "#121212"
            border {
                width: root.activeSection === 3 ? 2 : 1
                color: root.activeSection === 3 ? "#ffffff" : "#262626"
            }

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                // Launcher Label
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    spacing: 2

                    Text {
                        text: "LAUNCH"
                        font { family: Theme.mono; pixelSize: 10; weight: Font.Bold; letterSpacing: 1 }
                        color: Theme.fg
                    }
                    Text {
                        text: `${root.installedApps.length} APPS`
                        font { family: Theme.mono; pixelSize: 9 }
                        color: Theme.grey
                    }
                }

                // Vertical divider
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 36
                    color: Theme.s3
                }

                // Horizontal Carousel of Applications
                Flickable {
                    id: appFlickable
                    width: parent.width - 95
                    height: parent.height
                    contentWidth: appRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: appRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Repeater {
                            model: root.installedApps.slice(0, 30) // Show up to 30 matching apps

                            delegate: Rectangle {
                                id: appItem
                                required property var modelData
                                required property int index

                                readonly property bool isSelectedByKeyboard: root.activeSection === 3 && root.selectedAppIndex === index

                                width: 140
                                height: 48
                                radius: 12
                                color: isSelectedByKeyboard || appMouse.containsMouse ? "#222222" : "#161616"
                                border {
                                    width: isSelectedByKeyboard ? 2 : 1
                                    color: isSelectedByKeyboard ? "#ffffff" : (appMouse.containsMouse ? "#444444" : "#262626")
                                }

                                Row {
                                    anchors { fill: parent; margins: 6 }
                                    spacing: 8

                                    // App Icon
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 32
                                        height: 32

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 16
                                            color: "#1e1e1e"
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            width: 22
                                            height: 22
                                            source: modelData.iconPath
                                            visible: status === Image.Ready
                                        }

                                        Icon {
                                            anchors.centerIn: parent
                                            text: modelData.glyphChar
                                            font.pixelSize: 16
                                            color: Theme.fg
                                            visible: !modelData.iconPath
                                        }

                                        // Red Running Indicator Dot
                                        Rectangle {
                                            anchors { bottom: parent.bottom; right: parent.right }
                                            width: 7
                                            height: 7
                                            radius: 3.5
                                            color: Theme.red
                                            visible: modelData.isRunning
                                        }
                                    }

                                    // App Name
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 42
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            font { family: Theme.ui; pixelSize: 11; weight: Font.Medium }
                                            color: Theme.fg
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.isRunning ? "RUNNING" : "INSTALLED"
                                            font { family: Theme.mono; pixelSize: 8; weight: Font.Bold }
                                            color: modelData.isRunning ? Theme.red : Theme.grey
                                        }
                                    }
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.execute()
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- SECTION 4: BOTTOM CHEATSHEET BAR ---
        Row {
            id: cheatsheetBar
            anchors {
                bottom: parent.bottom
                bottomMargin: 14
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 16

            Text {
                text: "[TAB] SWITCH SECTION"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: root.activeSection === 0 ? "#ffffff" : Theme.grey
            }
            Text {
                text: "[ARROWS] NAVIGATE"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: Theme.grey
            }
            Text {
                text: "[ENTER] FOCUS / LAUNCH"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: Theme.grey
            }
            Text {
                text: "[1-9] SWITCH WS"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: Theme.grey
            }
            Text {
                text: "[SUPER+SHIFT+←/→] MOVE WINDOW"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: Theme.grey
            }
            Text {
                text: "[ESC] CLOSE"
                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                color: Theme.grey
            }
        }
    }
}
