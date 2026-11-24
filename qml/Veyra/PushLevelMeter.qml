// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
// A horizontal level meter for the streaming mode's audio mixer (StudioPage.qml), coloured like OBS
// Studio's: green below -20 dBFS, yellow to -9, red above. The bar is the RMS level, the thin line
// the peak, held for a second; both on a -60..0 dB scale (StudioLayout.meterPosition).
import QtQuick
import "StudioLayout.js" as StudioGeometry

Item {
    id: meter
    property real rmsDb: -100
    property real peakDb: -100
    property bool active: true
    property real holdDb: -100
    implicitHeight: 8
    onPeakDbChanged: {
        if (peakDb >= holdDb) { holdDb = peakDb; holdTimer.restart() }
    }
    Timer { id: holdTimer; interval: 1000; onTriggered: meter.holdDb = meter.peakDb }

    // The three zones, dim: the scale itself.
    Row {
        anchors.fill: parent
        opacity: meter.active ? 0.22 : 0.1
        Rectangle { width: parent.width * 40 / 60; height: parent.height; color: Theme.ok }
        Rectangle { width: parent.width * 11 / 60; height: parent.height; color: Theme.warn }
        Rectangle { width: parent.width * 9 / 60; height: parent.height; color: Theme.err }
    }
    // The level: the same zones, lit up to the RMS level.
    Item {
        objectName: "meter-level"
        width: parent.width * StudioGeometry.meterPosition(meter.rmsDb)
        height: parent.height
        clip: true
        visible: meter.active
        Row {
            width: meter.width; height: parent.height
            Rectangle { width: meter.width * 40 / 60; height: parent.height; color: Theme.ok }
            Rectangle { width: meter.width * 11 / 60; height: parent.height; color: Theme.warn }
            Rectangle { width: meter.width * 9 / 60; height: parent.height; color: Theme.err }
        }
    }
    // Peak, and the held peak.
    Rectangle {
        visible: meter.active && meter.peakDb > -60
        x: Math.max(0, meter.width * StudioGeometry.meterPosition(meter.peakDb) - 2)
        width: 2; height: parent.height
        color: meter.peakDb > -9 ? Theme.err : Theme.t1
        opacity: 0.85
    }
    Rectangle {
        visible: meter.active && meter.holdDb > -60
        x: Math.max(0, meter.width * StudioGeometry.meterPosition(meter.holdDb) - 2)
        width: 2; height: parent.height
        color: meter.holdDb > -9 ? Theme.err : meter.holdDb > -20 ? Theme.warn : Theme.ok
    }
}
