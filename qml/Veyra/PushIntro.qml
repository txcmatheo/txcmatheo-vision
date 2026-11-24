// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS "Sunset City" startup intro, 3.26 s, cut to the startup music's opening (the music file
// of Veyra's runtime package, media/startup-music.mp3; onsets 0.64, 0.76 and 1.12 s, the strongest,
// a breath at 3.16 and the re-entry at 3.26 s):
//   0-0.64 s   a night drive: a neon road grid rushes towards the horizon out of the dark;
//   0.64 s     the first chevron of the logo shoots in from the left and stops dead on the beat,
//              a fading trail of in-between copies behind it (frame generation, made visible);
//   0.76 s     the second chevron lands the same way;
//   1.12 s     the word "PushFPS" is pushed in behind them; on that hit the horizon ignites, the
//              sky turns to sunset, the city rises, palms slide in and a striped sun climbs;
//   1.3-2.6 s  under the logo a counter climbs 30 → 60 → 90 → 120 FPS;
//   2.7-3.26 s the logo glides into its place on the home page and the scene dissolves.
// Every element is drawn from scratch by scripts/brand/make_sunset.py (no game artwork).
//
// One clock (`ms`) drives every frame, as in Veyra's DuskIntro.qml, so the beats stay on the
// sound: with music the clock is the music's position (followMusic), the first frame waits for
// the music (0.7 s at most). A click or a key skips: before the logo has landed the scene fades
// out at once, after it the glide runs 2.5x faster. The software scene graph has no shader
// effects, so this is only Image, Rectangle, Text, opacity and transforms.
import QtQuick

Item {
    id: intro
    // Main.qml API (shared with DuskIntro.qml): the home page logo's rect in this item's coordinates.
    property rect target: Qt.rect(width / 2 - 190, height * 0.2, 380, 156)
    property string skipText: ""
    property real ms: 0
    property bool running: false
    property real speed: 1
    property bool dismissing: false
    property var musicClock: null
    property bool followMusic: false
    property real waited: 0
    property int frames: 0
    property real worstFrameMs: 0
    readonly property real hit1: 640
    readonly property real hit2: 760
    readonly property real hit3: 1120
    readonly property real handoffAt: 2700
    readonly property real total: 3262
    readonly property real landedAt: hit3

    signal frame()
    signal revealHome()
    signal finished()

    function start() { running = true; forceActiveFocus() }
    function skip() {
        if (dismissing || ms >= total) return
        if (ms < landedAt) { dismiss(); return }
        if (ms < handoffAt) ms = handoffAt
        followMusic = false
        speed = 2.5
    }
    function dismiss() {
        if (dismissing) return
        dismissing = true
        revealHome()
        fadeOut.start()
    }
    NumberAnimation { id: fadeOut; target: intro; property: "opacity"; to: 0; duration: 220; easing.type: Easing.OutCubic; onFinished: intro.finished() }
    FrameAnimation {
        running: intro.running && !intro.dismissing
        onTriggered: {
            intro.frame()
            ++intro.frames
            if (intro.frames > 2) intro.worstFrameMs = Math.max(intro.worstFrameMs, frameTime * 1000)
            const step = Math.min(frameTime * 1000, 34)
            let next = intro.ms + step * intro.speed
            if (intro.followMusic) {
                const music = intro.musicClock ? intro.musicClock() : -1
                if (music >= 0) next = Math.max(intro.ms, music)
                else if ((intro.waited += step) < 700) next = intro.ms
                else intro.followMusic = false
            }
            intro.ms = Math.min(intro.total, next)
            if (intro.ms >= intro.total) {
                intro.running = false
                intro.revealHome()
                intro.finished()
            }
        }
    }

    // --- timeline helpers ------------------------------------------------------------------
    function clamp01(x) { return x < 0 ? 0 : x > 1 ? 1 : x }
    function at(a, b) { return clamp01((ms - a) / (b - a)) }
    function atT(t, a, b) { return clamp01((t - a) / (b - a)) }
    function mix(a, b, t) { return a + (b - a) * t }
    function mixc(a, b, t) { return Qt.rgba(mix(a.r, b.r, t), mix(a.g, b.g, t), mix(a.b, b.b, t), 1) }
    function outCubic(t) { return 1 - Math.pow(1 - t, 3) }
    function outExpo(t) { return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t) }
    function inOutSine(t) { return (1 - Math.cos(Math.PI * t)) / 2 }
    function inOutQuart(t) { return t < 0.5 ? 8 * t * t * t * t : 1 - Math.pow(-2 * t + 2, 4) / 2 }
    function rnd(i, k) { const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453; return x - Math.floor(x) }
    // A hit at `beat`: a quick rise and a slower decay, 0..1.
    function kick(t, beat, len) { const p = (t - beat) / len; return p < 0 || p > 1 ? 0 : Math.sin(Math.PI * Math.min(1, p * 4)) * (1 - p) }
    // How far a layer still has to travel (0 = in place): it accelerates into its beat and stops dead.
    function travel(t, start, land) { const p = atT(t, start, land); return 1 - p * p * p }

    // --- derived state ---------------------------------------------------------------------
    readonly property real warm: inOutSine(at(hit3, 2400))                    // night -> sunset
    readonly property real horizonOn: outExpo(at(hit3, hit3 + 300))
    readonly property real cityUp: outCubic(at(hit3, hit3 + 700))
    readonly property real palmsIn: outCubic(at(hit3 + 40, hit3 + 760))
    readonly property real sunUp: outCubic(at(1250, 2650)) * (1 - inOutSine(at(handoffAt, total)))
    readonly property real roadOn: outCubic(at(60, 640))
    readonly property real glide: inOutQuart(at(handoffAt, total))
    readonly property real scene: 1 - inOutSine(at(handoffAt + 80, total))
    readonly property real camera: 1 + 0.018 * kick(ms, hit1, 260) + 0.014 * kick(ms, hit2, 260) + 0.04 * kick(ms, hit3, 420)
                                   + 0.035 * outCubic(at(hit3, handoffAt))
    readonly property real flash: 0.55 * kick(ms, hit3, 380)

    // Hero logo: big and centred, then the home page logo's art rect (its image carries a glow margin).
    readonly property real logoAspect: 1200 / 410
    readonly property real heroW: Math.round(Math.min(width * 0.64, height * 1.55, 1000))
    readonly property real heroH: Math.round(heroW / logoAspect)
    readonly property real horizonY: Math.round(height * 0.64)
    readonly property real artX: target.x + target.width * 70 / 1340
    readonly property real artY: target.y + target.height * 70 / 550
    readonly property real artW: target.width * 1200 / 1340
    readonly property real logoW: mix(heroW * camera, artW, glide)
    readonly property real logoH: logoW / logoAspect
    readonly property real logoX: mix(width / 2 - heroW * camera / 2, artX, glide)
    readonly property real logoY: mix(height * 0.36 - heroH * camera / 2, artY, glide)

    focus: true
    Keys.onPressed: event => { intro.skip(); event.accepted = true }
    MouseArea { anchors.fill: parent; onClicked: intro.skip() }

    // --- sky ---------------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        opacity: intro.scene
        gradient: Gradient {
            GradientStop { position: 0.0; color: intro.mixc(Qt.rgba(0.02, 0.01, 0.05, 1), Qt.rgba(0.09, 0.03, 0.2, 1), intro.warm) }
            GradientStop { position: 0.36; color: intro.mixc(Qt.rgba(0.04, 0.02, 0.1, 1), Qt.rgba(0.36, 0.1, 0.52, 1), intro.warm) }
            GradientStop { position: 0.52; color: intro.mixc(Qt.rgba(0.07, 0.03, 0.14, 1), Qt.rgba(0.85, 0.2, 0.55, 1), intro.warm) }
            GradientStop { position: 0.64; color: intro.mixc(Qt.rgba(0.12, 0.04, 0.2, 1), Qt.rgba(1.0, 0.55, 0.3, 1), intro.warm) }
            GradientStop { position: 0.641; color: Qt.rgba(0.05, 0.02, 0.1, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.01, 0.04, 1) }
        }
    }
    // Stars, gone once the sky warms.
    Repeater {
        model: 46
        Rectangle {
            required property int index
            x: intro.rnd(index, 1) * intro.width
            y: intro.rnd(index, 2) * intro.horizonY * 0.8
            width: 1 + Math.round(intro.rnd(index, 3) * 2); height: width; radius: width / 2
            color: "#FFE9F6"
            opacity: intro.scene * (1 - intro.warm) * (0.3 + 0.7 * Math.abs(Math.sin(intro.ms / (300 + intro.rnd(index, 4) * 500) + index)))
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: intro.scene
        transformOrigin: Item.Center
        scale: 1 + (intro.camera - 1) * 0.5

        // Sun, behind the city and the sea.
        Image {
            readonly property real d: Math.min(intro.heroW * 0.6, intro.horizonY * 0.7)
            source: "sunset-sun.png"
            width: d * 1.9; height: width          // the image has a glow margin of 0.45 D on every side
            x: intro.width / 2 - width / 2
            y: intro.mix(intro.horizonY + d * 0.15, intro.horizonY - d * 0.3, intro.sunUp) - height / 2
            opacity: intro.sunUp > 0 ? 1 : 0
            smooth: true
        }
        // City, rising from the horizon and drifting slowly.
        Image {
            source: "sunset-skyline.png"
            width: intro.width * 1.3; height: width * 420 / 2400 * 0.72   // kept low, under the logo
            x: -intro.width * 0.15 - intro.ms * 0.012
            y: intro.horizonY - height + (1 - intro.cityUp) * intro.height * 0.1
            opacity: intro.cityUp
            smooth: true
        }
        // Sea and road below the horizon.
        Rectangle {
            x: 0; y: intro.horizonY; width: intro.width; height: intro.height - intro.horizonY
            gradient: Gradient {
                GradientStop { position: 0; color: intro.mixc(Qt.rgba(0.08, 0.03, 0.15, 1), Qt.rgba(0.3, 0.08, 0.42, 1), intro.warm) }
                GradientStop { position: 1; color: Qt.rgba(0.02, 0.01, 0.04, 1) }
            }
        }
        Image {
            source: "sunset-road.png"
            width: intro.width * 1.7; height: (intro.height - intro.horizonY) * 1.02
            x: intro.width / 2 - width / 2; y: intro.horizonY
            opacity: intro.roadOn * 0.9
            smooth: true
        }
        // Road lines rushing towards the viewer (perspective: depth squared).
        Repeater {
            model: 11
            Rectangle {
                required property int index
                readonly property real near: ((index + (intro.ms / 520) % 1) / 11)   // 0 at the horizon, 1 at the viewer
                readonly property real depth: Math.pow(near, 2.3)
                x: 0; width: intro.width
                y: intro.horizonY + (intro.height - intro.horizonY) * depth
                height: 1 + depth * 4
                color: "#FF4FB8"
                opacity: intro.roadOn * near * 0.85
            }
        }
        // The horizon line ignites on the big hit.
        Rectangle {
            x: 0; width: intro.width; height: 2; y: intro.horizonY - 1
            color: "#FFD2E6"
            opacity: intro.horizonOn * 0.9
        }
        Rectangle {
            x: 0; width: intro.width; height: intro.height * 0.16; y: intro.horizonY - height / 2
            opacity: intro.horizonOn * (0.55 + intro.flash)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 0.3, 0.6, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.45, 0.6, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(1, 0.3, 0.6, 0) }
            }
        }
        // Palms in the foreground, sliding in from the sides.
        Image {
            source: "sunset-palm.png"
            height: intro.height * 0.78; width: height * 0.9
            x: intro.mix(-width, -width * 0.12, intro.palmsIn); y: intro.height - height * 0.98
            smooth: true
        }
        Image {
            source: "sunset-palm.png"
            mirror: true
            height: intro.height * 0.66; width: height * 0.9
            x: intro.width - intro.mix(0, width * 0.86, intro.palmsIn); y: intro.height - height * 0.96
            smooth: true
        }
    }

    // --- the logo ----------------------------------------------------------------------------
    // Dark haze behind the logo so the letters stay readable over the bright sunset scene.
    Image {
        source: "sunset-shade.png"
        width: intro.logoW * 1.7; height: intro.logoH * 2.4
        x: intro.logoX + intro.logoW / 2 - width / 2; y: intro.logoY + intro.logoH / 2 - height / 2
        opacity: intro.scene * (0.35 + 0.6 * intro.warm)
        smooth: true
    }
    Image {
        // glow canvas: 1340x550 for 1200x410 art (70 px margin at this scale)
        source: "sunset-logo-glow.png"
        width: intro.logoW * 1340 / 1200; height: intro.logoH * 550 / 410
        x: intro.logoX - intro.logoW * 70 / 1200; y: intro.logoY - intro.logoH * 70 / 410
        opacity: (1 - intro.glide) * intro.outCubic(intro.at(intro.hit3, intro.hit3 + 260)) * (0.85 + 0.15 * Math.sin(intro.ms / 260))
        smooth: true
    }
    // The logo parts, each sliding in to its beat with a trail of in-between copies. (A Repeater,
    // not an inline component: inline components do not see this file's ids.)
    Repeater {
        model: [{ src: "sunset-logo-push.png", start: 860, land: intro.hit3 },
                { src: "sunset-logo-fps.png", start: 900, land: intro.hit3 },
                { src: "sunset-logo-chev1.png", start: 360, land: intro.hit1 },
                { src: "sunset-logo-chev2.png", start: 500, land: intro.hit2 }]
        Item {
            id: part
            required property var modelData
            readonly property real squash: 1 + 0.08 * intro.kick(intro.ms, modelData.land, 200)
            function offset(t) { return -intro.width * 0.9 * intro.travel(t, modelData.start, modelData.land) * intro.logoW / intro.heroW }
            x: intro.logoX; y: intro.logoY; width: intro.logoW; height: intro.logoH
            visible: intro.ms >= modelData.start
            Repeater {
                model: 3        // ghosts at three earlier moments
                Image {
                    required property int index
                    source: part.modelData.src
                    width: part.width; height: part.height
                    x: part.offset(intro.ms - (3 - index) * 34)
                    opacity: intro.ms < part.modelData.land ? 0.14 + index * 0.1 : 0
                    smooth: true
                }
            }
            Image {
                source: part.modelData.src
                width: part.width; height: part.height
                x: part.offset(intro.ms)
                transform: Scale { origin.x: part.width; origin.y: part.height / 2; xScale: 1 / part.squash; yScale: part.squash }
                smooth: true
            }
        }
    }

    // 30 → 120 FPS under the logo.
    Text {
        readonly property int value: intro.ms < 1550 ? 30 : intro.ms < 1850 ? 60 : intro.ms < 2150 ? 90 : 120
        text: value + " FPS"
        anchors.horizontalCenter: parent.horizontalCenter
        y: intro.logoY + intro.logoH * 1.08
        color: value === 120 ? "#FFD27A" : "#FFE9F6"
        font.family: "Bahnschrift"
        font.italic: true
        font.weight: Font.Bold
        font.pixelSize: Math.round(intro.heroH * 0.2)
        style: Text.Outline; styleColor: Qt.rgba(1, 0.24, 0.55, 0.6)
        opacity: intro.at(1300, 1460) * (1 - intro.at(2500, intro.handoffAt))
        scale: 1 + 0.06 * (intro.kick(intro.ms, 1550, 200) + intro.kick(intro.ms, 1850, 200) + intro.kick(intro.ms, 2150, 200) + intro.kick(intro.ms, 2450, 260))
    }

    // Vignette and the flash on the big hit.
    Rectangle {
        anchors.fill: parent
        opacity: intro.scene * 0.55
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.7) }
            GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.8; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) }
        }
    }
    Rectangle { anchors.fill: parent; color: "#FFE3EF"; opacity: intro.flash * 0.35 }

    Text {
        text: intro.skipText
        visible: text.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        color: Qt.rgba(1, 1, 1, 0.45)
        font.family: Theme.fontUi
        font.pixelSize: 12
        opacity: intro.scene * intro.at(400, 900)
    }
}
