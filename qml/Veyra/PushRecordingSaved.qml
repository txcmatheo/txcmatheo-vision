// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// PushFPS: after a recording is saved, a small card offers the next step: edit it
// in the player (picture, sound, trim, then export), send it straight to the export
// queue, or show it in its folder. It goes away after 12 s or with ×.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    // Main supplies its page switch, so this file stays free of Main's ids.
    property var goPage: null
    property string path: ""
    property real lastSaved: -1
    property bool on: false
    readonly property string fileName: path.split(/[\\/]/).pop()

    objectName: "pushfps-recording-saved"
    // Over the picture: cut out of the native video window (main.cpp collects covers).
    readonly property bool videoCover: card.visible
    readonly property real coverRadius: 14
    width: Math.min(420, parent ? parent.width - 48 : 420)
    height: column.implicitHeight + 24
    radius: 14
    color: Theme.card
    border.width: 1
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
    opacity: on ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.d(200) } }
    transform: Translate { y: card.on ? 0 : 10; Behavior on y { NumberAnimation { duration: Theme.d(450); easing.bezierCurve: Theme.spring } } }

    // A finished recording, or a saved instant-replay clip, brings up the card.
    property bool replay: false
    property real lastReplaySaved: -1
    readonly property bool webhook: String(veyra.preferences.pushDiscordWebhook || "").length > 0
    property bool sending: false
    property string shareText: ""
    Connections {
        target: veyra
        function onPushShareFinished(ok, message) { card.sending = false; card.shareText = message; if (card.on) hideTimer.restart() }
    }
    // PushFPS clip markers: how many the finished recording has (its "-markers.txt" lies beside it).
    property int markers: 0
    function show(p, isReplay) {
        card.shareText = ""
        card.path = p
        card.replay = isReplay
        card.markers = isReplay ? 0 : Math.max(0, Number((veyra.recordingState || {}).markers || 0))
        card.on = true
        hideTimer.restart()
    }
    Connections {
        target: veyra
        function onRecordingChanged() {
            const s = veyra.recordingState || {}
            const saved = Number(s.saved ?? 0)
            if (card.lastSaved < 0) { card.lastSaved = saved; return }   // first state after start: no card
            if (saved > card.lastSaved && !s.active && String(s.path || "").length > 0) card.show(s.path, false)
            card.lastSaved = saved
        }
        function onReplayChanged() {
            const s = veyra.replayState || {}
            const saved = Number(s.saved ?? 0)
            if (card.lastReplaySaved < 0) { card.lastReplaySaved = saved; return }
            if (saved > card.lastReplaySaved && String(s.path || "").length > 0) card.show(s.path, true)
            card.lastReplaySaved = saved
        }
    }
    Component.onCompleted: {
        lastSaved = Number((veyra.recordingState || {}).saved ?? 0)
        lastReplaySaved = Number((veyra.replayState || {}).saved ?? 0)
    }
    Timer { id: hideTimer; interval: 12000; onTriggered: card.on = false }
    HoverHandler { onHoveredChanged: if (hovered) hideTimer.stop(); else if (card.on) hideTimer.restart() }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        RowLayout {
            spacing: 10
            Rectangle {
                implicitWidth: 30; implicitHeight: 30; radius: 9
                color: Theme.accentSoft
                VIcon { anchors.centerIn: parent; name: "film"; size: 15; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: card.replay ? qsTr("即时回放已保存") : qsTr("录制已保存"); color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: Theme.fsBody; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; text: card.fileName; color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: Theme.fsHint; elide: Text.ElideMiddle }
            }
            VButton {
                objectName: "pushfps-recording-saved-close"
                icon: true; iconName: "x"; ghost: true
                tip: qsTr("关闭")
                onClicked: card.on = false
            }
        }
        Text {
            objectName: "pushfps-recording-saved-markers"
            Layout.fillWidth: true
            visible: card.markers > 0
            text: qsTr("%1 个标记，记在录像旁边的同名文本文件里（-markers.txt）").arg(card.markers)
            color: Theme.t2; font.family: Theme.fontUi; font.pixelSize: Theme.fsHint
            wrapMode: Text.WordWrap
        }
        RowLayout {
            spacing: 6
            VButton {
                objectName: "pushfps-recording-edit"
                primary: true
                text: qsTr("编辑")
                iconName: "sliders"
                onClicked: {
                    card.on = false
                    veyra.openPath(card.path)
                    if (card.goPage) card.goPage("pro")
                }
            }
            VButton {
                objectName: "pushfps-recording-export"
                text: qsTr("加入导出")
                iconName: "upload"
                onClicked: {
                    card.on = false
                    veyra.addExportFiles([card.path])
                    if (card.goPage) card.goPage("exp")
                }
            }
            VButton {
                objectName: "pushfps-recording-folder"
                ghost: true
                text: qsTr("打开文件夹")
                iconName: "folder"
                onClicked: { card.on = false; veyra.openRecordingDirectory() }
            }
        }
        // Share to Discord: straight to the saved webhook when there is one (clips up to
        // Discord's 10 MB), otherwise the file goes on the clipboard and Discord opens.
        RowLayout {
            spacing: 6
            VButton {
                objectName: "pushfps-recording-discord"
                ghost: true
                text: card.webhook ? qsTr("发送到 Discord") : qsTr("分享到 Discord")
                iconName: "external"
                enabled: !card.sending
                onClicked: {
                    hideTimer.stop()
                    if (card.webhook) { card.sending = true; card.shareText = qsTr("正在发送…"); veyra.pushShareToDiscord(card.path) }
                    else if (veyra.pushCopyFile(card.path)) { veyra.pushOpenDiscord(); card.shareText = qsTr("已复制片段，在 Discord 中按 Ctrl+V 粘贴") }
                }
            }
            VButton {
                objectName: "pushfps-recording-copy"
                ghost: true
                text: qsTr("复制文件")
                iconName: "copy"
                onClicked: { hideTimer.stop(); if (veyra.pushCopyFile(card.path)) card.shareText = qsTr("已复制，可粘贴到任何聊天或文件夹") }
            }
        }
        Text {
            objectName: "pushfps-recording-share-text"
            Layout.fillWidth: true
            visible: card.shareText.length > 0
            text: card.shareText
            color: Theme.t2
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsHint
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            visible: veyra.fgEnabled === true
            text: qsTr("录制已包含补帧。导出前请在专业模式中关闭补帧，以免重复补帧。")
            color: Theme.t3
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsHint
            wrapMode: Text.WordWrap
        }
    }
}
