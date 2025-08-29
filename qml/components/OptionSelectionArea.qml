import QtQuick
import QtQuick.Controls

/**
 * 遮蔽選項設定區域組件
 * 包含常用區、其他區和生成按鈕
 */
Column {
    id: root
    spacing: 20
    
    // 公開屬性
    property var commonOptions: []
    property var otherOptions: []
    property bool canGenerate: false
    
    // 信號
    signal optionToggled(string category, int index)
    signal generateClicked()
    
    // 標題
    Text {
        text: "遮蔽選項設定"
        font.pixelSize: 24
        font.weight: Font.Bold
        color: "#FFFFFF"
    }
    
    // 常用區
    Rectangle {
        id: commonArea
        width: parent.width
        height: 280
        radius: 16
        color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
        border.width: 2
        border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
        
        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 16
            
            // 標題
            Row {
                spacing: 12
                
                Rectangle {
                    width: 4
                    height: 24
                    radius: 2
                    color: "#66FCF1"
                }
                
                Text {
                    text: "常用區"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#66FCF1"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // 選項按鈕
            Flow {
                width: parent.width
                spacing: 12
                
                Repeater {
                    model: commonOptions
                    delegate: OptionButton {
                        text: modelData.text
                        optionKey: modelData.key
                        checked: modelData.selected
                        buttonSize: "medium"
                        onToggled: root.optionToggled("common", index)
                    }
                }
            }
        }
    }
    
    // 其他區（可展開）
    Rectangle {
        id: otherArea
        width: parent.width
        height: expanded ? 180 : 60
        radius: 16
        color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
        border.width: 2
        border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
        
        property bool expanded: false
        
        Behavior on height {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: otherArea.expanded ? 32 : 18  // 縮起時減少margins
            spacing: 16
            
            
            // 標題行（可點擊展開）
            Item {
                width: parent.width
                height: otherArea.expanded ? 24 : parent.height  // 縮起時填滿可用高度
                
                Row {
                    anchors.centerIn: parent  // 在Item中居中
                    spacing: 12
                    
                    Rectangle {
                        width: 4
                        height: 24
                        radius: 2
                        color: "#66FCF1"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "其他區"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#66FCF1"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { 
                        width: otherArea.expanded ? (otherArea.width - 200) : (otherArea.width - 160)  // 動態調整寬度
                        height: 24
                    }
                    
                    // 展開/收合按鈕
                    Rectangle {
                        width: 32
                        height: 24
                        radius: 12
                        color: Qt.rgba(0.4, 0.99, 0.95, toggleArea.containsMouse ? 0.2 : 0.1)
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: otherArea.expanded ? "▲" : "▼"
                            color: "#66FCF1"
                            font.pixelSize: 12
                        }
                        
                        MouseArea {
                            id: toggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: otherArea.expanded = !otherArea.expanded
                        }
                    }
                }
            }
            
            // 選項按鈕（只在展開時顯示）
            Flow {
                width: parent.width
                spacing: 12
                visible: otherArea.expanded
                opacity: otherArea.expanded ? 1.0 : 0.0
                clip: true
                
                Behavior on opacity {
                    NumberAnimation { duration: 300 }
                }
                
                Repeater {
                    model: otherOptions
                    delegate: OptionButton {
                        text: modelData.text
                        optionKey: modelData.key
                        checked: modelData.selected
                        buttonSize: "small"
                        onToggled: root.optionToggled("other", index)
                    }
                }
            }
        }
    }
    
    // 生成按鈕
    Item {
        width: parent.width
        height: 80
        
        Rectangle {
            id: generateButton
            width: 200
            height: 50
            radius: 25
            anchors.centerIn: parent
            
            gradient: Gradient {
                GradientStop { 
                    position: 0.0
                    color: canGenerate 
                        ? (generateArea.pressed ? "#4A9B8E" : "#66FCF1")
                        : "#34495E"
                }
                GradientStop { 
                    position: 1.0
                    color: canGenerate 
                        ? (generateArea.pressed ? "#2F7A6B" : "#4A9B8E")
                        : "#2C3E50"
                }
            }
            
            border.width: 2
            border.color: canGenerate ? "#66FCF1" : "#34495E"
            
            // 發光效果
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: parent.radius + 6
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(0.4, 0.99, 0.95, canGenerate ? 0.3 : 0.1)
                opacity: canGenerate ? (generateArea.containsMouse ? 1.0 : 0.6) : 0.2
                
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: "生成結果"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: canGenerate ? "#0B0C10" : "#7F8C8D"
            }
            
            MouseArea {
                id: generateArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: canGenerate ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: {
                    if (canGenerate) {
                        root.generateClicked()
                    }
                }
            }
            
            // 工具提示
            ToolTip.visible: !canGenerate && generateArea.containsMouse
            ToolTip.text: "請先選擇檔案與遮蔽選項"
        }
    }
}
