// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// "Optimise for my PC": measures real configurations on the live picture and keeps
// the best one. Every number comes from the engine's own Present and latency
// records through a measurement window (engine/PushBenchmarkProbe.h):
//   1. baseline without effects: content frame rate (30/40/60) and base latency;
//   2. every frame generation method this PC can run (from the engine's own
//      capability list, with the reason for each one it skips) at the highest
//      targets the screen shows: the refresh itself on 144-240 Hz screens when a
//      whole multiplier reaches it, 120 FPS on 120 Hz+, else the refresh or 60;
//      then 60 if nothing held;
//   3. AI enhancement on top of the best one, then the upscalers when the screen
//      is larger than the capture;
//   4. the winner measured again to confirm it.
// A configuration passes only when it really generated frames, reached 95 % of
// its target, kept the 1% low at 80 % of the target, dropped under 1 % of capture
// frames and added no more than 60 ms latency over the baseline. Each one runs
// after its settings are applied and frames come out with them, plus a warm-up,
// then a 6-second window. Nothing is estimated; a method that cannot run is shown
// as such. The winner follows the chosen goal (balanced, lowest latency,
// smoothest motion, best picture) from the measured numbers; the only fixed
// assumption is the picture-quality order of the methods, shown as such.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "EffectSupport.js" as Support

DialogLayer {
    id: opt
    objectName: "pushfps-optimize-dialog"
    key: "optimize"
    glyph: "zap"
    title: qsTr("为我的电脑优化")
    sub: qsTr("在实际画面上逐一测试补帧方式、AI 画质增强和超分，选出最流畅、延迟最低的组合")
    dialogWidth: 660

    // Timing (seconds). Tests can shorten them.
    property real settleTimeout: 20
    property real settleHold: 0.5
    property real warmSeconds: 2.5
    property real measureSeconds: 6
    // Ground-truth quality test after each passing frame generation step (PushQualityProbe.h): every
    // second frame is withheld, regenerated and compared with the original. Its score replaces the
    // fixed quality order where it ran; a source that can't be tested falls back to the order.
    property real qualitySeconds: 5
    property bool qualityUnsupported: false
    property var pendingResult: null
    property int tickMs: 250

    property string phase: "idle"      // idle | running | done | failed
    property string failure: ""
    property var steps: []             // {label, config, result}
    property int current: -1
    property string stepState: ""      // settle | warm | measure | quality
    property real stepStarted: 0
    property real settledSince: 0
    property var startStats: ({})
    property var gpuSamples: []
    property var original: null
    property var baselineResult: null   // "baseline" is a FINAL property of Item in Qt 6.8
    property var best: null
    property int gameFps: 30
    property real refreshHz: 60
    property bool applied: false

    // Picture-quality order of the methods: a heuristic, used when the ground-truth test could not run.
    readonly property var qualityRank: ({ vfg: 6, dlss: 5, anr: 4, pushflow: 4, fsr4: 3, xess: 2, fsr3: 2, amdfrc: 1 })
    readonly property var backendLabel: ({ vfg: "NVIDIA VFG", dlss: qsTr("DLSS 帧生成"), anr: "ANR", fsr4: "FSR 4", xess: "XeSS", fsr3: "FSR 3.1", amdfrc: "AMD FRC", pushflow: "PushFlow" })
    // Goal (preference pushOptimizeGoal): balanced | latency | smooth | picture.
    property string goal: ["balanced", "latency", "smooth", "picture"].indexOf(String(veyra.preferences.pushOptimizeGoal)) >= 0
                          ? String(veyra.preferences.pushOptimizeGoal) : "balanced"
    // Methods and targets not tested, with the reason (shown under the results).
    property var skipped: []

    function now() { return Date.now() / 1000 }
    function stats() { return veyra.pushLiveStats() || {} }

    // --- configurations ------------------------------------------------------
    function saveOriginal() {
        return { fgEnabled: veyra.fgEnabled === true, backend: veyra.fgBackendName, multiplier: veyra.fgMultiplier,
                 rateMode: veyra.outputRateMode, customFps: veyra.outputCustomFps, nr: veyra.nrAnyEnabled === true,
                 sr: veyra.srEnabled === true, srQuality: veyra.videoSrQuality, gameFps: Number(veyra.preferences.pushGameFps || 30),
                 contentRate: Number(veyra.contentRate) }
    }
    function restoreOriginal() {
        const o = opt.original
        if (!o) return
        if (o.sr !== (veyra.srEnabled === true)) veyra.srEnabled = o.sr
        if (o.sr && veyra.videoSrQuality !== o.srQuality) veyra.videoSrQuality = o.srQuality
        if (o.nr !== (veyra.nrAnyEnabled === true)) opt.setEnhancement(o.nr)
        if (o.backend && veyra.fgBackendName !== o.backend) veyra.fgBackendName = o.backend
        if (!o.fgEnabled) veyra.fgEnabled = false
        else if (o.multiplier >= 2) veyra.fgMultiplier = o.multiplier
        if (!veyra.presentationOwned) {
            if (o.rateMode === 2) veyra.outputCustomFps = o.customFps
            veyra.outputRateMode = o.rateMode
        }
        veyra.setPreference("pushGameFps", o.gameFps === 40 || o.gameFps === 60 ? o.gameFps : 30)
        if (o.contentRate !== undefined && Number(veyra.contentRate) !== o.contentRate) veyra.contentRate = o.contentRate
    }
    function setEnhancement(on) {
        if (on) { if (veyra.nrLayers.length === 0) veyra.addEffect("nr"); else veyra.setAllNrEnabled(true) }
        else if (veyra.nrLayers.length > 0) veyra.setAllNrEnabled(false)
    }
    function targetFps(target) {
        if (target === "120") return 120
        if (target === "90") return 90
        if (target === "60") return 60
        if (target === "monitor") return opt.refreshHz
        return 0
    }
    function multiplierFor(fps) {
        const offered = (veyra.fgMultiplierChoices || []).map(o => parseInt(o.id)).filter(m => m >= 2).sort((a, b) => a - b)
        let pick = 0
        for (const m of offered) if (opt.gameFps * m <= fps + 0.5) pick = m
        return pick
    }
    // Applies one configuration; false when this machine cannot express it.
    function apply(c) {
        if (c.sr) { if (veyra.videoSrQuality !== c.sr) veyra.videoSrQuality = c.sr; if (!veyra.srEnabled) veyra.srEnabled = true }
        else if (veyra.srEnabled) veyra.srEnabled = false
        if (Support.available(veyra, "nr") && c.enhance !== (veyra.nrAnyEnabled === true)) opt.setEnhancement(c.enhance)
        if (!c.backend) { veyra.fgEnabled = false; return true }
        if (veyra.fgBackendName !== c.backend) veyra.fgBackendName = c.backend
        if (veyra.fgBackendName !== c.backend) return false
        const m = opt.multiplierFor(opt.targetFps(c.target))
        if (m < 2) return false
        veyra.fgMultiplier = m
        if (veyra.fgMultiplier !== m) return false
        // Every method is measured on the game's own pictures, not on the capture's repeats
        // (same rule as the quick setup's targets); Undo restores the previous mode.
        if (Number(veyra.contentRate) === 0) veyra.contentRate = 1
        if (!veyra.presentationOwned) {
            if (c.target === "monitor") veyra.outputRateMode = 1
            else { veyra.outputCustomFps = opt.targetFps(c.target); veyra.outputRateMode = 2 }
        }
        c.multiplier = m
        return true
    }
    function describe(c) {
        if (!c.backend) return qsTr("不补帧（基准）")
        let s = (opt.backendLabel[c.backend] || c.backend) + " · " + (c.multiplier ? c.multiplier + "× · " : "") + qsTr("%1 FPS").arg(Math.round(opt.targetFps(c.target)))
        if (c.enhance) s += " · " + qsTr("AI 增强")
        if (c.sr === 6) s += " · NIS"
        else if (c.sr) s += " · " + qsTr("RTX 视频超分")
        return s
    }
    // Methods PushFPS stopped in while this version was testing them (preference pushOptimizeSkip,
    // written at the next start from the step that was running): not tested again until PushFPS is
    // updated, so one method that crashes on this PC cannot crash every optimisation.
    function crashed() {
        let list = []
        try { list = JSON.parse(String(veyra.preferences.pushOptimizeSkip || "[]")) } catch (e) { list = [] }
        const version = String(veyra.version || "")
        return (Array.isArray(list) ? list : []).filter(e => e && typeof e.backend === "string" && String(e.version || "") === version).map(e => e.backend)
    }
    // What a step adds over the steps before it, and so what is blamed if PushFPS stops in it: the
    // frame generation method, or the extra put on top ("+enhance", "+sr2", "+sr6").
    function blame(c) {
        if (!c || !c.backend) return ""
        if (c.kind === "sr" || (c.kind === "confirm" && c.sr)) return "+sr" + c.sr
        if (c.kind === "enhance" || (c.kind === "confirm" && c.enhance)) return "+enhance"
        return String(c.backend)
    }
    function blameLabel(id) {
        if (id === "+enhance") return qsTr("AI 增强")
        if (id === "+sr6") return "NIS"
        if (id === "+sr2") return qsTr("RTX 视频超分")
        return opt.backendLabel[id] || id
    }
    // Every method the engine reports as available on this PC, best picture first.
    function backends() {
        const skip = opt.crashed()
        return (veyra.fgBackendChoices || [])
            .filter(o => !o.disabled && skip.indexOf(o.id) < 0)
            .map(o => o.id).sort((a, b) => (opt.qualityRank[b] || 0) - (opt.qualityRank[a] || 0))
    }
    // Methods the engine reports as unavailable, with its reason, and those skipped after a crash.
    function unavailable() {
        const skip = opt.crashed()
        const list = (veyra.fgBackendChoices || []).filter(o => o.disabled)
            .map(o => ({ label: opt.backendLabel[o.id] || o.label || o.id, reason: String(o.note || "") || qsTr("这台电脑不能运行") }))
        for (const o of (veyra.fgBackendChoices || []))
            if (!o.disabled && skip.indexOf(o.id) >= 0)
                list.push({ label: opt.backendLabel[o.id] || o.label || o.id, reason: qsTr("上次测试这种方式时 PushFPS 意外退出，这个版本不再测试它") })
        for (const extra of ["+enhance", "+sr2", "+sr6"])
            if (skip.indexOf(extra) >= 0)
                list.push({ label: opt.blameLabel(extra), reason: qsTr("上次测试这种方式时 PushFPS 意外退出，这个版本不再测试它") })
        return list
    }
    // A whole multiplier lands within 5 % of the refresh (30 FPS: 180 Hz = 6X, 240 Hz = 8X).
    function monitorReachable() {
        const offered = (veyra.fgMultiplierChoices || []).map(o => parseInt(o.id)).filter(m => m >= 2)
        return offered.some(m => Math.abs(opt.gameFps * m - opt.refreshHz) <= opt.refreshHz * 0.05)
    }
    // The targets tested first, highest first.
    function highTargets() {
        if (opt.refreshHz > 125) return opt.monitorReachable() ? ["monitor", "120"] : ["120"]
        if (opt.refreshHz >= 119) return ["120"]
        if (opt.refreshHz > 61) return ["monitor"]
        return ["60"]
    }
    function highTarget() { return opt.highTargets()[0] }

    // --- run -----------------------------------------------------------------
    function start() {
        const s = opt.stats()
        opt.failure = ""
        if (!s.running) { opt.failure = qsTr("先连接采集卡并让游戏画面出现，再开始优化"); opt.phase = "failed"; return }
        opt.original = opt.saveOriginal()
        // Crash safety: the settings to put back are kept on disk while the tests run. If PushFPS stops
        // halfway (a crash in one of the tested methods), the next start restores them instead of
        // loading the combination that crashed (field report 2026-11-17: every connect crashed after).
        veyra.setPreference("pushOptimizeRestore", JSON.stringify(opt.original))
        opt.refreshHz = Number(s.displayRefreshHz) > 0 ? Number(s.displayRefreshHz) : (veyra.displayRefreshHz > 0 ? veyra.displayRefreshHz : 60)
        opt.gameFps = opt.original.gameFps === 40 || opt.original.gameFps === 60 ? opt.original.gameFps : 30
        opt.baselineResult = null
        opt.qualityUnsupported = false
        opt.best = null
        opt.applied = false
        opt.steps = [{ label: "", config: { backend: "", enhance: false, sr: 0, kind: "baseline" }, result: null }]
        opt.phase = "running"
        veyra.logUi("push-optimize", "start refresh=" + opt.refreshHz + " backends=" + opt.backends().join(","))
        opt.beginStep(0)
    }
    function clearRestore() { veyra.setPreference("pushOptimizeRestore", "{}") }
    Component.onCompleted: {
        let saved = null
        try { saved = JSON.parse(String(veyra.preferences.pushOptimizeRestore || "{}")) } catch (e) { saved = null }
        if (!saved || saved.backend === undefined) return
        // The method that was being tested when PushFPS stopped is remembered for this version.
        const testing = typeof saved.testing === "string" ? saved.testing : ""
        if (testing.length > 0) {
            let list = []
            try { list = JSON.parse(String(veyra.preferences.pushOptimizeSkip || "[]")) } catch (e) { list = [] }
            if (!Array.isArray(list)) list = []
            const version = String(veyra.version || "")
            list = list.filter(e => e && String(e.version || "") === version && e.backend !== testing)
            list.push({ backend: testing, version: version })
            veyra.setPreference("pushOptimizeSkip", JSON.stringify(list.slice(-12)))
        }
        opt.original = saved
        opt.restoreOriginal()
        opt.original = null
        opt.clearRestore()
        veyra.logUi("push-optimize", "restored the settings from before an interrupted run" + (testing ? " (was testing " + testing + ")" : ""))
        if (typeof veyra.notice === "function")
            veyra.notice(testing ? qsTr("上次「为我的电脑优化」在测试 %1 时意外中断，已恢复优化前的设置；这个版本不再测试 %1").arg(opt.blameLabel(testing))
                                 : qsTr("上次「为我的电脑优化」没有完成，已恢复优化前的设置"), false)
    }
    function cancel() {
        opt.clearRestore()
        if (opt.phase === "running") { veyra.pushBenchmarkEnd(); veyra.pushQualityCancel(); runner.stop(); opt.restoreOriginal(); opt.phase = "idle" }
        opt.dialogHost.close()
    }
    function beginStep(i) {
        opt.current = i
        const step = opt.steps[i]
        // On disk before the method starts: which one was running, should PushFPS stop in it.
        if (opt.original) veyra.setPreference("pushOptimizeRestore", JSON.stringify(Object.assign({}, opt.original, { testing: opt.blame(step.config) })))
        if (!opt.apply(step.config)) { opt.finishStep({ ok: false, reason: qsTr("这台电脑不支持此组合") }); return }
        step.label = opt.describe(step.config)
        opt.steps = opt.steps.slice()
        opt.stepState = "settle"
        opt.stepStarted = opt.now()
        opt.settledSince = 0
        runner.restart()
    }
    function tick() {
        const s = opt.stats()
        const t = opt.now()
        if (s.failed || !s.running) { opt.abort(qsTr("画面停止了，优化已取消，设置已恢复")); return }
        if (opt.stepState === "settle") {
            if (s.settled) { if (!opt.settledSince) opt.settledSince = t }
            else opt.settledSince = 0
            if (opt.settledSince && t - opt.settledSince >= opt.settleHold) { opt.stepState = "warm"; opt.stepStarted = t }
            else if (t - opt.stepStarted > opt.settleTimeout) opt.finishStep({ ok: false, reason: qsTr("没能启动") })
        } else if (opt.stepState === "warm") {
            if (t - opt.stepStarted >= opt.warmSeconds) {
                opt.startStats = s
                opt.gpuSamples = []
                veyra.pushBenchmarkBegin()
                opt.stepState = "measure"
                opt.stepStarted = t
            }
        } else if (opt.stepState === "measure") {
            if (s.gpuUtilization !== undefined && s.gpuUtilization !== null) opt.gpuSamples.push(Number(s.gpuUtilization))
            if (!s.settled) { veyra.pushBenchmarkEnd(); opt.finishStep({ ok: false, reason: qsTr("测量中设置被改变") }); return }
            if (t - opt.stepStarted >= opt.measureSeconds) {
                const res = opt.evaluate(veyra.pushBenchmarkEnd(), opt.startStats, s)
                if (res.ok && opt.qualityWanted(opt.steps[opt.current]) && veyra.pushQualityBegin(opt.qualitySeconds)) {
                    opt.pendingResult = res
                    opt.stepState = "quality"
                    opt.stepStarted = t
                    return
                }
                opt.finishStep(res)
            }
        } else if (opt.stepState === "quality") {
            const q = veyra.pushQualityStatus() || {}
            if (q.done || q.failed || t - opt.stepStarted > opt.qualitySeconds + 8) {
                if (!q.done && !q.failed) veyra.pushQualityCancel()
                const res = opt.pendingResult
                opt.pendingResult = null
                res.quality = q.done ? { score: Number(q.score), psnr: Number(q.psnr), blendPsnr: Number(q.blendPsnr), gain: Number(q.gainOverBlend),
                                         realPsnr: Number(q.realPsnr), hudPsnr: Number(q.hudPsnr), hudSamples: Number(q.hudSamples),
                                         bad: Number(q.badShare), onTime: Number(q.onTime), samples: Number(q.samples) } : null
                res.qualityNote = q.failed ? String(q.error || "") : q.done ? "" : qsTr("画质测试超时")
                // A source whose pictures can't be read for the test (hardware-decoded streams) stays so.
                if (q.failed) opt.qualityUnsupported = true
                veyra.logUi("push-optimize", "quality " + (res.quality ? "score=" + res.quality.score.toFixed(1) + " psnr=" + res.quality.psnr.toFixed(2) +
                            " blend=" + res.quality.blendPsnr.toFixed(2) : "none " + res.qualityNote))
                opt.finishStep(res)
            }
        }
    }
    function qualityWanted(step) {
        return !opt.qualityUnsupported && (step.config.kind === "fg-high" || step.config.kind === "fg-low")
    }
    // The measured quality when the ground-truth test ran (0..6, the order's scale), else the order.
    function qualityOf(step) {
        const q = step.result && step.result.quality
        if (q && q.samples > 0) return q.score / 100 * 6
        const of = step.config.of !== undefined ? opt.steps[step.config.of] : null
        if (of && of.result && of.result.quality && of.result.quality.samples > 0) return of.result.quality.score / 100 * 6
        return opt.qualityRank[step.config.backend] || 0
    }
    function evaluate(r, before, after) {
        const step = opt.steps[opt.current]
        const c = step.config
        const received = Number(after.captureReceived || 0) - Number(before.captureReceived || 0)
        const dropped = Number(after.captureDropped || 0) - Number(before.captureDropped || 0)
        const gpu = opt.gpuSamples.length ? opt.gpuSamples.reduce((a, b) => a + b, 0) / opt.gpuSamples.length : -1
        const res = { ok: false, reason: "", fps: r.fps || 0, low1: r.low1Fps || 0, latency: r.latencyMeanMs || 0,
                      latencyP95: r.latencyP95Ms || 0, jitter: r.jitterMs || 0, generated: Number(r.generatedPresents || 0),
                      presents: Number(r.presents || 0), dropRate: received > 0 ? Math.max(0, dropped) / received : 0, gpu: gpu,
                      backendWarning: String(after.backendWarning || "") }
        if (!r.valid) { res.reason = qsTr("帧数不足，无法测量"); return res }
        if (c.kind === "baseline") {
            const content = Number(after.contentFps || 0)
            res.content = content
            res.ok = true
            return res
        }
        const target = Math.min(opt.targetFps(c.target), opt.refreshHz + 0.5)
        res.target = target
        const generatedShare = res.presents > 0 ? res.generated / res.presents : 0
        const expectedShare = c.multiplier >= 2 ? (c.multiplier - 1) / c.multiplier : 0
        if (res.backendWarning.length > 0) res.reason = res.backendWarning
        else if (expectedShare > 0 && generatedShare < expectedShare * 0.85) res.reason = qsTr("没有真正生成帧")
        else if (res.fps < target * 0.95) res.reason = qsTr("只达到 %1 FPS").arg(res.fps.toFixed(0))
        else if (res.low1 < target * 0.8) res.reason = qsTr("1% 低帧 %1 FPS，不够稳").arg(res.low1.toFixed(0))
        else if (res.dropRate > 0.01) res.reason = qsTr("采集卡丢帧 %1%").arg((res.dropRate * 100).toFixed(1))
        else if (opt.baselineResult && opt.baselineResult.latency > 0 && res.latency > opt.baselineResult.latency + 60) res.reason = qsTr("延迟增加太多（%1 ms）").arg(res.latency.toFixed(0))
        else res.ok = true
        return res
    }
    // Ranks passing configurations by the chosen goal. Every term except the quality order is measured.
    function score(step) {
        const c = step.config, r = step.result
        const fps = Math.min(r.fps || 0, opt.refreshHz + 0.5)
        const rank = opt.qualityOf(step)
        const extras = (c.enhance ? 12 : 0) + (c.sr === 2 ? 6 : c.sr === 6 ? 4 : 0)
        switch (opt.goal) {
        case "latency": return -r.latency * 100 + fps / 10 + rank
        case "smooth": return fps * 1000 + (r.low1 || 0) * 10 - (r.jitter || 0) * 50 - r.latency / 10 + rank
        case "picture": return rank * 1000 + extras * 40 + fps / 10 - r.latency / 100
        default: return Math.min(opt.targetFps(c.target), opt.refreshHz) * 1000 + rank * 20 + extras - r.latency / 10
        }
    }
    function finishStep(result) {
        runner.stop()
        const steps = opt.steps.slice()
        steps[opt.current].result = result
        if (!steps[opt.current].label) steps[opt.current].label = opt.describe(steps[opt.current].config)
        opt.steps = steps
        veyra.logUi("push-optimize", "step " + opt.current + " " + steps[opt.current].label + " ok=" + result.ok + " reason=" + result.reason +
                    " fps=" + (result.fps || 0).toFixed(2) + " low1=" + (result.low1 || 0).toFixed(2) + " latency=" + (result.latency || 0).toFixed(2))
        opt.plan()
    }
    // Decides what to measure next from what passed so far.
    function plan() {
        const steps = opt.steps
        const done = steps[opt.current]
        const add = (config) => { steps.push({ label: "", config: config, result: null }) }
        if (done.config.kind === "baseline") {
            if (!done.result.ok) { opt.abort(qsTr("无法测量基准画面：%1").arg(done.result.reason)); return }
            opt.baselineResult = done.result
            const content = Math.round(done.result.content || 0)
            if (content === 30 || content === 40 || content === 60) opt.gameFps = content
            const skipped = opt.unavailable()
            if (opt.refreshHz > 125 && !opt.monitorReachable())
                skipped.push({ label: qsTr("%1 FPS").arg(Math.round(opt.refreshHz)),
                               reason: qsTr("%1 FPS 的游戏只能按整数倍补帧，没有一种倍数能达到 %2 Hz，最高测试 120 FPS").arg(opt.gameFps).arg(Math.round(opt.refreshHz)) })
            // The game is set to 30 FPS, the capture runs at 60 and every sample counted as a new
            // picture: either the game really runs at 60, or the capture card adds noise to repeated
            // pictures. The tests below then run on what was measured; say what to do if it is the card.
            if (opt.original && opt.original.gameFps === 30 && content === 60 && Math.abs(Number(opt.stats().captureFps || 0) - 60) < 3 &&
                Number(opt.original.contentRate) !== 5 && Number(opt.original.contentRate) !== 6)
                skipped.push({ label: qsTr("游戏帧率"),
                               reason: qsTr("游戏帧率设为 30，但测到每秒 60 张新画面，下面按 60 FPS 测试。如果游戏确实是 30 FPS（采集卡给重复画面加了噪点），请在快速设置里把去重改为「60→30」后重新优化") })
            opt.skipped = skipped
            for (const high of opt.highTargets())
                for (const b of opt.backends())
                    if (opt.targetFps(high) > opt.gameFps + 0.5) add({ backend: b, target: high, enhance: false, sr: 0, kind: "fg-high" })
            if (steps.length === 1) for (const b of opt.backends())
                if (60 > opt.gameFps + 0.5) add({ backend: b, target: "60", enhance: false, sr: 0, kind: "fg-low" })
        } else if (done.config.kind === "fg-high" && opt.pending().length === 0 && !opt.passed().some(s => s.config.kind === "fg-high")) {
            if (60 > opt.gameFps + 0.5 && opt.highTarget() !== "60")
                for (const b of opt.backends()) add({ backend: b, target: "60", enhance: false, sr: 0, kind: "fg-low" })
        }
        if (opt.pending().length === 0 && !steps.some(s => s.config.kind === "enhance")) {
            const top = opt.bestOf(opt.passed())
            if (top && Support.available(veyra, "nr") && opt.crashed().indexOf("+enhance") < 0)
                add({ backend: top.config.backend, target: top.config.target, enhance: true, sr: 0, kind: "enhance" })
        }
        if (opt.pending().length === 0 && !steps.some(s => s.config.kind === "sr")) {
            const top = opt.bestOf(opt.passed())
            const caps = veyra.effectCapabilities || {}
            const screenHeight = Screen.height * Screen.devicePixelRatio
            const sourceHeight = Number(opt.stats().sourceHeight || 0)
            if (top && sourceHeight > 0 && screenHeight >= 1440 && sourceHeight + 100 < screenHeight) {
                if ((caps.sr2 || {}).available && opt.crashed().indexOf("+sr2") < 0) add({ backend: top.config.backend, target: top.config.target, enhance: top.config.enhance, sr: 2, kind: "sr" })
                if ((caps.sr6 || {}).available && opt.crashed().indexOf("+sr6") < 0) add({ backend: top.config.backend, target: top.config.target, enhance: top.config.enhance, sr: 6, kind: "sr" })
            }
        }
        if (opt.pending().length === 0 && !steps.some(s => s.config.kind === "confirm")) {
            const top = opt.bestOf(opt.passed())
            if (top) add({ backend: top.config.backend, target: top.config.target, enhance: top.config.enhance, sr: top.config.sr, kind: "confirm", of: steps.indexOf(top) })
        } else if (done.config.kind === "confirm" && !done.result.ok) {
            // The winner did not hold: confirm the next best once.
            const others = opt.passed().filter(s => s.config.kind !== "confirm" && steps.indexOf(s) !== done.config.of)
            const next = opt.bestOf(others)
            if (next && steps.filter(s => s.config.kind === "confirm").length < 2)
                add({ backend: next.config.backend, target: next.config.target, enhance: next.config.enhance, sr: next.config.sr, kind: "confirm", of: steps.indexOf(next) })
        }
        opt.steps = steps
        const pending = opt.pending()
        if (pending.length > 0) { opt.beginStep(steps.indexOf(pending[0])); return }
        opt.finish()
    }
    function pending() { return opt.steps.filter(s => s.result === null) }
    function passed() { return opt.steps.filter(s => s.result && s.result.ok && s.config.kind !== "baseline") }
    function bestOf(list) {
        let top = null
        for (const s of list) if (!top || opt.score(s) > opt.score(top)) top = s
        return top
    }
    function finish() {
        opt.clearRestore()
        const confirmed = opt.steps.filter(s => s.config.kind === "confirm" && s.result && s.result.ok)
        const winner = confirmed.length ? confirmed[confirmed.length - 1] : null
        opt.best = winner
        if (winner) {
            opt.apply(winner.config)
            veyra.setPreference("pushGameFps", opt.gameFps)
            opt.applied = true
            opt.phase = "done"
        } else {
            opt.restoreOriginal()
            opt.failure = opt.baselineResult ? qsTr("没有一种补帧组合能稳定达到目标，已保留原来的设置。可降低目标帧率或关闭其他效果后再试")
                                       : qsTr("无法测量")
            opt.phase = "failed"
        }
        const record = { v: 3, at: new Date().toISOString(), applied: !!winner, refreshHz: opt.refreshHz, gameFps: opt.gameFps, goal: opt.goal,
                         best: winner ? opt.describe(winner.config) : "",
                         skipped: opt.skipped,
                         steps: opt.steps.map(s => ({ label: s.label, ok: !!(s.result && s.result.ok), reason: s.result ? s.result.reason : "",
                                                      quality: s.result && s.result.quality ? +s.result.quality.score.toFixed(1) : null,
                                                      psnr: s.result && s.result.quality ? +s.result.quality.psnr.toFixed(2) : null,
                                                      fps: s.result ? +(s.result.fps || 0).toFixed(1) : 0, low1: s.result ? +(s.result.low1 || 0).toFixed(1) : 0,
                                                      latency: s.result ? +(s.result.latency || 0).toFixed(1) : 0,
                                                      latencyP95: s.result ? +(s.result.latencyP95 || 0).toFixed(1) : 0,
                                                      jitter: s.result ? +(s.result.jitter || 0).toFixed(2) : 0 })) }
        veyra.setPreference("pushBenchmark", JSON.stringify(record))
        veyra.logUi("push-optimize", "done best=" + record.best)
    }
    function abort(message) {
        opt.clearRestore()
        runner.stop()
        veyra.pushBenchmarkEnd()
        veyra.pushQualityCancel()
        opt.restoreOriginal()
        opt.failure = message
        opt.phase = "failed"
    }
    function undo() {
        opt.restoreOriginal(); opt.applied = false
        // The quick setup's tile turns grey again: nothing optimised is in use.
        let record = null
        try { record = JSON.parse(String(veyra.preferences.pushBenchmark || "")) } catch (e) { record = null }
        if (record) { record.applied = false; veyra.setPreference("pushBenchmark", JSON.stringify(record)) }
        opt.dialogHost.close()
    }

    Timer { id: runner; interval: opt.tickMs; repeat: true; onTriggered: opt.tick() }
    onShownChanged: if (!shown && phase === "running") cancel()

    foot: phase === "running" ? qsTr("测试中请不要切换画面；可以继续玩") : ""
    actions: phase === "running" ? [{ label: qsTr("取消") }]
           : phase === "done" ? [{ label: qsTr("撤销") }, { label: qsTr("保留"), primary: true }]
           : [{ label: qsTr("关闭") }, { label: qsTr("开始优化"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("开始优化")) opt.start()
        else if (label === qsTr("取消")) opt.cancel()
        else if (label === qsTr("撤销")) opt.undo()
        else opt.dialogHost.close()
    }

    DialogGroup {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 10
            Text {
                Layout.fillWidth: true
                visible: opt.phase === "idle"
                text: qsTr("让游戏画面通过采集卡显示出来，然后开始。PushFPS 会在实际画面上依次测试这台电脑能运行的每种补帧方式（每种约 10 秒，共 1 到 3 分钟），测量真实帧率、1% 低帧和延迟，按你选的目标选出最好的一种。")
                color: Theme.t2; font.family: Theme.fontUi; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                visible: opt.phase === "idle"
                spacing: 10
                Text { text: qsTr("目标"); color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 13 }
                VSeg {
                    objectName: "pushfps-optimize-goal"
                    options: [{ id: "balanced", label: qsTr("均衡") }, { id: "latency", label: qsTr("最低延迟") },
                              { id: "smooth", label: qsTr("最流畅") }, { id: "picture", label: qsTr("最佳画质") }]
                    current: opt.goal
                    onPicked: id => veyra.setPreference("pushOptimizeGoal", id)
                }
            }
            Text {
                Layout.fillWidth: true
                visible: opt.phase === "failed"
                text: opt.failure
                color: Theme.warn; font.family: Theme.fontUi; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
            Text {
                objectName: "pushfps-optimize-best"
                Layout.fillWidth: true
                visible: opt.phase === "done" && opt.best !== null
                text: opt.best ? qsTr("最佳组合：%1。已应用。").arg(opt.best.label) : ""
                color: Theme.accent; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold; wrapMode: Text.WordWrap
            }
            // Progress: steps done of planned.
            Rectangle {
                visible: opt.phase === "running"
                Layout.fillWidth: true
                implicitHeight: 6; radius: 3
                color: Theme.ink(0.08)
                Rectangle {
                    width: parent.width * Math.min(1, (opt.steps.filter(s => s.result !== null).length + 0.5) / Math.max(1, opt.steps.length + 2))
                    height: parent.height; radius: 3; color: Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.d(300) } }
                }
            }
            Text {
                visible: opt.phase === "running" && opt.current >= 0
                Layout.fillWidth: true
                text: opt.current >= 0 && opt.steps[opt.current] ? (opt.stepState === "measure" ? qsTr("正在测量：") : opt.stepState === "quality" ? qsTr("正在测试画质：") : qsTr("准备：")) + opt.steps[opt.current].label : ""
                color: Theme.t1; font.family: Theme.fontUi; font.pixelSize: 13; elide: Text.ElideRight
            }
            // Results, one line per configuration.
            Repeater {
                model: opt.steps.filter(s => s.result !== null)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    VIcon { name: modelData.result.ok ? "check" : "x"; size: 14; color: modelData.result.ok ? Theme.accent : Theme.t3 }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: modelData.result.ok ? Theme.t1 : Theme.t3; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.result.fps > 0
                              ? qsTr("%1 FPS · 1% %2 · %3 ms").arg(modelData.result.fps.toFixed(0)).arg(modelData.result.low1.toFixed(0)).arg(modelData.result.latency.toFixed(0))
                              : ""
                        color: Theme.t2; font.family: Theme.fontMono; font.pixelSize: 11
                    }
                    Text {
                        objectName: "pushfps-optimize-quality"
                        visible: !!modelData.result.quality
                        text: modelData.result.quality ? qsTr("画质 %1 · %2 dB").arg(modelData.result.quality.score.toFixed(0)).arg(modelData.result.quality.psnr.toFixed(1)) : ""
                        color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 11
                    }
                    Text {
                        visible: !modelData.result.ok && modelData.result.reason.length > 0
                        Layout.maximumWidth: 200
                        text: modelData.result.reason
                        color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight
                    }
                }
            }
            Repeater {
                model: opt.phase !== "idle" ? opt.skipped : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    VIcon { name: "minus"; size: 14; color: Theme.t3 }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("未测试：%1（%2）").arg(modelData.label).arg(modelData.reason)
                        color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11; wrapMode: Text.WordWrap
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: opt.phase !== "idle"
                text: qsTr("ms = 电脑处理延迟：采集卡画面到达电脑到交给显示器的时间，不含采集卡、显示器、手柄和游戏本身，不是从按键到画面的总延迟。1% 低帧越接近平均帧率越流畅。画质分数来自实测：每隔一帧扣下真实画面，让补帧重新生成，再和原画面比较（PSNR、像素误差、HUD 区域、与简单混合相比，以及生成帧是否准时）。无法测试画质的来源按经验顺序排序。")
                color: Theme.t3; font.family: Theme.fontUi; font.pixelSize: 11; wrapMode: Text.WordWrap
            }
        }
    }
}
