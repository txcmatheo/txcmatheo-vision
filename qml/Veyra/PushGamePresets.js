// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS game presets: the built-in library and the share-code format. A preset
// holds the quick-setup choices (game frame rate, target) and up to four HUD
// regions, which PushFPS applies as "Exclude all effects" areas so the minimap and
// HUD stay sharp and are never interpolated. Coordinates are fractions of the
// captured picture (0..1, left/top/right/bottom).
.pragma library

var kCodePrefix = "PUSHFPS1:"
var kMaxRegions = 4
var kMaxName = 40

// Layouts here are estimates, said so in each description: a preset is a start
// that the player adjusts by drawing the areas in Professional mode.
var builtIn = [
    // GTA VI (checked 18 November 2026, the day before release). Which corner holds what comes from
    // Rockstar's pre-release gameplay footage as written up by allthings.how, bo3.gg and gtanerd.com:
    // health, focus and stamina bars top left; weapon, ammo, wanted stars and cash top right; the
    // minimap bottom left (a rounded rectangle while driving; parts of the HUD fade out when unused).
    // The exact edges are NOT measured from the game. 30 FPS on every console, and the base PS5 dips
    // below it in busy scenes (Digital Foundry's review), so the adaptive multiplier is on.
    { id: "gta6", name: "GTA VI", fps: 30, target: "auto", feather: 6, adaptive: true,
      note: "Minimap bottom left, health and focus bars top left, weapon, wanted level and cash top right (from Rockstar's pre-release footage). The edges are estimates; check them with Adjust HUD areas once you play. The frame rate dips on the base PS5, so the adaptive multiplier is on.",
      regions: [ { left: 0.012, top: 0.72, right: 0.19, bottom: 0.97, ellipse: false },
                 { left: 0.80, top: 0.02, right: 0.99, bottom: 0.14, ellipse: false },
                 { left: 0.012, top: 0.02, right: 0.20, bottom: 0.10, ellipse: false } ] },
    { id: "open-world-bl", name: "Open world · minimap bottom left", fps: 30, target: "auto", feather: 6,
      note: "Round or square minimap in the bottom left corner.",
      regions: [ { left: 0.012, top: 0.72, right: 0.20, bottom: 0.97, ellipse: false } ] },
    { id: "open-world-tr", name: "Open world · minimap top right", fps: 30, target: "auto", feather: 6,
      note: "Minimap or compass in the top right corner.",
      regions: [ { left: 0.80, top: 0.025, right: 0.985, bottom: 0.30, ellipse: false } ] },
    { id: "action-corners", name: "Action · HUD in the bottom corners", fps: 30, target: "auto", feather: 6,
      note: "Health bottom left, weapon and ammo bottom right.",
      regions: [ { left: 0.012, top: 0.80, right: 0.30, bottom: 0.98, ellipse: false },
                 { left: 0.70, top: 0.80, right: 0.988, bottom: 0.98, ellipse: false } ] },
    { id: "racing", name: "Racing · speedometer bottom right", fps: 30, target: "auto", feather: 6,
      note: "Speed, gear and minimap in the bottom right corner.",
      regions: [ { left: 0.72, top: 0.68, right: 0.99, bottom: 0.98, ellipse: false } ] },
    { id: "shooter", name: "Shooter · HUD in all four corners", fps: 30, target: "auto", feather: 4,
      note: "Small elements in every corner.",
      regions: [ { left: 0.01, top: 0.02, right: 0.20, bottom: 0.16, ellipse: false },
                 { left: 0.80, top: 0.02, right: 0.99, bottom: 0.16, ellipse: false },
                 { left: 0.01, top: 0.84, right: 0.24, bottom: 0.98, ellipse: false },
                 { left: 0.76, top: 0.84, right: 0.99, bottom: 0.98, ellipse: false } ] },
    { id: "cinematic", name: "Cinematic · no HUD protection", fps: 30, target: "60", feather: 6,
      note: "Story games and films: the whole picture gets frame generation.",
      regions: [] }
].concat(switchGames())

// Nintendo Switch and Switch 2 games that run at 30 FPS docked (sources: Switch 2 backward
// compatibility reports on ResetEra, NintendoLife and NeoGAF, June 2025; Digital Foundry and
// the howsitrun.com database for Switch 2 games, checked November 2026). Switch games without
// a Switch 2 update stay capped at 30 FPS on Switch 2, usually holding it better than on Switch.
// unstable: the frame rate dips below the cap, so the preset turns on the adaptive multiplier.
// hud: regions only where the layout is well known; the others rely on automatic HUD detection.
function switchGames() {
    var BOTW_HUD = [ { left: 0.03, top: 0.03, right: 0.32, bottom: 0.13, ellipse: false },
                     { left: 0.80, top: 0.70, right: 0.975, bottom: 0.965, ellipse: false } ]
    var SOULS_HUD = [ { left: 0.02, top: 0.03, right: 0.40, bottom: 0.13, ellipse: false },
                      { left: 0.02, top: 0.70, right: 0.20, bottom: 0.97, ellipse: false },
                      { left: 0.82, top: 0.88, right: 0.985, bottom: 0.975, ellipse: false } ]
    var CORNERS_TOP_HUD = [ { left: 0.02, top: 0.03, right: 0.26, bottom: 0.15, ellipse: false },
                            { left: 0.80, top: 0.03, right: 0.985, bottom: 0.30, ellipse: false } ]
    var DOOM_HUD = [ { left: 0.02, top: 0.82, right: 0.30, bottom: 0.98, ellipse: false },
                     { left: 0.72, top: 0.82, right: 0.985, bottom: 0.98, ellipse: false } ]
    function g(id, name, console, opts) {
        opts = opts || {}
        return { id: id, name: name, console: console, fps: opts.fps || 30, target: "auto", feather: 6,
                 adaptive: opts.unstable === true, regions: opts.regions || [],
                 note: (console === "switch" ? "Switch game, 30 FPS on Switch 2 too." : "Switch 2 game, 30 FPS docked.") +
                       (opts.unstable ? " Its frame rate dips, so the adaptive multiplier is on." : "") }
    }
    return [
        // Switch games (30 FPS on Switch and on Switch 2 without an update)
        g("ns-age-of-calamity", "Hyrule Warriors: Age of Calamity", "switch", { unstable: true }),
        g("ns-legends-arceus", "Pokémon Legends: Arceus", "switch"),
        g("ns-botw", "Zelda: Breath of the Wild", "switch", { regions: BOTW_HUD }),
        g("ns-xenoblade-x", "Xenoblade Chronicles X: DE", "switch"),
        g("ns-monster-hunter-rise", "Monster Hunter Rise", "switch"),
        g("ns-witcher3", "The Witcher 3", "switch", { regions: CORNERS_TOP_HUD }),
        g("ns-doom-eternal", "DOOM Eternal", "switch", { regions: DOOM_HUD }),
        g("ns-arkham-knight", "Batman: Arkham Knight", "switch", { unstable: true }),
        g("ns-kcd", "Kingdom Come: Deliverance", "switch"),
        g("ns-smt5", "Shin Megami Tensei V: Vengeance", "switch"),
        g("ns-sparks-of-hope", "Mario + Rabbids Sparks of Hope", "switch"),
        g("ns-animal-crossing", "Animal Crossing: New Horizons", "switch"),
        g("ns-fe-three-houses", "Fire Emblem: Three Houses", "switch"),
        g("ns-fe-engage", "Fire Emblem Engage", "switch"),
        g("ns-persona5", "Persona 5 Royal", "switch"),
        g("ns-lets-go", "Pokémon: Let's Go", "switch"),
        g("ns-dq11", "Dragon Quest XI S", "switch"),
        g("ns-astral-chain", "Astral Chain", "switch"),
        // Switch 2 games (30 FPS docked)
        g("ns2-cyberpunk", "Cyberpunk 2077", "switch2", { unstable: true, regions: CORNERS_TOP_HUD }),
        g("ns2-hogwarts", "Hogwarts Legacy", "switch2"),
        g("ns2-ff7-remake", "Final Fantasy VII Remake", "switch2"),
        g("ns2-ff7-rebirth", "Final Fantasy VII Rebirth", "switch2"),
        g("ns2-outlaws", "Star Wars Outlaws", "switch2", { unstable: true }),
        g("ns2-ac-shadows", "Assassin's Creed Shadows", "switch2"),
        g("ns2-elden-ring", "Elden Ring", "switch2", { unstable: true, regions: SOULS_HUD }),
        g("ns2-indiana-jones", "Indiana Jones and the Great Circle", "switch2"),
        g("ns2-persona3", "Persona 3 Reload", "switch2"),
        g("ns2-lies-of-p", "Lies of P (Quality mode)", "switch2", { regions: SOULS_HUD })
    ]
}

// Consoles a preset can be tied to; "" = any.
var consoleIds = ["ps5", "ps5pro", "xbox", "switch", "switch2", "other"]

function clamp01(v) { v = Number(v); return isFinite(v) ? Math.min(1, Math.max(0, v)) : 0 }

// A clean preset, or null. Accepts the share-code and stored shapes.
function sanitize(p) {
    if (!p || typeof p !== "object") return null
    var name = String(p.name || "").trim().slice(0, kMaxName)
    if (name.length === 0) return null
    var fps = Number(p.fps)
    var regions = []
    var src = Array.isArray(p.regions) ? p.regions : []
    for (var i = 0; i < src.length && regions.length < kMaxRegions; ++i) {
        var r = src[i] || {}
        var l = clamp01(r.left !== undefined ? r.left : r.l), t = clamp01(r.top !== undefined ? r.top : r.t)
        var rr = clamp01(r.right !== undefined ? r.right : r.r), b = clamp01(r.bottom !== undefined ? r.bottom : r.b)
        var q = { left: Math.min(l, rr), top: Math.min(t, b), right: Math.max(l, rr), bottom: Math.max(t, b),
                  ellipse: (r.ellipse !== undefined ? r.ellipse : r.e) === true }
        if (q.right - q.left >= 0.005 && q.bottom - q.top >= 0.005) regions.push(q)
    }
    var feather = Number(p.feather)
    return {
        id: typeof p.id === "string" ? p.id.slice(0, 60) : "",
        name: name,
        fps: fps === 40 || fps === 60 ? fps : 30,
        target: ["auto", "off", "60", "90", "120", "monitor"].indexOf(p.target) >= 0 ? p.target : "auto",
        feather: isFinite(feather) ? Math.min(64, Math.max(0, feather)) : 6,
        note: String(p.note || "").slice(0, 200),
        console: consoleIds.indexOf(p.console) >= 0 ? p.console : "",
        adaptive: p.adaptive === true,
        regions: regions
    }
}

function round3(v) { return Math.round(v * 1000) / 1000 }

// "PUSHFPS1:" + base64 of the compact JSON (UTF-8 safe through URI encoding).
function encode(p, btoa) {
    var s = sanitize(p)
    if (!s) return ""
    var compact = { v: 1, name: s.name, fps: s.fps, target: s.target, feather: s.feather, note: s.note,
                    console: s.console || undefined, adaptive: s.adaptive || undefined,
                    regions: s.regions.map(function (r) {
                        return { l: round3(r.left), t: round3(r.top), r: round3(r.right), b: round3(r.bottom), e: r.ellipse } }) }
    return kCodePrefix + btoa(unescape(encodeURIComponent(JSON.stringify(compact))))
}

// The preset in a share code or a .pushfps file (code or JSON), or null.
function decode(text, atob) {
    var t = String(text || "").trim()
    if (t.length === 0 || t.length > 20000) return null
    try {
        if (t.indexOf(kCodePrefix) === 0)
            return sanitize(JSON.parse(decodeURIComponent(escape(atob(t.slice(kCodePrefix.length).replace(/\s+/g, ""))))))
        return sanitize(JSON.parse(t))
    } catch (e) {
        return null
    }
}

// Adaptive mode: the configured multiplier is a ceiling (engine/PushAdaptiveFg.h), so it
// is the largest offered one that a 20 FPS dip still needs to reach the target, and at
// least the smallest offered one. offered: the backend's multipliers (2 and up).
function adaptiveCeiling(offered, targetFps) {
    var list = (offered || []).filter(function (m) { return m >= 2 }).sort(function (a, b) { return a - b })
    if (list.length === 0) return 0
    var pick = list[0]
    for (var i = 0; i < list.length; ++i) if (20 * list[i] <= targetFps + 0.5) pick = list[i]
    return pick
}

// "auto": 120 FPS on a 120 Hz+ screen when the frame generation offers enough, 90 FPS on a
// 90 Hz screen (3X of a 30 FPS game, 2X of a 40 FPS one), else 60.
function resolveTarget(target, refreshHz) {
    if (target !== "auto") return target
    return refreshHz >= 119 ? "120" : refreshHz > 85 && refreshHz < 95 ? "90" : "60"
}
