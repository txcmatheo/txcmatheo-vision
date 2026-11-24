// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS crop and resize (dialog key "crop", opened from the quick setup): cut any side of the console
// picture, as a streaming program's crop handles do, and choose how large and where it is shown.
// One frame of the picture with the kept part outlined: drag an edge to cut that side, a corner to
// cut two, the middle to slide the kept part. Below it the same four sides as numbers, shapes cut
// evenly around the middle, the size on screen and the position.
// Every change is applied to the picture on screen as it is made (preferences pushCrop*, read by
// the bridge in View.cpp applyAspect; the engine's PreviewView cuts and VideoPresenter draws only
// the kept part). Recordings and streams keep the whole picture unless the switch here is on
// (Recording.cpp pushCanvas). Maths and the preference names in PushCrop.js.
import QtQuick
import QtQuick.Layouts
import "PushCrop.js" as Crop

DialogLayer {
    id: dlg
    objectName: "pushfps-crop-dialog"
    key: "crop"
    glyph: "fit"
    title: qsTr("裁剪和缩放")
    sub: qsTr("拖动边线裁掉这一边，拖动四角同时裁两边，拖动中间移动保留的部分。屏幕上的画面会立即跟着变")
    dialogWidth: 760

    property var crop: Crop.read(veyra.preferences)
    property string picture: ""
    // Tests set the picture's shape directly.
    property real frameAspect: veyra.previewAspect > 0.2 ? veyra.previewAspect : 16 / 9
    // The crop is for a console picture and is not applied while XeSS presents its own frames.
    readonly property bool consolePicture: Crop.kinds.indexOf(String(veyra.sourceKind || "")) >= 0
    readonly property bool xess: veyra.presentationOwned === true
    readonly property var shapeLabels: [qsTr("整个画面"), "16:9", "21:9", "32:9", "4:3", "1:1"]

    function percent(thousandths) { return (thousandths / 10).toFixed(1) }
    // Applies a change at once on this dialog's picture and, a moment later, in the preferences.
    function set(change) {
        dlg.crop = Crop.copy(dlg.crop, change)
        commitSoon.restart()
    }
    // Writes what differs. A crop that cuts or moves something is switched on with it (what is drawn
    // here is what the screen shows); one with nothing left to do is switched off.
    function commit() {
        const wanted = Crop.values(dlg.crop)
        const saved = Crop.values(Crop.read(veyra.preferences))
        for (const k of Crop.keys) if (wanted[k] !== saved[k]) veyra.setPreference(k, wanted[k])
        const on = !Crop.neutral(dlg.crop)
        if ((veyra.preferences.pushCropOn === true) !== on) veyra.setPreference("pushCropOn", on)
        dlg.crop = Crop.copy(dlg.crop, { on: on })
    }
    function reset() {
        commitSoon.stop()
        dlg.crop = Crop.copy(dlg.crop, { l: 0, t: 0, r: 0, b: 0, zoom: 100, x: 0, y: 0 })
        dlg.commit()
    }
    Timer { id: commitSoon; interval: 80; onTriggered: dlg.commit() }
    // A change is still to be written (tests wait for this instead of for a length of time).
    readonly property bool pendingWrite: commitSoon.running

    // --- one frame of the picture (as the layout editor takes it) -------------------------------
    property real pictureStarted: 0
    function takePicture() {
        if (!veyra.hasSource) return
        if (veyra.pushStartHudDetection(1)) { dlg.pictureStarted = Date.now(); picturePoll.start() }
    }
    Timer {
        id: picturePoll
        interval: 200; repeat: true
        onTriggered: {
            const s = veyra.pushHudDetection()
            if (s.done || s.failed || Date.now() - dlg.pictureStarted > 15000) {
                stop()
                if (s.done && s.preview) dlg.picture = s.preview
                if (!s.done && !s.failed) veyra.pushCancelHudDetection()
            }
        }
    }
    onShownChanged: {
        if (shown) {
            dlg.crop = Crop.read(veyra.preferences)
            dlg.takePicture()
        } else {
            if (picturePoll.running) { picturePoll.stop(); veyra.pushCancelHudDetection() }
            if (commitSoon.running) { commitSoon.stop(); dlg.commit() }
        }
    }

    actions: [{ label: qsTr("重置") }, { label: qsTr("完成"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("重置")) dlg.reset()
        else dlg.dialogHost.close()
    }

    // --- the picture and its handles ---------------------------------------------------------------
    Item {
        id: stageFrame
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(380, width / dlg.frameAspect)
        Item {
            id: stage
            objectName: "pushfps-crop-stage"
            width: Math.min(parent.width, parent.height * dlg.frameAspect)
            height: width / dlg.frameAspect
            anchors.centerIn: parent
            readonly property var kept: Crop.rect(dlg.crop, width, height)
            property string held: ""
            property var heldCrop: null
            property real heldX: 0
            property real heldY: 0

            Rectangle { anchors.fill: parent; radius: 6; color: "#1d2a14"; visible: frame.status !== Image.Ready }
            Image {
                id: frame
                anchors.fill: parent
                source: dlg.picture
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
            }
            Text {
                anchors.centerIn: parent
                visible: frame.status !== Image.Ready
                text: veyra.hasSource ? qsTr("正在取一帧画面…") : qsTr("打开画面后，这里显示游戏的一帧")
                color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: Theme.fsSmall
            }
            // The four cut parts, dimmed.
            Rectangle { x: 0; y: 0; width: parent.width; height: stage.kept.y0; color: "#000000"; opacity: 0.66 }
            Rectangle { x: 0; y: stage.kept.y1; width: parent.width; height: parent.height - stage.kept.y1; color: "#000000"; opacity: 0.66 }
            Rectangle { x: 0; y: stage.kept.y0; width: stage.kept.x0; height: stage.kept.y1 - stage.kept.y0; color: "#000000"; opacity: 0.66 }
            Rectangle { x: stage.kept.x1; y: stage.kept.y0; width: parent.width - stage.kept.x1; height: stage.kept.y1 - stage.kept.y0; color: "#000000"; opacity: 0.66 }
            // The kept part: outline, and a mark on each corner and edge.
            Rectangle {
                objectName: "pushfps-crop-kept"
                x: stage.kept.x0; y: stage.kept.y0
                width: stage.kept.x1 - stage.kept.x0; height: stage.kept.y1 - stage.kept.y0
                color: "transparent"
                border.width: 2; border.color: Theme.brandGreen
            }
            Repeater {
                model: [{ h: "tl", fx: 0, fy: 0 }, { h: "t", fx: 0.5, fy: 0 }, { h: "tr", fx: 1, fy: 0 }, { h: "r", fx: 1, fy: 0.5 },
                        { h: "br", fx: 1, fy: 1 }, { h: "b", fx: 0.5, fy: 1 }, { h: "bl", fx: 0, fy: 1 }, { h: "l", fx: 0, fy: 0.5 }]
                delegate: Rectangle {
                    required property var modelData
                    width: 12; height: 12; radius: 2
                    x: stage.kept.x0 + (stage.kept.x1 - stage.kept.x0) * modelData.fx - 6
                    y: stage.kept.y0 + (stage.kept.y1 - stage.kept.y0) * modelData.fy - 6
                    color: stage.held === modelData.h ? "#FFFFFF" : Theme.brandGreen
                    border.width: 1; border.color: "#0B0D0E"
                }
            }
            MouseArea {
                id: pointer
                objectName: "pushfps-crop-pointer"
                anchors.fill: parent
                anchors.margins: -10            // an edge at the picture's own border can still be taken
                hoverEnabled: true
                // The dialog scrolls: without this the scroll view takes over any drag that goes up or
                // down, and the top and bottom edges could not be moved.
                preventStealing: true
                property string over: ""
                cursorShape: {
                    const h = stage.held.length ? stage.held : over
                    if (h === "l" || h === "r") return Qt.SizeHorCursor
                    if (h === "t" || h === "b") return Qt.SizeVerCursor
                    if (h === "tl" || h === "br") return Qt.SizeFDiagCursor
                    if (h === "tr" || h === "bl") return Qt.SizeBDiagCursor
                    return h === "move" ? Qt.SizeAllCursor : Qt.ArrowCursor
                }
                onPositionChanged: mouse => {
                    const px = mouse.x - 10, py = mouse.y - 10
                    if (!stage.held.length) { over = Crop.hit(dlg.crop, px, py, stage.width, stage.height, 9); return }
                    const next = Crop.drag(stage.heldCrop, stage.held, (px - stage.heldX) / stage.width * 1000, (py - stage.heldY) / stage.height * 1000)
                    dlg.set({ l: next.l, t: next.t, r: next.r, b: next.b })
                }
                onPressed: mouse => {
                    const px = mouse.x - 10, py = mouse.y - 10
                    stage.held = Crop.hit(dlg.crop, px, py, stage.width, stage.height, 9)
                    stage.heldCrop = Crop.copy(dlg.crop)
                    stage.heldX = px; stage.heldY = py
                }
                onReleased: stage.held = ""
                onCanceled: stage.held = ""
                onDoubleClicked: dlg.set({ l: 0, t: 0, r: 0, b: 0 })
            }
        }
    }

    DialogNote {
        objectName: "pushfps-crop-note"
        visible: text.length > 0
        text: dlg.xess ? qsTr("XeSS 补帧自己呈现画面，裁剪和缩放对它不生效。换一种补帧方式后就会生效")
            : veyra.hasSource && !dlg.consolePicture ? qsTr("裁剪和缩放只用于主机画面：采集卡，或 PS5、Sunshine、Xbox 串流")
            : ""
    }

    DialogGroup {
        VRow {
            objectName: "pushfps-crop-sides-row"
            label: qsTr("裁掉的部分")
            hint: qsTr("左 / 上 / 右 / 下，占画面的百分比；每边最多 45%")
            hintBelow: true
            RowLayout {
                spacing: 4
                Repeater {
                    model: ["l", "t", "r", "b"]
                    delegate: DialogTextField {
                        required property string modelData
                        objectName: "pushfps-crop-" + modelData
                        implicitWidth: 62
                        text: dlg.percent(dlg.crop[modelData])
                        onEdited: text => {
                            const v = parseFloat(String(text).replace(",", "."))
                            const change = {}
                            change[modelData] = isFinite(v) ? v * 10 : 0
                            dlg.set(change)
                        }
                    }
                }
            }
        }
        VRow {
            objectName: "pushfps-crop-shape-row"
            label: qsTr("形状")
            hint: qsTr("从中间均匀裁成这个形状，例如把带黑边的 21:9 游戏画面裁成 21:9")
            hintBelow: true
            VSeg {
                objectName: "pushfps-crop-shape"
                options: dlg.shapeLabels.map((label, i) => ({ id: String(i), label: label }))
                current: String(Crop.shapeIndex(dlg.crop, dlg.frameAspect))
                onPicked: id => {
                    const s = Crop.shaped(dlg.crop, Crop.shapes[Number(id)], dlg.frameAspect)
                    dlg.set({ l: s.l, t: s.t, r: s.r, b: s.b })
                }
            }
        }
        VRow {
            objectName: "pushfps-crop-zoom-row"
            label: qsTr("屏幕上的大小")
            hint: qsTr("100% 是按「宽屏填充」的选择正好放进屏幕的大小")
            hintBelow: true
            RowLayout {
                spacing: 8
                VSlider {
                    objectName: "pushfps-crop-zoom"
                    valueFromModel: true      // the value stays bound: Reset and Centre must move the knob
                    implicitWidth: 220
                    from: 25; to: 400; stepSize: 1
                    value: dlg.crop.zoom
                    onMoved: value => dlg.set({ zoom: Math.round(value) })
                }
                Text {
                    objectName: "pushfps-crop-zoom-value"
                    text: dlg.crop.zoom + "%"
                    color: Theme.t1; font.family: Theme.fontMono; font.pixelSize: Theme.fsSmall
                    Layout.minimumWidth: 44
                }
            }
        }
        VRow {
            objectName: "pushfps-crop-position-row"
            label: qsTr("位置")
            hint: qsTr("横向和纵向移动画面；中间是屏幕正中")
            hintBelow: true
            RowLayout {
                spacing: 8
                VSlider {
                    objectName: "pushfps-crop-x"
                    valueFromModel: true      // the value stays bound: Reset and Centre must move the knob
                    implicitWidth: 130
                    from: -1000; to: 1000; stepSize: 5; center: true
                    value: dlg.crop.x
                    onMoved: value => dlg.set({ x: Math.round(value) })
                }
                VSlider {
                    objectName: "pushfps-crop-y"
                    valueFromModel: true      // the value stays bound: Reset and Centre must move the knob
                    implicitWidth: 130
                    from: -1000; to: 1000; stepSize: 5; center: true
                    value: dlg.crop.y
                    onMoved: value => dlg.set({ y: Math.round(value) })
                }
                VButton {
                    objectName: "pushfps-crop-centre"
                    ghost: true
                    text: qsTr("居中")
                    onClicked: dlg.set({ x: 0, y: 0 })
                }
            }
        }
        VRow {
            objectName: "pushfps-crop-outputs-row"
            label: qsTr("录制和直播也这样裁剪")
            hint: qsTr("关闭时，录制、即时回放和直播保留完整画面")
            hintBelow: true
            VSwitch {
                objectName: "pushfps-crop-outputs"
                checked: veyra.preferences.pushCropOutputs === true
                onToggled: checked => veyra.setPreference("pushCropOutputs", checked)
            }
        }
    }
}
