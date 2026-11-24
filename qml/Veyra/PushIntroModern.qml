// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The new design's startup animation (the legacy design keeps the Sunset City intro, PushIntro.qml).
// About two seconds on the new graphite: a lime line opens from the centre, the PushFPS mark rises
// over it, the wordmark comes up from behind the line, one bright frame runs along the line while the
// window's edge lights up once in lime, and then everything lets go into the interface behind it.
//
// It has the interface the main window drives the Sunset intro through (ms, running, dismissing,
// followMusic, frames, worstFrameMs, start(), dismiss(), frame / revealHome / finished), so the same
// loader, the same "skip with a click or any key" and the same --intro-at screenshot switch serve
// both. Every value on screen is a function of `ms` alone: a held `ms` is a held picture.
import QtQuick

Item {
    id: intro
    property rect target: Qt.rect(0, 0, 0, 0)     // unused here: nothing glides into the home page
    property string skipText: ""
    property real ms: 0
    property bool running: false
    property real speed: 1
    property bool dismissing: false
    property var musicClock: null
    property bool followMusic: false
    property int frames: 0
    property real worstFrameMs: 0
    readonly property real lineAt: 80
    readonly property real markAt: 260
    readonly property real wordAt: 620
    readonly property real sweepAt: 980
    readonly property real handoffAt: 1650
    readonly property real total: 2150

    signal frame()
    signal revealHome()
    signal finished()

    function start() { running = true; forceActiveFocus() }
    function skip() { dismiss() }
    function dismiss() {
        if (dismissing) return
        dismissing = true
        revealHome()
        fadeOut.start()
    }
    NumberAnimation { id: fadeOut; target: intro; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic; onFinished: intro.finished() }
    property bool revealed: false
    FrameAnimation {
        running: intro.running && !intro.dismissing
        onTriggered: {
            intro.frame()
            ++intro.frames
            if (intro.frames > 2) intro.worstFrameMs = Math.max(intro.worstFrameMs, frameTime * 1000)
            const step = Math.min(frameTime * 1000, 34)
            intro.ms = Math.min(intro.total, intro.ms + step * intro.speed)
            // The interface behind starts to show while the mark lets go.
            if (!intro.revealed && intro.ms >= intro.handoffAt) { intro.revealed = true; intro.revealHome() }
            if (intro.ms >= intro.total) {
                intro.running = false
                if (!intro.revealed) { intro.revealed = true; intro.revealHome() }
                intro.finished()
            }
        }
    }
    focus: true
    Keys.onPressed: event => { event.accepted = true; intro.skip() }
    TapHandler { acceptedButtons: Qt.AllButtons; onTapped: intro.skip() }

    function clamp01(x) { return x < 0 ? 0 : x > 1 ? 1 : x }
    function at(a, b) { return clamp01((ms - a) / (b - a)) }
    function outCubic(t) { return 1 - Math.pow(1 - t, 3) }
    function outExpo(t) { return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t) }
    function inOutSine(t) { return (1 - Math.cos(Math.PI * t)) / 2 }
    // A pulse: up in the first fifth of a..b, down over the rest, 0 outside.
    function pulse(a, b) {
        const p = (ms - a) / (b - a)
        if (p <= 0 || p >= 1) return 0
        return p < 0.2 ? outCubic(p / 0.2) : Math.pow(1 - (p - 0.2) / 0.8, 2)
    }

    readonly property real lineOn: outExpo(at(lineAt, lineAt + 520))
    readonly property real markOn: outExpo(at(markAt, markAt + 620))
    readonly property real wordOn: outCubic(at(wordAt, wordAt + 520))
    readonly property real sweep: inOutSine(at(sweepAt, sweepAt + 560))
    readonly property real edge: pulse(sweepAt - 40, sweepAt + 700)
    readonly property real away: inOutSine(at(handoffAt, total))
    // The colours of the design it opens (the theme is known before the first frame).
    readonly property color lime: Theme.accentPair ? (Theme.light ? Theme.accentPair.light : Theme.accentPair.dark) : "#89F52A"
    readonly property real unit: Math.max(0.7, Math.min(1.5, Math.min(width / 1280, height / 720)))

    // The ground: the window's own colour, so nothing jumps when the intro lets go.
    Rectangle { anchors.fill: parent; radius: Theme.rWindow; color: Theme.bgOuter; opacity: 1 - intro.away }

    Item {
        id: stage
        anchors.centerIn: parent
        width: 520 * intro.unit
        height: 260 * intro.unit
        opacity: 1 - intro.away
        scale: 1 + 0.06 * intro.away
        // The mark: the PushFPS logo, rising over the line.
        Image {
            id: mark
            source: Theme.logoImage
            width: 104 * intro.unit
            height: width
            sourceSize.width: 256; sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            x: (stage.width - width) / 2
            y: stage.height / 2 - height - 22 * intro.unit + (1 - intro.markOn) * 26 * intro.unit
            opacity: intro.markOn
            scale: 0.86 + 0.14 * intro.markOn
        }
        // The line: opens from the centre.
        Rectangle {
            id: line
            height: Math.max(2, 2 * intro.unit)
            width: stage.width * 0.78 * intro.lineOn
            x: (stage.width - width) / 2
            y: stage.height / 2
            radius: height / 2
            color: intro.lime
            opacity: 0.35 + 0.65 * Math.max(intro.lineOn * (1 - intro.wordOn * 0.5), intro.edge)
        }
        // Its glow: lime at the line, nothing a few pixels above and below.
        Rectangle {
            width: line.width; height: 26 * intro.unit
            x: line.x; y: line.y - height / 2 + line.height / 2
            opacity: 0.16 * intro.lineOn + 0.30 * intro.edge
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: intro.lime }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // One bright frame runs along the line, left to right.
        Rectangle {
            visible: intro.sweep > 0 && intro.sweep < 1
            width: 96 * intro.unit
            height: line.height + 2
            x: line.x + (line.width - width) * intro.sweep
            y: line.y - 1
            radius: height / 2
            opacity: Math.sin(Math.PI * intro.sweep)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: "#FFFFFF" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // The wordmark: comes up from behind the line.
        Item {
            id: wordClip
            x: 0; y: line.y + 14 * intro.unit
            width: stage.width
            height: 64 * intro.unit
            clip: true
            PushWordmark {
                id: word
                pixelSize: 44 * intro.unit
                x: (wordClip.width - width) / 2
                y: (1 - intro.wordOn) * -wordClip.height
                opacity: intro.wordOn
            }
        }
    }
    // The window's edge lights up once in lime, as an option's edge does under the pointer.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.rWindow
        color: "transparent"
        border.width: 2
        border.color: intro.lime
        opacity: 0.85 * intro.edge * (1 - intro.away)
    }
    Text {
        visible: intro.skipText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        text: intro.skipText
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        opacity: 0.8 * intro.at(500, 900) * (1 - intro.away)
    }
}
