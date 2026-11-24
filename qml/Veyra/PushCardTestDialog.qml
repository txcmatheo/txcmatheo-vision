// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Test my graphics card: runs PushFlow's benchmark (PushFlowBench.exe, in its own process) on the
// card PushFPS renders on, at 1080p and 4K with every tier, and says what that means for 30 and
// 60 FPS games (PushCardTest.js). The result can be copied: it holds the card's name, its memory,
// the PushFPS version, the Windows build and timings, nothing about the user.
// Dialog key "cardtest"; opened from Settings (row set-cardtest).
import QtQuick
import QtQuick.Layouts
import "PushCardTest.js" as CardTest

DialogLayer {
    id: card
    objectName: "pushfps-card-test"
    key: "cardtest"
    glyph: "cpu"
    title: qsTr("测试我的显卡")
    sub: qsTr("测出 PushFlow（PushFPS 自己的补帧）在这块显卡上有多快：1080p 和 4K，三个档位。大约一分钟")
    dialogWidth: 620

    property var status: ({})
    readonly property bool running: card.status.running === true
    readonly property bool done: card.status.done === true
    readonly property bool ok: card.done && card.status.ok === true
    readonly property var rows: card.ok ? CardTest.rows(card.status.runs) : []
    property bool copied: false
    function refresh() { card.status = veyra.pushCardTestStatus() || ({}) }
    function start() {
        card.copied = false
        veyra.pushStartCardTest()
        card.refresh()
    }
    function copy() {
        if (!card.ok || !card.status.text) return
        card.copied = veyra.pushCopyText(String(card.status.text)) === true
    }
    function tierName(tier) { return tier === "Fast" ? qsTr("快速") : tier === "Balanced" ? qsTr("均衡") : tier === "Quality" ? qsTr("质量") : tier }
    function reach(m, gameFps) { return m >= 2 ? (gameFps * m) + " FPS (" + m + "×)" : qsTr("太慢") }
    readonly property string reasonText: {
        const r = String(card.status.reason || "")
        if (r === "playing") return qsTr("请先停止播放再测试：测试要独占显卡，才能测得准")
        if (r === "missing") return qsTr("没有找到 PushFlowBench.exe，请重新安装 PushFPS")
        if (r === "not-started") return qsTr("PushFlowBench.exe 无法启动")
        if (r === "no-pushflow") return qsTr("PushFlow 在这块显卡上没有启动（没有安装 PushFlow 组件，或显卡不支持）。其他补帧方式不受影响")
        if (r === "cancelled") return qsTr("测试已取消")
        if (r === "stopped") return qsTr("测试没有完成：显卡驱动出错或用时超过五分钟。PushFPS 不受影响")
        return ""
    }
    // What the result means for the most common case: a 30 FPS game at 4K.
    readonly property string headline: {
        if (!card.ok) return ""
        const t120 = CardTest.tierFor(card.status.runs, 2160, 30, 4)
        if (t120 !== "") return qsTr("4K 的 30 FPS 游戏可以补到 120 FPS，用「%1」档").arg(card.tierName(t120))
        const t60 = CardTest.tierFor(card.status.runs, 2160, 30, 2)
        if (t60 !== "") return qsTr("4K 的 30 FPS 游戏可以补到 60 FPS，用「%1」档").arg(card.tierName(t60))
        return qsTr("这块显卡跑 4K 的 PushFlow 太慢：请改用其他补帧方式，或让主机输出 1080p")
    }
    onShownChanged: if (shown) { card.copied = false; card.refresh() }
    Timer {
        objectName: "pushfps-card-test-timer"
        interval: 500; repeat: true
        running: card.shown && card.running
        onTriggered: card.refresh()
    }

    Text {
        objectName: "pushfps-card-test-state"
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        wrapMode: Text.WordWrap
        color: card.done && !card.ok ? Theme.warn : Theme.t1
        font.family: Theme.fontUi
        font.pixelSize: 13
        text: card.running ? qsTr("正在测试…请不要在这期间玩游戏或开始采集")
            : card.ok ? card.headline
            : card.done ? card.reasonText
            : qsTr("测试时不能有画面在播放。结果只包含显卡型号、显存、PushFPS 版本、Windows 版本和用时，不含任何个人信息")
    }
    Text {
        objectName: "pushfps-card-test-adapter"
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        visible: card.ok
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        elide: Text.ElideRight
        text: String(card.status.adapter || "") + (Number(card.status.vramMB || 0) > 0 ? " · " + Math.round(Number(card.status.vramMB) / 1024) + " GB" : "")
    }
    Repeater {
        model: card.rows
        delegate: VRow {
            required property var modelData
            objectName: "pushfps-card-test-row"
            label: modelData.size + " · " + card.tierName(modelData.tier)
            hint: qsTr("30 FPS 游戏：%1　60 FPS 游戏：%2").arg(card.reach(modelData.for30, 30)).arg(card.reach(modelData.for60, 60))
            value: modelData.networkMs > 0 ? modelData.networkMs.toFixed(1) + " ms" : ""
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: card.ok
        wrapMode: Text.WordWrap
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        text: card.copied ? qsTr("已复制。贴到 GitHub 的反馈里，就能帮我们建立各型号显卡的实测表")
                          : qsTr("愿意的话请复制结果发给我们：真实显卡的数据都来自大家")
    }

    foot: card.running ? qsTr("正在测试…") : ""
    actions: card.running ? [{ label: qsTr("取消测试") }]
           : card.ok ? [{ label: qsTr("关闭") }, { label: qsTr("去 GitHub 反馈") }, { label: qsTr("复制结果"), primary: true }]
                     : [{ label: qsTr("关闭") }, { label: card.done ? qsTr("重新测试") : qsTr("开始测试"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("取消测试")) { veyra.pushCancelCardTest(); card.refresh() }
        else if (label === qsTr("开始测试") || label === qsTr("重新测试")) card.start()
        else if (label === qsTr("复制结果")) card.copy()
        else if (label === qsTr("去 GitHub 反馈")) { card.copy(); veyra.pushOpenLink("issues") }
        else card.dialogHost.close()
    }
}
