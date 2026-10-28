import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Nothing OS Zoomed-Out Overview
// Replicates the reference UI: Centered header, search, workspace filter pills,
// dynamic window preview grid, real-time CPU/RAM metrics, and minimal keyboard cheatsheet.
PanelWindow {
    id: root

    property bool open: false
    property string searchQuery: ""
    // Default to ALL (0) on every overview launch
    property int selectedWorkspaceId: 0
    property int selectedWsIndex: 0
    property int activeSection: 2 // 0: Search, 1: Workspaces, 2: Windows
    property int selectedWinIndex: 0
    property var windowStats: ({})

    function toggle() {
        if (open) close();
        else openOverview();
    }

    function openOverview() {
        searchQuery = "";
        // Default to ALL (0) showing windows across every workspace
        selectedWorkspaceId = 0;
        selectedWsIndex = 0;
        selectedWinIndex = 0;
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

    // Stats collector process
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

    // Periodic stats collection when overview is open
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

    function resolveIcon(icon) {
        if (!icon) return "";
        if (icon.startsWith("/") || icon.startsWith("file://")) return icon;
        return Quickshell.iconPath(icon, true) || "";
    }

    readonly property var glyphMap: [
        ["zen", "\u{F0239}"], ["firefox", "\u{F0239}"], ["chrom", "\u{F059F}"], ["edge", "\u{F0239}"],
        ["kitty", "\u{F018D}"], ["terminal", "\u{F018D}"], ["foot", "\u{F018D}"],
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
    readonly property int currentWsId: Hyprland.focusedWorkspace?.id ?? (Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1)

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

    // Extract running toplevel windows from Hyprland
    readonly property var allWindows: !open ? [] : Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject || {};
        const cls = ipc.class ?? "";
        const initCls = ipc.initialClass ?? "";
        const wsId = t.workspace?.id ?? (ipc.workspace?.id ?? 1);
        const wsName = t.workspace?.name ?? (ipc.workspace?.name ?? String(wsId));
        const iconName = DesktopEntries.heuristicLookup(cls)?.icon 
                      || DesktopEntries.heuristicLookup(initCls)?.icon 
                      || cls.toLowerCase();

        const st = root.windowStats[t.address] || {};
        const cpuStr = st.cpu || "0.0%";
        const memStr = st.mem || "N/A";
        const statusStr = st.status || (ipc.floating ? "Floating" : "Tiled");
        const previewPath = st.preview || "";

        // Nicely formatted display name
        let displayName = cls;
        if (cls.toLowerCase() === "microsoft-edge") displayName = "Microsoft Edge";
        else if (cls.toLowerCase() === "code" || cls.toLowerCase() === "codium") displayName = "Visual Studio Code";
        else if (cls.toLowerCase() === "kitty") displayName = "Terminal";
        else if (cls) displayName = cls.charAt(0).toUpperCase() + cls.slice(1);
        else displayName = "Application";

        return {
            title: t.title || cls || "Window",
            appName: displayName,
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
            toggleFullscreen: () => {
                Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", window = "address:${t.address}" })`);
            },
            minimizeWin: () => {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", window = "address:${t.address}" })`);
            },
            moveToWs: (targetWs) => {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, window = "address:${t.address}" })`);
                root.refreshStats();
            }
        };
    })

    // Filtered windows based on selected workspace and search query
    readonly property var filteredWindows: {
        const q = searchQuery.trim().toLowerCase();
        return allWindows.filter(w => {
            // Workspace filter: 0 means ALL workspaces
            if (selectedWorkspaceId > 0 && w.workspaceId !== selectedWorkspaceId) {
                return false;
            }
            // Search query filter
            if (q) {
                const haystack = (w.title + " " + w.appName + " " + w.appClass + " " + w.workspaceName).toLowerCase();
                return haystack.includes(q);
            }
            return true;
        });
    }

    // Dynamic Sizing based on window count and screen geometry
    readonly property int winCount: filteredWindows.length
    readonly property real availableStageW: root.width - 80
    readonly property real availableStageH: root.height - 240

    readonly property real cardW: {
        if (winCount <= 1) return Math.min(760, availableStageW);
        if (winCount === 2) return Math.min(540, (availableStageW - 28) / 2);
        if (winCount === 3) return Math.min(440, (availableStageW - 56) / 3);
        if (winCount === 4) return Math.min(460, (availableStageW - 28) / 2);
        if (winCount <= 6) return Math.min(380, (availableStageW - 56) / 3);
        return Math.min(350, (availableStageW - 84) / 4);
    }

    readonly property real cardH: {
        if (winCount <= 1) return Math.min(480, availableStageH);
        if (winCount === 2) return Math.min(380, availableStageH);
        if (winCount === 3) return Math.min(320, availableStageH);
        if (winCount === 4) return Math.min(290, (availableStageH - 24) / 2);
        if (winCount <= 6) return Math.min(250, (availableStageH - 24) / 2);
        return 220;
    }

    // Dimmed background with click-outside to exit
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.90 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Main Interactive Overlay
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

            // Tab / Shift+Tab cycles activeSection (Search -> Workspaces -> Windows)
            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                if (e.modifiers & Qt.ShiftModifier || e.key === Qt.Key_Backtab) {
                    root.activeSection = (root.activeSection + 2) % 3;
                } else {
                    root.activeSection = (root.activeSection + 1) % 3;
                }
                if (root.activeSection === 0) searchInput.forceActiveFocus();
                e.accepted = true;
                return;
            }

            // 0 Key: Switch to ALL workspaces view
            if (e.key === Qt.Key_0) {
                root.selectedWorkspaceId = 0;
                root.selectedWsIndex = 0;
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
                    root.selectedWorkspaceId = wsNum;
                    root.selectedWsIndex = wsNum;
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
        }

        // --- 1. TOP HEADER ---
        Column {
            id: topHeaderArea
            anchors {
                top: parent.top
                topMargin: 32
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 14
            z: 100

            // Title Pill: [● NOTHING OS OVERVIEW  (3 WINDOWS)]
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: titleRow.width + 24
                height: 32
                radius: 16
                color: "#131313"
                border { width: 1; color: "#222222" }

                Row {
                    id: titleRow
                    anchors.centerIn: parent
                    spacing: 10

                    // Red Dot Indicator
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.red
                    }

                    // Monospace uppercase title
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "NOTHING OS OVERVIEW"
                        font { family: Theme.mono; pixelSize: 12; weight: Font.Bold; letterSpacing: 2 }
                        color: Theme.fg
                    }

                    // Windows count sub-pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: countPillText.width + 14
                        height: 20
                        radius: 10
                        color: "#1c1c1c"
                        border { width: 1; color: "#282828" }

                        Text {
                            id: countPillText
                            anchors.centerIn: parent
                            text: `${root.allWindows.length} WINDOWS`
                            font { family: Theme.mono; pixelSize: 9; weight: Font.Bold }
                            color: Theme.grey
                        }
                    }
                }
            }

            // --- 2. SEARCH BAR ---
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 480
                height: 44
                radius: 22
                color: root.activeSection === 0 || searchInput.activeFocus ? "#181818" : "#121212"
                border {
                    width: root.activeSection === 0 || searchInput.activeFocus ? 2 : 1
                    color: root.activeSection === 0 || searchInput.activeFocus ? "#ffffff" : "#242424"
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
                            text: "Search windows..."
                            color: Theme.grey
                            font { family: Theme.ui; pixelSize: 13 }
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.selectedWinIndex = 0;
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

            // --- 3. WORKSPACE FILTER PILLS ---
            Row {
                id: workspaceBar
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // ALL (N) Pill (Selected by Default)
                Rectangle {
                    width: allWsLabel.width + 24
                    height: 32
                    radius: 16
                    color: root.selectedWorkspaceId === 0 ? "#ffffff" : (root.activeSection === 1 && root.selectedWsIndex === 0 ? "#222222" : "#141414")
                    border {
                        width: root.selectedWorkspaceId === 0 || (root.activeSection === 1 && root.selectedWsIndex === 0) ? 2 : 1
                        color: root.selectedWorkspaceId === 0 ? "#ffffff" : (root.activeSection === 1 && root.selectedWsIndex === 0 ? "#ffffff" : "#242424")
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

                // Workspace Pills: WS 1, WS 2 ●, WS 3, WS 4, WS 5
                Repeater {
                    model: root.workspaceList

                    delegate: Rectangle {
                        id: wsCard
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.selectedWorkspaceId === modelData.id
                        readonly property bool isFocusedByKeyboard: root.activeSection === 1 && root.selectedWsIndex === (index + 1)
                        readonly property bool isActiveInHyprland: modelData.active

                        width: wsPillContent.width + 24
                        height: 32
                        radius: 16
                        color: isSelected ? "#ffffff" : (isFocusedByKeyboard ? "#222222" : "#141414")
                        border {
                            width: isSelected || isFocusedByKeyboard ? 2 : 1
                            color: isSelected || isFocusedByKeyboard ? "#ffffff" : "#242424"
                        }

                        Row {
                            id: wsPillContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font { family: Theme.mono; pixelSize: 11; weight: Font.Bold }
                                color: isSelected ? "#000000" : Theme.fg
                            }

                            // Red dot indicator next to active Hyprland workspace (e.g. WS 2 ●)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.red
                                visible: isActiveInHyprland
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedWorkspaceId = modelData.id;
                                root.selectedWsIndex = index + 1;
                                root.activeSection = 1;
                            }
                            onDoubleClicked: {
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData.id} })`);
                                root.close();
                            }
                        }
                    }
                }
            }
        }

        // --- 4. SMART WINDOW PREVIEW GRID ---
        Item {
            id: windowStageArea
            anchors {
                top: topHeaderArea.bottom
                topMargin: 28
                bottom: cheatsheetBar.top
                bottomMargin: 24
                left: parent.left
                leftMargin: 40
                right: parent.right
                rightMargin: 40
            }

            // Empty state if no windows in this workspace/search
            Rectangle {
                anchors.centerIn: parent
                visible: root.filteredWindows.length === 0
                width: 440
                height: 180
                radius: 18
                color: "#121212"
                border { width: 1; color: "#242424" }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u{F05CE}"
                        font.pixelSize: 36
                        color: Theme.mute
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.selectedWorkspaceId > 0 ? `NO WINDOWS ON WORKSPACE ${root.selectedWorkspaceId}` : "NO MATCHING WINDOWS"
                        font { family: Theme.mono; pixelSize: 12; weight: Font.Bold; letterSpacing: 1 }
                        color: Theme.grey
                    }
                }
            }

            // Flow Grid of Window Preview Cards
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
                        if (root.winCount === 3) return root.cardW * 3 + 48;
                        if (root.winCount === 4) return root.cardW * 2 + 24;
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
                            radius: 20
                            color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#181818" : "#111111"
                            border {
                                width: isSelectedByKeyboard || cardMouseArea.containsMouse ? 2 : 1
                                color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#ffffff" : "#202020"
                            }
                            scale: isSelectedByKeyboard || cardMouseArea.containsMouse ? 1.02 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.focus()
                            }

                            // Inner Layout: Header + Preview Canvas
                            Column {
                                anchors {
                                    fill: parent
                                    margins: 12
                                }
                                spacing: 10

                                // --- Card Header: Icon, App Name, Subtitle, Workspace Badge, Minimize, Maximize, Close ---
                                Row {
                                    width: parent.width
                                    height: 40

                                    // Left: App Icon & Title/Subtitle
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - headerControls.width - 8
                                        spacing: 10

                                        // App Logo
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 34
                                            height: 34
                                            radius: 17
                                            color: "#181818"
                                            border { width: 1; color: "#282828" }

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
                                                font.pixelSize: 18
                                                color: Theme.fg
                                                visible: !modelData.iconPath
                                            }
                                        }

                                        // App Name & Window Title Column
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 44
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: modelData.appName
                                                font { family: Theme.ui; pixelSize: 13; weight: Font.Bold }
                                                color: isSelectedByKeyboard || cardMouseArea.containsMouse ? "#ffffff" : Theme.fg
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.title
                                                font { family: Theme.ui; pixelSize: 11 }
                                                color: Theme.grey
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    // Right: WS Badge & Window Controls
                                    Row {
                                        id: headerControls
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        spacing: 8

                                        // Workspace Pill (e.g. WS 2)
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: wsBadgeText.width + 14
                                            height: 24
                                            radius: 12
                                            color: "#1a1a1a"
                                            border { width: 1; color: "#2a2a2a" }

                                            Text {
                                                id: wsBadgeText
                                                anchors.centerIn: parent
                                                text: `WS ${modelData.workspaceName}`
                                                font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                                                color: Theme.fg
                                            }
                                        }

                                        // Minimize Button: —
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: minHover.containsMouse ? "#2a2a2a" : "#1a1a1a"
                                            border { width: 1; color: "#2a2a2a" }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u{2014}"
                                                font { pixelSize: 11; weight: Font.Bold }
                                                color: Theme.grey
                                            }

                                            MouseArea {
                                                id: minHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.minimizeWin()
                                            }
                                        }

                                        // Maximize Button: □
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: maxHover.containsMouse ? "#2a2a2a" : "#1a1a1a"
                                            border { width: 1; color: "#2a2a2a" }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u{25A2}"
                                                font { pixelSize: 13; weight: Font.Bold }
                                                color: Theme.grey
                                            }

                                            MouseArea {
                                                id: maxHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.toggleFullscreen()
                                            }
                                        }

                                        // Close Button: ✕ (Red accent circle)
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: closeHover.containsMouse ? "#ff333a" : Theme.red

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u{2715}"
                                                font { pixelSize: 11; weight: Font.Bold }
                                                color: "#ffffff"
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

                                // --- Actual Window Content Preview Canvas ---
                                Rectangle {
                                    width: parent.width
                                    height: parent.height - 50
                                    radius: 12
                                    color: "#080808"
                                    border { width: 1; color: "#1c1c1c" }
                                    clip: true

                                    // Live Window Thumbnail Image
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.preview ? `file://${modelData.preview}` : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                        visible: status === Image.Ready && !!modelData.preview
                                    }

                                    // Fallback UI if thumbnail is not ready or window is on another workspace
                                    Item {
                                        anchors.fill: parent
                                        visible: !modelData.preview

                                        // Central subtle logo watermark
                                        Icon {
                                            anchors.centerIn: parent
                                            text: modelData.glyphChar
                                            font.pixelSize: 64
                                            color: "#ffffff"
                                            opacity: isSelectedByKeyboard || cardMouseArea.containsMouse ? 0.20 : 0.10
                                        }

                                        Text {
                                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
                                            text: `Workspace ${modelData.workspaceName}`
                                            font { family: Theme.mono; pixelSize: 10; weight: Font.Bold }
                                            color: Theme.mute
                                        }
                                    }

                                    // Compact Overlay: Real-time CPU & RAM Usage (top right corner inside preview)
                                    Rectangle {
                                        anchors { top: parent.top; right: parent.right; margins: 8 }
                                        width: metricsRow.width + 12
                                        height: 20
                                        radius: 10
                                        color: Qt.rgba(0, 0, 0, 0.72)
                                        border { width: 1; color: "#2a2a2a" }

                                        Row {
                                            id: metricsRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            // CPU
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                Rectangle { width: 4; height: 4; radius: 2; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                                                Text {
                                                    text: modelData.cpu
                                                    font { family: Theme.mono; pixelSize: 8; weight: Font.Bold }
                                                    color: Theme.grey
                                                }
                                            }

                                            // Separator
                                            Text {
                                                text: "·"
                                                font { family: Theme.mono; pixelSize: 8 }
                                                color: Theme.mute
                                            }

                                            // RAM
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                Rectangle { width: 4; height: 4; radius: 2; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                                                Text {
                                                    text: modelData.mem
                                                    font { family: Theme.mono; pixelSize: 8; weight: Font.Bold }
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
            }
        }

        // --- 5. BOTTOM MINIMAL KEYBOARD CHEATSHEET ---
        Row {
            id: cheatsheetBar
            anchors {
                bottom: parent.bottom
                bottomMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 12

            component KeyCap: Rectangle {
                property alias text: label.text
                width: label.implicitWidth + 14
                height: 20
                radius: 5
                color: "#161616"
                border.width: 1
                border.color: "#303030"

                Text {
                    id: label
                    anchors.centerIn: parent
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }

            component CheatsheetLabel: Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.grey
            }

            component CheatsheetDivider: Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.mono
                font.pixelSize: 10
                color: "#333333"
                text: "|"
            }

            // [TAB] SWITCH SECTION
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                KeyCap { text: "TAB" }
                CheatsheetLabel { text: "SWITCH SECTION" }
            }

            CheatsheetDivider {}

            // [↑] [↓] [←] [→] NAVIGATE
            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                KeyCap { text: "↑"; width: 20 }
                KeyCap { text: "↓"; width: 20 }
                KeyCap { text: "←"; width: 20 }
                KeyCap { text: "→"; width: 20 }
                Item { width: 2; height: 1 }
                CheatsheetLabel { text: "NAVIGATE" }
            }

            CheatsheetDivider {}

            // [ENTER] FOCUS WINDOW
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                KeyCap { text: "ENTER" }
                CheatsheetLabel { text: "FOCUS WINDOW" }
            }

            CheatsheetDivider {}

            // [SUPER + SHIFT + ARROWS] MOVE TO WORKSPACE
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                KeyCap { text: "SUPER + SHIFT + ARROWS" }
                CheatsheetLabel { text: "MOVE TO WORKSPACE" }
            }

            CheatsheetDivider {}

            // [ESC] CLOSE OVERVIEW
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                KeyCap { text: "ESC" }
                CheatsheetLabel { text: "CLOSE OVERVIEW" }
            }
        }
    }
}
