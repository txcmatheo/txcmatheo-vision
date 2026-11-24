// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS "Check my setup": what in the running session costs picture quality, smoothness or sound,
// and the one change that answers each.
//
// Pure: `findings(state)` takes plain values (PushDiagnoseDialog.qml reads them from the bridge) and
// returns a list of { id, level, ... } in the order they are shown. The words and the changes are the
// dialog's; nothing here reads or writes a setting, so the rules can be run anywhere (the checks
// workflow runs tests/js/push_diagnose_test.js with Node).
//
// Levels:
//   "problem"  something does not work as it was set (frames asked for and not shown);
//   "better"   a setting nobody chose costs quality here, and the change is known to help;
//   "try"      a change with a price, worth trying on this PC (the price is said);
//   "note"     worth knowing, nothing to change from here.
// A rule only speaks when its numbers are there: a value that is missing is never a finding.
// Nothing is ever changed without the button being pressed.
.pragma library

// PushFlow: the share of a game frame's time that all generated frames of one pair may take at the
// current tier for the next tier to be worth trying. The card test's rule is 0.8 at the 95th
// percentile (PushCardTest.js); the next tier works the motion out on about 1.8 times the pixels
// (Fast -> Balanced, the same model) or on 2.25 times the pixels with the full model (Balanced ->
// Quality), and a fifth is left as margin. Estimates: the change is offered as a thing to try, and
// the too-slow watch brings the tier back down when it does not hold.
var kRoomFast = 0.36
var kRoomBalanced = 0.11
// Generated frames shown against generated frames asked for: under this, the card is not keeping up.
var kBehind = 0.8
// How much lower than the screen a picture is before upscaling is offered (PushUpscale.js kSmaller).
var kUpscaleSmaller = 1.2

// A reading as a number, or the fallback when it is not there. Only a number, or a number written as
// text, is a reading: JavaScript's Number() turns null, "", " ", false and [] into 0, and a missing
// reading taken for a zero was a finding nobody should see (a null "generated frames" read as "the
// card is falling behind", a null enhancement size as "worked out at 1080p").
function num(v, fallback) {
    if (typeof v === "string") { if (v.trim() === "") return fallback }
    else if (typeof v !== "number") return fallback
    var n = Number(v)
    return isFinite(n) ? n : fallback
}

// The sources a console's picture comes through (PushCrop.js `kinds`).
function consoleSource(kind) {
    return kind === "capture" || kind === "ps5" || kind === "moonlight" || kind === "xbox" || kind === "frameinput"
}

// The frames a second the screen can be given: the smallest of what the multiplier makes, a fixed or
// display-following cap, and the screen's own refresh rate (0 = unknown, then it does not limit).
function wantedOutput(realFps, multiplier, cap, refreshHz) {
    var want = realFps * multiplier
    if (cap > 0) want = Math.min(want, cap)
    if (refreshHz > 0) want = Math.min(want, refreshHz * 1.02)
    return want
}

function findings(s) {
    var out = []
    if (!s || s.playing !== true) return out
    var fgOn = s.fgOn === true
    var own = s.presentsOwnFrames === true          // XeSS: frames made in its own presenter, not counted
    var m = Math.max(1, Math.round(num(s.multiplier, 1)))
    var idle = Math.round(num(s.fgIdle, 0))         // PushFgHealth: 0 fine, 1 nothing to add, 2..4 a fault

    // Frame generation is on and no generated frame reaches the screen.
    if (fgOn && idle >= 2) out.push({ id: "fg-idle", level: "problem", cause: idle })

    // Fewer generated frames shown than asked for: the graphics card is not keeping up.
    var real = num(s.realFps, 0), gen = num(s.generatedFps, -1)
    if (fgOn && !own && idle === 0 && m >= 2 && real >= 10 && gen >= 0) {
        var want = wantedOutput(real, m, num(s.outputCap, 0), num(s.refreshHz, 0))
        var expected = want - real
        if (expected >= 10 && gen < expected * kBehind) {
            out.push({ id: "fg-behind", level: "problem", shown: Math.round(real + gen), wanted: Math.round(want) })
            // 4.4.5: FSR is given motion that PushFPS estimates from the picture first (optical flow). On a card
            // that is behind, that estimate can be made cheaper: its "performance" level, and at half the width
            // and height where the estimate is AMD's. Offered only while the card is behind, never switched.
            if ((s.method === "fsr3" || s.method === "fsr4") && s.motionFlow === true) {
                var quality = Math.round(num(s.flowQuality, -1))
                var half = s.flowHalfPossible === true && s.flowHalf === false
                if (quality >= 1 || half) out.push({ id: "fsr-lighter", level: "try", quality: quality, half: half })
            }
        }
    }

    // "Keep the HUD sharp" puts the older frame's pixels over parts of generated frames while the camera moves.
    if (fgOn && !own && s.stillOn === true) out.push({ id: "still-on", level: "better" })

    // AI picture enhancement worked out at 1080p (the standard) on a larger picture: the fuzz on a 4K screen.
    var h = Math.round(num(s.pictureHeight, 0))
    if (s.enhanceOn === true && s.enhanceSized === true && Math.round(num(s.enhanceSize, -1)) === 0 && h > 1088)
        out.push({ id: "enhance-small", level: "better", height: h, offer: h > 1448 ? [1, 5] : [1] })

    // 4.2.1: the picture is clearly smaller than the screen and nothing enlarges it but the window, which is
    // what "sharp in a small window, like 720p in full screen" is. Offered, never switched: upscaling costs
    // graphics card time. (kUpscaleSmaller is PushUpscale.js's kSmaller: change both together.)
    var screen = Math.round(num(s.screenHeight, 0))
    if (s.upscalePossible === true && s.upscaleOn === false && h >= 360 && screen > 0 && h * kUpscaleSmaller < screen)
        out.push({ id: "upscale-off", level: "try", height: h, screen: screen })

    // NVIDIA VFG below its best model.
    if (fgOn && s.method === "vfg" && idle < 2) {
        var q = Math.round(num(s.vfgQuality, -1))
        if (q === 0 || q === 1) out.push({ id: "vfg-quality", level: "try", tier: q })
    }

    // PushFlow with room for the next tier, on its own motion size.
    if (fgOn && s.method === "pushflow" && idle < 2 && Math.round(num(s.pushFlowMotion, 0)) === 0) {
        var tier = Math.round(num(s.pushFlowTier, -1)), p95 = num(s.pushFlowP95Ms, 0), game = num(s.gameFps, 0)
        if ((tier === 0 || tier === 1) && p95 > 0 && game >= 10 && m >= 2) {
            var share = p95 * (m - 1) * game / 1000
            if (share <= (tier === 0 ? kRoomFast : kRoomBalanced))
                out.push({ id: "pushflow-room", level: "try", tier: tier, percent: Math.round(share * 100) })
        }
    }

    // A console is playing and frame generation is off: the picture is the console's own frame rate.
    if (!fgOn && consoleSource(s.kind) && s.fgPossible === true) out.push({ id: "fg-off", level: "note" })

    // A fixed target the screen cannot show, or one its refresh rate does not divide by.
    var hz = num(s.refreshHz, 0), target = num(s.targetFps, 0)
    if (fgOn && s.targetFixed === true && hz >= 1 && target > 0) {
        if (s.vsync === true && target > hz * 1.02)
            out.push({ id: "target-above-screen", level: "note", target: Math.round(target), hz: Math.round(hz) })
        else if (s.vrr !== true && target <= hz * 1.02) {
            var ratio = hz / target
            if (Math.abs(ratio - Math.round(ratio)) > 0.05)
                out.push({ id: "target-uneven", level: "note", target: Math.round(target), hz: Math.round(hz) })
        }
    }

    // The capture card sends a compressed picture although it has an uncompressed one at another rate.
    if (s.kind === "capture" && num(s.sharperFps, 0) > 0)
        out.push({ id: "capture-compressed", level: "try", fps: Math.round(num(s.sharperFps, 0)), pixel: String(s.sharperPixel || "") })

    // No sound input is chosen and the card's own was found.
    if (s.kind === "capture" && Math.round(num(s.audioChoice, 0)) === -1 && Math.round(num(s.audioSuggestion, -1)) !== -1)
        out.push({ id: "no-sound", level: "better" })

    return out
}

// The findings counted by what they ask of the user: { problem, better, try, note, act } (act = the
// first three: something to do).
function count(list) {
    var c = { problem: 0, better: 0, "try": 0, note: 0, act: 0 }
    for (var i = 0; i < (list || []).length; ++i) {
        var level = list[i] && list[i].level
        if (c[level] !== undefined) c[level]++
    }
    c.act = c.problem + c.better + c["try"]
    return c
}

// The mean of the numbers in a list of samples for one key (missing, empty or non-finite values are
// left out; no value at all gives `fallback`). The dialog reads the live figures a few times and judges
// their mean, so one odd second is not a finding.
function mean(samples, key, fallback) {
    var sum = 0, n = 0
    for (var i = 0; i < (samples || []).length; ++i) {
        var raw = samples[i] ? samples[i][key] : undefined
        if (raw === null || raw === undefined || raw === "") continue   // "not known" is not a zero
        var v = Number(raw)
        if (isFinite(v)) { sum += v; ++n }
    }
    return n > 0 ? sum / n : fallback
}
