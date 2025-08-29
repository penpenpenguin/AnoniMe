import QtQuick

/**
 * 科技感背景組件
 * 包含漸層、網格線和動態粒子效果
 */
 
Rectangle {
    anchors.fill: parent
    
    // 漸層背景
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
    
    // 動態粒子效果
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
        }
    }
}
