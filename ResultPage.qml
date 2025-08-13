import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: pageRoot
    anchors.fill: parent
    color: "#FFFFFF"  // 白色背景

    // 對外暴露：讓 Main.qml 的 Loader 能直接呼叫與連線
    signal requestNavigate(string target, var payload)
    function loadResults(arr) {
        // 轉呼叫內部實作
        if (root && root.loadResults)
            root.loadResults(arr)
    }

    ColumnLayout {
        id: root
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24
        
        property int base: 72
        property int maxContentWidth: 1280
        property bool narrow: width < 1050
        property int sideWidth: 360
        property int currentIndex: -1
        signal requestNavigate(string target, var payload)

        Component.onCompleted: {
            console.log("ResultPage loaded. 現有 resultModel.count =", resultModel.count)
            // 延遲檢查：避免載入競態造成未呼叫 loadResults
            Qt.createQmlObject('import QtQuick 2.15; Timer { interval:150; running:true; repeat:false; onTriggered: { if (resultModel.count===0 && typeof Qt !== "undefined") { var win = Qt.application.activeWindow; if (win && win.pendingPayload && win.pendingPayload.length!==undefined && root.loadResults) { console.log("ResultPage: 延遲補載入 pendingPayload"); root.loadResults(win.pendingPayload); win.pendingPayload = null; win.lastResultPayload = null; } } } }', root, "LateLoadTimer")
        }

    ListModel { id: resultModel }     // { fileName, originalText, maskedText, type, expanded, viewMode }
    ListModel { id: fileNameModel }   // { name }

    // 新增：全域顯示模式 (masked / original)
    property string currentViewMode: "masked"

    // 顯示資料模型
    ListModel { id: headerModel }   // { text, kind }
    ListModel { id: bodyModel }     // { lineNumber, text, kind }
        ListModel { id: resultModel }     // { fileName, originalText, maskedText, type, embedData }
        ListModel { id: fileNameModel }   // { name }

        // 對外 API
        function loadResults(arr) {
            console.log("ResultPage.loadResults() called with arr.length =", arr ? arr.length : "null")
            resultModel.clear()
            fileNameModel.clear()
            if (!arr || !arr.length) {
                console.log("ResultPage.loadResults() - no data to load")
                return
            }
            for (let i=0;i<arr.length;i++) {
                const o = arr[i]
                console.log("ResultPage.loadResults() - processing file", i, ":", o.fileName)
                resultModel.append({
                                       fileName: o.fileName || ("Result_" + (i+1)),
                                       originalText: o.originalText || o.previewText || "",
                                       maskedText: o.maskedText || o.originalText || o.previewText || "",
                                       type: o.type || "text",
                                       embedData: o.embedData || ({})
                                   })
                fileNameModel.append({ name: o.fileName || ("Result_" + (i+1)) })
            }
            root.currentIndex = resultModel.count > 0 ? 0 : -1
            console.log("ResultPage.loadResults() - loaded", resultModel.count, "files, currentIndex =", root.currentIndex)
            // 開頭捲到頂
            if (contentFlick) contentFlick.contentY = 0
        }

        function downloadAll() {
            if (typeof backend !== "undefined" && backend.downloadAll)
                backend.downloadAll()
            else
                console.log("backend.downloadAll 未實作")
        }

        function selectFile(idx) {
            if (idx < 0 || idx >= resultModel.count) return
            root.currentIndex = idx
            // 捲到頂
            if (contentFlick) contentFlick.contentY = 0
            if (contentFlickN) contentFlickN.contentY = 0
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
                    onClicked: pageRoot.requestNavigate("home", null)
                }
            }
            Item { Layout.fillWidth: true }
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

                // 寬版布局：改用 RowLayout 防止重疊
                RowLayout {
                    id: wideLayout
                    anchors.fill: parent
                    spacing: 28
                    visible: !root.narrow

                    // 左側內容區（改用 Layout 分配空間）
                    Flickable {
                        id: contentFlick
                        clip: true
                        contentWidth: width
                        contentHeight: contentColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                    Column {
                        id: contentColumn
                        width: contentFlick.width
                        spacing: 18
                        padding: 0
                        Column {
                            id: contentColumn
                            width: contentFlick.width
                            spacing: 20
                            padding: 0

                            Rectangle {
                                width: parent.width
                                // 使用隱式高度，避免與內部元素高度互相牽制造成擠壓
                                implicitHeight: childColumn.implicitHeight + 32
                                radius: 10
                                color: "#F8F8F8"
                                border.color: "#DCDCDC"
                                border.width: 1
                                
                                Column {
                                    id: childColumn
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 14
                                    
                                    Text {
                                        text: root.currentIndex >= 0 ? resultModel.get(root.currentIndex).fileName : "選擇一個檔案來查看內容"
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#333"
                                        wrapMode: Text.Wrap
                                        width: parent.width
                                    }
                                    
                                    // 內嵌檢視器（若有 embedData 則優先）
                                    EmbedViewer {
                                        id: embedViewerWide
                                        width: parent.width
                                        visible: root.currentIndex >= 0
                                                 && resultModel.get(root.currentIndex).embedData
                                                 && resultModel.get(root.currentIndex).embedData.viewType
                                        embedData: root.currentIndex >= 0 ? resultModel.get(root.currentIndex).embedData : ({})
                                    }
                                    
                                    // 文字預覽（無 embedData 時後備顯示 originalText）
                                    ScrollView {
                                        width: parent.width
                                        // 固定高度，避免與父層高度互相扣算導致排版紊亂
                                        height: 500
                                        clip: true
                                        visible: !embedViewerWide.visible
                                        
                                        Text {
                                            text: root.currentIndex >= 0 ? (resultModel.get(root.currentIndex).originalText || "") : "請從右側檔案清單中選擇一個檔案來查看處理結果。\n\n如果您剛完成檔案上傳，處理結果應該會自動顯示在此處。"
                                            wrapMode: Text.Wrap
                                            font.pixelSize: 14
                                            color: "#222"
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 20 }
                        }
                    }

                    // 右側側欄（改用 Layout.preferredWidth，避免與左側重疊）
                    Rectangle {
                        id: sidePanel
                        Layout.preferredWidth: root.sideWidth
                        Layout.fillHeight: true
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
                                            property bool hover: false
                                            color: delegateIndex === root.currentIndex
                                                   ? "#D5F2E1"
                                                   : (hover ? "#E9F7EE" : "white")
                                            border.color: delegateIndex === root.currentIndex ? "#66CC33" : "#D0E3D8"
                                            border.width: 1
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
                                                    onClicked: root.selectFile(delegateIndex)
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: parent.hover = true
                                                onExited: parent.hover = false
                                                onClicked: root.selectFile(delegateIndex)
                                            }
                                        }
                                    }
                                }
                            }

                            // 底部按鈕列
                            RowLayout {
                                id: footerRow
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
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
                                    background: Rectangle { radius: 6; color: homeBtn.pressed ? "#4EA773" : homeBtn.hovered ? "#59B481" : "#66CC33" }
                                    contentItem: Text { anchors.centerIn: parent; text: homeBtn.text; color: "white"; font.bold: true; font.pixelSize: 14 }
                                    onClicked: pageRoot.requestNavigate("home", null)
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
                        contentHeight: contentColumnN.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        width: parent.width
                        height: parent.height - sidePanelN.height - narrowLayout.spacing

                        Column {
                            id: contentColumnN
                            width: contentFlickN.width
                            spacing: 20

                            Rectangle {
                                width: parent.width
                                implicitHeight: childColumnN.implicitHeight + 32
                                radius: 10
                                color: "#F8F8F8"
                                border.color: "#DCDCDC"
                                border.width: 1
                                
                                Column {
                                    id: childColumnN
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 14
                                    
                                    Text {
                                        text: root.currentIndex >= 0 ? resultModel.get(root.currentIndex).fileName : "選擇一個檔案來查看內容"
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#333"
                                        wrapMode: Text.Wrap
                                        width: parent.width
                                    }
                                    
                                    // 內嵌檢視器（若有 embedData 則優先）
                                    EmbedViewer {
                                        id: embedViewerNarrow
                                        width: parent.width
                                        visible: root.currentIndex >= 0
                                                 && resultModel.get(root.currentIndex).embedData
                                                 && resultModel.get(root.currentIndex).embedData.viewType
                                        embedData: root.currentIndex >= 0 ? resultModel.get(root.currentIndex).embedData : ({})
                                    }
                                    
                                    // 文字預覽（無 embedData 時後備顯示 originalText）
                                    ScrollView {
                                        width: parent.width
                                        height: 350
                                        clip: true
                                        visible: !embedViewerNarrow.visible
                                        
                                        Text {
                                            text: root.currentIndex >= 0 ? (resultModel.get(root.currentIndex).originalText || "") : "請從下方檔案清單中選擇一個檔案來查看處理結果。\n\n如果您剛完成檔案上傳，處理結果應該會自動顯示在此處。"
                                            wrapMode: Text.Wrap
                                            font.pixelSize: 14
                                            color: "#222"
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 20 }
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
                                            property bool hover: false
                                            color: delegateIndex === root.currentIndex
                                                   ? "#D5F2E1"
                                                   : (hover ? "#E9F7EE" : "white")
                                            border.color: delegateIndex === root.currentIndex ? "#66CC33" : "#D0E3D8"
                                            border.width: 1
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
                                                    onClicked: root.selectFile(delegateIndex)
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: parent.hover = true
                                                onExited: parent.hover = false
                                                onClicked: root.selectFile(delegateIndex)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                id: footerRowN
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
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
                                    background: Rectangle { radius: 6; color: homeBtnN.pressed ? "#4EA773" : homeBtnN.hovered ? "#59B481" : "#66CC33" }
                                    contentItem: Text { anchors.centerIn: parent; text: homeBtnN.text; color: "white"; font.bold: true; font.pixelSize: 14 }
                                    onClicked: pageRoot.requestNavigate("home", null)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
