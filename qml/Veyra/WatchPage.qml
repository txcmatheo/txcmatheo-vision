// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS video playback mode (page "watch"; dock button 视频播放模式): PushFPS's tools on any video
// on the PC. Pick a window (a browser playing YouTube, a video app), a whole screen or a video file,
// then switch on smoother motion (frame generation), a sharper picture (super resolution), AI picture
// enhancement and HDR from SDR video. Every switch is an existing engine setting (the same ones as
// Professional mode); the window and screen capture are Veyra's (ScreenSourceDialog, WGC/DXGI).
// The picture shows on the right through Main.qml's native video window (videoViewport).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "EffectSupport.js" as Support
import "PushCompareClip.js" as CompareClip
import "PushRecord.js" as Record
import "PushUpscale.js" as Upscale

VPage {
    id: watch
    signal requestPage(string page)
    // Opens Settings at a row (Main.qml: section, then scrolls to the objectName).
    signal requestSettings(string section, string row)
    readonly property bool compact: width < 980
    readonly property int margin: 12
    readonly property int bodyTop: 56
    readonly property int panelWidth: compact ? Math.max(300, width - 2 * margin) : 400
    // Narrow windows: the controls only; the picture is a fullscreen away (F11).
    readonly property rect videoViewport: compact ? Qt.rect(0, 0, 0, 0)
        : Qt.rect(margin + panelWidth + 10 + 1, bodyTop + 36, Math.max(1, width - 2 * margin - panelWidth - 10 - 2), Math.max(1, height - bodyTop - margin - 36 - 1))

    // What to play: 0 a window, 1 a whole screen, 2 a video file.
    property int kind: Number(veyra.screenOptions.kind || 0) === 1 ? 1 : 0
    readonly property var o: veyra.screenOptions
    readonly property bool fgOk: Support.available(veyra, "frame-generation")
    // (PushFPS 4.2.1: or any upscaler this card can run; "sr" alone answers for the one chosen now, and the
    // switch takes one the card can run when it is switched on.)
    readonly property bool srOk: Support.available(veyra, "sr") || Upscale.offered(veyra.srBackendChoices).length > 0
    readonly property bool nrOk: Support.available(veyra, "nr")
    readonly property bool hdrOk: Support.available(veyra, "video-hdr")
    readonly property var multipliers: (veyra.fgMultiplierChoices || []).map(c => parseInt(c.id)).filter(m => m >= 2 && m <= 4)

    function pick(k) {
        watch.kind = k
        if (k < 2) veyra.setScreenOption("kind", k)
    }
    // Videos repeat frames inside the capture's refresh (a 30 FPS video in a 60 Hz window): without
    // duplicate removal frame generation would interpolate between identical pictures and nothing
    // would look smoother, in the picture or in comparison clips. Auto finds the real frames.
    function ensureVideoCadence() {
        if (veyra.fgEnabled === true && Number(veyra.contentRate) === 0) {
            veyra.contentRate = 1
            veyra.logUi("push-watch", "duplicate removal set to auto for video")
        }
    }
    function start() {
        watch.ensureVideoCadence()
        if (watch.kind === 2) { veyra.openFileDialog(); return }
        if (watch.kind === 3) { veyra.navigate("frameinput"); return }   // PushFPS Frame Input API
        // A plain copy of the picture: no game mode, the whole window, fitted.
        if (watch.o.passthrough === true) veyra.setScreenOption("passthrough", false)
        if (veyra.startScreenCapture()) veyra.logUi("push-watch", "video playback started kind=" + watch.kind)
    }
    function setSmooth(on) {
        if (on) {
            const m = watch.multipliers.length ? watch.multipliers.reduce((a, b) => Math.min(a, b)) : 2
            if (Number(veyra.fgMultiplier) < 2) veyra.fgMultiplier = m
            veyra.fgEnabled = true
            // Videos repeat frames inside the screen's refresh: duplicate removal finds the real ones.
            watch.ensureVideoCadence()
        } else veyra.fgEnabled = false
    }
    function setEnhancement(on) {
        if (on) {
            if ((veyra.nrLayers || []).length === 0) veyra.addEffect("nr")
            else veyra.setAllNrEnabled(true)
        } else if ((veyra.nrLayers || []).length > 0) veyra.setAllNrEnabled(false)
    }
    onCurrentChanged: if (current) { veyra.refreshCaptureTargets(); watch.ensureVideoCadence() }

    // Recording, as in Professional mode: the same recorder, instant replay and comparison clips
    // (dialog "compare", same layouts and lengths); the options are the shared recording settings.
    readonly property bool compareRecording: veyra.recording && veyra.recordingState.compare === true
    readonly property bool recordSaving: !veyra.recording && !!(veyra.recordingState && veyra.recordingState.finishing)
    readonly property string recordElapsed: {
        const total = Math.max(0, Math.floor((veyra.recordingState && veyra.recordingState.seconds) || 0))
        const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, sec = total % 60
        const two = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + two(m) + ":" + two(sec) : two(m) + ":" + two(sec)
    }
    readonly property int replayHeld: Math.max(0, (veyra.replayState && veyra.replayState.seconds) || 0)
    readonly property int clipSeconds: CompareClip.seconds(veyra.preferences)
    readonly property bool clipUntilStop: CompareClip.untilStop(veyra.preferences)
    readonly property string clipLayout: {
        const n = CompareClip.layout(veyra.preferences)
        return n === 3 ? qsTr("滑动揭示") : n === 2 ? qsTr("竖屏") : n === 1 ? qsTr("并排") : qsTr("分屏")
    }

    RowLayout {
        x: watch.margin; y: 12; width: parent.width - 2 * watch.margin; height: 32
        spacing: 12
        VH2 { text: qsTr("视频播放模式") }
        Text {
            visible: !watch.compact
            text: qsTr("让电脑上的任何视频更流畅、更清晰：浏览器里的 YouTube、视频软件或本地文件")
            color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 12
        }
        Item { Layout.fillWidth: true }
    }

    Rectangle {
        objectName: "watch-panel"
        x: watch.margin; y: watch.bodyTop
        width: watch.panelWidth; height: watch.height - watch.bodyTop - watch.margin
        radius: Theme.rCard; color: Theme.card; border.color: Theme.stroke
        clip: true
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: VScrollBar {}
            ColumnLayout {
                id: column
                // (The new design: room for the scroll bar, so it never lies over a control's edge. Constant,
                // not "when the list scrolls": a width that follows the height is a layout loop.)
                width: scroll.width - (Theme.modern ? 8 : 0)
                spacing: 10

                Text {
                    text: qsTr("1. 选择要播放的内容")
                    color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 14
                    font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                }
                VSeg {
                    objectName: "watch-kind"
                    Layout.fillWidth: true
                    options: [{ id: "0", label: qsTr("窗口") }, { id: "1", label: qsTr("整个屏幕") }, { id: "2", label: qsTr("视频文件") }, { id: "3", label: qsTr("其他应用") }]
                    current: String(watch.kind)
                    onPicked: id => watch.pick(Number(id))
                }
                RowLayout {
                    visible: watch.kind < 2
                    Layout.fillWidth: true
                    spacing: 6
                    VSelect {
                        objectName: "watch-target"
                        Layout.fillWidth: true
                        value: veyra.screenTargetLabel
                        options: veyra.screenTargets
                        onPicked: id => veyra.screenTargetId = id
                    }
                    VButton { text: qsTr("刷新"); ghost: true; onClicked: veyra.refreshCaptureTargets() }
                }
                Text {
                    Layout.fillWidth: true
                    text: watch.kind === 0 ? qsTr("YouTube 或网页视频：先在浏览器里播放，再在这里选浏览器窗口。浏览器窗口变黑时，请在浏览器设置里关闭硬件加速（受版权保护的视频可能仍然是黑的）")
                        : watch.kind === 1 ? qsTr("整块显示器的画面，适合全屏播放的视频。PushFPS 请放在另一块屏幕上")
                        : watch.kind === 3 ? qsTr("支持 PushFPS 画面输入接口的应用直接把画面送进来，不用捕获窗口")
                        : qsTr("打开电脑上的视频文件，补帧和画面增强同样生效")
                    color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    VButton {
                        objectName: "watch-start"
                        Layout.fillWidth: true
                        primary: true
                        iconName: watch.kind === 2 ? "folder" : watch.kind === 3 ? "import" : "play"
                        text: watch.kind === 2 ? qsTr("打开视频文件") : watch.kind === 3 ? qsTr("选择应用") : qsTr("开始播放")
                        enabled: watch.kind >= 2 || veyra.screenTargets.length > 0
                        onClicked: watch.start()
                    }
                    VButton {
                        objectName: "watch-stop"
                        visible: veyra.hasSource
                        ghost: true
                        text: qsTr("停止")
                        onClicked: veyra.stopPlayback()
                    }
                }

                Text {
                    Layout.topMargin: 8
                    text: qsTr("2. 让画面更好")
                    color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 14
                    font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                }
                VGroup {
                    VRow {
                        objectName: "watch-smooth-row"
                        label: qsTr("更流畅")
                        help: qsTr("补帧：在视频的帧之间生成新帧，24 或 30 FPS 的视频看起来像 60 或 120 FPS")
                        hint: !watch.fgOk ? Support.reason(veyra, "frame-generation") : veyra.fgEnabled ? qsTr("%1× 补帧").arg(veyra.fgMultiplier) : qsTr("补帧让动作更顺滑")
                        VSwitch {
                            objectName: "watch-smooth"
                            enabled: watch.fgOk
                            opacity: enabled ? 1 : 0.4
                            checked: veyra.fgEnabled === true
                            onToggled: checked => watch.setSmooth(checked)
                        }
                    }
                    VRow {
                        objectName: "watch-multiplier-row"
                        visible: veyra.fgEnabled === true && watch.multipliers.length > 1
                        label: qsTr("倍数")
                        VSeg {
                            objectName: "watch-multiplier"
                            options: watch.multipliers.map(m => ({ id: String(m), label: m + "×" }))
                            current: String(veyra.fgMultiplier)
                            onPicked: id => veyra.fgMultiplier = Number(id)
                        }
                    }
                    VRow {
                        objectName: "watch-sharp-row"
                        label: qsTr("更清晰")
                        help: qsTr("超分辨率：把低分辨率视频放大到屏幕分辨率，边缘和文字更锐利")
                        hint: !watch.srOk ? Support.reason(veyra, "sr") : qsTr("放大到屏幕分辨率")
                        VSwitch {
                            objectName: "watch-sharp"
                            enabled: watch.srOk
                            opacity: enabled ? 1 : 0.4
                            checked: veyra.srEnabled === true
                            // PushFPS 4.2.1: switched on with an upscaler this card can run (PushUpscale.js). With
                            // one it cannot run the engine switches the stage off again, so on a card without the
                            // NVIDIA upscalers this switch did nothing.
                            onToggled: checked => {
                                if (checked) {
                                    const now = typeof veyra.srAlgorithmOf === "function" ? String(veyra.srAlgorithmOf(veyra.videoSrQuality)) : ""
                                    const id = Upscale.method(veyra.srBackendChoices, now)
                                    if (id !== "" && id !== now) veyra.videoSrQuality = veyra.srQualityFor(id, veyra.srTierOf(veyra.videoSrQuality))
                                }
                                veyra.srEnabled = checked
                            }
                        }
                    }
                    VRow {
                        objectName: "watch-enhance-row"
                        label: qsTr("AI 画面增强")
                        help: qsTr("用 AI 去掉压缩造成的色块和噪点，适合网络视频。更耗 GPU")
                        hint: !watch.nrOk ? Support.reason(veyra, "nr") : qsTr("去掉网络视频的色块和噪点")
                        VSwitch {
                            objectName: "watch-enhance"
                            enabled: watch.nrOk
                            opacity: enabled ? 1 : 0.4
                            checked: veyra.nrAnyEnabled === true
                            onToggled: checked => watch.setEnhancement(checked)
                        }
                    }
                    VRow {
                        objectName: "watch-hdr-row"
                        label: qsTr("SDR 转 HDR")
                        help: qsTr("把普通视频转换成 HDR，在 HDR 显示器上更明亮、颜色更丰富。需要 Windows HDR 开启")
                        hint: !watch.hdrOk ? Support.reason(veyra, "video-hdr") : qsTr("需要 HDR 显示器并开启 Windows HDR")
                        VSwitch {
                            objectName: "watch-hdr"
                            enabled: watch.hdrOk
                            opacity: enabled ? 1 : 0.4
                            checked: veyra.videoHdr === true
                            onToggled: checked => veyra.videoHdr = checked
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: qsTr("按 F11 全屏观看。更多设置在专业模式里")
                    color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                VButton { objectName: "watch-pro"; Layout.fillWidth: true; ghost: true; iconName: "sliders"; text: qsTr("专业模式"); onClicked: watch.requestPage("pro") }

                Text {
                    Layout.topMargin: 8
                    text: qsTr("3. 录制")
                    color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 14
                    font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                }
                VGroup {
                    VRow {
                        objectName: "watch-record-row"
                        label: qsTr("录制")
                        hint: watch.compareRecording ? qsTr("正在录制对比片段…")
                            : veyra.recording ? qsTr("正在录制 %1").arg(watch.recordElapsed)
                            : watch.recordSaving ? qsTr("保存中…")
                            : !veyra.hasSource ? qsTr("需要正在播放的画面") : qsTr("录下处理后的画面和声音")
                        VButton {
                            objectName: "watch-record"
                            iconName: "video"
                            text: veyra.recording ? qsTr("停止 %1").arg(watch.recordElapsed) : watch.recordSaving ? qsTr("保存中…") : qsTr("录制")
                            enabled: veyra.recording || (veyra.hasSource && !watch.recordSaving)
                            // PushFPS 4.0: the choices first (PushRecordDialog), unless that was switched off.
                            onClicked: !veyra.recording && Record.asks(veyra.preferences) ? veyra.navigate("record") : veyra.toggleRecording("watch")
                        }
                    }
                    // PushFPS clip markers: only while a recording (not a comparison clip) runs.
                    VRow {
                        objectName: "watch-marker-row"
                        visible: veyra.recording === true && !watch.compareRecording
                        label: qsTr("标记")
                        readonly property int count: Number(veyra.recordingState.markers || 0)
                        hint: count > 0 ? qsTr("这个录像已有 %1 个标记，记在它旁边的文本文件里").arg(count) : qsTr("把这一刻记下来，剪辑时好找")
                        VButton {
                            objectName: "watch-marker"
                            iconName: "plus"
                            text: qsTr("标记这一刻")
                            onClicked: veyra.pushAddMarker("watch")
                        }
                    }
                    VRow {
                        objectName: "watch-compare-row"
                        label: qsTr("对比片段")
                        help: qsTr("录制前后对比视频：一边是视频原本的帧率，一边是 PushFPS。可选分屏、并排或竖屏（TikTok、Shorts、Reels），以及时长")
                        hint: watch.compareRecording ? qsTr("正在录制…") + " " + watch.recordElapsed : veyra.recording ? qsTr("录制中不可用")
                            : (watch.clipUntilStop ? qsTr("手动停止") : qsTr("%1 秒").arg(watch.clipSeconds)) + " · " + watch.clipLayout
                        VButton {
                            objectName: "watch-compare"
                            iconName: "split"
                            text: watch.compareRecording ? qsTr("停止") : qsTr("设置并录制")
                            enabled: watch.compareRecording || !veyra.recording
                            onClicked: watch.compareRecording ? veyra.stopRecording("watch-compare") : veyra.navigate("compare")
                        }
                    }
                    VRow {
                        objectName: "watch-replay-row"
                        label: qsTr("即时回放")
                        help: qsTr("一直保留最近的画面和声音，按下保存时写成视频文件")
                        hint: {
                            if (!veyra.replayEnabled) return qsTr("关闭")
                            const s = veyra.replayState || {}
                            const key = qsTr("保存最近的画面和声音（%1）").arg(veyra.shortcuts.replay || qsTr("未设置快捷键"))
                            // Live: the memory the buffer uses now, and when the chosen length is full.
                            if (s.active && s.seconds > 0 && s.fullMegabytes > 0)
                                return key + " · " + qsTr("内存约 %1 MB，存满后约 %2 MB").arg(s.megabytes).arg(s.fullMegabytes)
                            if (s.fullMegabytes > 0) return key + " · " + qsTr("存满后约占用 %1 MB 内存").arg(s.fullMegabytes)
                            return key
                        }
                        hintBelow: true
                        RowLayout {
                            spacing: 8
                            VButton {
                                objectName: "watch-replay-save"
                                visible: veyra.replayEnabled
                                iconName: "clock"
                                text: veyra.replayState && veyra.replayState.saving ? qsTr("保存中…")
                                    : qsTr("回放 %1").arg(Math.floor(watch.replayHeld / 60) + ":" + (watch.replayHeld % 60 < 10 ? "0" : "") + watch.replayHeld % 60)
                                enabled: !(veyra.replayState && veyra.replayState.saving) && watch.replayHeld > 0
                                onClicked: veyra.saveReplay("watch")
                            }
                            VSwitch {
                                objectName: "watch-replay"
                                checked: veyra.replayEnabled === true
                                onToggled: checked => veyra.setPreference("replayEnabled", checked)
                            }
                        }
                    }
                    VRow {
                        objectName: "watch-recaudio-row"
                        label: qsTr("录制声音")
                        VSwitch {
                            objectName: "watch-recaudio"
                            checked: veyra.recordingAudio === true
                            onToggled: checked => veyra.setPreference("recordAudio", checked)
                        }
                    }
                    VRow {
                        objectName: "watch-recdesktop-row"
                        label: qsTr("录制电脑声音")
                        help: qsTr("录入电脑上除 PushFPS 以外的所有声音，例如浏览器或播放器里正在播放的视频声音。捕获窗口或屏幕时需要打开")
                        hint: veyra.recordingAudio !== true ? qsTr("先打开录制声音") : qsTr("浏览器或播放器里的视频声音")
                        VSwitch {
                            objectName: "watch-recdesktop"
                            enabled: veyra.recordingAudio === true
                            opacity: enabled ? 1 : 0.4
                            checked: veyra.preferences.mixDesktopOn === true
                            onToggled: checked => veyra.setPreference("mixDesktopOn", checked)
                        }
                    }
                    VRow {
                        objectName: "watch-recmic-row"
                        label: qsTr("录制麦克风")
                        VSwitch {
                            objectName: "watch-recmic"
                            checked: veyra.recordingMicrophone === true
                            onToggled: checked => { veyra.setPreference("recordMic", checked); if (checked) veyra.refreshMicrophones() }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    VButton {
                        objectName: "watch-record-settings"
                        Layout.fillWidth: true; ghost: true; iconName: "settings"
                        text: qsTr("录制设置")
                        tip: qsTr("保存位置、尺寸、码率、帧率、编码和高级选项，与专业模式相同")
                        onClicked: watch.requestSettings("rec", "set-recording")
                    }
                    VButton {
                        objectName: "watch-record-folder"
                        Layout.fillWidth: true; ghost: true; iconName: "folder"
                        text: qsTr("打开录制文件夹")
                        onClicked: veyra.openRecordingDirectory()
                    }
                }
            }
        }
    }

    // The picture (native video window), with a hint while nothing plays.
    Rectangle {
        objectName: "watch-preview"
        visible: !watch.compact
        x: watch.margin + watch.panelWidth + 10; y: watch.bodyTop
        width: watch.width - 2 * watch.margin - watch.panelWidth - 10; height: watch.height - watch.bodyTop - watch.margin
        radius: Theme.rCard; color: Theme.videoBlack; border.color: Theme.stroke
        Text {
            x: 12; height: 36
            verticalAlignment: Text.AlignVCenter
            width: parent.width - 24
            text: veyra.hasSource ? (veyra.sourceTitle.length > 0 ? veyra.sourceTitle : qsTr("片源")) : qsTr("没有画面")
            color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 12
            elide: Text.ElideRight
        }
        Text {
            visible: !veyra.hasSource
            anchors.centerIn: parent
            width: parent.width - 60
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("在左边选择一个窗口、屏幕或视频文件，然后开始播放")
            color: Theme.t2; font.family: Theme.fontUi; font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}
