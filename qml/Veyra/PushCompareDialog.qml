// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Before/after comparison clip: choose the layout and the length, then record
// (pushStartCompareClip, engine/RecordingCompare.h). Split: one picture cut down
// the middle. Side by side: the whole picture twice, each at half size, with the
// FPS labels in the black bar above each. Vertical: a 9:16 clip for TikTok, Shorts
// and Reels, the console on top and PushFPS below, labels next to the divider. Reveal:
// the whole picture, first at the console's rate, then a line sweeps across and
// uncovers PushFPS, and back, every few seconds (the preview plays it). Every
// layout labels each side with its frame rate. Dialog key "compare"; opened from the
// quick setup's comparison tile. Preferences pushCompareLayout (0 split, 1 side by
// side, 2 vertical, 3 reveal), pushCompareSeconds (10 to 120), pushCompareUntilStop (no
// timer: the clip runs until it is stopped; the same for every layout), and for the
// layouts that fill the frame (split, reveal) pushCompareQuality (0 automatic, 1080,
// 1440, 2160); Reveal also has pushCompareRevealSeconds (a sweep every 1 to 8 seconds).
// PushCompareClip.js reads them all.
import QtQuick
import QtQuick.Layouts
import "PushCompareClip.js" as Clip

DialogLayer {
    id: cmp
    objectName: "pushfps-compare"
    key: "compare"
    glyph: "split"
    title: qsTr("对比片段")
    sub: cmp.videoSource ? qsTr("录制一段前后对比视频：一边是视频原本的帧率，一边是 PushFPS")
                         : qsTr("录制一段前后对比视频：一边是主机原本的帧率，一边是 PushFPS")
    dialogWidth: 560

    readonly property var lengths: Clip.lengths
    readonly property bool untilStop: Clip.untilStop(veyra.preferences)
    readonly property int layoutId: Clip.layout(veyra.preferences)
    readonly property int seconds: Clip.seconds(veyra.preferences)
    // Split and Reveal: the height the clip is recorded at (0 automatic). Reveal: a sweep every so many seconds.
    readonly property bool takesQuality: Clip.takesQuality(cmp.layoutId)
    readonly property int quality: Clip.quality(veyra.preferences)
    // Every layout: the picture quality (0 standard, 1 high, 2 near lossless).
    readonly property int picture: Clip.picture(veyra.preferences)
    readonly property bool reveal: cmp.layoutId === 3
    readonly property int revealEvery: Clip.revealEvery(veyra.preferences)
    // The preview's clock, in seconds of a clip: runs while the Reveal preview is on screen. It
    // wraps after 240 s, a whole number of sweeps there and back for every interval offered
    // (2, 4, 6, 10 and 16 s), so the preview never jumps, also when the interval is changed.
    property real revealClock: 0
    readonly property real revealShare: Clip.revealPosition(cmp.revealClock, cmp.revealEvery)
    NumberAnimation on revealClock {
        running: cmp.shown && cmp.reveal
        from: 0; to: 240
        duration: 240000
        loops: Animation.Infinite
    }
    // For the preview only: the recording measures the real rates when it starts.
    readonly property int gameFps: {
        const n = Number(veyra.preferences.pushGameFps || 30)
        return n === 40 || n === 60 ? n : 30
    }
    readonly property int shownFps: cmp.gameFps * Math.max(2, Number(veyra.fgMultiplier || 2))
    // Video playback mode labels the left side "Original" instead of "Console" (as the recording does).
    readonly property bool videoSource: veyra.hasSource ? ["file", "url", "screen", "frameinput"].indexOf(String(veyra.sourceKind)) >= 0
                                                        : veyra.currentPage === "watch"
    // The original's side is called what the clip will call it: the chosen console's name where that is
    // known (the bridge's pushCompareSourceName, engine/PushCompareName.h), "Original" for a video.
    readonly property string leftName: {
        veyra.preferences.pushConsole; veyra.sourceKind; veyra.hasSource   // asked again when any of them changes
        if (!veyra.hasSource && cmp.videoSource) return qsTr("原画")
        return typeof veyra.pushCompareSourceName === "function" ? String(veyra.pushCompareSourceName())
                                                                 : cmp.videoSource ? qsTr("原画") : qsTr("主机原画")
    }
    readonly property string leftTag: cmp.leftName + " · " + cmp.gameFps + " FPS"
    readonly property string rightTag: "PushFPS · " + cmp.shownFps + " FPS"

    // The preview drawn: portrait for the vertical layout, landscape for the others.
    readonly property bool verticalPreview: cmp.layoutId === 2
    function layoutName(id) { return id === 3 ? qsTr("滑动揭示") : id === 2 ? qsTr("竖屏") : id === 1 ? qsTr("并排") : qsTr("分屏") }
    function layoutHint(id) {
        return id === 3 ? qsTr("整个画面：先是原帧率，一条线从左扫到右露出 PushFPS，停一会儿再扫回去，如此反复")
             : id === 2 ? qsTr("竖屏 9:16，适合 TikTok、Shorts 和 Reels：上面是原帧率，下面是 PushFPS，各占半屏（取画面中间部分）")
             : id === 1 ? qsTr("完整画面并排两份：左边是原帧率，右边是 PushFPS")
             : qsTr("同一个画面从中间分开：左半边是原帧率，右半边是 PushFPS")
    }
    function qualityLabel(height) { return height > 0 ? Clip.qualityName(height) : qsTr("自动") }
    function qualityHint(height) {
        return height === 2160 ? qsTr("最高按 4K 录制，每一帧都录：需要较强的显卡。若有帧没录下，录完会提示，请选低一档")
             : height > 0 ? qsTr("最高按所选的高度录制（画面本身更小时保持原样，不放大），并用更高的码率")
             : qsTr("按画面原本的大小录制，最高 1440p")
    }
    function pictureLabel(level) { return level === 2 ? qsTr("近无损") : level === 1 ? qsTr("高") : qsTr("标准") }
    function pictureHint(level) {
        return level === 2 ? qsTr("几乎看不出和原画的差别。文件很大（4K 每分钟可达数 GB），建议录到固态硬盘")
             : level === 1 ? qsTr("固定画质编码：细节清楚、画面干净，文件大小随画面内容变化")
             : qsTr("标准码率：文件较小，适合直接分享")
    }
    // Reveal preview: where the line is (x in the preview), as the clip moves it.
    function revealX(share, previewWidth) { return Math.max(0, Math.min(1, share)) * previewWidth }
    // Vertical preview (portrait, 108 x 192): where each label goes, centred just above (index 0)
    // and just below (index 1) the divider in the middle, as the clip puts them.
    function verticalTagY(index, tagHeight, previewHeight) {
        return index === 0 ? previewHeight / 2 - 4 - tagHeight : previewHeight / 2 + 4
    }
    // Where the preview puts each label (index 0 left, 1 right), as the clip does: split at
    // the top corners of the picture, side by side centred in the black bar above each picture.
    function tagX(index, tagWidth, previewWidth, sideBySide) {
        if (sideBySide) return (index === 0 ? 0 : previewWidth / 2) + (previewWidth / 2 - tagWidth) / 2
        return index === 0 ? 6 : previewWidth - tagWidth - 6
    }
    function tagY(tagHeight, previewHeight, sideBySide) {
        return sideBySide ? (previewHeight / 4 - tagHeight) / 2 : 6
    }

    // The layout drawn small, with the labels where the clip puts them.
    Rectangle {
        id: preview
        objectName: "pushfps-compare-preview"
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 12
        implicitWidth: 320
        implicitHeight: 180
        radius: 6
        color: "#000000"
        border.width: 1
        border.color: Theme.stroke
        clip: true
        visible: !cmp.verticalPreview
        readonly property bool sideBySide: cmp.layoutId === 1
        readonly property bool reveal: cmp.reveal
        readonly property real picW: sideBySide ? width / 2 : width / 2
        readonly property real picH: sideBySide ? height / 2 : height
        readonly property real picTop: sideBySide ? height / 4 : 0
        Repeater {
            model: preview.reveal ? 0 : 2
            delegate: Item {
                required property int index
                x: index === 0 ? 0 : preview.width / 2
                y: preview.picTop
                width: preview.picW
                height: preview.picH
                // A stand-in picture: a sky and a road, dimmer on the console side.
                Rectangle {
                    // Split: both halves are parts of one picture; side by side: each is the whole picture.
                    x: preview.sideBySide ? 0 : -index * preview.picW
                    width: preview.sideBySide ? parent.width : preview.width
                    height: parent.height
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#3d6fa8" }
                        GradientStop { position: 0.55; color: "#9cc3e6" }
                        GradientStop { position: 0.56; color: "#4b5a3a" }
                        GradientStop { position: 1.0; color: "#2c3324" }
                    }
                }
                clip: true
            }
        }
        Rectangle {
            visible: !preview.reveal
            x: preview.width / 2 - 1
            y: preview.picTop
            width: 2
            height: preview.picH
            color: "#ffffff"
        }
        // Reveal: the whole picture; right of the line the original (drawn dimmer here), left of it
        // PushFPS. The line moves as the clip moves it, and each label is cut off at the line.
        Item {
            id: revealPreview
            objectName: "pushfps-compare-preview-reveal"
            anchors.fill: parent
            visible: preview.reveal
            readonly property real lineX: cmp.revealX(cmp.revealShare, width)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3d6fa8" }
                    GradientStop { position: 0.55; color: "#9cc3e6" }
                    GradientStop { position: 0.56; color: "#4b5a3a" }
                    GradientStop { position: 1.0; color: "#2c3324" }
                }
            }
            Rectangle {
                x: revealPreview.lineX
                width: Math.max(0, revealPreview.width - x)
                height: parent.height
                color: "#47000000"
            }
            // PushFPS's label at the top left, shown as far as the line; the original's at the top right, from the line on.
            Item {
                x: 0; width: revealPreview.lineX; height: parent.height
                clip: true
                Rectangle {
                    objectName: "pushfps-compare-reveal-tag-push"
                    x: 6; y: 6
                    width: revealPushText.implicitWidth + 16
                    height: revealPushText.implicitHeight + 6
                    radius: height / 2
                    border.width: 1
                    border.color: "#8df237"
                    color: "#d60e0f12"
                    Text { id: revealPushText; anchors.centerIn: parent; text: cmp.rightTag; color: "#ffffff"; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.Bold }
                }
            }
            Item {
                x: revealPreview.lineX; width: Math.max(0, revealPreview.width - x); height: parent.height
                clip: true
                Rectangle {
                    objectName: "pushfps-compare-reveal-tag-original"
                    x: revealPreview.width - width - 6 - revealPreview.lineX; y: 6
                    width: revealOriginalText.implicitWidth + 16
                    height: revealOriginalText.implicitHeight + 6
                    radius: height / 2
                    border.width: 1
                    border.color: "#4dffffff"
                    color: "#d60e0f12"
                    Text { id: revealOriginalText; anchors.centerIn: parent; text: cmp.leftTag; color: "#ffffff"; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.Bold }
                }
            }
            // The line: a white core in a green glow, with a round handle, as in the clip.
            Item {
                objectName: "pushfps-compare-reveal-line"
                x: revealPreview.lineX - width / 2
                width: 14; height: parent.height
                visible: cmp.revealShare > 0.001 && cmp.revealShare < 0.999
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 8; height: parent.height; color: "#408df237" }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: parent.height; color: "#808df237" }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height; color: "#ffffff" }
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 14; radius: 7
                    color: "#101216"
                    border.width: 2
                    border.color: "#8df237"
                }
            }
        }
        Repeater {
            model: preview.reveal ? 0 : 2
            delegate: Rectangle {
                required property int index
                objectName: index === 0 ? "pushfps-compare-tag-left" : "pushfps-compare-tag-right"
                // The clip's badges in small: dark pills, the PushFPS one outlined in logo green.
                width: tagText.implicitWidth + 16
                height: tagText.implicitHeight + 6
                radius: height / 2
                border.width: 1
                border.color: index === 1 ? "#8df237" : "#4dffffff"
                // Split: top corners of the picture. Side by side: centred in the bar above each picture.
                x: cmp.tagX(index, width, preview.width, preview.sideBySide)
                y: cmp.tagY(height, preview.height, preview.sideBySide)
                color: "#d60e0f12"
                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: index === 0 ? cmp.leftTag : cmp.rightTag
                    color: "#ffffff"
                    font.family: Theme.fontUi
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Vertical: a portrait stand-in, the console picture on top and PushFPS below.
    Rectangle {
        id: portrait
        objectName: "pushfps-compare-preview-vertical"
        visible: cmp.verticalPreview
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 12
        implicitWidth: 108
        implicitHeight: 192
        radius: 6
        color: "#000000"
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                y: index * portrait.height / 2
                width: portrait.width
                height: portrait.height / 2
                opacity: index === 0 ? 0.8 : 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3d6fa8" }
                    GradientStop { position: 0.55; color: "#9cc3e6" }
                    GradientStop { position: 0.56; color: "#4b5a3a" }
                    GradientStop { position: 1.0; color: "#2c3324" }
                }
            }
        }
        Rectangle { y: portrait.height / 2 - 1; width: portrait.width; height: 2; color: "#ffffff" }
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                objectName: index === 0 ? "pushfps-compare-vtag-top" : "pushfps-compare-vtag-bottom"
                width: Math.min(portrait.width - 8, vtagText.implicitWidth + 10)
                height: vtagText.implicitHeight + 4
                radius: height / 2
                border.width: 1
                border.color: index === 1 ? "#8df237" : "#4dffffff"
                x: (portrait.width - width) / 2
                y: cmp.verticalTagY(index, height, portrait.height)
                color: "#d60e0f12"
                Text {
                    id: vtagText
                    anchors.centerIn: parent
                    text: index === 0 ? cmp.leftTag : cmp.rightTag
                    color: "#ffffff"
                    font.family: Theme.fontUi
                    font.pixelSize: 7
                    font.weight: Font.Bold
                }
            }
        }
    }

    DialogGroup {
        VRow {
            label: qsTr("布局")
            hint: cmp.layoutHint(cmp.layoutId)
            hintBelow: true
            VSeg {
                objectName: "pushfps-compare-layout"
                options: Clip.layouts.map(n => ({ id: String(n), label: cmp.layoutName(n) }))
                current: String(cmp.layoutId)
                onPicked: id => veyra.setPreference("pushCompareLayout", Number(id))
            }
        }
        // Reveal: how often the line sweeps.
        VRow {
            objectName: "pushfps-compare-reveal-row"
            visible: cmp.reveal
            label: qsTr("扫过间隔")
            hint: qsTr("线条每隔这么久扫过一次，在原帧率和 PushFPS 之间切换")
            hintBelow: true
            VSeg {
                objectName: "pushfps-compare-reveal"
                options: Clip.revealIntervals.map(n => ({ id: String(n), label: qsTr("%1 秒").arg(n) }))
                current: String(cmp.revealEvery)
                onPicked: id => veyra.setPreference("pushCompareRevealSeconds", Number(id))
            }
        }
        // Split and Reveal fill the frame: the height the clip is recorded at.
        VRow {
            objectName: "pushfps-compare-quality-row"
            visible: cmp.takesQuality
            label: qsTr("片段尺寸")
            hint: cmp.qualityHint(cmp.quality)
            hintBelow: true
            VSeg {
                objectName: "pushfps-compare-quality"
                options: Clip.qualities.map(n => ({ id: String(n), label: cmp.qualityLabel(n) }))
                current: String(cmp.quality)
                onPicked: id => veyra.setPreference("pushCompareQuality", Number(id))
            }
        }
        // Every layout: how finely the clip is encoded.
        VRow {
            objectName: "pushfps-compare-picture-row"
            label: qsTr("画质")
            hint: cmp.pictureHint(cmp.picture)
            hintBelow: true
            VSeg {
                objectName: "pushfps-compare-picture"
                options: Clip.pictures.map(n => ({ id: String(n), label: cmp.pictureLabel(n) }))
                current: String(cmp.picture)
                onPicked: id => veyra.setPreference("pushComparePicture", Number(id))
            }
        }
        VRow {
            label: qsTr("时长")
            VSeg {
                objectName: "pushfps-compare-length"
                options: cmp.lengths.map(n => ({ id: String(n), label: qsTr("%1 秒").arg(n) }))
                current: String(cmp.seconds)
                // Kept while "until I stop" is on (it is the length again when that is switched off).
                enabled: !cmp.untilStop
                opacity: cmp.untilStop ? 0.4 : 1
                onPicked: id => veyra.setPreference("pushCompareSeconds", Number(id))
            }
        }
        VRow {
            label: qsTr("录到我停止为止")
            hint: qsTr("不设时长：再点一次“对比片段”或按录制快捷键停止")
            hintBelow: true
            VSwitch {
                objectName: "pushfps-compare-until-stop"
                checked: cmp.untilStop
                onToggled: v => veyra.setPreference("pushCompareUntilStop", v)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: !veyra.hasSource ? qsTr("需要正在播放的画面")
            : cmp.layoutId === 3 ? qsTr("画面上方标着当前显示的是哪一边和它的帧率。视频保存在录制文件夹里，可直接导入剪辑软件")
            : cmp.layoutId === 2 ? qsTr("两半都标有各自的帧率。保存为 1080×1920 视频，可直接上传到手机应用")
            : qsTr("两边上方都标有各自的帧率。视频保存在录制文件夹里，可直接导入剪辑软件")
        color: veyra.hasSource ? Theme.t3 : Theme.warn
        font.family: Theme.fontUi
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    actions: [{ label: qsTr("取消") }, { label: qsTr("开始录制"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("开始录制")) {
            if (veyra.pushStartCompareClip(Clip.startSeconds(veyra.preferences), cmp.layoutId)) cmp.dialogHost.close()
        } else cmp.dialogHost.close()
    }
}
