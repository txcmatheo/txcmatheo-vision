// 首页, rebuilt from the design (pages-a.js PAGES.home + pages.css .home).
//
// The design is: a large logo, a two-line greeting, a 4-up grid of source cards
// (164x124 each), a "continue last capture" row, and a row of recent chips.
// The logo in the dock returns here; there is no other home affordance.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "TxcVersion.js" as TxcVersion

VPage {
    id: root
    signal requestPage(string page)
    // Main.qml keeps the dusk wordmark hidden while the startup intro (DuskIntro.qml) flies a
    // copy of it in, and aims that copy at this item.
    property bool introHold: false
    readonly property Item wordmarkItem: wordmark
    // Txcmatheo Vision sobre PushFPS: la portada Txcmatheo con el ajuste rápido de PushFPS.
    // API que Main.qml de PushFPS espera de la portada.
    property real topInset: 0
    readonly property bool sunset: false
    // PushFPS 4.2: el tour para usuarios nuevos (PushTour.qml / OnboardingGuide en Main.qml) pide esto a la portada.
    signal requestOnboarding()
    // PushFPS 4.3+: la portada de tres paneles (diseño nuevo) no se usa en Txcmatheo Vision.
    readonly property bool threePane: false
    // Txcmatheo Vision: el ajuste rápido de la portada, para el cambio automático de perfil (Main.qml).
    readonly property Item quickSetupItem: quickSetup
    readonly property rect videoViewport: Qt.rect(0, 0, 0, 0)
    signal requestFullscreen()
    signal requestAppearance()
    readonly property Item onboardingEntry: tourEntry
    readonly property alias sourceViewport: content
    function tourOffers(what) { return quickSetup.tourItem(what) !== null }
    function captureCardItem() {
        for (let i = 0; i < srcGrid.children.length; ++i) {
            const slot = srcGrid.children[i]
            if (slot.modelData && slot.modelData.act === "capture" && slot.children.length > 0) {
                for (let j = 0; j < slot.children.length; ++j)
                    if (slot.children[j].objectName === "home-src-capture") return slot.children[j]
            }
        }
        return null
    }
    function tourTarget(key) {
        const item = key === "capture" ? captureCardItem() : quickSetup.tourItem(key)
        return item ? { item: item, viewport: content } : null
    }
    function showTourStep(key) { quickSetup.showTourStep(key) }
    function showTuning() {
        tuning.open = true
        tuningScroll.restart()
    }
    // The screenshot run's `--scroll-to <objectName>` on this page (as SettingsPage.scrollToObject).
    function scrollToObject(name) {
        const find = (item) => {
            if (!item) return null
            if (item.objectName === name) return item
            for (let i = 0; i < item.children.length; ++i) { const r = find(item.children[i]); if (r) return r }
            return null
        }
        const target = find(column)
        if (!target) return false
        content.contentY = Math.max(0, Math.min(target.mapToItem(column, 0, 0).y - 24, content.contentHeight - content.height))
        return true
    }
    Timer {
        id: tuningScroll
        interval: 450
        onTriggered: content.contentY = Math.max(0, Math.min(tuning.mapToItem(column, 0, 0).y - 24, content.contentHeight - content.height))
    }

    // Con el ajuste rápido la portada es más alta que la ventana: se desplaza.
    Flickable {
        id: content
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, column.implicitHeight + 48 + root.topInset)
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: VScrollBar {}

    ColumnLayout {
        id: column
        x: Math.round((content.width - width) / 2)
        y: Math.max(24 + root.topInset, Math.round((content.height - implicitHeight) / 2))
        spacing: 24

        // .home .mark: 128px wide, drop-shadow(0 0 20px rgba(255,255,255,.35)) and the
        // 4.5s "breathe" loop: at 50% the glow is 30px at .55 and the mark scales 1.02.
        // MultiEffect blur is 0..1 of blurMax (32px): 20px = .625, 30px = .94.
        // The layer is padded 40px on every side so the glow has room (a layer on the
        // bare image clips the shadow to the image's own bounds). Negative margins
        // keep the layout the same as a plain 128px image.
        Item {
            id: mark
            visible: !Theme.dusk
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -40
            Layout.bottomMargin: -40
            implicitWidth: logoImg.implicitWidth + 80
            implicitHeight: logoImg.implicitHeight + 80
            property real breath: 0
            scale: 1 + 0.02 * breath
            // Only while the home page shows: running behind other pages it redrew the whole
            // window every vsync during playback (~300 presents/s on a 320 Hz screen), which
            // cost GPU time and kept OBS game capture on the UI instead of the video.
            SequentialAnimation on breath {
                running: !Theme.reduced && mark.visible
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: Theme.d(2250); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: Theme.d(2250); easing.type: Easing.InOutSine }
            }
            Image {
                id: logoImg
                anchors.centerIn: parent
                source: Theme.logoImage
                sourceSize.width: 128
                fillMode: Image.PreserveAspectFit
            }
            // A sibling MultiEffect, not layer.effect: Qt recreates a layer's effect item on
            // a screen DPI change while it walks the parent's children, and the walk then touched
            // the deleted item (crash moving the window to a 200 % monitor, field 2026-10-01).
            MultiEffect {
                source: logoImg
                anchors.fill: logoImg
                shadowEnabled: true
                // The dusk logo carries its own neon glow; the breath adds a pink one to it.
                shadowColor: Theme.dusk ? "#B06CFF" : "#FFFFFF"
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 64
                shadowBlur: 0.625 + 0.3125 * mark.breath
                shadowOpacity: (Theme.dusk ? 0.22 : 0.35) + 0.2 * mark.breath
            }
        }

        // 日落: the user's wordmark (tools/qt_probe/make-wordmark-dusk.py) in place of the gamepad
        // and the title, a baked glow breathing behind it (the software scene graph draws no
        // MultiEffect). 0.24 of the page height, 130..210 px, so short windows keep the cards.
        Item {
            id: duskMark
            visible: Theme.dusk
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: wordmark.width
            implicitHeight: wordmark.height
            property real breath: 0
            // Only while it shows, as the gamepad's breath (see above).
            SequentialAnimation on breath {
                running: !Theme.reduced && duskMark.visible && !root.introHold
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: Theme.d(2250); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: Theme.d(2250); easing.type: Easing.InOutSine }
            }
            Image {
                // wordmark-dusk-glow.png is the wordmark's box grown by 186/1164 of its width.
                readonly property real pad: wordmark.width * 186 / 1164
                x: -pad
                y: -pad
                width: wordmark.width + 2 * pad
                height: wordmark.height + 2 * pad
                source: "wordmark-dusk-glow.png"
                opacity: root.introHold ? 0 : 0.16 + 0.14 * duskMark.breath
            }
            Image {
                id: wordmark
                objectName: "home-wordmark"
                height: Math.round(Math.max(130, Math.min(210, root.height * 0.24)))
                width: Math.round(height * 1164 / 969)
                source: "wordmark-dusk.png"
                sourceSize: Qt.size(width, height)
                opacity: root.introHold ? 0 : 1
            }
        }

        // .hello: .h1 plus a muted line. The line asks for a coffee; the whole of it
        // opens the sponsor section of 设置.
        ColumnLayout {
            id: hello
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: !Theme.dusk                    // the dusk wordmark says it
                text: "Txcmatheo Vision"
                color: Theme.t1
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsH1
                font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
            }
            // Txcmatheo Vision: versión instalada (TxcVersion.js, la escribe el publicador).
            Text {
                objectName: "txc-version"
                Layout.alignment: Qt.AlignHCenter
                text: "v" + TxcVersion.version
                color: Theme.t3
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                opacity: root.introHold ? 0 : 1
            }
        }

        VButton {
            objectName: "home-playlist"
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("播放列表 · 导入文件夹"); iconName: "list"
            onClicked: veyra.showPlaylist()
        }

        // .srcgrid: 164px cards, gap 12. Six cards since PC and Xbox streaming (1044 wide,
        // fits a 1280 window); a narrower window wraps them onto a second row.
        Flow {
            id: srcGrid
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(1044, root.width - 48)
            spacing: 12
            // Subtitles name what is really there: the device of the last capture
            // session and the saved PS5 host; generic wording when there is none.
            // Only the subtitle follows the live state. The cards themselves are a fixed
            // list: when the whole array was one binding, every Xbox / PC state change
            // (polling after sign-in) destroyed and rebuilt all six cards, and a click
            // landing during the rebuild was lost (field report 2026-10-02).
            function cardSub(act) {
                switch (act) {
                case "file": return qsTr("MP4 · MKV · 图片")
                case "capture": return veyra.hasCaptureSession ? veyra.captureSessionSummary.split(" · ")[0] : qsTr("HDMI 采集设备")
                case "ps5": return veyra.remotePlayHost.length > 0 ? qsTr("已保存主机 ") + veyra.remotePlayHost : qsTr("局域网串流")
                case "moonlight": return veyra.moonlight && veyra.moonlight.state.lastLabel ? veyra.moonlight.state.lastLabel : qsTr("Sunshine 主机")
                case "xbox": return veyra.xbox && veyra.xbox.state.lastLabel ? veyra.xbox.state.lastLabel : qsTr("账号登录 · 实验")
                default: return qsTr("窗口或显示器")
                }
            }
            Repeater {
                model: [
                    { glyph: "folder", title: qsTr("打开视频"), act: "file" },
                    { glyph: "video", title: qsTr("采集卡"), act: "capture" },
                    { glyph: "gamepad", title: qsTr("PS5 串流"), act: "ps5" },
                    { glyph: "cast", title: qsTr("PC 串流"), act: "moonlight" },
                    { glyph: "gamepad", title: qsTr("Xbox 串流"), act: "xbox" },
                    { glyph: "monitor", title: qsTr("屏幕捕获"), act: "screen" }
                ]
                // The layout owns the slot's position, so the card inside it is free to
                // move its own y for the hover lift (a y set on a layout child is
                // overwritten); the entrance rise goes on the slot.
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    implicitWidth: 164
                    implicitHeight: 124
                    VRise { page: root; target: slot; d: 2 + slot.index }
                  Rectangle {
                    id: srcCard
                    objectName: "home-src-" + slot.modelData.act
                    readonly property var modelData: slot.modelData
                    // .srccard: 164x124, radius 14, content pinned top and bottom.
                    width: 164
                    height: 124
                    radius: Theme.rCard
                    color: cardHover.hovered ? Theme.card2 : Theme.card
                    border.width: 1
                    border.color: cardHover.hovered ? Theme.stroke2 : Theme.stroke
                    // .srccard:hover { transform: translateY(-4px) }
                    y: cardHover.hovered ? -4 : 0
                    Behavior on y { NumberAnimation { duration: Theme.d(500); easing.bezierCurve: Theme.spring } }
                    scale: cardTap.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.d(500); easing.bezierCurve: Theme.spring } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 0
                        Rectangle {
                            // .srccard .ico: 34x34, radius 10, translucent plate.
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.06)
                            VIcon {
                                anchors.centerIn: parent
                                name: modelData.glyph
                            }
                        }
                        Item { Layout.fillHeight: true }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            // Txcmatheo Vision: los textos no se salen de la tarjeta (antes
                            // "Account sign-in · experimental" pasaba por encima del borde).
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: Theme.t1
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srcGrid.cardSub(modelData.act)
                                color: Theme.t3
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 0.95
                            }
                        }
                    }
                    // PS5 手柄控制 is switched on for the capture card.
                    VTag {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 12
                        visible: modelData.act === "capture" && veyra.ps5Control.enabled === true
                        text: qsTr("PS5 手柄")
                        kind: "acc"
                    }
                    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: cardTap
                        onTapped: {
                            veyra.logUi("ui-source", "home card act=" + modelData.act)
                            switch (modelData.act) {
                            case "file": veyra.openFileDialog(); break
                            case "capture": veyra.openCaptureDialog(); break
                            case "ps5": veyra.openPs5Dialog(); break
                            case "moonlight": veyra.openMoonlightDialog(); break
                            case "xbox": veyra.openXboxDialog(); break
                            case "screen": veyra.openScreenCaptureDialog(); break
                            }
                        }
                    }
                  }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            VButton {
                objectName: "home-network"
                text: qsTr("播放地址…")
                iconName: "cast"
                onClicked: veyra.openNetworkDialog()
            }
            // PushFPS 4.2: abrir otra vez el tour para usuarios nuevos.
            VButton {
                id: tourEntry
                objectName: "home-onboarding"
                text: qsTr("查看新手引导")
                iconName: "info"
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.onPressAction: clicked()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onSpacePressed: clicked()
                onClicked: root.requestOnboarding()
            }
        }

        // .resume: 692 wide, an accent-tinted gradient plate, shown only when a
        // capture session was actually used before. Nothing invented: the text is
        // the recorded session, and the row is absent when there is none.
        Rectangle {
            id: resume
            objectName: "home-resume"
            Layout.alignment: Qt.AlignHCenter
            // The last source actually used: capture card, PS5 or screen capture.
            readonly property var last: veyra.lastSource
            visible: last.kind !== undefined
            implicitWidth: srcGrid.width
            implicitHeight: 54
            radius: 14
            border.width: 1
            border.color: Theme.stroke
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentSoft }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.03) }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 14
                Rectangle {
                    implicitWidth: 34; implicitHeight: 34; radius: 10
                    color: Theme.accentSoft
                    VIcon {
                        anchors.centerIn: parent
                        name: resume.last.kind === "screen" ? "monitor" : resume.last.kind === "capture" ? "video" : "gamepad"
                        color: Theme.accent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: qsTr("继续上次")
                        color: Theme.t1
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (resume.last.summary || "")
                            .replace(/^PS5 streaming/, qsTr("PS5 串流")).replace(/^PC streaming/, qsTr("PC 串流"))
                            .replace(/^Xbox streaming/, qsTr("Xbox 串流")).replace(/^PS5 串流/, qsTr("PS5 串流"))
                            .replace(/^PC 串流/, qsTr("PC 串流")).replace(/^Xbox 串流/, qsTr("Xbox 串流"))
                        color: Theme.t2
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                VButton {
                    text: qsTr("开始")
                    iconName: "play"
                    primary: true
                    onClicked: veyra.resumeLastSource()
                }
            }
        }

        // PushFPS: elige consola, fps del juego y objetivo antes de conectar (lo mismo que
        // Profesional → Frame Gen en corto), con "Optimizar para mi PC" y los presets de juego.
        PushQuickSetup {
            id: quickSetup
            objectName: "home-pushfps-quick"
            compact: true
            showSetupTip: true
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: srcGrid.width
        }

        // PushFPS: imagen y sonido de todos los días, plegado hasta que se necesite.
        VAccordion {
            id: tuning
            objectName: "home-picture-sound"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: srcGrid.width
            glyph: "sliders"
            title: qsTr("画面与声音")
            summary: {
                const p = homePicture.presets.find(x => x.id === homePicture.currentPreset)
                return (p ? p.label : qsTr("已自定义")) + " · " + homeSound.presets[homeSound.preset].label
            }
            enabledSwitch: false
            PushPicture { id: homePicture; Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 2; implicitHeight: 1; color: Theme.stroke }
            PushSoundProfile { id: homeSound; Layout.fillWidth: true; compact: true }
        }

        // .recent: 692 wide, left-aligned, wrapping; "最近" in --v-t3 then 28px chips
        // with a film/image icon. Present only when there are recent files; a chip
        // whose file is gone is dimmed and does nothing (clicking it cannot open it).
        Flow {
            id: recent
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: srcGrid.width
            visible: veyra.recentFiles.length > 0
            spacing: 8
            Text {
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: qsTr("最近")
                color: Theme.t3
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
            Repeater {
                model: veyra.recentFiles
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool isImage: /\.(png|jpe?g|bmp|webp|tiff?)$/i.test(modelData.path)
                    width: chipRow.implicitWidth + 22
                    height: 28
                    radius: 99
                    opacity: modelData.exists ? 1 : 0.45
                    color: chipHover.hovered && modelData.exists ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Theme.stroke
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 7
                        VIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: chip.isImage ? "image" : "film"
                            size: 14
                            color: chipText.color
                        }
                        Text {
                            id: chipText
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: chipHover.hovered && modelData.exists ? Theme.t1 : Theme.t2
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                        }
                    }
                    ToolTip.visible: chipHover.hovered && !modelData.exists
                    ToolTip.text: qsTr("文件已不存在")
                    HoverHandler { id: chipHover; cursorShape: modelData.exists ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (modelData.exists) veyra.openPath(modelData.path) }
                }
            }
        }
    }

    }

    // [data-in] entrance order from pages-a.js (the source cards rise from their delegate, --d 2-5).
    VRise { target: mark; d: 0 }
    VRise { target: hello; d: 1 }
    VRise { target: resume; d: 6 }
    VRise { target: quickSetup; d: 7 }
    VRise { target: tuning; d: 8 }
    VRise { target: recent; d: 9 }
}
