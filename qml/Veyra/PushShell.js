// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The new design's shell (Main.qml): the few decisions it makes about its own sides, kept apart from
// Qt so they can be run without it (tests/js/push_shell_test.js). No main window exists in any test,
// so what can be decided here is decided here.
.pragma library

// Below this window width the navigation shows its icons alone, whatever was chosen.
var kNavNames = 1100

function on(prefs, key) { return !!prefs && prefs[key] === true }

// The navigation: icons alone because the window is narrow / because of that or the title bar's button.
function navForcedSlim(width) { return !(Number(width) >= kNavNames) }
function navSlim(width, prefs) { return navForcedSlim(width) || on(prefs, "pushNavCollapsed") }

// The settings side: which pages have one (quick setup beside the home page's picture, the panel of
// Professional mode's list), and whether it is hidden.
function sideOffered(page, threePane) { return (page === "home" && threePane === true) || page === "pro" }
function sideCollapsed(prefs) { return on(prefs, "pushSideCollapsed") }

// A capture card connected from the home page: does the picture play there? Only where that page
// shows a picture (the new design, wide enough for its three panes); not where Professional mode
// was asked for, and not with "full screen on connecting", which goes full screen in Professional
// mode with its panel over the picture, as it always did.
function staysHomeOnConnect(modern, threePane, prefs) {
    if (modern !== true || threePane !== true) return false
    return !on(prefs, "pushConnectToPro") && !on(prefs, "pushAutoFullscreen")
}

// Full screen asked for (the shortcut, F11) while a picture plays on the new home page: full screen
// is that picture, not that page. The page's own Fullscreen button always went to the picture alone
// first; with a capture card now playing on the home page, the shortcut does the same.
function fullScreenLeavesHome(page, modern, hasSource) { return page === "home" && modern === true && hasSource === true }

// Professional mode's All tab: its blocks, and the list of the folded ones as it is kept (ids with
// commas; anything else in the text is dropped, as the bridge drops it).
var kBlocks = ["quality", "fg", "color", "audio", "display"]
function foldedBlocks(text) {
    var out = []
    var parts = String(text === undefined || text === null ? "" : text).split(",")
    for (var i = 0; i < parts.length; ++i)
        if (kBlocks.indexOf(parts[i]) >= 0 && out.indexOf(parts[i]) < 0) out.push(parts[i])
    return out
}
function blockOpen(text, id) { return foldedBlocks(text).indexOf(id) < 0 }
function withBlock(text, id, open) {
    var list = foldedBlocks(text).filter(function (s) { return s !== id })
    if (!open && kBlocks.indexOf(id) >= 0) list.push(id)
    return list.join(",")
}
