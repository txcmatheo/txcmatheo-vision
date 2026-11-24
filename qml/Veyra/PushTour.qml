// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
import QtQuick

// The first-run tour: what its steps are and when it is offered. The tour itself (the spotlight, the
// card, the keys) is OnboardingGuide.qml from the engine release PushFPS is built on; Main.qml gives
// it these steps and shows each one's place.
//
// A new user has a console, a capture card and a game. The steps follow what they do: the capture
// card and its six settings, then the three choices of the quick setup on the home page, then the
// tools. Nothing is changed by the tour: it points, and every choice stays the user's.
//
// A step is { target, title, detail }. target "" is a card in the middle of the window; the keys in
// `dialogKeys` are rows of the capture dialog (CaptureSourceDialog.onboardingTarget); every other
// key is a place on the home page (HomePage.tourTarget).
QtObject {
    id: tour

    readonly property var dialogKeys: ["device", "resolution", "capture-rate", "format", "input-color", "connect"]
    function inDialog(key) { return dialogKeys.indexOf(String(key)) >= 0 }
    function onHome(key) { return String(key) !== "" && !inDialog(key) }

    // has: what this PC and this install offer ({ enhance: AI picture enhancement can be switched on here }).
    // A step for something that is not there is left out, so the tour never points at nothing.
    function steps(has) {
        const offers = has || ({})
        const list = [
            { target: "", title: qsTr("欢迎使用 PushFPS"),
              detail: qsTr("用一分钟看一遍：接上采集卡，选好帧率，开始游戏。按 Esc 可以随时退出，以后在首页还能再看。") },
            { target: "capture", title: qsTr("从采集卡开始"),
              detail: qsTr("主机的 HDMI 接到采集卡，采集卡接到这台电脑。点「采集卡」打开采集设置。") },
            { target: "device", title: qsTr("选择你接入的采集卡"),
              detail: qsTr("在「视频输入设备」里选你实际连接的采集卡。选定后会读取它支持的采集档位。") },
            { target: "resolution", title: qsTr("选择采集分辨率"),
              detail: qsTr("从这张采集卡列出的分辨率里选你要用的那一档。帧率列表会随这项选择更新。") },
            { target: "capture-rate", title: qsTr("采集帧率优先选 60 FPS"),
              detail: qsTr("如果设备提供 60 FPS，优先选它。59.94 FPS 也是常见的近 60 档。游戏本身跑 30 FPS，也可以按 60 FPS 采集。") },
            { target: "format", title: qsTr("选择采集格式"),
              detail: qsTr("「像素格式」会列出当前分辨率和帧率下可以用的选项。这几种常见格式的区别如下。") },
            { target: "input-color", title: qsTr("设置输入色彩"),
              detail: qsTr("主机正在输出 HDR10 时，选 P010，再把这里设为「HDR · PQ」。NV12、YUY2 和 RGB24 走「SDR · 709」。修改后重新连接才生效。") },
            { target: "connect", title: qsTr("连接并开始采集"),
              detail: qsTr("选好设备和格式后，在这里连接。画面出现后，剩下的都在首页的「快速设置」里。") },
            { target: "console", title: qsTr("告诉 PushFPS 你玩的是什么"),
              detail: qsTr("选你的主机和游戏本身的帧率。多数主机游戏是 30 FPS；选对了，重复的画面才会被去掉，补帧才干净。") },
            { target: "target", title: qsTr("选择目标帧率"),
              detail: qsTr("60、120，或者跟随显示器。PushFPS 在游戏的每两帧之间生成新的画面，补到这个帧率。") }
        ]
        if (offers.enhance === true)
            list.push({ target: "enhance", title: qsTr("AI 画面增强"),
                        detail: qsTr("想要更清晰、更有层次的画面，就打开它。风格和处理尺寸可以在下面调，不喜欢随时关掉。") })
        list.push({ target: "tools", title: qsTr("常用工具都在这一排"),
                    detail: qsTr("「为我的电脑优化」实测这台电脑并选出合适的设置；「检查我的设置」找出影响画质的地方；「游戏预设」让小地图和 HUD 保持清晰。这里还能录对比片段和开播。") })
        list.push({ target: "", title: qsTr("可以开始了"),
                    detail: qsTr("更细的设置在专业模式里，录制和直播各有自己的页面。想再看一遍引导，点首页下方的「查看新手引导」。") })
        return list
    }

    // Offered by itself once, and only where nothing was ever set up: a new install. Someone who
    // updates has chosen a console or used a capture card, and is not walked through what they know.
    // prefs: the saved preferences; state: { captureUsed: a capture card was connected here before,
    // testRun: a test or screenshot run }.
    function offeredAtStart(prefs, state) {
        const p = prefs || ({})
        const s = state || ({})
        if (s.testRun === true || p.pushTourSeen === true) return false
        if (p.pushConsole !== undefined && String(p.pushConsole) !== "") return false
        if (p.pushGameFps !== undefined || p.pushProfiles !== undefined) return false
        return s.captureUsed !== true
    }
}
