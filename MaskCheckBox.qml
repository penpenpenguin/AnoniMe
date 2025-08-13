import QtQuick
import QtQuick.Controls

CheckBox {
    id: root
    property string optionKey: ""    // 新增：對應後端處理鍵
    // 配色
    property color accent: "#66CC33"
    property color accentHover: "#59B481"
    property color accentPressed: "#4EA773"
    property color borderNormal: "#B6C2BE"
    property color borderHover: "#8AA89E"
    property color disabledColor: "#D9DEDC"

    // 尺寸設定
    property int indicatorSize: 22
    property int gap: 10          // 指示器與文字間距
    property int vPadding: 4      // 上下內距 (可調行高)
    leftPadding: indicatorSize + gap
    rightPadding: 0
    topPadding: vPadding
    bottomPadding: vPadding

    implicitHeight: Math.max(indicatorSize, textItem.implicitHeight) + topPadding + bottomPadding

    // 文字
    contentItem: Text {
        id: textItem
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.enabled
               ? (root.checked ? "#222" : "#333")
               : "#999"
        font.pixelSize: 15
        font.bold: false
        elide: Text.ElideRight
    }

    // 指示器
    indicator: Rectangle {
        id: box
        x: 0
        y: (parent.height - indicatorSize) / 2
        width: indicatorSize
        height: indicatorSize
        radius: 6
        border.width: 2
        border.color: !root.enabled ? root.disabledColor
                    : root.checked ? (root.pressed ? root.accentPressed
                                       : root.hovered ? root.accentHover : root.accent)
                    : (root.hovered ? root.borderHover : root.borderNormal)
        color: !root.enabled ? "#F3F5F4"
              : root.checked ? (root.pressed ? root.accentPressed
                                : root.hovered ? root.accentHover : root.accent)
              : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // 勾勾
        Text {
            anchors.centerIn: parent
            text: "✓"
            visible: root.checked
            color: "white"
            font.pixelSize: 15
            font.bold: true
            scale: root.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
    }

    // Hover 柔光
    Rectangle {
        anchors.centerIn: box
        width: box.width + 14
        height: box.height + 14
        radius: 10
        color: root.accent
        opacity: (root.hovered && !root.checked && root.enabled) ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // Focus 外框
    Rectangle {
        anchors.centerIn: box
        width: box.width + 8
        height: box.height + 8
        radius: 8
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: "#2F7A47"
        Behavior on border.width { NumberAnimation { duration: 120 } }
    }

    states: State {
        name: "disabled"; when: !root.enabled
        PropertyChanges { target: box; opacity: 0.55 }
    }
}