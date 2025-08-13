import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: homeRoot
    // 傳入
    property int base: 72
    // 對 Main 發出導航請求
    signal requestNavigate(string target, var payload)

    anchors.fill: parent
    anchors.margins: base * 0.5
    spacing: base * 0.9

    // 打字機相關
    property string fullText: "EASILY LIVE WITH SAFETY"
    property string typingText: ""
    property string dotsText: ""
    property int _typingIndex: 0
    property var _dotCycle: ["", ".", "..", "..."]
    property int _dotIndex: 0

    function restartAnimations() {
        typingTimer.stop()
        dotsTimer.stop()
        typingText = ""
        dotsText = ""
        _typingIndex = 0
        _dotIndex = 0
        typingTimer.start()
        dotsTimer.start()
    }

    Timer {
        id: typingTimer
        interval: 100; repeat: true; running: false
        onTriggered: {
            if (_typingIndex < fullText.length)
                typingText += fullText.charAt(_typingIndex++)
            else
                stop()
        }
    }
    Timer {
        id: dotsTimer
        interval: 400; repeat: true; running: false
        onTriggered: {
            dotsText = _dotCycle[_dotIndex]
            _dotIndex = (_dotIndex + 1) % _dotCycle.length
        }
    }
    Component.onCompleted: restartAnimations()

    Item {
        id: heroArea
        Layout.fillWidth: true
        height: hero.height

        Column {
            id: hero
            anchors.left: parent.left
            anchors.leftMargin: base * 0.9
            spacing: base * 0.35
            property int heroWidth: Math.max(line1.implicitWidth,
                                             Math.max(line2.implicitWidth, line3.implicitWidth))
            Text { id: line1; width: hero.heroWidth; text: "ENCRYPT"; color: "#E7A36F"; font.pixelSize: base * 1.4; font.bold: true }
            Text { id: line2; width: hero.heroWidth; text: "YOUR";    color: "white";  font.pixelSize: base * 1.1; font.bold: true }
            Text { id: line3; width: hero.heroWidth; text: "LIFE";    color: "#71B784";font.pixelSize: base * 1.1; font.bold: true }
        }

        Item {
            id: typingBox
            anchors.left: hero.right
            anchors.leftMargin: base * 1.2
            anchors.bottom: hero.bottom
            property real typingWidth: parent.width * 0.42
            width: typingWidth
            height: hero.height
            property real typingScale: 0.33
            Text {
                text: homeRoot.typingText + homeRoot.dotsText
                color: "white"
                wrapMode: Text.Wrap
                width: parent.width
                anchors.bottom: parent.bottom
                font.pixelSize: base * typingBox.typingScale
                font.bold: true
                font.letterSpacing: 1.1
            }
        }
    }

    Button {
        id: uploadBtn
        Layout.topMargin: base * 0.6
        Layout.alignment: Qt.AlignHCenter
        text: "Upload"
        padding: 0
        leftPadding: 20; rightPadding: 20
        topPadding: 8;  bottomPadding: 8
        font.pixelSize: Math.max(16, base * 0.28)
        font.bold: true
        background: Rectangle {
            radius: 14
            color: uploadBtn.pressed ? "#4EA773"
                  : uploadBtn.hovered ? "#59B481" : "#63C290"
        }
        contentItem: Text {
            anchors.centerIn: parent
            text: uploadBtn.text
            color: "white"
            font.pixelSize: uploadBtn.font.pixelSize
            font.bold: true
        }
        onClicked: requestNavigate("upload", null)
    }

    Item { Layout.fillHeight: true }
}