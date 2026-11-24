import QtQuick
import QtQuick.Layouts

VRow {
    id: row
    required property var backend
    property string namePrefix: "list"
    property bool showHelp: true
    property int lastMode: 1
    readonly property int currentMode: backend && backend.contentRate!==undefined
        ? (Number(backend.contentRate)===5?5:Number(backend.contentRate)===6?6:Number(backend.contentRate)>0?1:0) : 0
    // 6 = "60->30 original" (PushFPS, after 4.4.5): the plain every-second-sample grid of 3.2.10 to 4.1.1.
    readonly property var modes: [
        {id:"5",label:"60→30"},
        {id:"6",label:qsTr("60→30 原始")},
        {id:"1",label:qsTr("自动去除")}
    ]
    onCurrentModeChanged: if(currentMode!==0)lastMode=currentMode
    Component.onCompleted: if(currentMode!==0)lastMode=currentMode
    label: qsTr("去除重复帧")
    hint: showHelp?qsTr("60→30：每两帧保留一帧，游戏卡顿或不足 30 帧时跳过重复画面。60→30 原始：严格每两帧保留一帧（3.2.10 到 4.1.1 的方式）。自动去除：检测并跳过重复画面。"):""
    hintBelow: true
    RowLayout {
        spacing: 8
        VSwitch {
            objectName: row.namePrefix+"-dedup-enabled"
            checked: row.currentMode!==0
            onToggled: checked=>row.backend.contentRate=checked?row.lastMode:0
        }
        VSelect {
            objectName: row.namePrefix+"-content-rate"
            implicitWidth: 160
            title: qsTr("去除重复帧")
            enabled: row.currentMode!==0
            options: row.modes
            value: (row.modes.find(option=>Number(option.id)===(row.currentMode||row.lastMode))||row.modes[2]).label
            onPicked: id=>{
                const mode=Number(id)
                if(mode===1||mode===5||mode===6)row.backend.contentRate=mode
            }
        }
    }
}
