// Professional-view reusable presentation component.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

RowLayout {
    id: light
    spacing: 8
    readonly property color tone: veyra.runStatusLevel === "ok" ? Theme.ok
                                : veyra.runStatusLevel === "warn" ? "#F2B941"
                                : veyra.runStatusLevel === "err" ? Theme.err : Theme.ink(0.3)
    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 32
        Layout.preferredHeight: 4
        Rectangle {
            id: strip
            anchors.fill: parent
            radius: 2
            color: light.tone
            opacity: veyra.runStatusLevel === "idle" ? 0.35 : 0.9
            Behavior on color { enabled: strip.visible; ColorAnimation { duration: Theme.d(300) } }
        }
        // A sibling MultiEffect, not layer.effect: Qt recreates a layer's effect item on
        // a screen DPI change while it walks the parent's children, and the walk then touched
        // the deleted item (crash moving the window to a 200 % monitor, field 2026-10-01).
        MultiEffect {
            source: strip
            anchors.fill: strip
            visible: veyra.runStatusLevel !== "idle"
            opacity: strip.opacity
            shadowEnabled: true; shadowColor: light.tone; shadowBlur: 0.6; shadowVerticalOffset: 0; blurMax: 12; autoPaddingEnabled: true
        }
    }
    Text {
        objectName: "run-status"
        Layout.maximumWidth: Math.max(0, light.width - 40)
        Layout.preferredWidth: Math.min(implicitWidth, light.width * 0.75)
        // Txcmatheo: estados del motor que llegan sin traducir (LiveStatusHistory.h)
        function txcStatus(s) {
            if (Qt.uiLanguage.indexOf("es") === 0)
                return s.replace("补帧调度降档", "FG reducido").replace("调度降档", "FG reducido")
                        .replace("输出未达标", "Salida bajo objetivo").replace("输入帧率不足", "Entrada insuficiente")
                        .replace("输入时间线异常", "Entrada irregular")
            if (Qt.uiLanguage.indexOf("zh") === 0) return s
            return s.replace("补帧调度降档", "FG stepped down").replace("调度降档", "FG stepped down")
                    .replace("输出未达标", "Output below target").replace("输入帧率不足", "Input rate too low")
                    .replace("输入时间线异常", "Input timeline irregular")
        }
        text: txcStatus(veyra.runStatus + (veyra.runStatusDetail.length > 0 ? " · " + veyra.runStatusDetail : ""))
        color: light.tone
        font.family: Theme.fontUi
        font.pixelSize: 11
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        HoverHandler { id: statusHover }
        ToolTip.visible: statusHover.hovered
        ToolTip.delay: 400
        ToolTip.text: text
    }
}
