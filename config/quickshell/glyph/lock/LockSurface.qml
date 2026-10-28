import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// блокировка Nothing OS (glyph): видеофон RB22.mp4, дата, погода, аватар, пилюля PIN и шестерёнка сессий.
WlSessionLockSurface {
    id: root

    required property var auth // { buffer, fail, busy, leaving, submit() } из lock.qml
    property string layout: "en"

    color: Theme.bg

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    readonly property var bat: UPower.displayDevice
    property bool blink: true
    Timer { running: true; interval: 500; repeat: true; onTriggered: root.blink = !root.blink }

    // появление: t 0→1 линейно
    property real t: 0
    Behavior on t { NumberAnimation { duration: root.auth.leaving ? 450 : 1100 } }
    Component.onCompleted: {
        t = Qt.binding(() => root.auth.leaving ? 0 : 1);
        stage.forceActiveFocus();
    }
    onVisibleChanged: if (visible) stage.forceActiveFocus()

    function ph(a, b) { const x = Math.max(0, Math.min(1, (t - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }

    // волна проверки пароля
    property real wave: 0
    NumberAnimation on wave { running: root.auth.busy; from: 0; to: 1; duration: 700; loops: Animation.Infinite }

    // Таймер авто-входа для 4-5 цифр
    Timer {
        id: autoSubmitTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.auth.buffer.length >= 4 && !root.auth.busy && !root.auth.leaving) {
                root.auth.submit();
            }
        }
    }

    function checkAutoSubmit() {
        autoSubmitTimer.stop();
        if (root.auth.buffer.length >= 6) {
            root.auth.submit();
        } else if (root.auth.buffer.length >= 4) {
            autoSubmitTimer.start();
        }
    }

    // Фоновые процессы для шестерёнки
    Process { id: switchProcess; command: ["sh", "-c", "hyprctl dispatch exit || loginctl terminate-session self"] }
    Process { id: logoutProcess; command: ["sh", "-c", "hyprctl dispatch exit || loginctl terminate-session self"] }
    Process { id: rebootProcess; command: ["systemctl", "reboot"] }
    Process { id: shutdownProcess; command: ["systemctl", "poweroff"] }

    Stage {
        id: stage
        anchors.fill: parent
        focus: true

        // Восстановление фокуса при клике в любое место
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                stage.forceActiveFocus();
                sessionMenu.visible = false;
            }
        }

        Keys.onPressed: e => {
            if (root.auth.leaving) return;
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                autoSubmitTimer.stop();
                root.auth.submit();
            } else if (e.key === Qt.Key_Escape) {
                autoSubmitTimer.stop();
                root.auth.buffer = "";
                sessionMenu.visible = false;
            } else if (e.key === Qt.Key_Backspace) {
                autoSubmitTimer.stop();
                root.auth.buffer = root.auth.buffer.slice(0, -1);
            } else {
                var ch = e.text;
                if (!ch && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) {
                    ch = String.fromCharCode(e.key);
                } else if (!ch && e.key >= Qt.Key_KP_0 && e.key <= Qt.Key_KP_9) {
                    ch = String.fromCharCode(48 + (e.key - Qt.Key_KP_0));
                }
                if (ch && ch.charCodeAt(0) >= 32) {
                    root.auth.buffer += ch;
                    root.auth.fail = false;
                    checkAutoSubmit();
                } else {
                    return;
                }
            }
            e.accepted = true;
        }

        // 1. Видеофон
        Item {
            anchors.fill: parent
            opacity: root.ph(0, 0.6)

            MediaPlayer {
                id: lockVideoPlayer
                source: "file:///home/marudhu/.config/hypr-nothing-os/assets/RB22.mp4"
                videoOutput: lockVideoOutput
                loops: MediaPlayer.Infinite
                audioOutput: null
            }

            VideoOutput {
                id: lockVideoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            // Мягкое затемнение для читаемости виджетов Nothing OS
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.35
            }

            Timer {
                interval: 50
                running: true
                onTriggered: lockVideoPlayer.play()
            }
        }

        // 2. Верхняя шапка: дата и погода (часы удалены по запросу)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            spacing: 8
            opacity: root.ph(0.15, 0.65)
            transform: Translate { y: 16 * (1 - root.ph(0.15, 0.65)) }

            Lb {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.en.toString(clock.date, "dddd · d MMMM")
                px: 16
                color: Theme.fg
            }

            Lb {
                anchors.horizontalCenter: parent.horizontalCenter
                text: [Weather.ok ? `${Math.round(Weather.now.temp)}° ${Weather.name(Weather.now.code)}` : "",
                       Media.player?.trackTitle ? `${Media.player.trackTitle} — ${Media.player.trackArtist}` : ""].filter(Boolean).join(" · ")
                px: 13
                color: Theme.dim
                visible: text.length > 0
            }
        }

        // 3. Правый верхний угол: статус и кнопка-шестерёнка
        Row {
            id: statusRow
            anchors { right: parent.right; rightMargin: 44 }
            y: 36
            spacing: 16
            opacity: root.ph(0.45, 0.85)

            Lb { anchors.verticalCenter: parent.verticalCenter; text: root.layout }
            Icon { anchors.verticalCenter: parent.verticalCenter; text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"; font.pixelSize: 17 }

            Rectangle {
                visible: root.bat.isLaptopBattery
                anchors.verticalCenter: parent.verticalCenter
                width: 27
                height: 13
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle { x: 3; y: 3; width: (parent.width - 6) * root.bat.percentage; height: parent.height - 6; radius: 4; color: Theme.fg }
            }
            Lb { visible: root.bat.isLaptopBattery; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.bat.percentage * 100) }

            // Шестерёнка: меню сессий и выхода
            Item {
                width: 34
                height: 34
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 17
                    color: gearArea.containsMouse ? Theme.s2 : "transparent"
                    border { width: 1; color: gearArea.containsMouse ? Theme.s3 : "transparent" }

                    Icon {
                        anchors.centerIn: parent
                        text: "\u{F0493}"
                        font.pixelSize: 19
                        color: gearArea.containsMouse ? Theme.fg : Theme.dim
                        rotation: sessionMenu.visible ? 60 : 0
                        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: gearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sessionMenu.visible = !sessionMenu.visible
                }
            }
        }

        // Выпадающее меню сессий
        Rectangle {
            id: sessionMenu
            visible: false
            z: 100
            anchors { right: parent.right; rightMargin: 44; top: statusRow.bottom; topMargin: 12 }
            width: 190
            height: menuColumn.height + 16
            radius: 16
            color: "#181818"
            border { width: 1; color: "#333333" }

            Column {
                id: menuColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 4

                // Переключить сессию / экран входа
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 8
                    color: switchHover.containsMouse ? "#282828" : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Icon { text: "\u{F0504}"; font.pixelSize: 16; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                        Lb { text: "Switch Session"; px: 13; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: switchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionMenu.visible = false;
                            switchProcess.running = true;
                        }
                    }
                }

                // Выйти (Log Out)
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 8
                    color: logoutHover.containsMouse ? "#282828" : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Icon { text: "\u{F0343}"; font.pixelSize: 16; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                        Lb { text: "Log Out"; px: 13; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: logoutHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionMenu.visible = false;
                            logoutProcess.running = true;
                        }
                    }
                }

                // Перезагрузка
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 8
                    color: rebootHover.containsMouse ? "#282828" : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Icon { text: "\u{F0450}"; font.pixelSize: 16; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                        Lb { text: "Restart"; px: 13; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: rebootHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionMenu.visible = false;
                            rebootProcess.running = true;
                        }
                    }
                }

                // Выключение
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 8
                    color: shutdownHover.containsMouse ? "#282828" : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Icon { text: "\u{F0425}"; font.pixelSize: 16; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                        Lb { text: "Shut Down"; px: 13; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: shutdownHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionMenu.visible = false;
                            shutdownProcess.running = true;
                        }
                    }
                }
            }
        }

        // 4. Счётчик уведомлений слева внизу
        Row {
            visible: Theme.state.unread > 0
            opacity: root.ph(0.45, 0.85)
            x: 44
            anchors { bottom: parent.bottom; bottomMargin: 44 }
            spacing: 16
            Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F009A}"; font.pixelSize: 17 }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: `${Theme.state.unread} notifications` }
        }

        // 5. Центр внизу: Аватар (Lego Spider-Man), имя и пилюля ввода PIN
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 120 }
            spacing: 16

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 104
                height: 104
                opacity: root.ph(0.3, 0.7)
                transform: Translate { y: 24 * (1 - root.ph(0.3, 0.7)) }

                Ring { anchors.fill: parent; n: 32; f: root.t > 0.35 ? 1 : 0 }

                Rectangle {
                    anchors { fill: parent; margins: 14 }
                    radius: width / 2
                    color: Theme.s2
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "file:///home/marudhu/.config/hypr-nothing-os/assets/avatar.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        cache: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border { width: 1.5; color: Theme.s3 }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER")
                font { family: Theme.ui; pixelSize: 22 }
                color: Theme.fg
                opacity: root.ph(0.4, 0.75)
                transform: Translate { y: 16 * (1 - root.ph(0.4, 0.75)) }
            }

            // Поле ввода PIN
            Rectangle {
                id: pwd
                anchors.horizontalCenter: parent.horizontalCenter
                width: 58 + (380 - 58) * root.ph(0.5, 0.9)
                height: 58
                radius: 29
                opacity: root.ph(0.45, 0.6)
                color: Theme.s1
                border { width: 1; color: root.auth.fail ? Theme.red : Theme.s3 }

                TapHandler {
                    onTapped: stage.forceActiveFocus()
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    opacity: root.ph(0.75, 1)

                    Repeater {
                        id: typed
                        model: Math.min(root.auth.buffer.length, 16)
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: root.auth.fail ? Theme.red : Theme.fg
                            opacity: root.auth.busy && Math.abs(root.wave * (typed.count + 2) - 1 - index) > 1.2 ? 0.3 : 1
                            NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 24
                        color: Theme.red
                        opacity: root.blink ? 1 : 0
                    }

                    Repeater {
                        model: Math.max(0, 6 - root.auth.buffer.length)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: Theme.s3
                        }
                    }
                }

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 10; duration: 80 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }

                Connections {
                    target: root.auth
                    function onFailChanged() { if (root.auth.fail) shake.restart(); }
                }
            }

            Lb {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.ph(0.8, 1)
                text: root.auth.busy ? "checking…" : root.auth.fail ? "wrong PIN · try again" : "enter PIN or password"
                color: root.auth.fail ? Theme.red : Theme.grey
            }
        }
    }
}
