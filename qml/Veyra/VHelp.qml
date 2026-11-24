// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS help mark: a small "?" beside a setting that is hard to understand.
// Hovering it (or clicking or tapping it, or focusing it with the keyboard) shows
// a short explanation of what the setting does. VRow shows one beside its label
// when its `help` text is set.
import QtQuick
import QtQuick.Controls

Item {
    id: help
    objectName: "vhelp"
    property string text: ""
    // Clicked or tapped open (touch screens and keyboard users have no hover).
    property bool pinned: false
    readonly property bool open: text.length > 0 && (hover.hovered || pinned || activeFocus)
    implicitWidth: 16
    implicitHeight: 16
    activeFocusOnTab: text.length > 0
    Accessible.role: Accessible.HelpBalloon
    Accessible.name: qsTr("帮助")
    Accessible.description: text

    Rectangle {
        anchors.centerIn: parent
        width: 15
        height: 15
        radius: 7.5
        color: help.open ? Theme.accentSoft : "transparent"
        border.width: 1
        border.color: help.open ? Theme.accent : Theme.t3
        Behavior on color { ColorAnimation { duration: Theme.d(150) } }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 0.5
            text: "?"
            color: help.open ? Theme.accent : Theme.t3
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.WhatsThisCursor; onHoveredChanged: if (!hovered) help.pinned = false }
    TapHandler { onTapped: help.pinned = !help.pinned }
    Keys.onSpacePressed: help.pinned = !help.pinned
    Keys.onEscapePressed: help.pinned = false

    ToolTip {
        id: popup
        objectName: "vhelp-tip"
        visible: help.open
        delay: help.pinned || help.activeFocus ? 0 : 150
        text: help.text
        y: help.height + 4
        padding: 0
        // Short explanations wrap instead of running across the window.
        contentItem: Text {
            objectName: "vhelp-text"
            width: Math.min(tipMetrics.advanceWidth(help.text) + 1, 300)
            leftPadding: 10; rightPadding: 10; topPadding: 7; bottomPadding: 7
            text: help.text
            color: Theme.t1
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsHint
            lineHeight: 1.15
            wrapMode: Text.WordWrap
        }
        background: Rectangle {
            radius: 8
            color: Theme.popover
            border.width: 1
            border.color: Theme.stroke2
        }
    }
    FontMetrics { id: tipMetrics; font.family: Theme.fontUi; font.pixelSize: Theme.fsHint }
}
