// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS layout editor maths (PushLayoutDialog.qml). Rectangles are {x, y, w, h} in fractions of
// the output picture, as the engine places them (engine/PushCanvas.h for the game picture,
// engine/PushStreamOverlay.h resolvePushLayerPlace for sources). Pure: tested in tst_push_layout.qml.
.pragma library

var kMin = 0.03          // smallest side while resizing
var kSnap = 0.012        // snap distance to the edges and the middle

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
function num(v, d) { var n = Number(v); return isFinite(n) ? n : d }

// The aspect (width / height) of a frame after cropping fractions off its sides.
function croppedAspect(aspect, cl, ct, cr, cb) {
    var w = Math.max(0.1, 1 - num(cl, 0) - num(cr, 0)), h = Math.max(0.1, 1 - num(ct, 0) - num(cb, 0))
    return aspect * w / h
}

// Where a scene source sits ({x, y, w, h}), the same as PushStudio.cpp + resolvePushLayerPlace.
// frameAspect: the source's own width / height (before cropping); outAspect: the output's.
function sourceRect(src, frameAspect, outAspect) {
    var aspect = croppedAspect(frameAspect > 0 ? frameAspect : 16 / 9, src.cropL, src.cropT, src.cropR, src.cropB)
    var w = clamp(num(src.size, 0.25), 0.05, 1)
    var corner = String(src.corner || "br")
    var h = corner === "custom" && num(src.h, 0) > 0 ? clamp(num(src.h, 0), 0.01, 1) : w * outAspect / aspect
    if (corner === "custom") return { x: num(src.x, 0.7), y: num(src.y, 0.7), w: w, h: h }
    if (corner === "c") return { x: 0.5 - w / 2, y: 0.5 - h / 2, w: w, h: h }
    var margin = clamp(num(src.margin, 0.025), 0, 0.2)
    var right = corner === "tr" || corner === "br", bottom = corner === "bl" || corner === "br"
    return { x: right ? 1 - margin * 9 / 16 - w : margin * 9 / 16, y: bottom ? 1 - margin - h : margin, w: w, h: h }
}
// The source fields for a rectangle. stretched: keep the height as given (Ctrl resize); otherwise
// the source keeps its own shape (h 0) unless it was already stretched.
function sourceFields(src, rect, stretched) {
    var keepH = stretched || num(src.h, 0) > 0 && String(src.corner) === "custom"
    return { corner: "custom", x: round4(clamp(rect.x, -0.5, 1)), y: round4(clamp(rect.y, -0.5, 1)),
             size: round4(clamp(rect.w, 0.05, 1)), h: keepH ? round4(clamp(rect.h, 0.01, 1)) : 0 }
}
function round4(v) { return Math.round(v * 10000) / 10000 }

// The game picture's box from the canvas preferences (thousandths).
function canvasRect(prefs) {
    return { x: num(prefs.canvasX, 0) / 1000, y: num(prefs.canvasY, 0) / 1000,
             w: num(prefs.canvasW, 1000) / 1000, h: num(prefs.canvasH, 1000) / 1000 }
}
function canvasPrefs(rect) {
    return { canvasX: Math.round(clamp(rect.x, -1, 1) * 1000), canvasY: Math.round(clamp(rect.y, -1, 1) * 1000),
             canvasW: Math.round(clamp(rect.w, 0.02, 3) * 1000), canvasH: Math.round(clamp(rect.h, 0.02, 3) * 1000) }
}

// Where the game picture lands inside its box (PushCanvas.h mapPushCanvas, in fractions):
// dst = the drawn part on the output, src = the part of the picture it shows (fractions of the frame).
function mapCanvas(box, crop, fit, frameAspect, outAspect) {
    var sx = num(crop.l, 0), sy = num(crop.t, 0)
    var sw = Math.max(0.05, 1 - sx - num(crop.r, 0)), sh = Math.max(0.05, 1 - sy - num(crop.b, 0))
    var dst = { x: box.x, y: box.y, w: box.w, h: box.h }
    var src = { x: sx, y: sy, w: sw, h: sh }
    // Pixel aspects: the cropped picture's and the box's.
    var picture = frameAspect * sw / sh, boxAspect = box.w / box.h * outAspect
    if (fit === 0) {
        if (picture > boxAspect) { var h = box.w * outAspect / picture; dst.y = box.y + (box.h - h) / 2; dst.h = h }
        else { var w = box.h * picture / outAspect; dst.x = box.x + (box.w - w) / 2; dst.w = w }
    } else if (fit === 1) {
        if (picture > boxAspect) { var cw = sw * boxAspect / picture; src.x = sx + (sw - cw) / 2; src.w = cw }
        else { var ch = sh * picture / boxAspect; src.y = sy + (sh - ch) / 2; src.h = ch }
    }
    return { dst: dst, src: src }
}

// Snaps a moving rectangle's edges and middle to the output's edges and middle.
function snapMove(rect) {
    var r = { x: rect.x, y: rect.y, w: rect.w, h: rect.h }
    var xs = [[r.x, 0], [r.x + r.w, 1], [r.x + r.w / 2, 0.5]]
    for (var i = 0; i < xs.length; ++i) if (Math.abs(xs[i][0] - xs[i][1]) < kSnap) { r.x += xs[i][1] - xs[i][0]; break }
    var ys = [[r.y, 0], [r.y + r.h, 1], [r.y + r.h / 2, 0.5]]
    for (var j = 0; j < ys.length; ++j) if (Math.abs(ys[j][0] - ys[j][1]) < kSnap) { r.y += ys[j][1] - ys[j][0]; break }
    return r
}
// Moves by (dx, dy), keeping at least a sliver on the picture.
function moveRect(start, dx, dy, snap) {
    var r = { x: start.x + dx, y: start.y + dy, w: start.w, h: start.h }
    if (snap) r = snapMove(r)
    r.x = clamp(r.x, 0.02 - r.w, 0.98)
    r.y = clamp(r.y, 0.02 - r.h, 0.98)
    return r
}
// Drags corner c (0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right) of `start` to (px, py);
// the opposite corner stays. keepShape: the rectangle keeps its proportions (the default; the
// editor turns it off while Ctrl is held). maxSide: the largest width or height allowed.
function resizeRect(start, c, px, py, keepShape, maxSide) {
    var ax = c === 0 || c === 2 ? start.x + start.w : start.x
    var ay = c === 0 || c === 1 ? start.y + start.h : start.y
    var limit = maxSide > 0 ? maxSide : 1
    var w = clamp(Math.abs(px - ax), kMin, limit), h = clamp(Math.abs(py - ay), kMin, limit)
    if (keepShape && start.w > 0 && start.h > 0) {
        var s = Math.max(w / start.w, h / start.h)
        s = Math.max(s, kMin / Math.min(start.w, start.h))
        s = Math.min(s, limit / Math.max(start.w, start.h))
        w = start.w * s; h = start.h * s
    }
    var left = (c === 0 || c === 2) ? ax - w : ax
    var top = (c === 0 || c === 1) ? ay - h : ay
    return { x: left, y: top, w: w, h: h }
}

// Undo history: a list of snapshots (plain objects) with a cursor. push() drops anything undone.
function History(limit) {
    this.items = []
    this.limit = limit || 50
    this.redoItems = []
}
History.prototype.push = function(snapshot) {
    var text = JSON.stringify(snapshot)
    if (this.items.length && this.items[this.items.length - 1] === text) return false
    this.items.push(text)
    if (this.items.length > this.limit) this.items.shift()
    this.redoItems = []
    return true
}
// Returns the snapshot to restore, given the state now (kept for redo), or null.
History.prototype.undo = function(current) {
    if (!this.items.length) return null
    this.redoItems.push(JSON.stringify(current))
    return JSON.parse(this.items.pop())
}
History.prototype.redo = function(current) {
    if (!this.redoItems.length) return null
    this.items.push(JSON.stringify(current))
    return JSON.parse(this.redoItems.pop())
}
History.prototype.clear = function() { this.items = []; this.redoItems = [] }
function history(limit) { return new History(limit) }
