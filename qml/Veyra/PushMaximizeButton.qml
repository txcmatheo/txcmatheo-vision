// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// A maximize / restore button in a page's own header (PushFPS 4.1; a user's request: in Professional
// and Streaming mode the only way seen to make the window as large as the screen was dragging its
// edge). The window's own buttons are in the dock at the top, which shows when the mouse goes there;
// this one is always in sight. It does what the dock's button and a double click on the header do:
// the window's toggleMaximized() (Main.qml), which also leaves full screen.
import QtQuick

VButton {
    id: maxButton
    objectName: "pushfps-maximize"
    // The window the page sits in. A test gives its own.
    property var shell: maxButton.Window.window
    readonly property bool usable: maxButton.shell !== null && maxButton.shell !== undefined && typeof maxButton.shell.toggleMaximized === "function"
    readonly property bool maximized: maxButton.usable && (maxButton.shell.maximized === true || maxButton.shell.fullscreen === true)
    visible: maxButton.usable
    ghost: true
    iconName: "max"
    tip: maxButton.maximized ? qsTr("还原") : qsTr("最大化")
    onClicked: if (maxButton.usable) maxButton.shell.toggleMaximized()
}
