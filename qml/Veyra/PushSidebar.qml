// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The new design's navigation: every mode of the app by name, always on screen in a window (the
// legacy design's dock is an icon capsule that shows on hover). It changes nothing about the pages:
// an entry asks the shell for the same page id the dock asks for. At the bottom stands the palette
// button that opens the Appearance panel (the design itself, themes, colours).
//
// An entry's edge lights up in the accent while the pointer is over it; the current page is filled.
// Under `slim` only the icons are shown, each with its name as a tooltip.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: nav
    objectName: "pushfps-nav"
    property string currentPage: "home"
    property bool slim: false
    signal requestPage(string page)
    signal requestAppearance()

    // The same pages, in the same order, as the legacy dock (TopDock.qml), with the home page first.
    // (Not read-only: the Linux and macOS preview, which shares this file, has fewer pages.)
    property var entries: [
        { id: "home",  icon: "home",     label: qsTr("首页") },
        { id: "pro",   icon: "sliders",  label: qsTr("专业模式") },
        { id: "live",  icon: "cast",     label: qsTr("直播模式") },
        { id: "watch", icon: "play",     label: qsTr("视频播放模式") },
        { id: "exp",   icon: "upload",   label: qsTr("导出") },
        { id: "min",   icon: "tv",       label: qsTr("极简") },
        { id: "set",   icon: "settings", label: qsTr("设置") }
    ]

    color: Theme.card
    bottomLeftRadius: Theme.rWindow

    component Entry: Item {
        id: entry
        property string pageId: ""
        property string glyph: ""
        property string text: ""
        property bool current: false
        // (An inline component stands on its own: it does not see this file's ids, so the width's state is handed in.)
        property bool slim: false
        signal picked()
        Layout.fillWidth: true
        implicitHeight: 40
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        Keys.onReturnPressed: entry.picked()
        Keys.onEnterPressed: entry.picked()
        Keys.onSpacePressed: entry.picked()
        Rectangle {
            id: plate
            anchors.fill: parent
            radius: Theme.rCtl
            readonly property bool lit: entryHover.hovered || entry.activeFocus
            color: entry.current ? Theme.accentSoft : lit ? Theme.ink(0.04) : "transparent"
            border.width: 1
            border.color: lit ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75)
                              : entry.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.d(160) } }
            Behavior on border.color { ColorAnimation { duration: Theme.d(160) } }
            scale: entryTap.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: Theme.d(220); easing.type: Easing.OutCubic } }
            // The current page's mark: a short bar in the accent at the left edge.
            Rectangle {
                visible: entry.current
                x: 0; y: 10; width: 3; height: parent.height - 20; radius: 1.5
                color: Theme.accent
            }
            VIcon {
                x: entry.slim ? Math.round((parent.width - width) / 2) : 13
                anchors.verticalCenter: parent.verticalCenter
                name: entry.glyph
                size: 17
                color: entry.current ? Theme.accent : plate.lit ? Theme.t1 : Theme.t2
                Behavior on color { ColorAnimation { duration: Theme.d(160) } }
            }
            Text {
                id: entryLabel
                visible: !entry.slim
                x: 42
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                text: entry.text
                elide: Text.ElideRight
                color: entry.current || plate.lit ? Theme.t1 : Theme.t2
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: entry.current ? Font.DemiBold : Font.Medium
                font.variableAxes: entry.current ? Theme.axesDemiBold : Theme.axesMedium
                Behavior on color { ColorAnimation { duration: Theme.d(160) } }
            }
        }
        HoverHandler { id: entryHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: entryTap; onTapped: entry.picked() }
        // The whole name where it is not on screen: the icons alone, or a name longer than the pane.
        ToolTip.visible: (entry.slim || entryLabel.truncated) && entryHover.hovered
        ToolTip.delay: 300
        ToolTip.text: entry.text
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 12
        anchors.bottomMargin: 10
        spacing: 4
        Repeater {
            model: nav.entries
            delegate: Entry {
                required property var modelData
                objectName: "pushfps-nav-" + modelData.id
                pageId: modelData.id
                glyph: modelData.icon
                text: modelData.label
                current: nav.currentPage === modelData.id
                slim: nav.slim
                onPicked: nav.requestPage(modelData.id)
            }
        }
        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.stroke }
        // The painter's palette: the design (new or legacy), the theme, the colours.
        Entry {
            objectName: "pushfps-nav-appearance"
            glyph: "palette"
            text: qsTr("外观")
            slim: nav.slim
            onPicked: nav.requestAppearance()
        }
    }
    // The line between the navigation and the page.
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.stroke }
}
