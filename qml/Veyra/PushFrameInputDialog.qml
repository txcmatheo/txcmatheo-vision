// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS Frame Input API (dialog key "frameinput"): other applications that send their video into
// PushFPS over shared memory (include/pushfps/FrameInput.h, docs/FRAME-INPUT-API.md). Lists the
// senders found (bridge pushFrameInputSenders, refreshed every second while open) and opens one as
// the source (pushStartFrameInput), which then works like a capture card: frame generation,
// enhancement, recording and streaming. A channel name can be typed for senders on other channels.
import QtQuick
import QtQuick.Layouts

DialogLayer {
    id: input
    objectName: "pushfps-frame-input-dialog"
    key: "frameinput"
    glyph: "import"
    title: qsTr("其他应用的画面")
    sub: qsTr("游戏、模拟器、串流或视频软件可以通过 PushFPS 画面输入接口把画面直接送进来，然后像采集卡一样补帧、增强、录制和直播")
    dialogWidth: 640

    property var senders: []
    property string channel: "default"
    function refresh() { input.senders = veyra.pushFrameInputSenders() || [] }
    function use(name) {
        if (veyra.pushStartFrameInput(name)) { veyra.logUi("push-frame-input", "start " + name); input.dialogHost.close(); return true }
        return false
    }
    onShownChanged: if (shown) input.refresh()
    Timer { interval: 1000; repeat: true; running: input.shown; onTriggered: input.refresh() }

    actions: [{ label: qsTr("关闭") }]
    onActionTriggered: label => input.dialogHost.close()

    DialogGroup {
        Repeater {
            model: input.senders
            delegate: VRow {
                required property var modelData
                objectName: "frame-input-sender-" + modelData.channel
                label: String(modelData.name || modelData.channel)
                hint: qsTr("通道 %1 · 最大 %2×%3").arg(modelData.channel).arg(modelData.width).arg(modelData.height)
                      + (Number(modelData.fps) > 0 ? " · " + qsTr("%1 FPS").arg(Math.round(Number(modelData.fps) * 100) / 100) : "")
                      + (modelData.alive ? "" : " · " + qsTr("应用已关闭"))
                VButton {
                    objectName: "frame-input-use-" + modelData.channel
                    primary: true
                    enabled: modelData.alive === true
                    text: qsTr("使用")
                    onClicked: input.use(modelData.channel)
                }
            }
        }
        VRow {
            visible: input.senders.length === 0
            objectName: "frame-input-none"
            label: qsTr("没有找到正在发送画面的应用")
            hint: qsTr("打开支持 PushFPS 画面输入的应用后，它会自动出现在这里")
        }
        VRow {
            label: qsTr("其他通道")
            hint: qsTr("应用用了别的通道名时，在这里输入")
            RowLayout {
                spacing: 6
                DialogTextField {
                    objectName: "frame-input-channel"
                    implicitWidth: 140
                    text: input.channel
                    onTyped: value => input.channel = value
                }
                VButton { objectName: "frame-input-use-channel"; text: qsTr("使用"); onClicked: input.use(input.channel) }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("开发者：接口说明、C/C++ 头文件和 Python 示例在 GitHub 上")
        color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    VButton {
        objectName: "frame-input-docs"
        ghost: true
        iconName: "external"
        text: qsTr("打开接口说明")
        onClicked: veyra.pushOpenLink("frameInputDocs")
    }
}
