// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Appearance (dialog key "appearance"): opened by the painter's palette at the bottom of the window.
// The design itself (the new one, or Legacy: the interface every version up to 4.2.1 had), the
// theme, the accent colour and the small things about how PushFPS looks when it starts. Every
// choice is the preference Settings -> Appearance writes; nothing here is a second store, and
// nothing about the picture, the engine or a saved setting changes with the design.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DialogLayer {
    id: look
    objectName: "pushfps-appearance-dialog"
    key: "appearance"
    glyph: "palette"
    title: qsTr("外观")
    sub: qsTr("新版把导航、预览和全部快速设置放在同一个窗口里；旧版是 4.2 及更早版本的界面。两种设计的功能完全相同")
    dialogWidth: 620

    signal requestSettings()

    readonly property var themes: [{ id: "default", tip: qsTr("石墨") }, { id: "light", tip: qsTr("浅色") }, { id: "black", tip: qsTr("纯黑") },
                                   { id: "midnight", tip: qsTr("午夜蓝") }, { id: "plum", tip: qsTr("深紫") }, { id: "forest", tip: qsTr("墨绿") },
                                   { id: "contrast", tip: qsTr("高对比度") }]
    readonly property var accentList: [{ id: "orange", tip: qsTr("PushFPS 绿") }, { id: "white", tip: qsTr("白色光晕") }, { id: "ice", tip: qsTr("冰蓝") },
                                       { id: "blue", tip: qsTr("蓝色") }, { id: "violet", tip: qsTr("紫色") }, { id: "rose", tip: qsTr("玫红") },
                                       { id: "amber", tip: qsTr("琥珀") }]
    readonly property string themeShown: Theme.surfaces[Theme.mode] ? Theme.mode : "default"
    readonly property string accentShown: Theme.accents[Theme.accentName] ? Theme.accentName : "orange"

    DialogGroup {
        VRow {
            objectName: "pushfps-appearance-design-row"
            visible: false   // Txcmatheo Vision: siempre el diseño Txcmatheo
            label: qsTr("设计")
            VSeg {
                objectName: "pushfps-appearance-design"
                options: [{ id: "new", label: qsTr("新版") }, { id: "legacy", label: qsTr("旧版") }]
                current: Theme.modern ? "new" : "legacy"
                onPicked: id => veyra.setPreference("pushDesign", id)
            }
        }
    }
    DialogGroup {
        VRow {
            objectName: "pushfps-appearance-theme-row"
            label: qsTr("主题")
            hint: (look.themes.find(t => t.id === look.themeShown) || look.themes[0]).tip
            hintBelow: true
            Row {
                objectName: "pushfps-appearance-theme"
                spacing: 8
                Repeater {
                    model: look.themes
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property var shown: Theme.surfaceOf(modelData.id)
                        readonly property bool lightLook: modelData.id === "light"
                        readonly property bool on: look.themeShown === modelData.id
                        objectName: "pushfps-appearance-theme-" + modelData.id
                        width: 52; height: 38; radius: 8
                        color: shown.bgMid
                        border.width: on || tileHover.hovered ? 2 : 1
                        border.color: on ? Theme.accent : tileHover.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : Theme.stroke2
                        Behavior on border.color { ColorAnimation { duration: Theme.d(160) } }
                        Rectangle {
                            x: 7; y: 7; width: parent.width - 14; height: parent.height - 14; radius: 4
                            color: tile.shown.card2
                            border.width: tile.modelData.id === "contrast" ? 1 : 0
                            border.color: "#FFFFFF"
                            Rectangle { x: 5; y: 6; width: 17; height: 3; radius: 1.5; color: tile.lightLook ? "#17202B" : "#F4F7FA"; opacity: 0.85 }
                            Rectangle { x: 5; y: 14; width: 11; height: 3; radius: 1.5; color: tile.lightLook ? "#17202B" : "#F4F7FA"; opacity: 0.4 }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                                width: 11; height: 7; radius: 3.5
                                color: tile.lightLook ? Theme.accentPair.light : Theme.accentPair.dark
                            }
                        }
                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: veyra.setPreference("pushTheme", tile.modelData.id) }
                        ToolTip.visible: tileHover.hovered
                        ToolTip.delay: 300
                        ToolTip.text: modelData.tip
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.tip
                        Accessible.checked: on
                    }
                }
            }
        }
        VRow {
            objectName: "pushfps-appearance-accent-row"
            label: qsTr("强调色")
            hint: (look.accentList.find(a => a.id === look.accentShown) || look.accentList[0]).tip
            Row {
                objectName: "pushfps-appearance-accent"
                spacing: 10
                Repeater {
                    model: look.accentList
                    delegate: Rectangle {
                        id: swatch
                        required property var modelData
                        readonly property bool on: look.accentShown === modelData.id
                        objectName: "pushfps-appearance-accent-" + modelData.id
                        width: 26; height: 26; radius: 13
                        color: "transparent"
                        border.width: 2
                        border.color: on ? Theme.t1 : swatchHover.hovered ? Theme.t3 : "transparent"
                        Behavior on border.color { ColorAnimation { duration: Theme.d(160) } }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: width / 2
                            color: Theme.light ? Theme.accents[swatch.modelData.id].light : Theme.accents[swatch.modelData.id].dark
                        }
                        HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: veyra.setPreference("accent", swatch.modelData.id) }
                        ToolTip.visible: swatchHover.hovered
                        ToolTip.delay: 300
                        ToolTip.text: modelData.tip
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.tip
                        Accessible.checked: on
                    }
                }
            }
        }
    }
    DialogGroup {
        VRow {
            label: qsTr("启动动画")
            VSwitch {
                objectName: "pushfps-appearance-intro"
                checked: veyra.preferences.introAnimation !== false
                onToggled: checked => veyra.setPreference("introAnimation", checked)
            }
        }
        VRow {
            label: qsTr("启动音乐")
            VSwitch {
                objectName: "pushfps-appearance-music"
                checked: veyra.preferences.introMusic === true
                onToggled: checked => {
                    veyra.setPreference("introMusic", checked)
                    if (!checked && typeof vyMusic !== "undefined") vyMusic.pause()
                }
            }
        }
        // The Sunset City logo belongs to the legacy home page; the new design has the wordmark in its title bar.
        VRow {
            visible: !Theme.modern
            label: qsTr("日落之城标志")
            VSwitch {
                objectName: "pushfps-appearance-sunset"
                checked: veyra.preferences.pushSunset !== false
                onToggled: checked => veyra.setPreference("pushSunset", checked)
            }
        }
        VRow {
            label: qsTr("更多外观设置")
            hint: qsTr("语言、启动方式和窗口选项在「设置」里")
            VButton {
                objectName: "pushfps-appearance-more"
                ghost: true
                text: qsTr("打开")
                onClicked: look.requestSettings()
            }
        }
    }
}
