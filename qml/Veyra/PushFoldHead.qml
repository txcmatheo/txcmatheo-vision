// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The title of a block that folds (4.3.1: Quality, Frame Gen, Color, Audio and Display in Professional
// mode's All tab). It only says what is asked: the page keeps which blocks are folded and hides or
// shows the block itself (with `visible`, never by shrinking it: a layout keeps the height of an item
// whose own height reaches 0, see PushSection.qml).
import QtQuick
import QtQuick.Layouts

Item {
    id: head
    property string text: ""
    property bool open: true
    signal toggled(bool open)

    Layout.fillWidth: true
    implicitHeight: 34
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: head.toggled(!head.open)
    Keys.onSpacePressed: head.toggled(!head.open)
    Keys.onReturnPressed: head.toggled(!head.open)
    Keys.onEnterPressed: head.toggled(!head.open)

    Rectangle {
        anchors.fill: parent
        radius: Theme.rCtl
        readonly property bool lit: headHover.hovered || head.activeFocus
        color: lit ? Theme.ink(0.04) : "transparent"
        border.width: 1
        border.color: lit ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.d(160) } }
        Behavior on border.color { ColorAnimation { duration: Theme.d(160) } }
    }
    Text {
        objectName: "pushfps-fold-title"
        x: 8
        width: parent.width - x - 34
        anchors.verticalCenter: parent.verticalCenter
        text: head.text
        elide: Text.ElideRight
        color: Theme.t1
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsH3
        font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
    }
    VIcon {
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        name: "down"
        color: headHover.hovered ? Theme.t1 : Theme.t3
        rotation: head.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.d(260); easing.type: Easing.OutCubic } }
    }
    HoverHandler { id: headHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: head.toggled(!head.open) }
}
