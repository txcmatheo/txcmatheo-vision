// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
import QtQuick
import QtQuick.Layouts

// A titled section of the quick setup (PushQuickSetup.qml): what belongs together stands together, under a
// name, and can be folded away. The rows are the section's children.
//
// Folding changes the height of the part that holds the rows and nothing else. A row's own `visible` says
// what it said before there were sections, so nothing that reads a row (a profile, a test, a screenshot run)
// depends on whether its section happens to be folded. A section whose rows are all hidden (a mode that
// leaves them out) shows no title and takes no room.
ColumnLayout {
    id: section
    property string sectionId: ""
    property string title: ""
    // One short line beside the title: what is set, readable while the section is folded.
    property string summary: ""
    property bool open: true
    // The first thing in its card: no line above the title (there is nothing to set it off from).
    property bool first: false
    default property alias rows: body.data
    readonly property bool empty: body.implicitHeight <= 0
    signal toggled(bool open)
    // Whether a row of this name stands in this section (for a jump to a row that may be folded away).
    function holds(name) {
        const find = item => {
            if (!item) return false
            if (item.objectName === name) return true
            const kids = item.children || []
            for (let i = 0; i < kids.length; ++i) if (find(kids[i])) return true
            return false
        }
        return find(body)
    }
    Layout.fillWidth: true
    spacing: 0

    Item {
        id: head
        objectName: "pushfps-section-" + section.sectionId
        visible: !section.empty
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 34
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: section.title
        Accessible.onPressAction: section.toggled(!section.open)
        Keys.onSpacePressed: section.toggled(!section.open)
        Keys.onReturnPressed: section.toggled(!section.open)
        // The line that sets one section off from the one above it.
        Rectangle {
            visible: !section.first
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.stroke
        }
        Rectangle {
            visible: head.activeFocus
            anchors.fill: parent
            anchors.topMargin: 5
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            radius: 7
            color: "transparent"
            border.width: 1
            border.color: Theme.accent
        }
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            spacing: 8
            Text {
                text: section.title
                color: headHover.hovered ? Theme.t1 : Theme.tLabel
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: section.summary
                color: Theme.t3
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsHint
            }
            VIcon {
                name: "down"
                color: Theme.t3
                rotation: section.open ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.d(260); easing.type: Easing.OutCubic } }
            }
        }
        HoverHandler { id: headHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: section.toggled(!section.open) }
    }
    Item {
        id: fold
        objectName: "pushfps-section-fold-" + section.sectionId
        Layout.fillWidth: true
        // Only the fold itself is animated: rows that come and go, or wrap differently while the window is
        // resized, take their room at once.
        property real shown: section.open ? 1 : 0
        Behavior on shown { NumberAnimation { duration: Theme.d(260); easing.type: Easing.OutCubic } }
        implicitHeight: body.implicitHeight * shown
        // Said to the layout in so many words: with an implicit height of 0 and nothing else to go by, a
        // layout keeps the height an item happens to have. A fold that reached 0 in one step (reduced
        // motion, or a frame that took longer than the animation) then stayed as high as it was, and the
        // section's rows were still drawn under a title that said it was folded.
        Layout.preferredHeight: body.implicitHeight * shown
        clip: shown < 1
        // Folded rows cannot be reached with the keyboard either.
        enabled: section.open
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0
        }
    }
}
