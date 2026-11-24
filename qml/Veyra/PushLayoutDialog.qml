// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS layout editor (dialog key "layout", opened from streaming mode): the output picture of a
// recording or stream with the game picture and the scene's sources on it. Drag to move, drag a
// corner to resize; resizing keeps the proportions, holding Ctrl lets the shape change freely.
// Edges and the middle snap. Crop and background for the selected item below the picture. Ctrl+Z
// undoes, Ctrl+Y / Ctrl+Shift+Z redoes; the arrow keys nudge (Shift: ten times as far).
// Writes the canvas preferences (canvasX/Y/W/H, canvasCrop*, canvasBackground, canvasStretch;
// engine/PushCanvas.h, applied live through setPushLiveCanvas) and the scene's sources (pref
// studioScenes; StudioPage.qml applies them). Maths in PushLayout.js.
import QtQuick
import QtQuick.Layouts
import "PushLayout.js" as LayoutMath

DialogLayer {
    id: lay
    objectName: "pushfps-layout-dialog"
    key: "layout"
    glyph: "layers"
    title: qsTr("布局")
    sub: qsTr("拖动游戏画面和来源来摆放，拖角改变大小。按住 Ctrl 可以不按原比例拉伸。Ctrl+Z 撤销")
    dialogWidth: 820

    property string sceneId: ""
    property string output: "stream"      // which output's shape the editor shows: stream or record
    property var box: ({ x: 0, y: 0, w: 1, h: 1 })
    property var crop: ({ l: 0, t: 0, r: 0, b: 0 })
    property int background: 0
    property bool stretch: false
    property var sources: []
    property int selected: -1              // -1 nothing, 0 game picture, 1.. sources
    property string picture: ""
    property var sourceStatus: []
    property int historyRevision: 0
    property var history: LayoutMath.history(60)
    readonly property bool canUndo: historyRevision >= 0 && history.items.length > 0
    readonly property bool canRedo: historyRevision >= 0 && history.redoItems.length > 0
    // Tests set the picture aspect directly.
    property real frameAspect: veyra.previewAspect > 0.2 ? veyra.previewAspect : 16 / 9

    // --- scenes and outputs -----------------------------------------------------------------
    function scenes() {
        let list = null
        try { list = JSON.parse(String(veyra.preferences.studioScenes || "")) } catch (e) { list = null }
        return Array.isArray(list) ? list : []
    }
    function gameScenes() { return lay.scenes().filter(s => s.type === "game") }
    function scene() {
        const games = lay.gameScenes()
        return games.find(s => s.id === lay.sceneId) || games[0] || null
    }
    readonly property int outW: Number(veyra.preferences[output === "record" ? "recordWidth" : "streamWidth"] || 0)
    readonly property int outH: Number(veyra.preferences[output === "record" ? "recordHeight" : "streamHeight"] || 0)
    readonly property real outAspect: outW > 0 && outH > 0 ? outW / outH : frameAspect
    readonly property int outputFit: lay.stretch ? 2 : Number(veyra.preferences[output === "record" ? "recordFit" : "streamFit"] || 0)

    function load() {
        const p = veyra.preferences
        lay.box = LayoutMath.canvasRect(p)
        lay.crop = { l: Number(p.canvasCropL || 0) / 1000, t: Number(p.canvasCropT || 0) / 1000,
                     r: Number(p.canvasCropR || 0) / 1000, b: Number(p.canvasCropB || 0) / 1000 }
        lay.background = Number(p.canvasBackground || 0)
        lay.stretch = p.canvasStretch === true
        const s = lay.scene()
        lay.sources = s && Array.isArray(s.sources) ? JSON.parse(JSON.stringify(s.sources)) : []
        if (lay.selected > lay.sources.length) lay.selected = -1
    }
    function snapshot() {
        return { box: lay.box, crop: lay.crop, background: lay.background, stretch: lay.stretch, sources: lay.sources }
    }
    function restore(s) {
        if (!s) return
        lay.box = s.box; lay.crop = s.crop; lay.background = s.background; lay.stretch = s.stretch === true
        lay.sources = s.sources || []
        if (lay.selected > lay.sources.length) lay.selected = -1
        lay.commit()
    }
    // Remembers the state before an edit (one undo step), unless nothing changed since.
    function remember(before) { if (lay.history.push(before)) lay.historyRevision++ }
    function undo() { const s = lay.history.undo(lay.snapshot()); if (s) { lay.restore(s); lay.historyRevision++ } }
    function redo() { const s = lay.history.redo(lay.snapshot()); if (s) { lay.restore(s); lay.historyRevision++ } }

    // Writes what differs from the stored preferences.
    function commit() {
        const p = veyra.preferences
        const want = Object.assign(LayoutMath.canvasPrefs(lay.box), {
            canvasCropL: Math.round(lay.crop.l * 1000), canvasCropT: Math.round(lay.crop.t * 1000),
            canvasCropR: Math.round(lay.crop.r * 1000), canvasCropB: Math.round(lay.crop.b * 1000),
            canvasBackground: lay.background, canvasStretch: lay.stretch })
        const defaults = { canvasX: 0, canvasY: 0, canvasW: 1000, canvasH: 1000, canvasCropL: 0, canvasCropT: 0, canvasCropR: 0,
                           canvasCropB: 0, canvasBackground: 0, canvasStretch: false }
        for (const k in want) {
            const have = p[k] === undefined ? defaults[k] : (typeof defaults[k] === "boolean" ? p[k] === true : Number(p[k]))
            if (have !== want[k]) veyra.setPreference(k, want[k])
        }
        const s = lay.scene()
        if (!s) return
        if (JSON.stringify(s.sources || []) === JSON.stringify(lay.sources)) return
        const list = lay.scenes().map(x => x.id === s.id ? Object.assign({}, x, { sources: lay.sources }) : x)
        veyra.setPreference("studioScenes", JSON.stringify(list))
    }
    Timer { id: commitSoon; interval: 80; onTriggered: lay.commit() }

    // --- items --------------------------------------------------------------------------------
    function statusAspect(id) {
        const st = lay.sourceStatus.find(x => x.id === id)
        return st && st.width > 0 && st.height > 0 ? st.width / st.height : 16 / 9
    }
    // The visible game picture (what the handles hold).
    function gameMap() { return LayoutMath.mapCanvas(lay.box, lay.crop, lay.outputFit, lay.frameAspect, lay.outAspect) }
    function rectOf(i) {
        if (i === 0) return lay.gameMap().dst
        const src = lay.sources[i - 1]
        return src ? LayoutMath.sourceRect(src, lay.statusAspect(src.id), lay.outAspect) : { x: 0, y: 0, w: 0, h: 0 }
    }
    // Sets item i to rect. stretched: Ctrl was held (the shape may change).
    function setRect(i, rect, stretched) {
        if (i === 0) {
            lay.box = rect
            if (stretched) lay.stretch = true
        } else {
            const list = lay.sources.slice()
            list[i - 1] = Object.assign({}, list[i - 1], LayoutMath.sourceFields(list[i - 1], rect, stretched))
            lay.sources = list
        }
        commitSoon.restart()
    }
    function nudge(dx, dy) {
        if (lay.selected < 0) return
        const before = lay.snapshot()
        lay.setRect(lay.selected, LayoutMath.moveRect(lay.rectOf(lay.selected), dx, dy, false), false)
        lay.remember(before)
    }
    function setCrop(side, value) {
        const v = Math.max(0, Math.min(0.45, value))
        if (lay.selected === 0) { const c = Object.assign({}, lay.crop); c[side] = v; lay.crop = c }
        else if (lay.selected > 0) {
            const key = { l: "cropL", t: "cropT", r: "cropR", b: "cropB" }[side]
            const list = lay.sources.slice()
            const changes = {}; changes[key] = Math.round(v * 1000) / 1000
            list[lay.selected - 1] = Object.assign({}, list[lay.selected - 1], changes)
            lay.sources = list
        }
        commitSoon.restart()
    }
    function cropOf(i, side) {
        if (i === 0) return lay.crop[side]
        const src = lay.sources[i - 1]
        return src ? Number(src[{ l: "cropL", t: "cropT", r: "cropR", b: "cropB" }[side]] || 0) : 0
    }
    function resetItem() {
        if (lay.selected < 0) return
        const before = lay.snapshot()
        if (lay.selected === 0) { lay.box = { x: 0, y: 0, w: 1, h: 1 }; lay.crop = { l: 0, t: 0, r: 0, b: 0 }; lay.stretch = false }
        else {
            const list = lay.sources.slice()
            const src = Object.assign({}, list[lay.selected - 1])
            for (const k of ["x", "y", "h", "cropL", "cropT", "cropR", "cropB"]) delete src[k]
            src.corner = src.kind === "camera" ? "br" : "tr"
            src.size = src.kind === "camera" ? 0.24 : 0.3
            list[lay.selected - 1] = src
            lay.sources = list
        }
        lay.commit()
        lay.remember(before)
    }
    function itemName(i) {
        if (i === 0) return qsTr("游戏画面")
        const src = lay.sources[i - 1]
        return src ? String(src.name || "") : ""
    }

    // --- the game picture for the editor (one frame, as the HUD editor takes it) --------------
    property real pictureStarted: 0
    function takePicture() {
        if (!veyra.hasSource) return
        if (veyra.pushStartHudDetection(1)) { lay.pictureStarted = Date.now(); picturePoll.start() }
    }
    Timer {
        id: picturePoll
        interval: 200; repeat: true
        onTriggered: {
            const s = veyra.pushHudDetection()
            if (s.done || s.failed || Date.now() - lay.pictureStarted > 15000) {
                stop()
                if (s.done && s.preview) lay.picture = s.preview
                if (!s.done && !s.failed) veyra.pushCancelHudDetection()
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: lay.shown
        onTriggered: lay.sourceStatus = veyra.pushSourceStatus() || []
    }

    onShownChanged: {
        if (shown) {
            lay.history.clear(); lay.historyRevision++
            lay.selected = -1
            lay.load()
            lay.takePicture()
            stageFrame.forceActiveFocus()
        } else {
            if (picturePoll.running) { picturePoll.stop(); veyra.pushCancelHudDetection() }
            if (commitSoon.running) { commitSoon.stop(); lay.commit() }
        }
    }
    // Another scene chosen in the editor starts its own history.
    onSceneIdChanged: if (shown) { lay.history.clear(); lay.historyRevision++; lay.selected = -1; lay.load() }

    Shortcut { sequences: [StandardKey.Undo]; enabled: lay.shown; onActivated: lay.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Shift+Z"]; enabled: lay.shown; onActivated: lay.redo() }

    actions: [{ label: qsTr("完成"), primary: true }]
    onActionTriggered: label => { if (commitSoon.running) { commitSoon.stop(); lay.commit() } lay.dialogHost.close() }

    // --- top row: scene, output, undo/redo ------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        spacing: 8
        VSelect {
            objectName: "layout-scene"
            visible: lay.gameScenes().length > 1
            implicitWidth: 160
            title: qsTr("场景")
            options: lay.gameScenes().map(s => ({ id: s.id, label: String(s.name || s.id) }))
            value: { const s = lay.scene(); return s ? String(s.name || s.id) : "" }
            onPicked: id => lay.sceneId = id
        }
        VSeg {
            objectName: "layout-output"
            options: [{ id: "stream", label: qsTr("直播画面") }, { id: "record", label: qsTr("录制画面") }]
            current: lay.output
            onPicked: id => lay.output = id
        }
        Text {
            Layout.fillWidth: true
            text: (lay.outW > 0 ? lay.outW + " × " + lay.outH : qsTr("画面原尺寸"))
                  + (lay.outputFit === 1 ? " · " + qsTr("填满") : lay.outputFit === 2 ? " · " + qsTr("拉伸") : " · " + qsTr("适应"))
            color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11
            elide: Text.ElideRight
        }
        VButton { objectName: "layout-undo"; icon: true; ghost: true; iconName: "undo"; tip: qsTr("撤销 (Ctrl+Z)"); enabled: lay.canUndo; onClicked: lay.undo() }
        VButton { objectName: "layout-redo"; icon: true; ghost: true; iconName: "rotatecw"; tip: qsTr("重做 (Ctrl+Y)"); enabled: lay.canRedo; onClicked: lay.redo() }
    }

    // --- the output picture -----------------------------------------------------------------------
    Item {
        id: stageFrame
        objectName: "layout-stage-frame"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.round(width / lay.outAspect), 420)
        focus: true
        Keys.onPressed: e => {
            const step = (e.modifiers & Qt.ShiftModifier) ? 0.02 : 0.002
            if (e.key === Qt.Key_Left) lay.nudge(-step, 0)
            else if (e.key === Qt.Key_Right) lay.nudge(step, 0)
            else if (e.key === Qt.Key_Up) lay.nudge(0, -step)
            else if (e.key === Qt.Key_Down) lay.nudge(0, step)
            else return
            e.accepted = true
        }
        Item {
            id: stage
            objectName: "layout-stage"
            width: Math.min(parent.width, parent.height * lay.outAspect)
            height: width / lay.outAspect
            anchors.centerIn: parent
            clip: true
            Rectangle {
                anchors.fill: parent
                color: "#" + ("000000" + lay.background.toString(16)).slice(-6)
            }
            // Click on an empty spot: nothing selected.
            MouseArea { anchors.fill: parent; onPressed: { lay.selected = -1; stageFrame.forceActiveFocus() } }
            // Game picture and sources, the game first (sources draw over it, as recorded).
            Repeater {
                model: lay.sources.length + 1
                delegate: Item {
                    id: item
                    required property int index
                    objectName: "layout-item-" + index
                    readonly property bool chosen: lay.selected === index
                    readonly property var rect: { lay.box; lay.crop; lay.sources; lay.outAspect; lay.outputFit; lay.sourceStatus; return lay.rectOf(index) }
                    readonly property var map: index === 0 ? lay.gameMap() : null
                    readonly property var src: index > 0 ? lay.sources[index - 1] : null
                    x: rect.x * stage.width; y: rect.y * stage.height
                    width: Math.max(4, rect.w * stage.width); height: Math.max(4, rect.h * stage.height)
                    z: index
                    // Picture: the game frame, or the source's latest preview.
                    Item {
                        anchors.fill: parent
                        clip: true
                        Rectangle {
                            anchors.fill: parent
                            visible: pic.status !== Image.Ready
                            color: item.index === 0 ? "#1d2a14" : "#20262e"
                            radius: item.src && item.src.shape === "circle" ? Math.min(width, height) / 2 : item.src && item.src.shape === "round" ? 8 : 0
                        }
                        Image {
                            id: pic
                            readonly property real cw: item.index === 0 ? item.map.src.w : Math.max(0.1, 1 - lay.cropOf(item.index, "l") - lay.cropOf(item.index, "r"))
                            readonly property real ch: item.index === 0 ? item.map.src.h : Math.max(0.1, 1 - lay.cropOf(item.index, "t") - lay.cropOf(item.index, "b"))
                            readonly property real cx: item.index === 0 ? item.map.src.x : lay.cropOf(item.index, "l")
                            readonly property real cy: item.index === 0 ? item.map.src.y : lay.cropOf(item.index, "t")
                            width: item.width / cw; height: item.height / ch
                            x: -cx * width; y: -cy * height
                            fillMode: Image.Stretch
                            // The game picture is one still; a source is live (image://push-source,
                            // a new picture for every frame it publishes; once a second until 3.2.3).
                            property int serial: 0
                            cache: false; asynchronous: item.index === 0
                            sourceSize: item.index === 0 ? undefined : Qt.size(960, 0)
                            source: item.index === 0 ? lay.picture : serial > 0 && item.src ? "image://push-source/" + item.src.id + "/" + serial : ""
                            Timer {
                                interval: 33; repeat: true; triggeredOnStart: true
                                running: lay.shown && item.index > 0
                                onTriggered: pic.serial = item.src ? veyra.pushSourceSerial(item.src.id) : 0
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: pic.status !== Image.Ready
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: lay.itemName(item.index)
                            color: Theme.onVideo; opacity: 0.75
                            font.family: Theme.fontUi; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: item.chosen ? 2 : 1
                        border.color: item.chosen ? Theme.brandGreen : Qt.rgba(1, 1, 1, 0.35)
                    }
                    MouseArea {
                        objectName: "layout-move-" + item.index
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property var start: null
                        property var before: null
                        property real gx: 0
                        property real gy: 0
                        onPressed: m => {
                            lay.selected = item.index
                            stageFrame.forceActiveFocus()
                            const p = mapToItem(stage, m.x, m.y)
                            gx = p.x; gy = p.y; start = item.rect; before = lay.snapshot()
                        }
                        onPositionChanged: m => {
                            if (!pressed || !start) return
                            const p = mapToItem(stage, m.x, m.y)
                            lay.setRect(item.index, LayoutMath.moveRect(start, (p.x - gx) / stage.width, (p.y - gy) / stage.height, true), false)
                        }
                        onReleased: { if (before) { lay.commit(); lay.remember(before) } before = null; start = null }
                    }
                    // Corner handles of the selected item.
                    Repeater {
                        model: item.chosen ? 4 : 0
                        delegate: Rectangle {
                            id: handle
                            required property int index
                            objectName: "layout-handle-" + index
                            width: 12; height: 12; radius: 3
                            x: (index % 2 ? item.width : 0) - 6
                            y: (index >= 2 ? item.height : 0) - 6
                            z: 10
                            color: Theme.brandGreen
                            border.width: 1; border.color: "#0D1A04"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                preventStealing: true
                                cursorShape: handle.index === 0 || handle.index === 3 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                property var start: null
                                property var before: null
                                onPressed: { start = item.rect; before = lay.snapshot() }
                                onPositionChanged: m => {
                                    if (!pressed || !start) return
                                    const p = mapToItem(stage, m.x, m.y)
                                    const free = (m.modifiers & Qt.ControlModifier) !== 0
                                    lay.setRect(item.index, LayoutMath.resizeRect(start, handle.index, p.x / stage.width, p.y / stage.height, !free,
                                                                              item.index === 0 ? 3 : 1), free)
                                }
                                onReleased: { if (before) { lay.commit(); lay.remember(before) } before = null; start = null }
                            }
                        }
                    }
                }
            }
        }
        // Along the bottom edge, so it never runs into the labels of the boxes in the middle.
        Rectangle {
            objectName: "layout-no-picture"
            visible: lay.picture.length === 0 && !veyra.hasSource
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: noPictureText.implicitWidth + 16; height: noPictureText.implicitHeight + 8
            radius: height / 2
            color: Theme.card2
            Text {
                id: noPictureText
                anchors.centerIn: parent
                text: qsTr("没有画面：方框仍可以摆放，连接画面后会显示游戏")
                color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }

    // --- the selected item ------------------------------------------------------------------------
    DialogGroup {
        Layout.topMargin: 10
        VRow {
            label: lay.selected < 0 ? qsTr("点击画面里的游戏画面或来源来调整") : lay.itemName(lay.selected)
            hint: lay.selected < 0 ? qsTr("拖动角上的方块改变大小，按住 Ctrl 可以改变形状；方向键微调")
                : lay.selected === 0 && lay.stretch ? qsTr("游戏画面已拉伸，不再保持原比例")
                : ""
            RowLayout {
                spacing: 6
                visible: lay.selected >= 0
                VButton { objectName: "layout-reset"; ghost: true; text: qsTr("重置"); onClicked: lay.resetItem() }
            }
        }
        Repeater {
            model: lay.selected >= 0 ? [{ side: "l", label: qsTr("裁剪左边") }, { side: "r", label: qsTr("裁剪右边") },
                                        { side: "t", label: qsTr("裁剪上边") }, { side: "b", label: qsTr("裁剪下边") }] : []
            delegate: VRow {
                id: cropRow
                required property var modelData
                label: modelData.label
                value: Math.round(lay.cropOf(lay.selected, modelData.side) * 100) + "%"
                VSlider {
                    objectName: "layout-crop-" + cropRow.modelData.side
                    implicitWidth: 200
                    valueFromModel: true
                    from: 0; to: 0.45; stepSize: 0.005
                    value: lay.cropOf(lay.selected, cropRow.modelData.side)
                    property var before: null
                    onPressedChanged: {
                        if (pressed) before = lay.snapshot()
                        else if (before) { lay.commit(); lay.remember(before); before = null }
                    }
                    onMoved: v => lay.setCrop(cropRow.modelData.side, v)
                }
            }
        }
        VRow {
            visible: lay.selected === 0
            label: qsTr("背景颜色")
            hint: qsTr("游戏画面没有盖住的地方")
            RowLayout {
                spacing: 6
                Repeater {
                    model: [0x000000, 0x1b1d21, 0x8df237, 0x00b140, 0xffffff]
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "layout-bg-" + modelData.toString(16)
                        width: 22; height: 22; radius: 6
                        color: "#" + ("000000" + modelData.toString(16)).slice(-6)
                        border.width: lay.background === modelData ? 2 : 1
                        border.color: lay.background === modelData ? Theme.brandGreen : Theme.stroke2
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { const before = lay.snapshot(); lay.background = parent.modelData; lay.commit(); lay.remember(before) }
                        }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("布局按比例用于直播和录制；两者形状不同时请分别检查。正在直播或录制时，改动会立即生效")
        color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
}
