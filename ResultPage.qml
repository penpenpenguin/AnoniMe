import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    anchors.fill: parent
    spacing: 24
    property int base: 72
    property int maxContentWidth: 1280
    property bool narrow: width < 1050
    property int sideWidth: 360
    signal requestNavigate(string target, var payload)

    ListModel { id: resultModel }     // { fileName, originalText, maskedText, type, expanded, viewMode }
    ListModel { id: fileNameModel }   // { name }

    // 對外 API
    function loadResults(arr) {
        resultModel.clear()
        fileNameModel.clear()
        if (!arr || !arr.length) return
        for (let i=0;i<arr.length;i++) {
            const o = arr[i]
            resultModel.append({
                                   fileName: o.fileName || ("Result_" + (i+1)),
                                   originalText: o.originalText || o.previewText || "(無原始內容)",
                                   maskedText: o.maskedText || o.previewText || "(無去識別化內容)",
                                   type: o.type || "text",
                                   expanded: false,
                                   viewMode: "masked"   // masked | original
                               })
            fileNameModel.append({ name: o.fileName || ("Result_" + (i+1)) })
        }
        // 開頭捲到頂
        contentFlick.contentY = 0
    }

    function downloadAll() {
        if (typeof backend !== "undefined" && backend.downloadAll)
            backend.downloadAll()
        else
            console.log("backend.downloadAll 未實作")
    }

    function scrollTo(idx) {
        if (idx < 0 || idx >= cardColumn.children.length) return
        const item = cardColumn.children[idx]
        contentFlick.contentY = item.y - 8
    }

    // Header (Back + Title)
    RowLayout {
        Layout.fillWidth: true
        spacing: 20
        Text {
            text: "← Back"
            font.pixelSize: 16
            font.bold: true
            color: backMouse.pressed ? "#2F7A47"
                  : backMouse.containsMouse ? "#66CC33" : "#DDDDDD"
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: requestNavigate("home", null)
            }
        }
        Item { Layout.fillWidth: true }
    }

    // 成功訊息
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "去識別化完成囉！"
        font.pixelSize: 32
        font.bold: true
        color: "#66CC33"
    }

    // 主版面容器（自適應：寬→左右；窄→上下）
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // 置中框
        Item {
            id: frame
            anchors.fill: parent
            implicitWidth: Math.min(root.width, root.maxContentWidth)
            width: Math.min(root.width, root.maxContentWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 0

            // 寬版布局
            Row {
                id: wideLayout
                anchors.fill: parent
                spacing: 28
                visible: !root.narrow

                // 左側內容區
                Flickable {
                    id: contentFlick
                    clip: true
                    contentWidth: width
                    contentHeight: cardColumn.implicitHeight
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 2500
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    width: parent.width - sidePanel.width - wideLayout.spacing
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        id: cardColumn
                        width: contentFlick.width
                        spacing: 16

                        // 卡片列表
                        Repeater {
                            model: resultModel
                            delegate: cardDelegate
                        }

                        // 無資料
                        Text {
                            visible: resultModel.count === 0
                            width: parent.width
                            text: "尚無結果"
                            color: "#999"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 14
                            padding: 40
                        }
                        Item { width: 1; height: 12 }
                    }
                }

                // 右側側欄
                Rectangle {
                    id: sidePanel
                    width: root.sideWidth
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 10
                    color: "#F8F8F8"
                    border.color: "#D6D6D6"
                    border.width: 1

                    Item {
                        id: sidePanelBody
                        anchors.fill: parent
                        anchors.margins: 16

                        // 標題
                        Text {
                            id: sideHeader
                            text: "處理檔案"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#333"
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                        }

                        // 檔案清單捲動區域
                        ScrollView {
                            id: fileScroll
                            anchors {
                                top: sideHeader.bottom
                                topMargin: 12
                                left: parent.left
                                right: parent.right
                                bottom: footerRow.top
                                bottomMargin: 12
                            }
                            clip: true
                            Column {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: fileNameModel
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 34
                                        radius: 6
                                        property int delegateIndex: index
                                        color: hover ? "#E9F7EE" : "white"
                                        border.color: "#D0E3D8"
                                        border.width: 1
                                        property bool hover: false
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            Text {
                                                text: name
                                                font.pixelSize: 13
                                                color: "#444"
                                                elide: Text.ElideRight
                                                width: parent.width - openBtn.width - 12
                                            }
                                            Button {
                                                id: openBtn
                                                text: "查看"
                                                font.pixelSize: 11
                                                padding: 4
                                                background: Rectangle {
                                                    radius: 4
                                                    color: openBtn.pressed ? "#4EA773"
                                                          : openBtn.hovered ? "#59B481" : "#66CC33"
                                                }
                                                contentItem: Text {
                                                    anchors.centerIn: parent
                                                    text: openBtn.text
                                                    color: "white"
                                                    font.pixelSize: openBtn.font.pixelSize
                                                    font.bold: true
                                                }
                                                onClicked: scrollTo(delegateIndex)
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.hover = true
                                            onExited: parent.hover = false
                                            onClicked: scrollTo(delegateIndex)
                                        }
                                    }
                                }
                            }
                        }

                        // 底部按鈕列
                        RowLayout {
                            id: footerRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            spacing: 10
                            Button {
                                id: downloadBtn
                                Layout.fillWidth: true
                                text: "下載全部"
                                enabled: resultModel.count > 0
                                height: 40
                                background: Rectangle {
                                    radius: 6
                                    color: enabled
                                           ? (downloadBtn.pressed ? "#4EA773"
                                              : downloadBtn.hovered ? "#59B481" : "#66CC33")
                                           : "#BBBBBB"
                                }
                                contentItem: Text {
                                    anchors.centerIn: parent
                                    text: downloadBtn.text
                                    color: enabled ? "white" : "#666"
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                onClicked: downloadAll()
                            }
                            Button {
                                id: homeBtn
                                Layout.fillWidth: true   // 讓它取得另一半寬度
                                text: "返回首頁"
                                height: 40
                                background: Rectangle {
                                    radius: 6
                                    color: homeBtn.pressed ? "#4EA773"
                                          : homeBtn.hovered ? "#59B481" : "#66CC33"
                                }
                                contentItem: Text {
                                    anchors.centerIn: parent
                                    text: homeBtn.text
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                onClicked: requestNavigate("home", null)
                            }
                        }
                    }
                }
            }

            // 窄版：上下堆疊（側欄放下）
            Column {
                id: narrowLayout
                anchors.fill: parent
                spacing: 20
                visible: root.narrow

                Flickable {
                    id: contentFlickN
                    clip: true
                    contentWidth: width
                    contentHeight: cardColumnN.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    width: parent.width
                    height: parent.height - sidePanelN.height - narrowLayout.spacing

                    Column {
                        id: cardColumnN
                        width: contentFlickN.width
                        spacing: 16
                        Repeater {
                            model: resultModel
                            delegate: cardDelegate
                        }
                        Text {
                            visible: resultModel.count === 0
                            width: parent.width
                            text: "尚無結果"
                            color: "#999"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 14
                            padding: 40
                        }
                        Item { width: 1; height: 8 }
                    }
                }

                Rectangle {
                    id: sidePanelN
                    width: parent.width
                    height: Math.min(260, 100 + fileNameModel.count * 36)
                    radius: 10
                    color: "#F8F8F8"
                    border.color: "#D6D6D6"
                    border.width: 1

                    Item {
                        id: sidePanelNBody
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            id: sideHeaderN
                            text: "處理檔案"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#333"
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                        }

                        ScrollView {
                            id: fileScrollN
                            anchors {
                                top: sideHeaderN.bottom
                                topMargin: 10
                                left: parent.left
                                right: parent.right
                                bottom: footerRowN.top
                                bottomMargin: 10
                            }
                            clip: true
                            Column {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: fileNameModel
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 32
                                        radius: 6
                                        property int delegateIndex: index
                                        color: hover ? "#E9F7EE" : "white"
                                        border.color: "#D0E3D8"
                                        border.width: 1
                                        property bool hover: false
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6
                                            Text {
                                                text: name
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                                color: "#444"
                                                width: parent.width - openBtn.width - 10
                                            }
                                            Button {
                                                id: openBtn
                                                text: "查看"
                                                font.pixelSize: 11
                                                padding: 4
                                                background: Rectangle {
                                                    radius: 4
                                                    color: openBtn.pressed ? "#4EA773"
                                                          : openBtn.hovered ? "#59B481" : "#66CC33"
                                                }
                                                contentItem: Text {
                                                    anchors.centerIn: parent
                                                    text: openBtn.text
                                                    color: "white"
                                                    font.pixelSize: openBtn.font.pixelSize
                                                    font.bold: true
                                                }
                                                onClicked: {
                                                    for (let i=0;i<cardColumnN.children.length;i++) {
                                                        if (cardColumnN.children[i].fileName === name) {
                                                            contentFlickN.contentY = cardColumnN.children[i].y - 4
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.hover = true
                                            onExited: parent.hover = false
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            id: footerRowN
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            spacing: 10
                            Button {
                                id: downloadBtnN
                                Layout.fillWidth: true
                                text: "下載全部"
                                enabled: resultModel.count > 0
                                height: 40
                                background: Rectangle {
                                    radius: 6
                                    color: enabled ? "#66CC33" : "#BBBBBB"
                                }
                                contentItem: Text {
                                    anchors.centerIn: parent
                                    text: downloadBtnN.text
                                    color: enabled ? "white" : "#666"
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                onClicked: downloadAll()
                            }
                            Button {
                                id: homeBtnN
                                Layout.fillWidth: true
                                text: "返回首頁"
                                height: 40
                                background: Rectangle {
                                    radius: 6
                                    color: homeBtnN.pressed ? "#4EA773"
                                          : homeBtnN.hovered ? "#59B481" : "#66CC33"
                                }
                                contentItem: Text {
                                    anchors.centerIn: parent
                                    text: homeBtnN.text
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                onClicked: requestNavigate("home", null)
                            }
                        }
                    }
                }
            }
        }
    }

    // 卡片 Component
    Component {
        id: cardDelegate
        Rectangle {
            id: card
            // 從 model role 綁定
            property int    modelIndex: index
            property string fileName: model.fileName
            property string originalText: model.originalText
            property string maskedText: model.maskedText
            property string type: model.type
            property bool   expanded: model.expanded
            property string viewMode: model.viewMode   // masked / original

            width: parent ? parent.width : 600
            radius: 10
            color: "#F8F8F8"
            border.color: "#DCDCDC"
            border.width: 1
            property int maxCollapsedLines: 4
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            implicitHeight: contentColumn.implicitHeight + 32

            Column {
                id: contentColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 16
                    rightMargin: 16
                    top: parent.top
                    topMargin: 16
                }
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 12
                    Text {
                        text: card.fileName
                        font.pixelSize: 16
                        font.bold: true
                        color: "#333"
                        elide: Text.ElideRight
                        width: parent.width - viewSwitcher.width - expandBtn.width - 24
                    }
                    Row {
                        id: viewSwitcher
                        spacing: 4
                        property int tabW: 54
                        Repeater {
                            model: ["去識別後","原文"]
                            delegate: Rectangle {
                                width: viewSwitcher.tabW
                                height: 26
                                radius: 6
                                color: (index===0 && card.viewMode==="masked") ||
                                       (index===1 && card.viewMode==="original")
                                       ? "#66CC33" : "#E0E0E0"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: ((index===0 && card.viewMode==="masked") ||
                                            (index===1 && card.viewMode==="original"))
                                            ? "white" : "#444"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        card.viewMode = (index===0) ? "masked" : "original"
                                        resultModel.set(card.modelIndex, {
                                            fileName: card.fileName,
                                            originalText: card.originalText,
                                            maskedText: card.maskedText,
                                            type: card.type,
                                            expanded: card.expanded,
                                            viewMode: card.viewMode
                                        })
                                    }
                                }
                            }
                        }
                    }
                    Button {
                        id: expandBtn
                        text: card.expanded ? "收合" : "展開"
                        font.pixelSize: 12
                        padding: 6
                        background: Rectangle {
                            radius: 6
                            color: expandBtn.pressed ? "#4EA773"
                                  : expandBtn.hovered ? "#59B481" : "#66CC33"
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            text: expandBtn.text
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        onClicked: {
                            card.expanded = !card.expanded
                            resultModel.set(card.modelIndex, {
                                fileName: card.fileName,
                                originalText: card.originalText,
                                maskedText: card.maskedText,
                                type: card.type,
                                expanded: card.expanded,
                                viewMode: card.viewMode
                            })
                        }
                    }
                }

                Loader {
                    width: parent.width
                    sourceComponent: textViewComp
                }
            }

            Component {
                id: textViewComp
                Column {
                    spacing: 6
                    Text {
                        id: contentText
                        width: parent.width
                        text: card.viewMode === "masked" ? card.maskedText : card.originalText
                        wrapMode: Text.Wrap
                        font.pixelSize: 14
                        color: "#222"
                        elide: card.expanded ? Text.ElideNone : Text.ElideRight
                        maximumLineCount: card.expanded ? -1 : card.maxCollapsedLines
                    }
                }
            }
        }
    }

    // 測試資料（外部未呼叫時）
    Component.onCompleted: {
        if (resultModel.count === 0) {
            loadResults([
                {
                    fileName: "測試1.txt",
                    originalText: "原文：這是第一個檔案的原始文字。\n第二行原文資料。",
                    maskedText: "去識別後：這是第一個檔案的處理結果。\n第二行處理後資料。"
                },
                {
                    fileName: "報告2.docx",
                    originalText: "原文：很長很長的內容 AAAAA BBBBB CCCCC DDDDD EEEEE FFFFF GGGGG HHHHH IIIII JJJJJ …",
                    maskedText: "去識別後：長內容已遮蔽 (示例) ……"
                }
            ])
        }
    }
}