import QtQuick
import QtQuick.Controls


/**
 * 可重用的選項按鈕組件
 */
Rectangle {
    id: root
    
    // 公開屬性
    property string text: ""
    property string optionKey: ""
    property bool checked: false
    property string buttonSize: "medium" // "small", "medium", "large"
    
    // 信號
    signal toggled()
    
    // 計算尺寸
    readonly property var sizes: ({
        small: { width: 100, height: 32, fontSize: 10, padding: 20 },
        medium: { width: 120, height: 36, fontSize: 12, padding: 24 },
        large: { width: 140, height: 40, fontSize: 14, padding: 28 }
    })
    
    readonly property var currentSize: sizes[buttonSize] || sizes.medium
    
    width: Math.min(buttonText.implicitWidth + currentSize.padding, currentSize.width)
    height: currentSize.height
    radius: height / 2
    
    // 背景和邊框
    color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.4) : Qt.rgba(0.15, 0.2, 0.25, 0.8)
    border.width: checked ? 2 : 1
    border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.8)
    
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    
    // 發光效果
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: parent.radius + 3
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.4, 0.99, 0.95, root.checked ? 0.6 : 0.0)
        opacity: root.checked ? (mouseArea.containsMouse ? 1.0 : 0.7) : 0.0
        
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    
    Text {
        id: buttonText
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: currentSize.fontSize
        font.weight: root.checked ? Font.Bold : Font.Medium
        color: "#FFFFFF"
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
    
    // 懸停縮放效果
    scale: mouseArea.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150 } }
}
