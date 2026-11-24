// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// Read the text on the picture: a menu in another language, a line of dialogue. One frame of the
// picture PushFPS shows is taken when asked, Windows reads the text on it on this PC, and the text
// can be copied or translated (the bridge: src/ui/bridge/PushOcr.cpp; the rules: ui/PushOcr.h).
//
// What it does not do: nothing runs until Read is pressed (or the dialog is opened with something
// playing, which is asking); nothing is read from a game or from another program, only pixels
// PushFPS already shows; the reading never leaves the PC. A translation is asked for with its own
// button, and when the engine chosen is an online one the dialog says, beside that button, that the
// text will be sent there.
//
// The translation uses the engines live translation has (the local model, a custom API, MyMemory)
// through its `translateOnce`, whether or not live translation is on. Dialog key "readtext"; opened
// from Settings (row set-readtext) and by the shortcut `readText`.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DialogLayer {
    id: read
    objectName: "pushfps-readtext-dialog"
    key: "readtext"
    glyph: "type"
    title: qsTr("读取画面上的文字")
    sub: qsTr("取正在播放的一帧画面，由 Windows 在这台电脑上识别其中的文字。识别过程不联网，这一帧用完即删")
    dialogWidth: 640

    readonly property var info: veyra.pushReadText || ({})
    readonly property string phase: String(read.info.phase || "idle")
    readonly property bool busy: read.phase === "frame" || read.phase === "reading"
    readonly property string found: String(read.info.text || "")
    readonly property bool playing: veyra.hasSource === true
    readonly property var known: read.info.languages || []
    readonly property bool languagesKnown: read.info.languagesKnown === true
    readonly property var languageOptions: [{ id: "", label: qsTr("自动（Windows 的语言）") }]
        .concat(read.known.map(l => ({ id: String(l.tag), label: String(l.name) })))
    // A language chosen earlier that Windows no longer has is not used.
    readonly property string language: {
        const saved = String(veyra.preferences.pushReadLanguage || "")
        return read.known.some(l => String(l.tag) === saved) ? saved : ""
    }
    readonly property var regionOptions: [
        { id: "0", label: qsTr("整个画面") },
        { id: "2", label: qsTr("下面三分之一（字幕、对话）") },
        { id: "1", label: qsTr("下半部分") },
        { id: "3", label: qsTr("上半部分") }
    ]
    readonly property int region: {
        const saved = Number(veyra.preferences.pushReadRegion || 0)
        return saved >= 0 && saved <= 3 ? Math.round(saved) : 0
    }
    function labelOf(options, id) {
        const hit = options.find(o => o.id === String(id))
        return hit ? hit.label : options[0].label
    }

    // --- translation ---------------------------------------------------------------------
    readonly property var translation: veyra.liveTranslation || null
    readonly property int engine: read.translation ? Number(read.translation.provider) : 0
    readonly property int ready: read.translation ? Number(read.translation.onceReady) : 2
    readonly property bool online: read.translation ? read.translation.onceOnline === true : false
    readonly property bool translating: read.translation ? read.translation.onceBusy === true : false
    readonly property string translated: read.translation ? String(read.translation.onceText || "") : ""
    readonly property string translateStatus: read.translation ? String(read.translation.onceStatus || "") : ""
    // The custom API is set up in live translation's own dialog; it is offered here once it is
    // set up there, or where that dialog can be opened to do so.
    readonly property bool apiOffered: read.translation !== null
        && (read.engine === 1 || read.translation.supported === true || String(read.translation.apiBase || "").length > 0)
    readonly property var engines: [{ id: "0", label: qsTr("本地模型") }]
        .concat(read.apiOffered ? [{ id: "1", label: qsTr("自定义 API（OpenAI 兼容）") }] : [])
        .concat([{ id: "2", label: "MyMemory" }])
    readonly property var targets: [
        { id: "en", label: "English" }, { id: "zh-CN", label: "简体中文" }, { id: "zh-TW", label: "繁體中文" },
        { id: "ja", label: "日本語" }, { id: "ko", label: "한국어" }, { id: "fr", label: "Français" },
        { id: "de", label: "Deutsch" }, { id: "es", label: "Español" }, { id: "pt-BR", label: "Português (Brasil)" },
        { id: "ru", label: "Русский" }, { id: "it", label: "Italiano" }, { id: "ar", label: "العربية" },
        { id: "th", label: "ไทย" }, { id: "vi", label: "Tiếng Việt" }
    ]
    // MyMemory has to be told the language of the text; the others find it themselves.
    readonly property var sources: read.engine === 2 ? read.targets
        : [{ id: "", label: qsTr("自动识别原文") }].concat(read.targets)
    function nameOf(options, id) {
        const hit = options.find(o => o.id === String(id))
        return hit ? hit.label : String(id)
    }

    // Which Copy button was pressed last ("text" or "translation"): it says so for two seconds.
    property string copied: ""
    Timer { interval: 2000; running: read.copied.length > 0; onTriggered: read.copied = "" }

    function start() {
        if (read.busy) return false
        read.copied = ""
        if (read.translation) read.translation.clearOnce()
        return veyra.pushReadTextStart(read.language, read.region) === true
    }
    function translate() {
        if (!read.translation || read.found.length === 0 || read.translating) return false
        return read.translation.translateOnce(read.found) === true
    }
    function stateText() {
        if (read.phase === "frame" || read.phase === "reading") return qsTr("正在读取…")
        if (read.phase === "done")
            return read.found.length === 0 ? qsTr("这一帧里没有读到文字。试试只读画面的一部分，或换一种语言")
                : qsTr("读到 %1 行").arg(Number(read.info.count || 0))
        if (read.phase === "failed") {
            switch (String(read.info.error || "")) {
            case "no-picture": return qsTr("先让画面播放起来，再来读取")
            case "busy": return qsTr("正在保存截图或导出图片，请稍后再试")
            case "no-frame": return qsTr("没有拿到画面：现在没有画面在播放")
            case "no-language": return qsTr("Windows 没有可用的文字识别语言。在 Windows 的语言设置里添加一种语言（带「光学字符识别」）后再试")
            }
            return qsTr("读取失败，请再试一次")
        }
        return read.playing ? qsTr("按「读取」来读正在播放的画面") : qsTr("先让画面播放起来，再来读取")
    }
    function readyText() {
        switch (read.ready) {
        case 1: return qsTr("本地模型还没有下载（约 %1 GB，只需一次）").arg(read.translation ? (Number(read.translation.downloadBytes) / 1000000000).toFixed(2) : "")
        case 2: return qsTr("自定义 API 还没有设置好")
        case 3: return qsTr("MyMemory 需要选择原文语言")
        case 4: return qsTr("本地模型正在下载… %1%").arg(read.translation ? Math.round(Number(read.translation.downloadProgress) * 100) : 0)
        }
        return read.online ? qsTr("按下「翻译」后，读到的文字会发送给 %1").arg(read.nameOf(read.engines, read.engine))
                           : qsTr("在这台电脑上翻译，文字不会离开这台电脑。第一次需要一点时间加载模型")
    }

    // Opening it with a picture playing is asking: it reads at once (and when it was opened before
    // the picture started, once the picture is there, if nothing was read yet). Closing it forgets
    // the text.
    onPlayingChanged: if (read.shown && read.playing && read.phase === "idle") read.start()
    onShownChanged: {
        if (shown) {
            veyra.pushReadTextPrepare()
            if (read.playing && !read.busy) read.start()
        } else {
            veyra.pushReadTextClear()
            if (read.translation) read.translation.clearOnce()
        }
    }

    DialogGroup {
        VRow {
            objectName: "pushfps-readtext-language-row"
            label: qsTr("文字的语言")
            hintBelow: true
            hint: !read.languagesKnown ? ""
                : read.known.length === 0 ? qsTr("Windows 里没有装文字识别语言：在语言设置里添加语言（带「光学字符识别」）")
                : qsTr("只能读 Windows 里装了文字识别的语言。要读日文、韩文等，先在 Windows 的语言设置里添加它")
            RowLayout {
                spacing: 8
                VSelect {
                    objectName: "pushfps-readtext-language"
                    implicitWidth: 224
                    enabled: !read.busy
                    options: read.languageOptions
                    value: read.labelOf(read.languageOptions, read.language)
                    onPicked: id => { veyra.setPreference("pushReadLanguage", String(id)) }
                }
                VButton {
                    objectName: "pushfps-readtext-language-settings"
                    ghost: true
                    text: qsTr("语言设置")
                    onClicked: veyra.pushOpenLanguageSettings()
                }
            }
        }
        VRow {
            objectName: "pushfps-readtext-region-row"
            label: qsTr("读哪一部分")
            hint: qsTr("只读一部分时字更大，读得更准")
            VSelect {
                objectName: "pushfps-readtext-region"
                implicitWidth: 224
                enabled: !read.busy
                options: read.regionOptions
                value: read.labelOf(read.regionOptions, read.region)
                onPicked: id => { veyra.setPreference("pushReadRegion", Number(id)) }
            }
        }
    }

    DialogGroup {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                objectName: "pushfps-readtext-state"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: read.stateText()
                color: read.phase === "failed" ? Theme.warn : Theme.t1
                font.family: Theme.fontUi
                font.pixelSize: 13
            }
            VButton {
                objectName: "pushfps-readtext-copy"
                visible: read.found.length > 0
                ghost: true
                iconName: "copy"
                text: read.copied === "text" ? qsTr("已复制") : qsTr("复制")
                onClicked: { if (veyra.pushCopyText(read.found)) read.copied = "text" }
            }
            VButton {
                objectName: "pushfps-readtext-read"
                primary: read.found.length === 0
                enabled: read.playing && !read.busy
                opacity: enabled ? 1 : 0.5
                text: read.phase === "done" || read.phase === "failed" ? qsTr("再读一次") : qsTr("读取")
                onClicked: read.start()
            }
        }
        Rectangle {
            objectName: "pushfps-readtext-box"
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: read.found.length > 0
            implicitHeight: Math.min(220, foundText.implicitHeight + 20)
            radius: 10
            color: Theme.ink(0.05)
            border.width: 1
            border.color: Theme.stroke
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: width
                contentHeight: foundText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                TextEdit {
                    id: foundText
                    objectName: "pushfps-readtext-text"
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    text: read.found
                    color: Theme.t1
                    selectionColor: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                }
            }
        }
    }

    DialogGroup {
        objectName: "pushfps-readtext-translate-group"
        visible: read.translation !== null && read.found.length > 0
        VRow {
            label: qsTr("翻译成")
            RowLayout {
                spacing: 8
                VSelect {
                    objectName: "pushfps-readtext-source"
                    visible: read.engine === 2
                    implicitWidth: 150
                    options: read.sources
                    value: read.translation ? read.nameOf(read.sources, read.translation.sourceLanguage) : ""
                    onPicked: id => { read.translation.sourceLanguage = id }
                }
                VSelect {
                    objectName: "pushfps-readtext-target"
                    implicitWidth: 170
                    options: read.targets
                    value: read.translation ? read.nameOf(read.targets, read.translation.targetLanguage) : ""
                    onPicked: id => { read.translation.targetLanguage = id }
                }
            }
        }
        VRow {
            objectName: "pushfps-readtext-engine-row"
            label: qsTr("翻译引擎")
            hintBelow: true
            hint: read.readyText()
            RowLayout {
                spacing: 8
                VSelect {
                    objectName: "pushfps-readtext-engine"
                    implicitWidth: 224
                    enabled: !read.translating
                    options: read.engines
                    value: read.nameOf(read.engines, read.engine)
                    onPicked: id => { read.translation.provider = Number(id) }
                }
                VButton {
                    objectName: "pushfps-readtext-model"
                    visible: read.ready === 1 || read.ready === 4
                    text: read.ready === 4 ? qsTr("取消下载") : qsTr("下载模型")
                    onClicked: {
                        if (read.ready === 4) read.translation.cancelModelDownload()
                        else read.translation.onceDownloadModel()
                    }
                }
                VButton {
                    objectName: "pushfps-readtext-api"
                    visible: read.ready === 2 && read.translation !== null && read.translation.supported === true
                    text: qsTr("去设置")
                    onClicked: veyra.navigate("translation")
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Text {
                objectName: "pushfps-readtext-translate-state"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: read.translating ? qsTr("正在翻译…")
                    : read.translateStatus.length > 0 ? read.translateStatus
                    : read.translated.length > 0 && read.translation.onceCut === true ? qsTr("文字太长，只翻译了开头的一部分")
                    : ""
                color: read.translateStatus.length > 0 && !read.translating ? Theme.warn : Theme.t3
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
            VButton {
                objectName: "pushfps-readtext-translate-copy"
                visible: read.translated.length > 0
                ghost: true
                iconName: "copy"
                text: read.copied === "translation" ? qsTr("已复制") : qsTr("复制")
                onClicked: { if (veyra.pushCopyText(read.translated)) read.copied = "translation" }
            }
            VButton {
                objectName: "pushfps-readtext-translate"
                primary: read.translated.length === 0
                enabled: read.ready === 0 && !read.translating
                opacity: enabled ? 1 : 0.5
                text: qsTr("翻译")
                onClicked: read.translate()
            }
        }
        Rectangle {
            objectName: "pushfps-readtext-translated-box"
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: read.translated.length > 0
            implicitHeight: Math.min(220, translatedText.implicitHeight + 20)
            radius: 10
            color: Theme.ink(0.05)
            border.width: 1
            border.color: Theme.stroke
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: width
                contentHeight: translatedText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                TextEdit {
                    id: translatedText
                    objectName: "pushfps-readtext-translated"
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    text: read.translated
                    color: Theme.t1
                    selectionColor: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                }
            }
        }
    }

    actions: [{ label: qsTr("完成"), primary: read.found.length > 0 }]
    onActionTriggered: read.dialogHost.close()
}
