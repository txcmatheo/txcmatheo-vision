// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// How to measure the whole delay, from the console to the monitor. PushFPS measures only its own
// part (the latency readout); the capture card, the console and the monitor add theirs. A phone's
// slow-motion camera filming the TV (the capture card's HDMI passthrough) next to the PC monitor
// shows the extra delay of the PushFPS path directly: count the frames between the two pictures.
// Dialog key "latencyguide"; opened from the quick setup's latency row.
import QtQuick
import QtQuick.Layouts

DialogLayer {
    id: guide
    objectName: "pushfps-latency-guide"
    key: "latencyguide"
    glyph: "gauge"
    title: qsTr("测量总延迟")
    sub: qsTr("PushFPS 只能测出自己的处理时间。用手机慢动作拍摄，可以看到从主机到显示器多出的全部延迟")
    dialogWidth: 600

    // 240 fps slow motion: one recorded frame is about 4.2 ms.
    property int phoneFps: 240
    property int frames: 10
    readonly property real msPerFrame: 1000 / Math.max(1, guide.phoneFps)
    readonly property real totalMs: guide.frames * guide.msPerFrame

    readonly property var steps: [
        qsTr("把采集卡的 HDMI 输出（直通）接到电视或第二台显示器，PushFPS 画面放在电脑显示器上，两块屏幕并排"),
        qsTr("在游戏里找一个画面会突然变化的动作，例如打开菜单或开枪"),
        qsTr("用手机慢动作（240 FPS 更准）同时拍下两块屏幕，按几次按钮"),
        qsTr("逐帧查看视频：数一数直通屏幕变化后，PushFPS 屏幕过了几帧才变化，填在下面")
    ]

    Repeater {
        model: guide.steps
        delegate: RowLayout {
            required property int index
            required property string modelData
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 22
                implicitHeight: 22
                radius: 11
                color: Theme.accentSoft
                Text {
                    anchors.centerIn: parent
                    text: String(index + 1)
                    color: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            Text {
                Layout.fillWidth: true
                text: modelData
                color: Theme.t1
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                wrapMode: Text.WordWrap
            }
        }
    }

    DialogGroup {
        VRow {
            label: qsTr("手机慢动作帧率")
            VSeg {
                objectName: "pushfps-latency-guide-fps"
                options: [{ id: "120", label: "120" }, { id: "240", label: "240" }, { id: "480", label: "480" }, { id: "960", label: "960" }]
                current: String(guide.phoneFps)
                onPicked: id => guide.phoneFps = Number(id)
            }
        }
        VRow {
            label: qsTr("相差的帧数")
            value: String(guide.frames)
            VSlider {
                objectName: "pushfps-latency-guide-frames"
                implicitWidth: 160
                valueFromModel: true
                from: 0; to: 60
                value: guide.frames
                onMoved: value => guide.frames = Math.round(value)
            }
        }
    }

    Text {
        objectName: "pushfps-latency-guide-result"
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("PushFPS 比直通多出约 %1 毫秒（每帧约 %2 毫秒）").arg(Math.round(guide.totalMs)).arg(guide.msPerFrame.toFixed(1))
        color: Theme.accent
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: qsTr("多拍几次取平均值。补帧要等下一张真实画面，30 FPS 游戏最多多出约 33 毫秒；关闭补帧再测一次，就能看出补帧本身占了多少")
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
