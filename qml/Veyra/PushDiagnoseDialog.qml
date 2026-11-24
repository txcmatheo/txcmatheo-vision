// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Check my setup: looks at the running picture and says what costs quality, smoothness or sound,
// with the one change that answers each (PushDiagnose.js has the rules; this file has the words and
// the changes). Most reports of a soft or broken picture came down to a setting nobody had chosen:
// AI picture enhancement worked out at 1080p on a 4K picture, NVIDIA VFG on its standard model, a
// target the screen cannot show. Nothing here changes a setting until its button is pressed, every
// change can be taken back from the same row, and a change with a price says the price.
//
// How it reads: the live figures are sampled once a second, `sampleCount` times, and their mean is
// judged, so one odd second is not a finding. The list is what was found at that moment: a row
// stays after its change so it can be undone. Dialog key "diagnose"; opened from the quick setup's
// tools (tile pushfps-diagnose) and from Settings (row set-diagnose).
import QtQuick
import QtQuick.Layouts
import "EffectSupport.js" as Support
import "PushDiagnose.js" as Diagnose
import "PushUpscale.js" as Upscale

DialogLayer {
    id: diag
    objectName: "pushfps-diagnose-dialog"
    key: "diagnose"
    glyph: "activity"
    title: qsTr("检查我的设置")
    sub: qsTr("看看正在运行的画面里，是什么在影响清晰度、流畅度和声音。只有按下按钮才会改动设置")
    dialogWidth: 640

    // Tests shorten these.
    property int sampleCount: 3
    property int sampleInterval: 1000

    property var samples: []
    property var found: []          // the findings of the last check (PushDiagnose.findings)
    property var changed: ({})      // finding id -> what its change replaced (for Undo)
    property string phase: "idle"   // idle | reading | done
    readonly property bool playing: veyra.hasSource === true
    readonly property var counts: Diagnose.count(diag.found)

    function enhanceLayers() { return (veyra.nrLayers || []).map(l => l.index) }
    // Plain values for the rules, read from the bridge and the sampled figures.
    function readState() {
        const stats = diag.samples
        const last = stats.length > 0 ? stats[stats.length - 1] : ({})
        const all = veyra.nrLayers || []
        const layer = all.length > 0 ? all[0] : null
        const kind = String(veyra.sourceKind || "")
        const sharper = veyra.captureSharperFormat || []
        const mode = Number(veyra.outputRateMode || 0)
        const hz = Number(veyra.displayRefreshHz || 0)
        const custom = Number(veyra.outputCustomFps || 0)
        const now = Number(last.fgMultiplierNow || 0)
        return {
            playing: diag.playing && last.running === true,
            kind: kind,
            fgPossible: Support.available(veyra, "frame-generation"),
            fgOn: veyra.fgEnabled === true && Number(veyra.fgMultiplier || 1) > 1,
            presentsOwnFrames: veyra.presentationOwned === true,
            multiplier: now >= 1 ? now : Number(veyra.fgMultiplier || 1),
            method: String(veyra.fgBackendName || ""),
            // 4.4.5: the motion estimate FSR is given (PushDiagnose.js "fsr-lighter"). A setting nobody reported is never "can be lighter".
            motionFlow: Number(veyra.fgMotionSource) === 1,
            flowQuality: veyra.flowQuality !== undefined ? Number(veyra.flowQuality) : -1,
            flowHalfPossible: Number(veyra.opticalFlowChoice) === 1 && veyra.amdFlowHalf !== undefined,
            flowHalf: veyra.amdFlowHalf === true,
            vfgQuality: Number(veyra.vfgQuality),
            pushFlowTier: Number(veyra.vfgQuality),
            pushFlowMotion: Number(veyra.preferences.pushFlowMotion || 0),
            pushFlowP95Ms: Diagnose.mean(stats, "pushFlowP95Ms", 0),
            gameFps: Diagnose.mean(stats, "contentFps", 0),
            realFps: Diagnose.mean(stats, "realFps", 0),
            generatedFps: Diagnose.mean(stats, "generatedFps", -1),
            fgIdle: Number(last.fgIdle || 0),
            stillOn: veyra.preferences.pushHudStill === true,
            enhanceOn: veyra.nrAnyEnabled === true && layer !== null,
            enhanceSized: layer !== null && Number(layer.runtime) !== 4,
            // -1 = not known: a size nobody reported is never taken for "up to 1080p".
            enhanceSize: layer !== null && layer.sizePolicy !== undefined ? Number(layer.sizePolicy) : -1,
            pictureHeight: Number(veyra.sourceHeight || 0),
            // 4.2.1: upscaling (PushUpscale.js). A screen size nobody reported is 0 and never "larger".
            screenHeight: diag.screenHigh,
            upscalePossible: Upscale.offered(veyra.srBackendChoices).length > 0,   // any upscaler this card can run
            upscaleOn: veyra.srEnabled === true,
            targetFixed: mode === 2,
            targetFps: custom,
            outputCap: mode === 2 ? custom : mode === 1 ? hz : 0,
            refreshHz: hz,
            vsync: veyra.displaySync === 1,
            vrr: Number(veyra.vrrState || 0) >= 2,
            sharperFps: kind === "capture" && sharper.length > 0 ? Number(sharper[0].fps || 0) : 0,
            sharperPixel: sharper.length > 0 ? String(sharper[0].pixel || "") : "",
            audioChoice: veyra.captureAudioChoice === undefined ? 0 : Number(veyra.captureAudioChoice),
            audioSuggestion: veyra.captureAudioSuggestion === undefined ? -1 : Number(veyra.captureAudioSuggestion)
        }
    }
    function idleText() {
        const last = diag.samples.length > 0 ? diag.samples[diag.samples.length - 1] : ({})
        return String(last.fgIdleText || "")
    }
    function judge() {
        diag.found = Diagnose.findings(diag.readState())
        diag.phase = "done"
    }
    function check() {
        diag.samples = []
        diag.found = []
        diag.changed = ({})
        if (!diag.playing) { diag.phase = "done"; return }
        diag.phase = "reading"
        diag.sample()
    }
    function sample() {
        const list = diag.samples.slice()
        list.push(veyra.pushLiveStats() || ({}))
        diag.samples = list
        if (list.length >= Math.max(1, diag.sampleCount)) diag.judge()
    }
    onShownChanged: if (shown) diag.check(); else { diag.phase = "idle"; diag.samples = [] }
    Timer {
        objectName: "pushfps-diagnose-timer"
        interval: Math.max(10, diag.sampleInterval); repeat: true
        running: diag.shown && diag.phase === "reading"
        onTriggered: diag.sample()
    }

    // --- words ---------------------------------------------------------------------------
    function tierName(t) { return t === 2 ? qsTr("高") : t === 1 ? qsTr("中") : qsTr("低") }
    function flowTierName(t) { return t === 2 ? qsTr("高质量") : t === 1 ? qsTr("均衡") : qsTr("快速") }
    function levelName(level) {
        return level === "problem" ? qsTr("问题") : level === "better" ? qsTr("建议更改") : level === "try" ? qsTr("可以试试") : qsTr("提示")
    }
    function levelColor(level) { return level === "problem" ? Theme.warn : level === "note" ? Theme.t3 : Theme.accent }
    function titleOf(f) {
        switch (f.id) {
        case "fg-idle": return qsTr("补帧开着，但没有生成的画面显示出来")
        case "fg-behind": return qsTr("显卡跟不上：每秒显示 %1 帧，目标是 %2 帧").arg(f.shown).arg(f.wanted)
        case "still-on": return qsTr("「保持 HUD 清晰」开着")
        case "enhance-small": return qsTr("AI 画质增强按 1080p 计算，画面是 %1p").arg(f.height)
        case "upscale-off": return qsTr("画面是 %1p，屏幕是 %2p").arg(f.height).arg(f.screen)
        case "fsr-lighter": return qsTr("FSR 的运动估算可以更省")
        case "vfg-quality": return qsTr("NVIDIA VFG 用的是「%1」质量").arg(diag.tierName(f.tier))
        case "pushflow-room": return qsTr("PushFlow 还有余量：只用了每帧时间的 %1%").arg(f.percent)
        case "fg-off": return qsTr("补帧没有开")
        case "target-above-screen": return qsTr("目标是 %1 FPS，这块屏幕是 %2 Hz").arg(f.target).arg(f.hz)
        case "target-uneven": return qsTr("目标 %1 FPS 除不尽屏幕的 %2 Hz").arg(f.target).arg(f.hz)
        case "capture-compressed": return qsTr("采集卡送来的是压缩画面")
        case "no-sound": return qsTr("没有选声音输入")
        }
        return f.id
    }
    function bodyOf(f) {
        switch (f.id) {
        case "fg-idle": return diag.idleText().length > 0 ? diag.idleText() : qsTr("原因可以在性能报告里看到（设置 → 性能报告）")
        case "fg-behind": return qsTr("生成的画面来不及做完就被跳过，看起来不流畅。可以降低目标帧率、把 AI 画质增强的大小调低，或把补帧质量调低一档")
        case "still-on": return qsTr("镜头移动时，它会把上一帧的像素盖在生成的画面上：物体边缘会破碎，画面会发糊。要保护 HUD，请用游戏预设或 HUD 保护")
        case "enhance-small": return qsTr("增强的结果被放大后贴回画面，所以会发糊、有颗粒。按画面的完整大小计算更清晰，也更吃显卡；帧率掉了就换回来")
        case "upscale-off": return qsTr("全屏时画面只是被拉大到屏幕大小，所以看起来发软。开启放大后由显卡把画面放大到屏幕分辨率，更清晰，也更吃显卡；帧率掉了就关掉")
        case "fsr-lighter": return qsTr("FSR 补帧前，PushFPS 先从画面里估算运动。改用更省的估算后每帧少占显卡，中低端显卡更容易跟上；物体边缘会粗一些，看起来变差就撤销")
        case "vfg-quality": return qsTr("「高」在物体边缘、头部和细小物体上更稳，每帧也更吃显卡。帧率掉了就换回来")
        case "pushflow-room": return qsTr("可以试试「%1」档：运动在更大的画面上估算，物体边缘更干净。显卡跟不上时 PushFPS 会自己降回来").arg(diag.flowTierName(f.tier + 1))
        case "fg-off": return qsTr("现在看到的是主机原本的帧率。在快速设置里选一个目标帧率就会开启")
        case "target-above-screen": return qsTr("屏幕显示不了更多，PushFPS 会按 %1 FPS 输出。可以在 Windows 显示设置里把刷新率调高，或换一个目标").arg(f.hz)
        case "target-uneven": return qsTr("每帧在屏幕上停留的时间不一样长，看起来有顿挫。选一个能整除刷新率的目标，或开启可变刷新率（G-SYNC / FreeSync）")
        case "capture-compressed": return qsTr("在 %1 FPS 下它有不压缩的格式（%2），更清晰；代价是采集帧率变成 %1。60 FPS 的游戏会少一半画面，30 FPS 的游戏没有损失").arg(f.fps).arg(f.pixel)
        case "no-sound": return qsTr("这张采集卡自己的声音输入已经找到，现在连接却没有声音。在采集设置里可以一键选用")
        }
        return ""
    }
    // The buttons of a finding: [{ label, arg }].
    function buttonsOf(f) {
        switch (f.id) {
        case "still-on": return [{ label: qsTr("关闭"), arg: 0 }]
        case "enhance-small": return (f.offer || []).map(id => ({ label: id === 1 ? qsTr("完整大小") : "1440p", arg: id }))
        case "upscale-off": return [{ label: qsTr("开启放大"), arg: 1 }]
        case "fsr-lighter": return [{ label: qsTr("改用更省的运动估算"), arg: 0 }]
        case "vfg-quality": return [{ label: qsTr("改用「高」"), arg: 2 }]
        case "pushflow-room": return [{ label: qsTr("试试「%1」").arg(diag.flowTierName(f.tier + 1)), arg: f.tier + 1 }]
        case "capture-compressed":
        case "no-sound": return [{ label: qsTr("打开采集设置"), arg: 0 }]
        }
        return []
    }

    // --- changes -------------------------------------------------------------------------
    function remember(id, before) {
        const map = Object.assign({}, diag.changed)
        map[id] = before
        diag.changed = map
    }
    function forget(id) {
        const map = Object.assign({}, diag.changed)
        delete map[id]
        diag.changed = map
    }
    function setEnhanceSize(id) {
        let ok = true
        const list = diag.enhanceLayers()
        for (const index of list) ok = veyra.setNrLayerParameter(index, "sizePolicy", Number(id)) && ok
        return ok && list.length > 0
    }
    // 4.2.1: upscaling switched on as quick setup's row does it (PushUpscale.js); what was set is kept for Undo.
    property real screenHighOverride: 0   // tests
    readonly property real screenHigh: diag.screenHighOverride > 0 ? diag.screenHighOverride
                                       : Math.round(Screen.height * Math.max(1, Screen.devicePixelRatio))
    function upscaleNow() { return typeof veyra.srAlgorithmOf === "function" ? String(veyra.srAlgorithmOf(veyra.videoSrQuality)) : "" }
    function setUpscaleOn() {
        const now = diag.upscaleNow()
        const id = Upscale.method(veyra.srBackendChoices, now)
        if (id === "") return null
        const before = { quality: Number(veyra.videoSrQuality), target: Number(veyra.srTargetIndex) }
        if (id !== now) veyra.videoSrQuality = veyra.srQualityFor(id, veyra.srTierOf(veyra.videoSrQuality))
        const size = Upscale.targetIndex(diag.screenHigh, veyra.srTargetIndex)
        if (size > 0) veyra.srTargetIndex = size
        veyra.srEnabled = true
        return before
    }
    function apply(f, arg) {
        switch (f.id) {
        case "upscale-off": {
            const before = diag.setUpscaleOn()
            if (before !== null) diag.remember(f.id, before)
            break
        }
        case "still-on":
            if (veyra.setPreference("pushHudStill", false) !== false) diag.remember(f.id, true)
            break
        case "enhance-small":
            if (diag.setEnhanceSize(arg)) diag.remember(f.id, 0)
            break
        case "fsr-lighter": {
            const before = { quality: Number(veyra.flowQuality), half: veyra.amdFlowHalf === true }
            if (f.quality >= 1) veyra.flowQuality = 0
            if (f.half === true) veyra.amdFlowHalf = true
            diag.remember(f.id, before)
            break
        }
        case "vfg-quality":
        case "pushflow-room": {
            const before = Number(veyra.vfgQuality)
            veyra.vfgQuality = Number(arg)
            diag.remember(f.id, before)
            break
        }
        case "capture-compressed":
        case "no-sound":
            veyra.navigate("capture")
            break
        }
    }
    function undo(f) {
        const before = diag.changed[f.id]
        if (before === undefined) return
        if (f.id === "still-on") veyra.setPreference("pushHudStill", before === true)
        else if (f.id === "enhance-small") diag.setEnhanceSize(before)
        else if (f.id === "upscale-off") {
            veyra.srEnabled = false
            if (Number(veyra.videoSrQuality) !== before.quality) veyra.videoSrQuality = before.quality
            if (before.target >= 1 && Number(veyra.srTargetIndex) !== before.target) veyra.srTargetIndex = before.target
        }
        else if (f.id === "vfg-quality" || f.id === "pushflow-room") veyra.vfgQuality = Number(before)
        else if (f.id === "fsr-lighter") {
            if (Number(veyra.flowQuality) !== before.quality) veyra.flowQuality = before.quality
            if ((veyra.amdFlowHalf === true) !== before.half) veyra.amdFlowHalf = before.half
        }
        diag.forget(f.id)
    }

    // --- what is shown -------------------------------------------------------------------
    Text {
        objectName: "pushfps-diagnose-state"
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        wrapMode: Text.WordWrap
        color: Theme.t1
        font.family: Theme.fontUi
        font.pixelSize: 13
        text: !diag.playing ? qsTr("先让画面播放起来（连接主机），再回来检查：这里看的是正在运行的画面")
            : diag.phase === "reading" ? qsTr("正在读取数据…")
            : diag.found.length === 0 ? qsTr("没有发现需要改的地方")
            : diag.counts.act > 0 ? qsTr("发现 %1 处可以改进").arg(diag.counts.act)
            : qsTr("没有需要改的地方，有 %1 条提示").arg(diag.counts.note)
    }
    Text {
        objectName: "pushfps-diagnose-checked"
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        visible: diag.playing && diag.phase === "done" && diag.found.length === 0
        wrapMode: Text.WordWrap
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        text: qsTr("检查了：补帧是否真的在出帧、显卡是否跟得上、AI 画质增强的大小、补帧质量、目标帧率与屏幕、采集格式和声音")
    }
    Repeater {
        model: diag.phase === "done" ? diag.found : []
        delegate: Rectangle {
            id: item
            required property var modelData
            required property int index
            readonly property var finding: modelData
            readonly property bool done: diag.changed[finding.id] !== undefined
            readonly property var buttons: diag.buttonsOf(finding)
            objectName: "pushfps-diagnose-item-" + finding.id
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            implicitHeight: column.implicitHeight + 24
            radius: 12
            color: Theme.card2
            border.width: 1
            border.color: Theme.stroke
            ColumnLayout {
                id: column
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 1
                        implicitWidth: levelText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: "transparent"
                        border.width: 1
                        border.color: diag.levelColor(item.finding.level)
                        Text {
                            id: levelText
                            anchors.centerIn: parent
                            text: diag.levelName(item.finding.level)
                            color: diag.levelColor(item.finding.level)
                            font.family: Theme.fontUi
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        objectName: "pushfps-diagnose-title-" + item.finding.id
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: diag.titleOf(item.finding)
                        color: Theme.t1
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    objectName: "pushfps-diagnose-body-" + item.finding.id
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: diag.bodyOf(item.finding)
                    color: Theme.t2
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBody
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    visible: item.buttons.length > 0
                    spacing: 8
                    Text {
                        objectName: "pushfps-diagnose-done-" + item.finding.id
                        Layout.fillWidth: true
                        text: item.done ? qsTr("已更改") : ""
                        color: Theme.ok
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                    }
                    VButton {
                        objectName: "pushfps-diagnose-undo-" + item.finding.id
                        visible: item.done
                        ghost: true
                        text: qsTr("撤销")
                        onClicked: diag.undo(item.finding)
                    }
                    Repeater {
                        model: item.done ? [] : item.buttons
                        delegate: VButton {
                            required property var modelData
                            required property int index
                            objectName: "pushfps-diagnose-fix-" + item.finding.id + "-" + index
                            primary: index === 0 && item.finding.level !== "try"
                            text: modelData.label
                            onClicked: diag.apply(item.finding, modelData.arg)
                        }
                    }
                }
            }
        }
    }

    foot: diag.phase === "reading" ? qsTr("正在读取数据…") : ""
    actions: [{ label: qsTr("关闭") }, { label: qsTr("重新检查"), primary: diag.found.length === 0 }]
    onActionTriggered: label => {
        if (label === qsTr("重新检查")) diag.check()
        else diag.dialogHost.close()
    }
}
