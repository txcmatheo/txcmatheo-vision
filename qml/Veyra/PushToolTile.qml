// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// A PushFPS tool in the quick setup (Optimise for my PC, game presets, HUD
// protection, comparison clip): the same card as the home screen's sources,
// an icon, a name and one line on what it does. `primary` gives the icon the
// accent colour; a disabled tile says why in its second line.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: tile
    property string text: ""
    property string sub: ""
    property string iconName: ""
    property bool primary: false
    // Shown as a tooltip after a short hover (the full sentence when `sub` is cut short).
    property string tip: ""
    signal clicked()
    // Narrow tiles (the Professional side panel): the name may take two lines and the
    // second line moves into the tooltip.
    readonly property bool compact: width > 0 && width < 230
    implicitHeight: Math.max(52, textColumn.implicitHeight + 18)
    implicitWidth: 200
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: sub
    Accessible.onPressAction: if (tile.enabled) tile.clicked()
    Keys.onReturnPressed: if (tile.enabled) tile.clicked()
    Keys.onSpacePressed: if (tile.enabled) tile.clicked()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 12
        color: hover.hovered && tile.enabled ? Theme.card2 : Theme.card
        border.width: tile.activeFocus ? 2 : 1
        // (The new design: the edge lights up in the accent under the pointer. Legacy: as it was.)
        border.color: tile.activeFocus ? Theme.accent
                    : hover.hovered && tile.enabled ? (Theme.modern ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75) : Theme.stroke2) : Theme.stroke
        Behavior on border.color { enabled: Theme.modern; ColorAnimation { duration: Theme.d(160) } }
        opacity: tile.enabled ? 1 : 0.55
        scale: tap.pressed ? 0.98 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.d(Theme.durFast) } }
        Behavior on scale { NumberAnimation { duration: Theme.d(400); easing.bezierCurve: Theme.spring } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Rectangle {
                implicitWidth: 32; implicitHeight: 32; radius: 9
                color: tile.primary ? Theme.accent : Theme.ink(0.06)
                VIcon { anchors.centerIn: parent; name: tile.iconName; size: 16; color: tile.primary ? Theme.accentInk : Theme.t1 }
            }
            ColumnLayout {
                id: textColumn
                Layout.fillWidth: true
                spacing: 1
                Text {
                    objectName: "pushfps-tool-title"
                    Layout.fillWidth: true
                    text: tile.text
                    color: Theme.t1
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                    wrapMode: tile.compact ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    objectName: "pushfps-tool-sub"
                    Layout.fillWidth: true
                    visible: text.length > 0 && !tile.compact
                    text: tile.sub
                    color: Theme.t3
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
    HoverHandler { id: hover; cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { id: tap; enabled: tile.enabled; onTapped: tile.clicked() }
    ToolTip.visible: (tile.tip.length > 0 || tile.compact) && hover.hovered
    ToolTip.delay: 600
    ToolTip.text: tile.compact && tile.sub.length > 0 ? tile.sub + (tile.tip.length > 0 ? "\n" + tile.tip : "") : tile.tip
}
