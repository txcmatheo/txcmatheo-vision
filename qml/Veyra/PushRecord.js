// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The choices of a normal recording, as the record dialog offers them before it starts
// (PushRecordDialog.qml, PushFPS 4.0): the shape (wide as the picture is, or tall 9:16), for a tall
// one whether the picture fills it or fits into it, the size, and the picture quality.
//
// Nothing here is a setting of its own: the dialog reads and writes the recording preferences that
// Settings -> Recording has (recordWidth, recordHeight, recordFit, recordBitrateKbps,
// recordBitrateMbps, recordAdvanced, recordRateControl, recordQuality, recordProfile), so the two can
// never disagree. Two preferences are new: pushRecordBitrateScale (the share of the automatic rate in
// percent, 100 unless "smaller files" is chosen) and pushRecordAsk (false: the record buttons start at
// once, as before 4.0; the shortcut always does).
.pragma library

// The shape: "wide" the picture's own, "tall" 9:16 for the phone apps.
function shape(prefs) {
    var w = Number((prefs && prefs.recordWidth) || 0), h = Number((prefs && prefs.recordHeight) || 0)
    return w > 0 && h > w ? "tall" : "wide"
}
// A tall recording: true when the picture fills it (its sides are cut), false when it fits (bars above and below).
function fills(prefs) { return Number((prefs && prefs.recordFit) || 0) === 1 }

// The size, named by its short side: 0 the picture's own (wide only), 2160, 1440, 1080; -1 anything
// else Settings has (another shape or size), which the dialog shows as it is and leaves alone.
var sizes = [0, 2160, 1440, 1080]
var tallSizes = [2160, 1440, 1080]
function dimensions(shapeId, sizeId) {
    var s = Number(sizeId)
    if (shapeId === "tall") {
        if (tallSizes.indexOf(s) < 0) s = 1080
        return [s, Math.round(s * 16 / 9)]
    }
    if (s === 0 || sizes.indexOf(s) < 0) return [0, 0]
    return [Math.round(s * 16 / 9), s]
}
function size(prefs) {
    var w = Number((prefs && prefs.recordWidth) || 0), h = Number((prefs && prefs.recordHeight) || 0)
    if (w <= 0 || h <= 0) return 0
    var list = h > w ? tallSizes : sizes, short = Math.min(w, h)
    for (var i = 0; i < list.length; ++i) {
        var d = dimensions(h > w ? "tall" : "wide", list[i])
        if (list[i] > 0 && d[0] === w && d[1] === h) return short
    }
    return -1
}
function sizeName(sizeId) { return Number(sizeId) === 2160 ? "4K" : Number(sizeId) + "p" }

// The picture quality: "best" a constant quality (no rate to run out of; the largest files), "high"
// the recorder's standard rate, "small" half of it, "custom" a rate or profile chosen in Settings.
var qualities = ["best", "high", "small"]
var bestLevel = 18
function quality(prefs) {
    var p = prefs || {}
    if (p.recordAdvanced === true && Number(p.recordRateControl) === 2) return "best"
    if (Number(p.recordBitrateKbps || 0) > 0 || Number(p.recordBitrateMbps || 0) > 0) return "custom"
    return Number(p.pushRecordBitrateScale || 100) === 50 ? "small" : "high"
}

// What a choice writes. Each returns the preferences to set; a choice made here ends a platform
// profile chosen in Settings (recordProfile), as changing the same value there does.
function shapePrefs(shapeId, sizeId, fill) {
    var d = dimensions(shapeId, sizeId)
    return { recordWidth: d[0], recordHeight: d[1], recordFit: shapeId === "tall" && fill ? 1 : 0, recordProfile: "" }
}
function qualityPrefs(id, prefs) {
    var out = { recordBitrateKbps: 0, recordBitrateMbps: 0, pushRecordBitrateScale: id === "small" ? 50 : 100, recordProfile: "" }
    if (id === "best") { out.recordAdvanced = true; out.recordRateControl = 2; out.recordQuality = bestLevel }
    // Back from a constant quality to a rate: the standard rate control. Other advanced values stay as they are.
    else if (prefs && Number(prefs.recordRateControl) === 2) out.recordRateControl = 1
    return out
}

// The recorder's standard rate in Mbps: the same rule as engine/PushRecordQuality.h (change both together).
function autoMbps(width, height, fps, hevc, scalePercent) {
    var f = Math.max(0, Number(fps) || 0)
    var rate = Math.min(f, 60) + Math.max(f - 60, 0) * 0.5
    var mbps = width * height * rate * 0.3 * (hevc ? 0.65 : 1.0) / 1e6
    var standard = Math.max(hevc ? 8 : 10, Math.min(160, Math.round(mbps)))
    var scale = Math.max(25, Math.min(200, Number(scalePercent) || 100))
    if (scale === 100) return standard
    return Math.max(hevc ? 4 : 5, Math.min(160, Math.round(standard * scale / 100)))
}

// What a recording started now would be: its size, frames a second, codec and rate (0: constant quality,
// no fixed rate). picture: the size and rate of what is playing, { width, height, fps, hdr }.
function plan(prefs, picture) {
    var p = prefs || {}, pic = picture || {}
    var w = Number(p.recordWidth || 0), h = Number(p.recordHeight || 0)
    if (w <= 0 || h <= 0) { w = Number(pic.width || 0); h = Number(pic.height || 0) }
    var limit = Number(p.recordFps || 0), shown = Number(pic.fps || 0)
    var fps = Math.round(limit > 0 ? (shown > 1 ? Math.min(limit, shown) : limit) : (shown > 1 ? shown : 60))
    // HDR pictures and anything past 4096 a side are recorded as HEVC whatever is chosen.
    var hevc = p.recordHevc === true || pic.hdr === true || w > 4096 || h > 4096
    var q = quality(p), mbps = 0
    if (q === "custom") mbps = Number(p.recordBitrateKbps || 0) > 0 ? Number(p.recordBitrateKbps) / 1000 : Number(p.recordBitrateMbps || 0)
    else if (q !== "best" && w > 0 && h > 0) mbps = autoMbps(w, h, fps, hevc, Number(p.pushRecordBitrateScale || 100))
    return { width: w, height: h, fps: fps, hevc: hevc, quality: q, mbps: mbps }
}
// Megabytes a minute at a rate in Mbps (the sound's share is small and left out).
function megabytesPerMinute(mbps) { return Math.round(mbps * 60 / 8) }

// Do the record buttons show the dialog first? (The shortcut never does.)
function asks(prefs) { return !prefs || prefs.pushRecordAsk !== false }
