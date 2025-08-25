import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components" 
import "."

Item {
    id: pageRoot
    anchors.fill: parent

    // 提供給 Loader 連結與呼叫
    signal requestNavigate(string target, var payload)
    function loadResults(arr) {
        console.log("loadResults called with:", arr)
    }

    // 科技感漸層背景
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0B0C10" }
            GradientStop { position: 0.3; color: "#1F2833" }
            GradientStop { position: 0.7; color: "#2C3E50" }
            GradientStop { position: 1.0; color: "#34495E" }
        }
        
        // 網格線背景
        Canvas {
            anchors.fill: parent
            opacity: 0.02
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#66FCF1"
                ctx.lineWidth = 1
                
                var gridSize = 50
                for (var x = 0; x <= width; x += gridSize) {
                    ctx.beginPath()
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                    ctx.stroke()
                }
                for (var y = 0; y <= height; y += gridSize) {
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }
            }
        }
        
        // 動態背景粒子
        Repeater {
            model: 8
            Rectangle {
                width: 2 + Math.random() * 3
                height: width
                radius: width / 2
                color: Qt.rgba(0.4, 0.99, 0.95, 0.3 + Math.random() * 0.4)
                x: Math.random() * parent.width
                y: Math.random() * parent.height
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { 
                        from: 0.1; to: 0.6
                        duration: 3000 + Math.random() * 2000
                        easing.type: Easing.InOutSine 
                    }
                    NumberAnimation { 
                        from: 0.6; to: 0.1
                        duration: 3000 + Math.random() * 2000
                        easing.type: Easing.InOutSine 
                    }
                }
                
                NumberAnimation on y {
                    running: true
                    loops: Animation.Infinite
                    from: y; to: y - 30 - Math.random() * 50
                    duration: 8000 + Math.random() * 4000
                    easing.type: Easing.InOutQuad
                    onFinished: {
                        parent.x = Math.random() * pageRoot.width
                        parent.y = pageRoot.height + 20
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 40
        
        // 頂部導航
        Item {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            
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
                        text: ""
                        color: "#66FCF1"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "返回上傳"
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
                    onClicked: requestNavigate("upload", null)
                }
            }
            
            // 標題
            Text {
                anchors.centerIn: parent
                text: "處理結果"
                font.pixelSize: 24
                font.weight: Font.Bold
                color: "#FFFFFF"
            }
        }

        // 測試用簡單內容區域
        Rectangle {
            id: testContent
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 30
            color: Qt.rgba(0.07, 0.08, 0.1, 0.8)
            radius: 16
            border.width: 2
            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "結果頁面測試"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#66FCF1"
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "如果您看到這個文字，說明頁面基本結構正常"
                    font.pixelSize: 16
                    color: "#FFFFFF"
                    opacity: 0.8
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300
                    height: 200
                    radius: 12
                    color: Qt.rgba(0.15, 0.2, 0.25, 0.8)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.5)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "檔案處理結果將顯示在這裡"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
