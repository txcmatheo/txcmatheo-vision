// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// The crash notice: PushFPS stopped unexpectedly last time. Shown once at the next start (the bridge
// opens it, bridge/PushTools.cpp) with a summary to copy. The summary is built without the Windows
// user name, any folder path or any address (engine/PushCrashNote.h); the crash file itself does
// hold the user name, so the dialog says to send that one privately and never sends anything itself.
// Dialog key "crash".
import QtQuick
import QtQuick.Layouts

DialogLayer {
    id: crash
    objectName: "pushfps-crash"
    key: "crash"
    glyph: "info"
    title: qsTr("PushFPS 上次意外关闭了")
    sub: crash.report.optimising === true
         ? qsTr("当时「为我的电脑优化」正在测试，出问题的那一项这个版本不会再测。下面的摘要可以帮我们找到原因")
         : qsTr("抱歉。下面的摘要可以帮我们找到原因")
    dialogWidth: 600

    property var report: ({})
    property bool copied: false
    readonly property bool present: crash.report.present === true
    readonly property string summary: String(crash.report.summary || "")
    readonly property string dumpName: String(crash.report.dump || "")
    onShownChanged: {
        if (shown) { crash.copied = false; crash.report = veyra.pushCrashReport() || ({}) }
        // Seen: it does not come back at the next start (the handler's note is already gone).
        else if (crash.present) veyra.pushDismissCrashReport()
    }
    function copy() { crash.copied = crash.summary.length > 0 && veyra.pushCopyText(crash.summary) === true }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        visible: !crash.present
        wrapMode: Text.WordWrap
        color: Theme.t2
        font.family: Theme.fontUi
        font.pixelSize: 13
        text: qsTr("没有记录到意外关闭")
    }
    Rectangle {
        Layout.fillWidth: true
        visible: crash.present
        implicitHeight: summaryText.implicitHeight + 20
        radius: 8
        color: Theme.ink(0.05)
        border.width: 1
        border.color: Theme.ink(0.08)
        Text {
            id: summaryText
            objectName: "pushfps-crash-summary"
            anchors.fill: parent
            anchors.margins: 10
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Theme.t1
            font.family: "Consolas"
            font.pixelSize: 12
            text: crash.summary
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: crash.present
        wrapMode: Text.WordWrap
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 12
        text: crash.copied ? qsTr("已复制。可以贴到 GitHub 的反馈里，或发给帮你的人")
                           : qsTr("摘要里没有你的 Windows 用户名、文件夹路径或串流地址，可以公开粘贴")
    }
    VRow {
        objectName: "pushfps-crash-file-row"
        Layout.topMargin: 6
        visible: crash.present
        label: qsTr("崩溃文件")
        hint: crash.dumpName.length > 0
              ? qsTr("%1：能帮我们找到确切位置，但里面有你的 Windows 用户名，请私下发送，不要公开贴出").arg(crash.dumpName)
              : qsTr("日志文件夹里最新的 .dmp 文件：里面有你的 Windows 用户名，请私下发送，不要公开贴出")
        hintBelow: true
        VButton {
            objectName: "pushfps-crash-folder"
            text: qsTr("打开所在文件夹")
            ghost: true
            onClicked: veyra.openLogFolder()
        }
    }

    actions: crash.present ? [{ label: qsTr("关闭") }, { label: qsTr("去 GitHub 反馈") }, { label: qsTr("复制摘要"), primary: true }]
                           : [{ label: qsTr("关闭") }]
    onActionTriggered: label => {
        if (label === qsTr("复制摘要")) crash.copy()
        else if (label === qsTr("去 GitHub 反馈")) { crash.copy(); veyra.pushOpenLink("issues") }
        else crash.dialogHost.close()
    }
}
