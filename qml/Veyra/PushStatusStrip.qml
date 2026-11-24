// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The new design's status strip: what the engine reports about the running picture, read once a
// second (pushLiveStats, the figures the latency readout and Check my setup read). A figure nobody
// reported is a dash, never a zero and never a made-up number; with nothing playing every figure is
// a dash. Nothing here changes a setting.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: strip
    objectName: "pushfps-status"
    property var stats: ({})
    readonly property bool playing: veyra.hasSource === true
    // Only a number is a reading (null, undefined and "" are not: Number(null) is 0).
    function num(v) { return (typeof v === "number" && isFinite(v)) || (typeof v === "string" && v.trim() !== "" && isFinite(Number(v))) ? Number(v) : NaN }
    function whole(v) { const n = num(v); return n > 0 ? String(Math.round(n)) : "" }
    readonly property string dash: "—"
    readonly property string sizeText: {
        const w = whole(stats.sourceWidth), h = whole(stats.sourceHeight)
        return playing && w !== "" && h !== "" ? w + " × " + h : dash
    }
    readonly property string captureText: {
        const f = whole(stats.captureFps)
        return playing && f !== "" ? f + " FPS" : dash
    }
    readonly property string rateText: {
        const game = whole(stats.contentFps)
        const shown = num(stats.realFps) + (num(stats.generatedFps) > 0 ? num(stats.generatedFps) : 0)
        if (!playing || game === "" || !(shown > 0)) return dash
        return game + " → " + Math.round(shown) + " FPS"
    }
    readonly property bool latencyKnown: playing && stats.running === true && num(stats.latencyMs) >= 0
    readonly property string latencyText: qsTr("延迟 %1 ms").arg(latencyKnown ? num(stats.latencyMs).toFixed(0) : dash)
    readonly property string gpuText: {
        const g = num(stats.gpuUtilization)
        return playing && g >= 0 ? Math.round(g) + " %" : dash
    }
    readonly property string outputText: {
        const w = whole(stats.outputWidth), h = whole(stats.outputHeight)
        return playing && w !== "" && h !== "" ? w + " × " + h + (stats.hdr === true ? " · HDR" : "") : dash
    }
    function refresh() { strip.stats = (strip.playing && typeof veyra.pushLiveStats === "function" ? veyra.pushLiveStats() : null) || ({}) }
    // (After the change, not inside it: the figures above read `playing`, and a new `stats` while one of
    // them is being worked out is a binding loop.)
    onPlayingChanged: Qt.callLater(strip.refresh)
    Timer {
        objectName: "pushfps-status-timer"
        interval: 1000; repeat: true
        running: strip.visible && strip.playing
        onTriggered: strip.refresh()
    }

    color: Theme.card
    bottomRightRadius: Theme.rWindow
    Rectangle { width: parent.width; height: 1; color: Theme.stroke }

    component Cell: RowLayout {
        id: cell
        property string glyph: ""
        property string label: ""
        property string value: ""
        property bool known: true
        spacing: 7
        VIcon { name: cell.glyph; size: 14; color: cell.known ? Theme.accent : Theme.t3; Layout.alignment: Qt.AlignVCenter }
        Text { visible: cell.label !== ""; text: cell.label; color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 12 }
        Text {
            text: cell.value
            color: cell.known ? Theme.t1 : Theme.t3
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.variableAxes: Theme.axesMedium
            font.features: ({ "tnum": 1 })
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 0
        Cell { objectName: "pushfps-status-capture"; glyph: "video"; label: qsTr("采集"); value: strip.sizeText === strip.dash ? strip.dash : strip.captureText === strip.dash ? strip.sizeText : strip.sizeText + " · " + strip.captureText; known: strip.sizeText !== strip.dash }
        Item { Layout.fillWidth: true; Layout.minimumWidth: 12 }
        Cell { objectName: "pushfps-status-rate"; glyph: "zap"; label: qsTr("帧率"); value: strip.rateText; known: strip.rateText !== strip.dash }
        Item { Layout.fillWidth: true; Layout.minimumWidth: 12 }
        Cell { objectName: "pushfps-status-latency"; glyph: "clock"; visible: strip.width >= 700; label: ""; value: strip.latencyText; known: strip.latencyKnown }
        Item { visible: strip.width >= 700; Layout.fillWidth: true; Layout.minimumWidth: 12 }
        Cell { objectName: "pushfps-status-gpu"; glyph: "cpu"; visible: strip.width >= 860; label: qsTr("GPU 占用"); value: strip.gpuText; known: strip.gpuText !== strip.dash }
        Item { visible: strip.width >= 860; Layout.fillWidth: true; Layout.minimumWidth: 12 }
        Cell { objectName: "pushfps-status-output"; glyph: "monitor"; label: qsTr("输出"); value: strip.outputText; known: strip.outputText !== strip.dash }
    }
}
