// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Before a normal recording starts (PushFPS 4.0): the shape (wide as the picture is, or tall 9:16),
// for a tall one whether the picture fills it or fits into it, the size, and the picture quality;
// then "Start recording". Dialog key "record"; the record buttons of Professional mode, Streaming
// mode and Video playback open it unless "Ask before every recording" was switched off (preference
// pushRecordAsk), and the recording shortcut never does: a key pressed in a game starts at once,
// with what was chosen here last.
//
// It has no settings of its own. Every choice is one of the recording preferences that
// Settings -> Recording shows too (PushRecord.js says which), and it says what a recording started
// now will be: its size, frames a second, codec and rate. That line is also how a low rate left
// behind by a platform profile is seen before it is recorded with.
import QtQuick
import QtQuick.Layouts
import "PushRecord.js" as Record

DialogLayer {
    id: rec
    objectName: "pushfps-record"
    key: "record"
    glyph: "video"
    title: qsTr("录制")
    sub: qsTr("选择录成什么样，然后开始")
    dialogWidth: 560

    readonly property string shapeId: Record.shape(veyra.preferences)
    readonly property bool tall: rec.shapeId === "tall"
    readonly property bool fills: Record.fills(veyra.preferences)
    readonly property int sizeId: Record.size(veyra.preferences)
    readonly property string qualityId: Record.quality(veyra.preferences)
    readonly property bool asks: Record.asks(veyra.preferences)
    // The vertical copy (4.1): a second file, 1080 x 1920, recorded beside a wide recording.
    readonly property bool copy: veyra.preferences.pushRecordVerticalCopy === true
    readonly property bool copyFills: veyra.preferences.pushRecordVerticalFit === undefined || Number(veyra.preferences.pushRecordVerticalFit) !== 0
    // What is playing, read when the dialog opens: the recording measures it again when it starts.
    readonly property var stats: rec.shown ? (veyra.pushLiveStats() || {}) : ({})
    readonly property var picture: ({ width: Number(rec.stats.outputWidth || 0), height: Number(rec.stats.outputHeight || 0),
                                      fps: Math.round(Number(rec.stats.realFps || 0) + Number(rec.stats.generatedFps || 0)),
                                      hdr: rec.stats.hdr === true })
    readonly property var plan: Record.plan(veyra.preferences, rec.picture)
    // The chosen size asks for more than the picture has: it would be enlarged, which adds nothing.
    readonly property bool enlarges: {
        const pw = rec.picture.width, ph = rec.picture.height
        if (pw <= 0 || ph <= 0 || rec.plan.width <= 0) return false
        if (rec.tall) return rec.fills ? rec.plan.height > ph : rec.plan.width > pw
        return rec.plan.height > ph || rec.plan.width > pw
    }

    function setAll(values) { for (const k in values) veyra.setPreference(k, values[k]) }
    function pickShape(id) {
        // Wide goes back to the picture's own size; tall starts at 1080 x 1920, filled, as the phone apps show it.
        if (id === "tall") rec.setAll(Record.shapePrefs("tall", rec.tall && rec.sizeId > 0 ? rec.sizeId : 1080, rec.tall ? rec.fills : true))
        else rec.setAll(Record.shapePrefs("wide", !rec.tall && rec.sizeId > 0 ? rec.sizeId : 0, false))
    }
    function pickSize(id) { rec.setAll(Record.shapePrefs(rec.shapeId, Number(id), rec.fills)) }
    function pickFill(fill) { rec.setAll(Record.shapePrefs("tall", rec.sizeId > 0 ? rec.sizeId : 1080, fill)) }
    function pickQuality(id) { rec.setAll(Record.qualityPrefs(id, veyra.preferences)) }
    function sizeLabel(n) { return n === 0 ? qsTr("与画面相同") : Record.sizeName(n) }
    function qualityLabel(id) { return id === "best" ? qsTr("最佳") : id === "small" ? qsTr("小文件") : qsTr("高") }
    function qualityHint(id) {
        return id === "best" ? qsTr("恒定画质：画面再复杂也不会糊，文件最大")
             : id === "small" ? qsTr("标准码率的一半：文件小一半，快速运动时画面会软一些")
             : id === "custom" ? qsTr("正在使用设置里选的码率或平台预设（%1 Mbps）。在这里选一项就会改用它").arg(rec.plan.mbps)
             : qsTr("标准码率：快速运动也保持清晰，适合保存和剪辑")
    }
    readonly property string summary: {
        const p = rec.plan
        if (p.width <= 0 || p.height <= 0) return qsTr("开始录制时按画面的大小和帧率录")
        // Numbers and names only: the same in every language.
        const what = p.width + " × " + p.height + " · " + p.fps + " FPS · " + (p.hevc ? "HEVC" : "H.264")
        if (p.quality === "best" || p.mbps <= 0) return qsTr("将录制：%1，恒定画质").arg(what)
        const mb = Record.megabytesPerMinute(p.mbps)
        return qsTr("将录制：%1，约 %2 Mbps（每分钟约 %3）").arg(what).arg(Math.round(p.mbps))
                   .arg(mb >= 1000 ? (mb / 1000).toFixed(1) + " GB" : mb + " MB")
    }

    // The shape drawn small: the frame that is recorded, and the game picture inside it.
    Rectangle {
        id: preview
        objectName: "pushfps-record-preview"
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 12
        implicitWidth: rec.tall ? 108 : 288
        implicitHeight: rec.tall ? 192 : 162
        radius: 6
        color: "#000000"
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Rectangle {
            objectName: "pushfps-record-preview-picture"
            // Fit: the whole 16:9 picture, as wide as the frame. Fill: as high as the frame, its sides cut.
            width: rec.tall && rec.fills ? preview.height * 16 / 9 : preview.width
            height: rec.tall && !rec.fills ? preview.width * 9 / 16 : preview.height
            anchors.centerIn: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3d6fa8" }
                GradientStop { position: 0.55; color: "#9cc3e6" }
                GradientStop { position: 0.56; color: "#4b5a3a" }
                GradientStop { position: 1.0; color: "#2c3324" }
            }
        }
    }

    DialogGroup {
        VRow {
            label: qsTr("形状")
            hint: rec.tall ? qsTr("竖屏 9:16，适合 TikTok、Shorts 和 Reels") : qsTr("横屏：和画面一样的形状")
            hintBelow: true
            VSeg {
                objectName: "pushfps-record-shape"
                options: [{ id: "wide", label: qsTr("横屏") }, { id: "tall", label: qsTr("竖屏") }]
                current: rec.shapeId
                onPicked: id => rec.pickShape(String(id))
            }
        }
        VRow {
            objectName: "pushfps-record-fill-row"
            visible: rec.tall
            label: qsTr("竖屏里的画面")
            hint: rec.fills ? qsTr("填满：画面占满整个竖屏，左右两边被裁掉") : qsTr("完整显示：整个画面都在，上下留黑边")
            hintBelow: true
            VSeg {
                objectName: "pushfps-record-fill"
                options: [{ id: "fill", label: qsTr("填满") }, { id: "fit", label: qsTr("完整显示") }]
                current: rec.fills ? "fill" : "fit"
                onPicked: id => rec.pickFill(String(id) === "fill")
            }
        }
        VRow {
            objectName: "pushfps-record-size-row"
            label: qsTr("大小")
            hint: rec.sizeId < 0 ? qsTr("设置里选了另一种大小（%1 × %2）。在这里选一项就会改用它").arg(rec.plan.width).arg(rec.plan.height)
                : rec.enlarges ? qsTr("比画面本身大：会被放大，不会更清晰")
                : rec.sizeId === 0 ? qsTr("按画面原本的大小录，不缩放") : qsTr("画面缩放到这个大小再录")
            hintBelow: true
            VSeg {
                objectName: "pushfps-record-size"
                options: (rec.tall ? Record.tallSizes : Record.sizes).map(n => ({ id: String(n), label: rec.sizeLabel(n) }))
                current: String(rec.sizeId)
                onPicked: id => rec.pickSize(Number(id))
            }
        }
        VRow {
            objectName: "pushfps-record-quality-row"
            label: qsTr("画质")
            hint: rec.qualityHint(rec.qualityId)
            hintBelow: true
            VSeg {
                objectName: "pushfps-record-quality"
                options: Record.qualities.map(id => ({ id: id, label: rec.qualityLabel(id) }))
                current: rec.qualityId
                onPicked: id => rec.pickQuality(String(id))
            }
        }
        VRow {
            objectName: "pushfps-record-vertical-row"
            visible: !rec.tall
            label: qsTr("同时录一份竖屏副本")
            help: qsTr("一次录制得到两个文件：横屏的照常录，另有一份 1080 × 1920 的竖屏副本（文件名以 -vertical 结尾），适合 TikTok、Shorts 和 Reels。两个编码同时进行，更吃显卡；竖屏副本最高 60 FPS。")
            hint: !rec.copy ? qsTr("关闭：只录一个文件")
                : rec.copyFills ? qsTr("副本里画面填满竖屏，左右两边被裁掉") : qsTr("副本里整个画面都在，上下留黑边")
            hintBelow: true
            RowLayout {
                spacing: 8
                VSeg {
                    objectName: "pushfps-record-vertical-fit"
                    visible: rec.copy
                    options: [{ id: "fill", label: qsTr("填满") }, { id: "fit", label: qsTr("完整显示") }]
                    current: rec.copyFills ? "fill" : "fit"
                    onPicked: id => veyra.setPreference("pushRecordVerticalFit", String(id) === "fill" ? 1 : 0)
                }
                VSwitch {
                    objectName: "pushfps-record-vertical"
                    checked: rec.copy
                    onToggled: v => veyra.setPreference("pushRecordVerticalCopy", v)
                }
            }
        }
        VRow {
            label: qsTr("每次录制前都询问")
            hint: qsTr("关闭后，点录制按钮会直接开始，用的是这里最后选的。录制快捷键总是直接开始")
            hintBelow: true
            VSwitch {
                objectName: "pushfps-record-ask"
                checked: rec.asks
                onToggled: v => veyra.setPreference("pushRecordAsk", v)
            }
        }
    }

    Text {
        objectName: "pushfps-record-summary"
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: !veyra.hasSource ? qsTr("需要正在播放的画面")
            : rec.summary + (rec.copy && !rec.tall ? "\n" + qsTr("另存一份竖屏副本：1080 × 1920，最高 60 FPS") : "")
        color: veyra.hasSource ? Theme.t2 : Theme.warn
        font.family: Theme.fontUi
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    actions: [{ label: qsTr("取消") }, { label: qsTr("开始录制"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("开始录制")) {
            if (!veyra.hasSource || veyra.recording) return
            rec.dialogHost.close()
            veyra.startRecording("record-dialog")
        } else rec.dialogHost.close()
    }
}
