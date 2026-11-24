// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Crop and resize of the console picture: the one place that reads its preferences and holds its
// maths (the dialog PushCropDialog.qml, the quick setup row and the profiles all use it).
//   pushCropOn                 the switch: off shows the whole picture and keeps the values
//   pushCropL / T / R / B      thousandths of the picture cut from each side, 0..450 each
//                              (engine: PreviewView::kMaxCrop, so at least a tenth always stays)
//   pushCropZoom               size on screen in percent of the fitted size, 25..400
//   pushCropX / pushCropY      where the picture sits in the window, thousandths of the window's
//                              width / height from the middle, -1000..1000
//   pushCropOutputs            recordings and streams are cropped the same way
// The bridge applies them (View.cpp applyAspect, Recording.cpp pushCanvas); nothing here draws.
.pragma library

var maxSide = 450
// The sources the crop is for: a console picture (View.cpp pushCropValues has the same list).
var kinds = ["capture", "ps5", "moonlight", "xbox", "frameinput"]
var keys = ["pushCropL", "pushCropT", "pushCropR", "pushCropB", "pushCropZoom", "pushCropX", "pushCropY"]
// Shapes offered for a crop cut evenly around the middle; 0 is the whole picture.
var shapes = [0, 16 / 9, 21 / 9, 32 / 9, 4 / 3, 1]

function side(v) {
    v = Math.round(Number(v))
    return isFinite(v) ? Math.max(0, Math.min(maxSide, v)) : 0
}
function zoomValue(v) {
    v = Math.round(Number(v))
    return isFinite(v) && v !== 0 ? Math.max(25, Math.min(400, v)) : 100
}
function offset(v) {
    v = Math.round(Number(v))
    return isFinite(v) ? Math.max(-1000, Math.min(1000, v)) : 0
}
// What the preferences say, cleaned.
function read(prefs) {
    var p = prefs || {}
    return { on: p.pushCropOn === true, l: side(p.pushCropL), t: side(p.pushCropT), r: side(p.pushCropR), b: side(p.pushCropB),
             zoom: zoomValue(p.pushCropZoom), x: offset(p.pushCropX), y: offset(p.pushCropY), outputs: p.pushCropOutputs === true }
}
// Nothing set: switching it on would change nothing.
function neutral(c) { return !c || (c.l === 0 && c.t === 0 && c.r === 0 && c.b === 0 && c.zoom === 100 && c.x === 0 && c.y === 0) }
function cuts(c) { return !!c && (c.l > 0 || c.t > 0 || c.r > 0 || c.b > 0) }
// The values as preferences, for one write each (and for a profile).
function values(c) {
    return { pushCropL: side(c.l), pushCropT: side(c.t), pushCropR: side(c.r), pushCropB: side(c.b),
             pushCropZoom: zoomValue(c.zoom), pushCropX: offset(c.x), pushCropY: offset(c.y) }
}
function copy(c, change) {
    var out = { on: c.on === true, l: c.l, t: c.t, r: c.r, b: c.b, zoom: c.zoom, x: c.x, y: c.y, outputs: c.outputs === true }
    if (change) for (var k in change) out[k] = change[k]
    out.l = side(out.l); out.t = side(out.t); out.r = side(out.r); out.b = side(out.b)
    out.zoom = zoomValue(out.zoom); out.x = offset(out.x); out.y = offset(out.y)
    return out
}

// The kept part's shape for a picture of the given shape (width / height).
function keptAspect(c, pictureAspect) {
    return pictureAspect * (1000 - c.l - c.r) / (1000 - c.t - c.b)
}
// A crop cut evenly around the middle that leaves the wanted shape; 0 (or the picture's own shape)
// is no crop. Limited by maxSide, so a very different shape is approached, not reached.
function shaped(c, wanted, pictureAspect) {
    var out = copy(c, { l: 0, t: 0, r: 0, b: 0 })
    if (!(wanted > 0) || !(pictureAspect > 0)) return out
    if (wanted > pictureAspect) {                      // wider: cut top and bottom
        var each = side((1 - pictureAspect / wanted) * 500)
        out.t = each; out.b = each
    } else if (wanted < pictureAspect) {               // narrower: cut the sides
        var eachSide = side((1 - wanted / pictureAspect) * 500)
        out.l = eachSide; out.r = eachSide
    }
    return out
}
// Which of the offered shapes the crop is, or -1 for one made by hand.
function shapeIndex(c, pictureAspect) {
    if (!cuts(c)) return 0
    for (var i = 1; i < shapes.length; ++i) {
        var s = shaped(c, shapes[i], pictureAspect)
        if (cuts(s) && s.l === c.l && s.t === c.t && s.r === c.r && s.b === c.b) return i
    }
    return -1
}

// The kept part in a stage w x h pixels large: { x0, y0, x1, y1 }.
function rect(c, w, h) {
    return { x0: c.l / 1000 * w, y0: c.t / 1000 * h, x1: w - c.r / 1000 * w, y1: h - c.b / 1000 * h }
}
// What a press at (px, py) takes hold of: a corner ("tl", "tr", "bl", "br"), an edge ("l", "r", "t",
// "b"), the kept part itself ("move"), or nothing (""). Corners first, then edges; grip is how many
// pixels around a line still take it.
function hit(c, px, py, w, h, grip) {
    var k = rect(c, w, h)
    var nearL = Math.abs(px - k.x0) <= grip, nearR = Math.abs(px - k.x1) <= grip
    var nearT = Math.abs(py - k.y0) <= grip, nearB = Math.abs(py - k.y1) <= grip
    var inX = px >= k.x0 - grip && px <= k.x1 + grip, inY = py >= k.y0 - grip && py <= k.y1 + grip
    if (nearT && nearL) return "tl"
    if (nearT && nearR) return "tr"
    if (nearB && nearL) return "bl"
    if (nearB && nearR) return "br"
    if (nearL && inY) return "l"
    if (nearR && inY) return "r"
    if (nearT && inX) return "t"
    if (nearB && inX) return "b"
    if (px > k.x0 && px < k.x1 && py > k.y0 && py < k.y1) return "move"
    return ""
}
// The crop after dragging a handle by (dx, dy) thousandths of the picture from where the drag
// began (start). An edge moves that side; a corner moves two; "move" slides the kept part, keeping
// its size, as far as the picture and the side limit allow.
function drag(start, handle, dx, dy) {
    var out = copy(start)
    if (handle === "move") {
        var mx = Math.max(-Math.min(start.l, maxSide - start.r), Math.min(Math.min(start.r, maxSide - start.l), Math.round(dx)))
        var my = Math.max(-Math.min(start.t, maxSide - start.b), Math.min(Math.min(start.b, maxSide - start.t), Math.round(dy)))
        out.l = start.l + mx; out.r = start.r - mx; out.t = start.t + my; out.b = start.b - my
        return out
    }
    if (handle.indexOf("l") >= 0) out.l = side(start.l + dx)
    if (handle.indexOf("r") >= 0) out.r = side(start.r - dx)
    if (handle.indexOf("t") >= 0) out.t = side(start.t + dy)
    if (handle === "b" || handle === "bl" || handle === "br") out.b = side(start.b - dy)
    return out
}
