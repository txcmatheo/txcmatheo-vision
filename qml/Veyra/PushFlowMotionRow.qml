// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// The size PushFlow works the motion out at, chosen apart from its tier (Professional mode; preference
// pushFlowMotion: 0 the tier's own, 540, 720 or 1080 lines; include/veyra/pushflow/PushFlowMotion.h).
// The tier still chooses the model; the picture is rebuilt at full size either way. While PushFlow
// runs, the row says the size really in use. Changing it rebuilds the graph, as changing the tier does.
import QtQuick
import QtQuick.Layouts
VRow {
    id: row
    objectName: "list-pushflow-motion-row"
    readonly property var sizes: [0, 540, 720, 1080]
    readonly property int chosen: {
        const v = Math.round(Number(veyra.preferences.pushFlowMotion || 0))
        return row.sizes.indexOf(v) >= 0 ? v : 0
    }
    // What the network runs at right now; 0: PushFlow is not running.
    property int liveWidth: 0
    property int liveHeight: 0
    label: qsTr("PushFlow 运动估算尺寸")
    help: qsTr("档位决定用哪个模型，这里决定在多大的画面上估算运动。画面始终用原分辨率的真实帧重建，所以清晰度不变。较小的尺寸更省显卡，有时能跟上更快的运动；较大的尺寸对细小的运动更准。哪一个适合你的游戏，只能测出来：换一个尺寸，然后运行“补帧画质测试”，比较“最差的位置”")
    hint: liveWidth > 0 ? qsTr("正在运行：%1 × %2").arg(liveWidth).arg(liveHeight)
        : chosen === 0 ? qsTr("自动：快速 540p，均衡 720p，高质量 1080p")
        : qsTr("不论档位，都在最高 %1p 上估算运动").arg(chosen)
    hintBelow: true
    function readLive() {
        const st = veyra.pushLiveStats() || ({})
        const on = st.running === true && Number(st.pushFlowMotionWidth || 0) > 0
        row.liveWidth = on ? Math.round(Number(st.pushFlowMotionWidth)) : 0
        row.liveHeight = on ? Math.round(Number(st.pushFlowMotionHeight || 0)) : 0
    }
    RowLayout {
        spacing: 8
        VSeg {
            objectName: "list-pushflow-motion"
            options: [{ id: "0", label: qsTr("自动") }, { id: "540", label: "540p" }, { id: "720", label: "720p" }, { id: "1080", label: "1080p" }]
            current: String(row.chosen)
            onPicked: id => veyra.setPreference("pushFlowMotion", Number(id))
        }
        Timer {
            objectName: "list-pushflow-motion-timer"
            interval: 1000; repeat: true; triggeredOnStart: true
            running: row.visible && veyra.hasSource === true
            onTriggered: row.readLive()
            onRunningChanged: if (!running) { row.liveWidth = 0; row.liveHeight = 0 }
        }
    }
}
