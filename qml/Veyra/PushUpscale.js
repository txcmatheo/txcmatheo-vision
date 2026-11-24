// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
.pragma library

// PushFPS 4.2.1: "Upscale to my screen" (quick setup's row and Check my setup's offer). Pure rules, no
// Qt: tests/js/push_upscale_test.js runs them in Node.
//
// A user's report: sharp in a small window, "like 720p" in full screen. A capture smaller than the
// screen is only stretched to it by the window; the upscalers (super resolution) were in Professional
// mode and nowhere else. These rules decide what switching it on from quick setup sets. Nothing here
// switches anything by itself.

// How much lower than the screen a picture has to be before upscaling is worth offering: 1080p on a
// 1440p or 4K screen and 1440p on 4K, not 1080p on a 1200-line screen.
var kSmaller = 1.2
// A picture nobody would call a console's, or a size not yet known.
var kLeastPicture = 360

// Whether the picture is clearly smaller than the screen (both in real pixels, top to bottom).
function gains(pictureHigh, screenHigh) {
    var p = Number(pictureHigh), s = Number(screenHigh)
    if (!(p >= kLeastPicture) || !(s > 0)) return false
    return p * kSmaller < s
}

// The upscalers this card can run now: the bridge's choices without the disabled ones.
function offered(choices) {
    var out = []
    var list = choices || []
    for (var i = 0; i < list.length; ++i)
        if (list[i] && list[i].disabled !== true && typeof list[i].id === "string" && list[i].id.length > 0) out.push(list[i])
    return out
}

// The upscaler to switch on with. The one already chosen when this card can run it (a choice made in
// Professional mode is kept). Otherwise the engine would switch the stage off again, as it does for
// an upscaler the card cannot run, so one every card runs is taken: FSR ("5": FSR 4 where the card
// and driver have it, FSR 3.1 elsewhere), then NVIDIA Image Scaling ("6", a shader, any card), then
// whatever is first. "" when there is none.
function method(choices, current) {
    var list = offered(choices)
    var now = String(current === undefined || current === null ? "" : current)
    var i
    for (i = 0; i < list.length; ++i) if (list[i].id === now) return now
    var neutral = ["5", "6"]
    for (var n = 0; n < neutral.length; ++n)
        for (i = 0; i < list.length; ++i) if (list[i].id === neutral[n]) return neutral[n]
    return list.length > 0 ? list[0].id : ""
}

// The size to upscale to (the bridge's srTargetIndex: 1 = 2560x1440, 2 = 3840x2160, 3.. = 8K, 5K, 6K,
// 7K), or 0 for "leave it". A screen up to 1440 lines gets 1440p and a larger one 4K, so a 1440p
// screen is not made to work out a 4K picture it then shrinks. A larger size somebody chose in
// Professional mode is left alone, and so is everything while the screen's size is unknown.
function targetIndex(screenHigh, now) {
    var s = Number(screenHigh), n = Math.round(Number(now))
    if (!(s > 0) || (n !== 1 && n !== 2)) return 0
    var want = s <= 1440 ? 1 : 2
    return want === n ? 0 : want
}

// Why a choice cannot run, as the bridge says it ("" when it can, or is not in the list).
function note(choices, id) {
    var list = choices || []
    for (var i = 0; i < list.length; ++i)
        if (list[i] && list[i].id === id) return list[i].disabled === true ? String(list[i].note || "") : ""
    return ""
}

// The label of a choice by its id ("" when it is not in the list).
function label(choices, id) {
    var list = choices || []
    for (var i = 0; i < list.length; ++i) if (list[i] && list[i].id === id) return String(list[i].label || "")
    return ""
}
