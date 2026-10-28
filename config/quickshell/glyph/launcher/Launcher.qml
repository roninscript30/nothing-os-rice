import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// лаунчер: тап Super или Super+Space. Панель 860 по центру, экран гаснет до 74%. Поиск-пилюля с красной кареткой,
// режимы чипами (Tab): apps / run / windows / calc. Без запроса — «recent» и все приложения сеткой по 6, справа алфавит.
// Иконки — монохромные глифы в кругах, неизвестные — сама иконка точками; выбранная — белый круг
PanelWindow {
    id: root

    property int mode: 0
    property int sel: 0
    readonly property var modes: ["apps", "run", "windows", "calc"]
    readonly property string query: input.text
    property var uses: ({}) // id приложения → сколько раз открыли

    // глифы для известных приложений; ключ — кусок id/имени в нижнем регистре
    readonly property var glyphs: [
        ["zen", "\u{F0239}"], ["firefox", "\u{F0239}"], ["chrom", "\u{F059F}"], ["kitty", "\u{F018D}"], ["foot", "\u{F018D}"],
        ["spotify", "\u{F04C7}"], ["telegram", "\u{F2C6}"], ["codium", "\u{F0A1E}"], ["code", "\u{F0A1E}"], ["steam", "\u{F04D3}"],
        ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"], ["equibop", "\u{F066F}"], ["calculator", "\u{F00EC}"], ["calendar", "\u{F00ED}"],
        ["camera", "\u{F0100}"], ["thunar", "\u{F024B}"], ["nautilus", "\u{F024B}"], ["files", "\u{F024B}"], ["gimp", "\u{F02E9}"],
        ["mail", "\u{F01EE}"], ["btop", "\u{F035B}"], ["monitor", "\u{F035B}"], ["obsidian", "\u{F082E}"], ["settings", "\u{F0493}"],
        ["pavucontrol", "\u{F057E}"], ["mpv", "\u{F040A}"], ["vlc", "\u{F040A}"], ["clash", "\u{F0483}"], ["torrent", "\u{F01DA}"]
    ]
    function glyph(key) { return glyphs.find(g => key.toLowerCase().includes(g[0]))?.[1] ?? ""; }

    // на старте DesktopEntries добавляет записи по одной (~160 valuesChanged): биндинг пересобирал бы сетку на каждую —
    // секунды фриза. Собираем раз, когда список затих
    property var apps: []
    function resolveIcon(icon) {
        if (!icon) return "";
        if (icon.startsWith("/") || icon.startsWith("file://")) return icon;
        return Quickshell.iconPath(icon, true) || "";
    }
    Timer {
        id: appsT
        interval: 300
        running: true
        onTriggered: root.apps = DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            id: e.id, name: e.name, src: root.resolveIcon(e.icon), glyph: root.glyph(`${e.id} ${e.name}`),
            extra: `${e.id} ${e.genericName} ${(e.keywords ?? []).join(" ")}`.toLowerCase(),
            run: () => {
                try {
                    const isSettings = e.id && (e.id.toLowerCase().includes("settings") || e.name === "Settings" || (typeof e.execString === "string" && e.execString.includes("gnome-control-center")));
                    let cmdStr = typeof e.execString === "string" ? e.execString : (Array.isArray(e.command) ? e.command.filter(a => !a.startsWith("%")).join(" ") : "");
                    cmdStr = cmdStr.replace(/%[a-zA-Z]/g, "").trim();
                    if (isSettings) {
                        Quickshell.execDetached(["sh", "-c", `env XDG_CURRENT_DESKTOP='ubuntu:GNOME' ${cmdStr || "gnome-control-center"}`]);
                    } else if (typeof e.execute === "function") {
                        e.execute();
                    } else if (cmdStr) {
                        if (e.runInTerminal) cmdStr = `kitty -e ${cmdStr}`;
                        Quickshell.execDetached(["sh", "-c", cmdStr]);
                    }
                } catch (err) {
                    console.log("e.execute() error, falling back to execDetached:", err);
                    let cmdStr = typeof e.execString === "string" ? e.execString : (Array.isArray(e.command) ? e.command.filter(a => !a.startsWith("%")).join(" ") : "");
                    cmdStr = cmdStr.replace(/%[a-zA-Z]/g, "").trim();
                    if (cmdStr) {
                        if (e.runInTerminal) cmdStr = `kitty -e ${cmdStr}`;
                        Quickshell.execDetached(["sh", "-c", cmdStr]);
                    }
                }
            }
        })).sort((a, b) => a.name.localeCompare(b.name))
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsT.restart(); }
    }
    // окна — только пока открыт режим windows: иначе любая смена заголовка пересобирала бы список
    readonly property var wins: !visible || mode !== 2 ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        const icon = DesktopEntries.heuristicLookup(cls)?.icon;
        const ws = t.lastIpcObject?.workspace?.name ?? "";
        return {
            name: t.title || cls || "Window",
            app: cls || "App",
            ws: ws ? `WS ${ws}` : "",
            src: icon ? root.resolveIcon(icon) : "",
            glyph: glyph(cls),
            extra: (cls + " " + (t.title ?? "")).toLowerCase(),
            isWindow: true,
            address: t.address,
            toplevel: t.wayland || t,
            run: () => Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`),
            closeWin: () => Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${t.address}" })`)
        };
    })

    // подпоследовательность: начало слова и подряд — выше. hl — индексы совпавших букв
    function match(s, q) {
        if (!q) return { score: 1, hl: [] };
        const l = s.toLowerCase(), hl = [], at = l.indexOf(q);
        if (at >= 0) { for (let k = 0; k < q.length; k++) hl.push(at + k); return { score: (at === 0 ? 100 : 50) - at, hl }; }
        let i = 0;
        for (const c of q) {
            i = l.indexOf(c, i);
            if (i < 0) return null;
            hl.push(i++);
        }
        return { score: 10, hl };
    }
    function filter(src, q) {
        const out = [];
        for (const it of src) {
            const m = match(it.name, q);
            if (m) out.push(Object.assign({}, it, { hl: m.hl, score: m.score }));
            else if (it.extra.includes(q)) out.push(Object.assign({}, it, { hl: [], score: 1 }));
        }
        return out.sort((a, b) => b.score - a.score || (uses[b.id] ?? 0) - (uses[a.id] ?? 0) || a.name.localeCompare(b.name));
    }

    // блоки: { head, sub, items }; каждой ячейке — row/col, по ним ходят стрелки
    readonly property var blocks: {
        const q = query.trim().toLowerCase();
        let b;
        if (mode === 1) b = q ? [{ head: "run", items: [{ name: query, glyph: "\u{F018D}", hl: [], run: () => Quickshell.execDetached(["sh", "-c", query]) }] }] : [];
        else if (mode === 3) b = [];
        else if (mode === 2) b = [{ head: "windows", sub: String(wins.length), items: filter(wins, q) }];
        else if (q) {
            const r = filter(apps, q);
            b = [{ head: "results", sub: String(r.length), items: r }];
        } else {
            const sortedApps = apps.slice().sort((a, b) => (uses[b.id] ?? 0) - (uses[a.id] ?? 0) || a.name.localeCompare(b.name));
            b = [{ head: "apps", sub: String(apps.length), all: true, items: sortedApps }];
        }
        let row = 0, k = 0;
        const cols = mode === 2 ? 3 : 6;
        for (const x of b) {
            x.items = x.items.map((it, i) => Object.assign({}, it, { row: row + Math.floor(i / cols), col: i % cols, k: k++ }));
            row += Math.ceil(x.items.length / cols);
        }
        return b;
    }
    readonly property var flat: blocks.reduce((a, x) => a.concat(x.items), [])
    readonly property var cur: flat[sel] ?? null

    function open(m) {
        input.text = "";
        mode = m !== undefined ? m : 0;
        sel = 0;
        flick.contentY = 0;
        visible = true;
        input.forceActiveFocus();
    }
    function close() { visible = false; }
    function toggle(m) {
        if (visible) {
            if (m !== undefined && mode !== m) {
                mode = m;
                input.text = "";
                sel = 0;
            } else {
                close();
            }
        } else {
            open(m);
        }
    }
    function move(dr, dc) {
        if (!flat.length) return;
        if (dc) return sel = (sel + dc + flat.length) % flat.length;
        const c = cur, row = flat.filter(x => x.row === c.row + dr);
        if (row.length) sel = row.reduce((a, x) => Math.abs(x.col - c.col) < Math.abs(a.col - c.col) ? x : a).k;
    }
    function launch() {
        if (mode === 3) {
            if (calcOut) Quickshell.execDetached(["wl-copy", calcOut]);
            return close();
        }
        const it = cur;
        if (!it) return;
        close();
        if (it.id) {
            uses = Object.assign({}, uses, { [it.id]: (uses[it.id] ?? 0) + 1 });
            usesFile.setText(JSON.stringify(uses));
        }
        it.run();
    }

    FileView {
        id: usesFile
        path: Quickshell.statePath("launcher-uses.json")
        printErrors: false
        onLoaded: try { root.uses = JSON.parse(text()); } catch (e) {}
    }

    property string calcOut: ""
    Process { id: calc; stdout: StdioCollector { onStreamFinished: root.calcOut = text.trim() } }
    onQueryChanged: {
        sel = 0;
        if (mode === 3 && query.trim()) calc.exec(["qalc", "-t", query]); // exec гасит прошлый расчёт
        else calcOut = "";
    }
    onModeChanged: { sel = 0; flick.contentY = 0; if (mode === 3) queryChanged(); }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-launcher"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 140
            width: 860
            height: Math.min(stage.height - 280, 30 + 66 + body.height + 34)
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            // поиск: пилюля, красная каретка, чипы режимов
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: 33
                color: Theme.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 22 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: ["Search apps, files, commands", "Run a command", "Find a window", "2 + 2, 20 usd to eur…"][root.mode]
                        font: input.font
                        color: Theme.mute
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                        else if (e.key === Qt.Key_Down) root.move(1, 0);
                        else if (e.key === Qt.Key_Up) root.move(-1, 0);
                        else if (e.key === Qt.Key_Right && (!input.text || input.cursorPosition === input.text.length) && root.flat.length) root.move(0, 1);
                        else if (e.key === Qt.Key_Left && (!input.text || input.cursorPosition === 0) && root.flat.length) root.move(0, -1);
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.modes
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.mode === index ? Theme.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.mode === parent.index ? Theme.ink : Theme.grey }
                            TapHandler { onTapped: { root.mode = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: parent.bottom; leftMargin: 34; rightMargin: 34; bottomMargin: 34 }
                contentHeight: body.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function ensure(y, h) {
                    if (y < contentY) contentY = y;
                    else if (y + h > contentY + height) contentY = y + h - height;
                }

                Column {
                    id: body
                    width: flick.width

                    // calc: ответ крупно, Enter — скопировать
                    Column {
                        visible: root.mode === 3
                        topPadding: 30
                        spacing: 10
                        Lb { text: root.calcOut ? "↵ copy" : "qalc" }
                        Num { width: body.width; elide: Text.ElideRight; text: root.calcOut || "—"; font.pixelSize: 96 }
                    }

                    // по индексу, а не по массиву: новый blocks (буква в поиске, запуск, recent) не пересоздаёт ~160 ячеек
                    // с иконками и слоями — им только меняются данные
                    Repeater {
                        id: blockRep
                        model: root.blocks.length

                        Column {
                            id: block
                            required property int index
                            readonly property var modelData: root.blocks[index] ?? ({ head: "", items: [] })
                            readonly property Item g: grid
                            width: body.width
                            topPadding: 30

                            Row {
                                spacing: 14
                                bottomPadding: 18
                                Lb { id: blab; text: block.modelData.head + (block.modelData.sub ? ` · ${block.modelData.sub}` : "") }
                            }
                            Grid {
                                id: grid
                                columns: root.mode === 2 ? 3 : 6
                                rowSpacing: 22
                                Repeater {
                                    model: block.modelData.items.length
                                    Cell { items: block.modelData.items }
                                }
                            }
                        }
                    }
                }
            }

            // алфавит справа: скрыт, так как сортировка по частоте использования
            Column {
                visible: false
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 130 }
                spacing: 3
                Repeater {
                    model: [..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
                    Text {
                        required property string modelData
                        width: 12
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font { family: Theme.mono; pixelSize: 10 }
                        color: root.range.includes(modelData) ? Theme.fg : Theme.mute
                        TapHandler { onTapped: root.jump(parent.modelData) }
                    }
                }
            }
        }
    }

    // буквы всех приложений, чьи ряды сейчас видны
    readonly property var allItems: blocks.find(b => b.all)?.items ?? []
    readonly property Item allGrid: { const i = blocks.findIndex(b => b.all); return blockRep.count > i && i >= 0 ? blockRep.itemAt(i)?.g ?? null : null; }
    readonly property string range: ""
    function jump(l) {}

    // ячейка: если это окно (mode 2) — карточка приложения; иначе круг 88
    component Cell: Item {
        id: cell
        required property int index
        property var items: []
        readonly property var modelData: items[index] ?? ({ name: "", hl: [] })
        readonly property bool on: root.sel === modelData.k
        readonly property bool isWin: root.mode === 2 || !!modelData.isWindow
        width: isWin ? (body.width / 3) : (body.width / 6)
        height: isWin ? 230 : 124

        onOnChanged: if (on) flick.ensure(mapToItem(body, 0, 0).y, height)

        // Карточка окна (mobile-style window card with live screen mini)
        Rectangle {
            id: winCard
            visible: cell.isWin
            anchors.centerIn: parent
            width: parent.width - 14
            height: 220
            radius: 20
            color: cell.on ? Theme.s3 : Theme.s2
            border.width: cell.on ? 2 : 1
            border.color: cell.on ? Theme.fg : Theme.s3
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Верхняя строка: иконка, имя приложения, воркспейс, кнопка закрыть
                Row {
                    width: parent.width
                    height: 26
                    spacing: 8

                    Image {
                        id: winIcon
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        source: (root.visible && root.mode === 2 && cell.modelData.src) ? cell.modelData.src : ""
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                        visible: !!cell.modelData.src && status !== Image.Error
                    }
                    Icon {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !winIcon.visible && !!cell.modelData.glyph
                        text: cell.modelData.glyph ?? ""
                        font.pixelSize: 18
                        color: Theme.fg
                    }
                    Text {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !winIcon.visible && !cell.modelData.glyph
                        text: (cell.modelData.app || cell.modelData.name || "?").charAt(0).toUpperCase()
                        font { family: Theme.mono; pixelSize: 16; bold: true }
                        color: Theme.fg
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22 - 8 - (wsPill.visible ? wsPill.width + 8 : 0) - 26
                        elide: Text.ElideRight
                        text: cell.modelData.app || "App"
                        font { family: Theme.ui; pixelSize: 13; bold: true }
                        color: Theme.fg
                    }

                    Rectangle {
                        id: wsPill
                        visible: !!cell.modelData.ws
                        anchors.verticalCenter: parent.verticalCenter
                        width: wsLabel.width + 10
                        height: 18
                        radius: 9
                        color: cell.on ? Theme.s2 : Theme.s3
                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: cell.modelData.ws ?? ""
                            font { family: Theme.mono; pixelSize: 9 }
                            color: Theme.grey
                        }
                    }

                    // Кнопка закрыть окно (✕)
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: closeHover.hovered ? Theme.red : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: closeHover.hovered ? Theme.fg : Theme.mute
                        }
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (cell.modelData.closeWin) cell.modelData.closeWin();
                            }
                        }
                    }
                }

                // Логотип приложения (быстро, легковесно, без видеозахвата)
                Rectangle {
                    id: logoBox
                    width: parent.width
                    height: 126
                    radius: 12
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.s3

                    Image {
                        id: bigLogo
                        anchors.centerIn: parent
                        width: 68
                        height: 68
                        source: (root.visible && root.mode === 2 && cell.modelData.src) ? cell.modelData.src : ""
                        sourceSize: Qt.size(136, 136)
                        fillMode: Image.PreserveAspectFit
                        visible: !!cell.modelData.src && status !== Image.Error
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !bigLogo.visible && !!cell.modelData.glyph
                        text: cell.modelData.glyph ?? ""
                        font.pixelSize: 48
                        color: Theme.fg
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !bigLogo.visible && !cell.modelData.glyph
                        text: (cell.modelData.app || cell.modelData.name || "?").charAt(0).toUpperCase()
                        font { family: Theme.mono; pixelSize: 36; bold: true }
                        color: Theme.fg
                    }
                }

                // Заголовок окна внизу
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: cell.modelData.name ?? ""
                    font { family: Theme.ui; pixelSize: 12 }
                    color: cell.on ? Theme.fg : Theme.grey
                }
            }

            TapHandler { onTapped: { root.sel = cell.modelData.k; root.launch(); } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        // Обычная круглая ячейка для приложений (App Launcher)
        Column {
            visible: !cell.isWin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 88
                height: 88
                radius: 44
                color: cell.on ? Theme.s3 : Theme.s2
                border.width: cell.on ? 2 : 0
                border.color: Theme.fg

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    visible: !!cell.modelData.src && status !== Image.Error
                    width: 50
                    height: 50
                    source: (root.visible && cell.modelData.src) ? cell.modelData.src : ""
                    sourceSize: Qt.size(100, 100)
                    fillMode: Image.PreserveAspectFit
                }

                Icon {
                    anchors.centerIn: parent
                    visible: (!cell.modelData.src || appIcon.status === Image.Error) && !!cell.modelData.glyph
                    text: cell.modelData.glyph ?? ""
                    font.pixelSize: 36
                    color: Theme.fg
                }

                Text {
                    anchors.centerIn: parent
                    visible: (!cell.modelData.src || appIcon.status === Image.Error) && !cell.modelData.glyph
                    text: (cell.modelData.name || "?").charAt(0).toUpperCase()
                    font { family: Theme.mono; pixelSize: 28; bold: true }
                    color: Theme.fg
                }

                TapHandler { onTapped: { root.sel = cell.modelData.k; root.launch(); } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }

            Text {
                width: cell.width - 8
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.StyledText
                readonly property var hl: cell.modelData.hl ?? []
                text: [...(cell.modelData.name ?? "")].map((c, i) => {
                    const e = c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
                    return hl.includes(i) ? `<font color="${Theme.fg}">${e}</font>` : e;
                }).join("")
                font { family: Theme.ui; pixelSize: 14 }
                color: cell.on ? Theme.fg : Theme.grey
            }
        }
    }
}
