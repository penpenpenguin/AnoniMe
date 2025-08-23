import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: homeRoot
    // 傳入
    property int base: 72
    // 對 Main 發出導航請求
    signal requestNavigate(string target, var payload)

    anchors.fill: parent

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
        
        // 動態背景粒子
        Repeater {
            model: 15
            Rectangle {
                width: 2 + Math.random() * 3
                height: width
                radius: width / 2
                color: Qt.rgba(0.4, 0.99, 0.95, 0.4 + Math.random() * 0.6)
                x: Math.random() * parent.width
                y: Math.random() * parent.height
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { 
                        from: 0.1; to: 0.8
                        duration: 2000 + Math.random() * 3000
                        easing.type: Easing.InOutSine 
                    }
                    NumberAnimation { 
                        from: 0.8; to: 0.1
                        duration: 2000 + Math.random() * 3000
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
                        parent.x = Math.random() * homeRoot.width
                        parent.y = homeRoot.height + 20
                    }
                }
            }
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
    }

    // 主要內容區域
    Item {
        anchors.fill: parent
        anchors.margins: 60
        
        // 中央內容
        Column {
            anchors.centerIn: parent
            spacing: 60
            
            // 品牌區域
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 400
                height: 120
                
                // 主標題
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: "AnoniMe"
                    font.pixelSize: 48
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    font.family: "Segoe UI"
                    
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 1.0; duration: 2000 }
                        NumberAnimation { from: 1.0; to: 0.8; duration: 2000 }
                    }
                }
                
                // 副標題
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: "隱私保護 • 文檔匿名處理"
                    font.pixelSize: 18
                    color: "#66FCF1"
                    font.weight: Font.Light
                    opacity: 0.9
                }
                
                // 裝飾線
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80
                    height: 2
                    color: "#66FCF1"
                    opacity: 0.6
                    
                    SequentialAnimation on width {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 60; to: 100; duration: 3000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 100; to: 60; duration: 3000; easing.type: Easing.InOutSine }
                    }
                }
            }
            
            // 透明檔案上傳框
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 500
                height: 300
                radius: 20
                color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
                border.width: 2
                border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                
                // 發光效果
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.1)
                    opacity: uploadArea.containsMouse ? 1.0 : 0.5
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
                
                Column {
                    anchors.centerIn: parent
                    spacing: 30
                    
                    // 上傳圖標
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80
                        height: 80
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 80
                            height: 80
                            radius: 40
                            color: "transparent"
                            border.width: 3
                            border.color: "#66FCF1"
                            opacity: 0.8
                            
                            RotationAnimation on rotation {
                                running: uploadArea.containsMouse
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 4000
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "📄"
                            font.pixelSize: 32
                            color: "#66FCF1"
                            
                            SequentialAnimation on scale {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 1.1; duration: 1500; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 1.1; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                    
                    // 上傳文字
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "開始匿名化您的文檔"
                            font.pixelSize: 24
                            font.weight: Font.Medium
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "點擊此處上傳文件"
                            font.pixelSize: 16
                            color: "#66FCF1"
                            opacity: 0.8
                        }
                    }
                }
                
                // 點擊區域
                MouseArea {
                    id: uploadArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: requestNavigate("upload", null)
                    
                    // hover 效果
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.parent.radius
                        color: Qt.rgba(0.4, 0.99, 0.95, 0.05)
                        opacity: parent.containsMouse ? 1.0 : 0.0
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }
            }
            
            // 功能說明
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 60
                
                Repeater {
                    model: [
                        { icon: "🔒", title: "安全加密", desc: "軍用級加密技術" },
                        { icon: "⚡", title: "快速處理", desc: "毫秒級響應速度" },
                        { icon: "🎯", title: "精準匿名", desc: "智能識別敏感訊息" }
                    ]
                    
                    Column {
                        spacing: 12
                        width: 120
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 32
                            
                            SequentialAnimation on scale {
                                running: true
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 600 }
                                NumberAnimation { from: 1.0; to: 1.2; duration: 400 }
                                NumberAnimation { from: 1.2; to: 1.0; duration: 400 }
                                PauseAnimation { duration: 2000 }
                            }
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.title
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.desc
                            font.pixelSize: 12
                            color: "#66FCF1"
                            opacity: 0.7
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}