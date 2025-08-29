import QtQuick
import QtQuick.Controls

/**
 * 頂部導航欄組件
 * 包含返回按鈕和進度顯示
 */
 
Item {
    id: root
    
    // 公開屬性
    property bool showProgress: false
    property int progressValue: 0
    property string statusText: ""
    
    // 信號
    signal backClicked()
    
    // 返回按鈕
    Item {
        id: backButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: backContent.width + 20
        height: 40
        
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(0.4, 0.99, 0.95, backArea.containsMouse ? 0.15 : 0.08)
            border.width: 1
            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
            
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }
        
        Row {
            id: backContent
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                text: "←"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "返回"
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }
    
    // 進度指示器
    Item {
        id: progressIndicator
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        height: 40
        visible: showProgress
        opacity: visible ? 1 : 0
        
        Behavior on opacity { 
            NumberAnimation { duration: 200 } 
        }
        
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(0.07, 0.08, 0.1, 0.8)
            border.width: 1
            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 4
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: statusText
                color: "#FFFFFF"
                font.pixelSize: 12
                font.weight: Font.Medium
                visible: statusText.length > 0
            }
            
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 240
                height: 6
                radius: 3
                color: Qt.rgba(0.4, 0.99, 0.95, 0.2)
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: 3
                    width: Math.max(6, parent.width * progressValue / 100)
                    color: "#66FCF1"
                    
                    SequentialAnimation on opacity {
                        running: progressIndicator.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 1.0; duration: 800 }
                        NumberAnimation { from: 1.0; to: 0.8; duration: 800 }
                    }
                }
            }
        }
    }
}
