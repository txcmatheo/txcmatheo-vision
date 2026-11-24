// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// One channel of the streaming mode's audio mixer (StudioPage.qml), laid out like a row of OBS
// Studio's mixer: name, level in dB, the meter over the fader, mute and the filters (gear) button.
// Extra controls (the microphone's "in recordings / in streams" chips) go in the default slot.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: strip
    property string title: ""
    property string subtitle: ""
    property string iconName: "vol"
    property real value: 0             // fader position, in `from`..`to`
    property real from: -60
    property real to: 0
    property bool decibels: true       // the readout is dB (else percent of `to`)
    property bool muted: false
    property bool meterActive: true
    property real rmsDb: -100
    property real peakDb: -100
    property bool gear: false
    property string gearTip: ""
    default property alias extra: extraRow.data
    signal moved(real value)
    signal muteToggled()
    signal gearClicked()

    implicitHeight: 44
    radius: 8
    color: Theme.ink(0.03)
    border.width: 1
    border.color: Theme.stroke

    readonly property string readout: strip.muted ? qsTr("静音")
        : strip.decibels ? (strip.value <= strip.from ? "-∞ dB" : (strip.value > 0 ? "+" : "") + strip.value.toFixed(1) + " dB")
        : Math.round(strip.value / strip.to * 100) + "%"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10
        VIcon { name: strip.iconName; size: 15; color: strip.muted ? Theme.err : Theme.t2 }
        ColumnLayout {
            Layout.preferredWidth: 118
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: strip.title
                color: Theme.t1
                font.family: Theme.fontUi; font.pixelSize: 12
                font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: strip.subtitle
                color: Theme.t3
                font.family: Theme.fontUi; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        Text {
            objectName: "mixer-readout"
            Layout.preferredWidth: 58
            horizontalAlignment: Text.AlignRight
            text: strip.readout
            color: strip.muted ? Theme.err : Theme.t2
            font.family: Theme.fontMono; font.pixelSize: 11
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            PushLevelMeter {
                Layout.fillWidth: true
                implicitHeight: 6
                active: strip.meterActive && !strip.muted
                rmsDb: strip.rmsDb
                peakDb: strip.peakDb
            }
            VSlider {
                objectName: "mixer-fader"
                Layout.fillWidth: true
                from: strip.from
                to: strip.to
                stepSize: strip.decibels ? 1 : 0.01
                valueFromModel: true
                value: strip.value
                defaultValue: strip.decibels ? 0 : strip.to
                onMoved: v => strip.moved(v)
            }
        }
        RowLayout {
            id: extraRow
            spacing: 6
        }
        // Mute: the speaker, struck through and red while muted.
        Rectangle {
            objectName: "mixer-mute"
            implicitWidth: Theme.ctlHeight; implicitHeight: Theme.ctlHeight
            radius: Theme.rCtl
            color: strip.muted ? Theme.errGlow : muteHover.hovered ? Theme.ink(0.07) : "transparent"
            VIcon { anchors.centerIn: parent; name: "vol"; size: 15; color: strip.muted ? Theme.err : Theme.t2 }
            Rectangle {
                visible: strip.muted
                anchors.centerIn: parent
                width: 20; height: 2; radius: 1
                rotation: -45
                color: Theme.err
            }
            HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: strip.muteToggled() }
            ToolTip.visible: muteHover.hovered
            ToolTip.delay: 500
            ToolTip.text: strip.muted ? qsTr("取消静音") : qsTr("静音")
        }
        VButton {
            objectName: "mixer-gear"
            visible: strip.gear
            icon: true
            ghost: true
            iconName: "sliders"
            tip: strip.gearTip
            onClicked: strip.gearClicked()
        }
    }
}
