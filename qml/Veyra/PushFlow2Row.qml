// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// One PushFlow 2 experiment's switch (Professional mode; docs/PUSHFLOW2.md, pushflow/PushFlow2.h). Every
// experiment is off unless switched on here, the preference `pushFlow2` holds them all as one small JSON
// object, and the row says what really runs: asked for is not the same as in use.
//   part: the experiment's name in the preference ("fusion", "guard", ...)
//   stateKey: the name in pushLiveStats() of what the engine says of it: "" not asked for or not started
//             yet, "on", or a word for why not (shown here as `cacheState`)
//   describe: what to say while it runs, from the live stats
import QtQuick
import QtQuick.Layouts
VRow {
    id: row
    property string part: "fusion"
    property string title: ""
    property string explanation: ""
    property string stateKey: "pushFlowEncoderCache"
    property var describe: function(st) { return "" }
    property var stats: ({})
    // What pushLiveStats() says while PushFlow plays (read once a second while the row is shown).
    property string cacheState: ""
    property bool stopped: false
    property bool live: false
    readonly property var flags: {
        try { const v = JSON.parse(veyra.preferences.pushFlow2 || "{}"); return v && typeof v === "object" && !Array.isArray(v) ? v : ({}) } catch (e) { return ({}) }
    }
    readonly property bool asked: row.flags[row.part] === true
    function setAsked(on) {
        const next = Object.assign({}, row.flags)
        next.v = 1
        next[row.part] = on === true
        veyra.setPreference("pushFlow2", JSON.stringify(next))
    }
    function why(word) {
        if (word === "no-files") return qsTr("这个版本的 PushFlow 运行库里没有拆分后的模型")
        if (word === "half-precision") return qsTr("半精度开启时不可用")
        if (word === "dynamic-shapes") return qsTr("当前模型没有固定尺寸")
        if (word === "session") return qsTr("拆分后的模型没能打开")
        if (word === "mismatch") return qsTr("在这块显卡上，结果和完整模型不一致")
        if (word === "failed") return qsTr("运行时出错，已改回完整模型")
        if (word === "no-grids") return qsTr("当前模型不提供运动数据")
        if (word === "too-small") return qsTr("运动估算尺寸太小")
        if (word === "shader") return qsTr("着色器没能载入")
        if (word === "not-live") return qsTr("只用于采集卡、串流等实时画面")
        if (word === "needs-predict") return qsTr("需要 Predict 已开启并且正在运行")
        if (word === "needs-2x") return qsTr("只在 2X 倍率下起作用")
        if (word === "no-stick") return qsTr("没有右摇杆经过 PushFPS（目前只有 PS5 Remote Play；接在主机上的手柄看不到）")
        return word
    }
    function readLive() {
        const st = veyra.pushLiveStats() || ({})
        row.live = st.running === true && Number(st.pushFlowMotionWidth || 0) > 0
        row.stopped = st.pushFlow2Stopped === true
        row.cacheState = row.live ? String(st[row.stateKey] || "") : ""
        row.stats = st
    }
    label: row.title
    help: row.explanation
    hint: !row.asked ? qsTr("实验功能，默认关闭。关闭时 PushFlow 和以前完全一样")
        : row.stopped ? qsTr("已开启，但本次以安全模式启动，所有实验功能都不运行")
        : row.cacheState === "on" ? row.describe(row.stats)
        : row.cacheState.length > 0 ? qsTr("已开启，但没有使用：%1。PushFlow 照常运行").arg(row.why(row.cacheState))
        : row.live ? qsTr("已开启，下一次 PushFlow 启动时生效")
        : qsTr("已开启。PushFlow 运行时，这里会显示它是否真的在用")
    hintBelow: true
    RowLayout {
        spacing: 8
        VSwitch {
            objectName: "list-pushflow2-" + row.part
            checked: row.asked
            onToggled: on => row.setAsked(on)
        }
        Timer {
            objectName: "list-pushflow2-" + row.part + "-timer"
            interval: 1000; repeat: true; triggeredOnStart: true
            running: row.visible && veyra.hasSource === true
            onTriggered: row.readLive()
            onRunningChanged: if (!running) { row.live = false; row.cacheState = "" }
        }
    }
}
