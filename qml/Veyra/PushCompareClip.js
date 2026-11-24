// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS comparison clips: which layout, how long one runs, and for the layouts that have them the
// recording quality and how often the Reveal layout's line sweeps. Shared by the dialog
// (PushCompareDialog.qml), Settings, the quick setup tile, Streaming mode and the video playback page,
// so they can never disagree.
//
// Preferences: pushCompareLayout (0 split, 1 side by side, 2 vertical, 3 reveal; anything else counts
// as split), pushCompareSeconds (one of `lengths`; anything else counts as 15), pushCompareUntilStop
// (no timer: the clip runs until it is stopped, in every layout), pushCompareQuality (one of
// `qualities`: 0 automatic, or the height recorded; Split and Reveal only), pushComparePicture
// (one of `pictures`: the picture quality, every layout; high unless set) and
// pushCompareRevealSeconds (one of `revealIntervals`; anything else counts as 3).
.pragma library

var lengths = [10, 15, 30, 60, 90, 120]

function seconds(prefs) {
    var n = Number((prefs && prefs.pushCompareSeconds) || 15)
    return lengths.indexOf(n) >= 0 ? n : 15
}

// The layout: 0 split, 1 side by side, 2 vertical (9:16), 3 reveal (a line sweeps across the whole picture).
var layouts = [0, 1, 2, 3]
function layout(prefs) {
    var n = Number((prefs && prefs.pushCompareLayout) || 0)
    return layouts.indexOf(n) >= 0 ? n : 0
}

// Recording quality: the height a clip is recorded at. 0: automatic (the picture's own size, at most
// 1440p, as before 3.2.5). Split and Reveal fill the frame and take it; side by side and vertical
// have sizes of their own.
var qualities = [0, 1080, 1440, 2160]
function takesQuality(layoutId) { return layoutId === 0 || layoutId === 3 }
function quality(prefs) {
    var n = Number((prefs && prefs.pushCompareQuality) || 0)
    return qualities.indexOf(n) >= 0 ? n : 0
}
function qualityName(height) { return height === 2160 ? "4K" : height + "p" }

// Picture quality, in every layout: 0 standard (by bitrate, as every clip was), 1 high and 2 near
// lossless (a fixed quality level: engine/RecordingComparePlan.h compareClipQualityLevel). High
// unless chosen: a clip is made to be looked at closely.
var pictures = [0, 1, 2]
function picture(prefs) {
    var v = prefs ? prefs.pushComparePicture : undefined
    if (v === undefined || v === null || v === "") return 1
    var n = Number(v)
    return pictures.indexOf(n) >= 0 ? n : 1
}

// Reveal: a sweep starts every so many seconds. The line's place over time is the recorder's own
// rule (engine/RecordingComparePlan.h compareRevealPosition), repeated here for the preview.
var revealIntervals = [1, 2, 3, 5, 8]
function revealEvery(prefs) {
    var n = Number((prefs && prefs.pushCompareRevealSeconds) || 3)
    return revealIntervals.indexOf(n) >= 0 ? n : 3
}
function revealSweepSeconds(every) { return Math.min(1.2, Math.max(0.5, 0.3 * every)) }
// The share of the picture's width that shows PushFPS, from the left: 0 all original, 1 all PushFPS.
function revealPosition(seconds, every) {
    if (!(seconds > 0) || !(every > 0)) return 0
    var sweep = revealSweepSeconds(every), hold = every - sweep
    var u = seconds % (2 * every)
    var back = u >= every
    if (back) u -= every
    var p = 0
    if (u > hold) {
        var x = Math.min(1, (u - hold) / sweep)
        p = x * x * x * (x * (6 * x - 15) + 10)
    }
    return back ? 1 - p : p
}

function untilStop(prefs) { return !!prefs && prefs.pushCompareUntilStop === true }

// What pushStartCompareClip takes: 0 records until stopped.
function startSeconds(prefs) { return untilStop(prefs) ? 0 : seconds(prefs) }

// A running clip's time as 01:23 (1:02:03 from an hour on).
function elapsed(total) {
    var s = Math.max(0, Math.floor(Number(total) || 0))
    var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60
    function two(n) { return (n < 10 ? "0" : "") + n }
    return h > 0 ? h + ":" + two(m) + ":" + two(sec) : two(m) + ":" + two(sec)
}
