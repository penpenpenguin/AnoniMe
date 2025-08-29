import QtQuick
import QtQuick.Controls

/**
 * 檔案上傳區域組件
 * 包含拖放區域和檔案列表
 */
 
Column {
    id: root
    spacing: 20
    
    // 公開屬性
    property alias fileModel: fileRepeater.model
    property var acceptedExtensions: ["txt", "pdf", "doc", "docx"]
    property int maxFiles: 20
    property bool uploading: false
    
    // 信號
    signal fileAdded(string fileName, string filePath)
    signal fileRemoved(int index)
    signal filesDropped(var urls)
    signal browseFiles()
    
    // 標題
    Text {
        text: "檔案上傳"
        font.pixelSize: 24
        font.weight: Font.Bold
        color: "#FFFFFF"
    }
    
    // 拖放上傳區域
    Rectangle {
        id: dropZone
        width: parent.width
        height: 280
        radius: 16
        color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
        border.width: 2
        border.color: dragHover ? "#66FCF1" : Qt.rgba(0.4, 0.99, 0.95, 0.3)
        
        property bool dragHover: false
        
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }
        
        // 發光效果
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0.4, 0.99, 0.95, parent.dragHover ? 0.4 : 0.1)
            opacity: parent.dragHover ? 1.0 : 0.5
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            // 上傳圖標
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 60
                height: 60
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 60
                    height: 60
                    radius: 30
                    color: "transparent"
                    border.width: 2
                    border.color: "#66FCF1"
                    opacity: 0.8
                    
                    RotationAnimation on rotation {
                        running: dropZone.dragHover
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 3000
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "📁"
                    font.pixelSize: 24
                    color: "#66FCF1"
                    scale: dropZone.dragHover ? 1.1 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
            
            // 上傳文字
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "拖放檔案至此處"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: "#FFFFFF"
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "支援 " + acceptedExtensions.map(function(ext) { return ext.toUpperCase() }).join(" • ")
                    font.pixelSize: 12
                    color: "#66FCF1"
                    opacity: 0.8
                }
            }
            
            // 檔案計數
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (fileModel && fileModel.count > 0) ? (fileModel.count + " 個檔案已選擇") : ""
                font.pixelSize: 10
                color: "#66FCF1"
                opacity: 0.6
                visible: fileModel && fileModel.count > 0
            }
        }
        
        // 拖放處理
        DropArea {
            anchors.fill: parent
            onEntered: function(drag) {
                drag.acceptProposedAction()
                dropZone.dragHover = true
            }
            onExited: {
                dropZone.dragHover = false
            }
            onDropped: function(drop) {
                dropZone.dragHover = false
                if (drop.hasUrls && drop.urls.length > 0) {
                    root.filesDropped(drop.urls)
                }
                drop.acceptProposedAction()
            }
        }
        
        // 點擊上傳
        MouseArea {
            anchors.fill: parent
            onClicked: root.browseFiles()
            cursorShape: Qt.PointingHandCursor
        }
    }
    
    // 檔案列表
    Rectangle {
        width: parent.width
        height: 120
        radius: 16
        color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
        border.width: 2
        border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
        visible: fileModel && fileModel.count > 0
        
        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            
            // 標題
            Row {
                spacing: 12
                
                Rectangle {
                    width: 4
                    height: 16
                    radius: 2
                    color: "#66FCF1"
                }
                
                Text {
                    text: "已選檔案"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#66FCF1"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // 檔案清單
            ScrollView {
                width: parent.width
                height: 60
                clip: true
                
                Flow {
                    width: parent.width
                    spacing: 6
                    
                    Repeater {
                        id: fileRepeater
                        delegate: Rectangle {
                            radius: 12
                            color: Qt.rgba(0.4, 0.99, 0.95, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                            height: 24
                            width: Math.min(chipText.implicitWidth + 40, 160)
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6
                                
                                Text {
                                    id: chipText
                                    text: model.name || ""
                                    font.pixelSize: 10
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 120)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "✕"
                                    color: "#66FCF1"
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.fileRemoved(index)
                                    }
                                }
                            }
                            
                            ToolTip.visible: hoverHandler.hovered
                            ToolTip.text: model.name || ""
                            HoverHandler { id: hoverHandler }
                        }
                    }
                }
            }
        }
    }
}
