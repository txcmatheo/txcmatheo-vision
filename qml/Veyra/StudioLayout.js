// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// PushFPS streaming mode (StudioPage.qml) geometry, shared by the QML cards and Main.qml's one native
// video window: the preview in the middle, PushFPS features on the left, controls on the right, the
// audio mixer across the bottom and a status bar under it, as OBS Studio lays out its docks.
.pragma library
function calculate(width, height) {
    const compact = width < 1100 || height < 640
    const margin = 12, top = 56, gap = 10
    const statusHeight = 28
    const mixerHeight = compact ? 170 : 196   // three rows of two strips (game, mic, monitor, desktop, extra input)
    const leftWidth = compact ? 0 : 300
    const rightWidth = compact ? 236 : 286
    const bodyHeight = Math.max(1, height - top - margin - statusHeight - gap - mixerHeight - gap)
    const left = { x: margin, y: top, width: leftWidth, height: bodyHeight }
    const right = { x: width - margin - rightWidth, y: top, width: rightWidth, height: bodyHeight }
    const centerX = margin + (leftWidth > 0 ? leftWidth + gap : 0)
    const preview = { x: centerX, y: top, width: Math.max(1, right.x - gap - centerX), height: bodyHeight }
    const headerHeight = 36
    // The picture inside the preview card, below its header (1 px border kept clear).
    const video = { x: preview.x + 1, y: preview.y + headerHeight, width: Math.max(1, preview.width - 2),
                    height: Math.max(1, preview.height - headerHeight - 1) }
    const mixer = { x: margin, y: top + bodyHeight + gap, width: Math.max(1, width - 2 * margin), height: mixerHeight }
    const status = { x: margin, y: height - margin - statusHeight, width: Math.max(1, width - 2 * margin), height: statusHeight }
    return { compact: compact, left: left, right: right, preview: preview, headerHeight: headerHeight,
             video: video, mixer: mixer, status: status }
}
// Meter scale: dBFS to 0..1 along the bar (-60 dB at the left end, 0 dB at the right).
function meterPosition(db) {
    if (!isFinite(db)) return 0
    return Math.max(0, Math.min(1, (db + 60) / 60))
}
// OBS-style ballistics: a level rises at once and falls by `fallDbPerSecond`.
function fall(shown, measured, seconds, fallDbPerSecond) {
    const dropped = shown - fallDbPerSecond * seconds
    return Math.max(measured, Math.max(-100, dropped))
}
// "1:02:03" / "2:03".
function duration(seconds) {
    const s = Math.max(0, Math.floor(seconds || 0))
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, r = s % 60
    return (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(r).padStart(2, "0")
}
