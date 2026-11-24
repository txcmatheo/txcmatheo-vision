// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Microphone filters for recordings and streams (the gear on the streaming mode's microphone
// channel, dialog key "micfilters"): rumble filter, 5-band EQ with presets, noise gate and
// compressor, then a limiter that is always on. They run once on the microphone capture thread
// (engine/PushAudioMix.h), so every recording, the instant replay and every stream get the same
// voice. Preferences micHighPass, micEqOn, micEq ("a,b,c,d,e" dB), micGate, micGateDb, micCompressor.
import QtQuick
import QtQuick.Layouts

DialogLayer {
    id: filters
    objectName: "pushfps-mic-filters"
    key: "micfilters"
    glyph: "sliders"
    title: qsTr("麦克风滤镜")
    sub: qsTr("只影响录制和直播里的麦克风声音，不改变你自己听到的声音")
    dialogWidth: 600

    readonly property var bandLabels: ["100 Hz", "300 Hz", "1 kHz", "3.5 kHz", "10 kHz"]
    readonly property var bandHz: [100, 300, 1000, 3500, 10000]
    readonly property var eq: {
        const parts = String(veyra.preferences.micEq || "").split(",").map(Number)
        return parts.length === 5 && parts.every(v => isFinite(v)) ? parts : [0, 0, 0, 0, 0]
    }
    readonly property bool eqOn: veyra.preferences.micEqOn === true
    // EQ presets for a voice: id, label, gains per band.
    readonly property var presets: [
        { id: "flat", label: qsTr("平直"), gains: [0, 0, 0, 0, 0] },
        { id: "clear", label: qsTr("人声清晰"), gains: [-2, -3, 0, 4, 2] },
        { id: "broadcast", label: qsTr("广播"), gains: [3, -2, 0, 3, 1] },
        { id: "warm", label: qsTr("温暖"), gains: [2, 1, 0, -1, -2] },
        { id: "headset", label: qsTr("耳机麦克风"), gains: [-4, -2, 1, 3, 0] }
    ]
    function presetOf(gains) {
        const p = filters.presets.find(x => x.gains.every((g, i) => g === gains[i]))
        return p ? p.label : qsTr("自定义")
    }
    function setBand(band, db) {
        const next = filters.eq.slice()
        next[band] = Math.max(-12, Math.min(12, Math.round(db * 2) / 2))
        veyra.setPreference("micEq", next.join(","))
        if (!filters.eqOn) veyra.setPreference("micEqOn", true)
    }
    function applyPreset(id) {
        const p = filters.presets.find(x => x.id === id)
        if (!p) return
        veyra.setPreference("micEq", p.gains.join(","))
        veyra.setPreference("micEqOn", id !== "flat")
    }
    // RBJ biquad magnitude in dB (the same filters PushAudioMix.h runs), for the curve.
    function biquadDb(kind, hz0, q, gainDb, hz) {
        const rate = 48000, w0 = 2 * Math.PI * Math.min(Math.max(hz0, 10), rate * 0.45) / rate
        const cw = Math.cos(w0), sw = Math.sin(w0), A = Math.pow(10, gainDb / 40)
        let b0, b1, b2, a0, a1, a2
        if (kind === "peak") {
            const alpha = sw / (2 * q)
            b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A; a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A
        } else if (kind === "hp") {
            const alpha = sw / (2 * q)
            b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
        } else {
            const alpha = sw / 2 * Math.sqrt((A + 1 / A) * (1 / q - 1) + 2), k = 2 * Math.sqrt(A) * alpha
            if (kind === "low") {
                b0 = A * ((A + 1) - (A - 1) * cw + k); b1 = 2 * A * ((A - 1) - (A + 1) * cw); b2 = A * ((A + 1) - (A - 1) * cw - k)
                a0 = (A + 1) + (A - 1) * cw + k; a1 = -2 * ((A - 1) + (A + 1) * cw); a2 = (A + 1) + (A - 1) * cw - k
            } else {
                b0 = A * ((A + 1) + (A - 1) * cw + k); b1 = -2 * A * ((A - 1) + (A + 1) * cw); b2 = A * ((A + 1) + (A - 1) * cw - k)
                a0 = (A + 1) - (A - 1) * cw + k; a1 = 2 * ((A - 1) - (A + 1) * cw); a2 = (A + 1) - (A - 1) * cw - k
            }
        }
        b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
        const w = 2 * Math.PI * hz / rate
        const nr = b0 + b1 * Math.cos(w) + b2 * Math.cos(2 * w), ni = -b1 * Math.sin(w) - b2 * Math.sin(2 * w)
        const dr = 1 + a1 * Math.cos(w) + a2 * Math.cos(2 * w), di = -a1 * Math.sin(w) - a2 * Math.sin(2 * w)
        return 10 * Math.log10((nr * nr + ni * ni) / Math.max(1e-30, dr * dr + di * di))
    }
    function responseDb(hz) {
        let db = 0
        if (veyra.preferences.micHighPass === true) db += filters.biquadDb("hp", 80, 0.707, 0, hz)
        if (filters.eqOn)
            for (let b = 0; b < 5; ++b) {
                const g = filters.eq[b]
                if (g === 0) continue
                db += filters.biquadDb(b === 0 ? "low" : b === 4 ? "high" : "peak", filters.bandHz[b], b === 0 || b === 4 ? 0.9 : 1.0, g, hz)
            }
        return db
    }

    DialogGroup {
        VRow {
            label: qsTr("低频滤除")
            hint: qsTr("去掉 80 Hz 以下的嗡嗡声、桌面震动和风扇声")
            VSwitch {
                objectName: "mic-highpass"
                checked: veyra.preferences.micHighPass === true
                onToggled: v => veyra.setPreference("micHighPass", v)
            }
        }
        VRow {
            label: qsTr("噪声门")
            hint: veyra.preferences.micGate === true
                  ? qsTr("低于 %1 dB 时静音：不说话时听不到键盘和背景声").arg(Number(veyra.preferences.micGateDb ?? -45))
                  : qsTr("不说话时自动静音，挡住键盘、风扇和房间噪音")
            RowLayout {
                spacing: 8
                VSlider {
                    objectName: "mic-gate-threshold"
                    visible: veyra.preferences.micGate === true
                    implicitWidth: 130
                    from: -80; to: -10; stepSize: 1
                    valueFromModel: true
                    value: Number(veyra.preferences.micGateDb ?? -45)
                    resettable: true; defaultValue: -45
                    live: false
                    onMoved: v => veyra.setPreference("micGateDb", Math.round(v))
                }
                VSwitch {
                    objectName: "mic-gate"
                    checked: veyra.preferences.micGate === true
                    onToggled: v => veyra.setPreference("micGate", v)
                }
            }
        }
        VRow {
            label: qsTr("压缩器")
            hint: qsTr("让大声和小声更接近，喊叫不爆音、轻声也听得清（3:1，-18 dB 起）")
            VSwitch {
                objectName: "mic-compressor"
                checked: veyra.preferences.micCompressor === true
                onToggled: v => veyra.setPreference("micCompressor", v)
            }
        }
        VRow {
            label: qsTr("均衡器")
            hint: filters.eqOn ? filters.presetOf(filters.eq) : qsTr("调整声音的低频、中频和高频")
            RowLayout {
                spacing: 8
                VSelect {
                    objectName: "mic-eq-preset"
                    implicitWidth: 130
                    options: filters.presets.map(p => ({ id: p.id, label: p.label }))
                    value: filters.presetOf(filters.eq)
                    onPicked: id => filters.applyPreset(id)
                }
                VSwitch {
                    objectName: "mic-eq"
                    checked: filters.eqOn
                    onToggled: v => veyra.setPreference("micEqOn", v)
                }
            }
        }
    }

    // The rumble filter and EQ response, 20 Hz to 20 kHz, ±12 dB.
    Canvas {
        id: curve
        objectName: "mic-eq-curve"
        visible: filters.eqOn || veyra.preferences.micHighPass === true
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 64
        property var points: {
            const out = []
            for (let i = 0; i <= 60; ++i) out.push(filters.responseDb(20 * Math.pow(1000, i / 60)))
            return out
        }
        onPointsChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height, mid = h / 2
            ctx.strokeStyle = Theme.ink(0.08)
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(w, mid); ctx.stroke()
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 2
            ctx.beginPath()
            for (let i = 0; i < points.length; ++i) {
                const x = i / (points.length - 1) * w
                const y = mid - Math.max(-12, Math.min(12, points[i])) / 12 * (mid - 4)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; text: "20 Hz"; color: Theme.t3; font.pixelSize: 10; font.family: Theme.fontUi }
        Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "20 kHz"; color: Theme.t3; font.pixelSize: 10; font.family: Theme.fontUi }
    }

    DialogGroup {
        visible: filters.eqOn
        Repeater {
            model: filters.eqOn ? 5 : 0
            delegate: VRow {
                required property int index
                objectName: "mic-eq-band-" + index
                label: filters.bandLabels[index]
                value: (filters.eq[index] > 0 ? "+" : "") + filters.eq[index].toFixed(1) + " dB"
                VSlider {
                    objectName: "mic-eq-slider-" + index
                    implicitWidth: 170
                    center: true
                    from: -12; to: 12; stepSize: 0.5
                    valueFromModel: true
                    value: filters.eq[index]
                    resettable: true; defaultValue: 0
                    live: false
                    onMoved: v => filters.setBand(index, v)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: qsTr("最后总有一个 -1 dB 的限幅器，防止爆音。滤镜在麦克风开启录制或直播时生效")
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    actions: [{ label: qsTr("全部关闭") }, { label: qsTr("完成"), primary: true }]
    onActionTriggered: label => {
        if (label === qsTr("全部关闭")) {
            veyra.setPreference("micHighPass", false)
            veyra.setPreference("micGate", false)
            veyra.setPreference("micCompressor", false)
            veyra.setPreference("micEqOn", false)
        } else filters.dialogHost.close()
    }
}
