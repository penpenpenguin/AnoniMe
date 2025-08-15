import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: pageRoot
    anchors.fill: parent
    color: "#FFFFFF"

    // 提供給 Loader 連結與呼叫
    signal requestNavigate(string target, var payload)
    function loadResults(arr) {
        if (root && root.loadResults) root.loadResults(arr)
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

        Component.onCompleted: {
            console.log("ResultPage loaded. 現有 resultModel.count =", resultModel.count)
            Qt.createQmlObject('import QtQuick 2.15; Timer { interval:150; running:true; repeat:false; onTriggered: { if (resultModel.count===0) { var win = Qt.application.activeWindow; if (win && win.pendingPayload && root.loadResults) { root.loadResults(win.pendingPayload); win.pendingPayload=null; win.lastResultPayload=null } } } }', root, "LateLoadTimer")
        }

        ListModel { id: resultModel }     // { fileName, originalText, maskedText, type, embedData }
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
                    originalText: o.originalText || o.previewText || "",
                    maskedText: o.maskedText || o.previewText || "",
                    type: o.type || "text",
                    embedData: o.embedData || null
                })
                fileNameModel.append({ name: o.fileName || ("Result_" + (i+1)) })
            }
            root.currentIndex = resultModel.count > 0 ? 0 : -1
            if (contentFlick) contentFlick.contentY = 0
            if (contentFlickN) contentFlickN.contentY = 0
            console.log("ResultPage.loadResults: 成功載入 =", resultModel.count, "fileNameModel.count =", fileNameModel.count)
        }

        function selectFile(idx) {
            if (idx < 0 || idx >= resultModel.count) return
            root.currentIndex = idx
            if (contentFlick) contentFlick.contentY = 0
            if (contentFlickN) contentFlickN.contentY = 0
        }
        // 主版面容器
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: frame
                anchors.fill: parent
                implicitWidth: Math.min(root.width, root.maxContentWidth)
                width: Math.min(root.width, root.maxContentWidth)
                anchors.horizontalCenter: parent.horizontalCenter

                // 寬版
                Row {
                    id: wideLayout
                    anchors.fill: parent
                    spacing: 28
                    visible: !root.narrow

                    // 左側內容
                    Flickable {
                        id: contentFlick
                        clip: true
                        contentWidth: width
                        contentHeight: contentColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        width: parent.width - sidePanel.width - wideLayout.spacing
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Column {
                            id: contentColumn
                            width: contentFlick.width
                            spacing: 20

                            // 內嵌預覽（使用 EmbedViewer）
                            Rectangle {
                                width: parent.width
                                radius: 10
                                color: "#F8F8F8"
                                border.color: "#DCDCDC"
                                border.width: 1

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 14

                                    // 類型橫幅（可留可拔）
                                    Row {
                                        spacing: 10
                                        Rectangle {
                                            width: 24; height: 24; radius: 5
                                            color: {
                                                let t = root.currentIndex>=0 ? resultModel.get(root.currentIndex).type : ""
                                                return t==="pdf" ? "#E74C3C" : t==="docx" ? "#2E6EE7" : "#888"
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: (root.currentIndex>=0 ? resultModel.get(root.currentIndex).type : "").toUpperCase().slice(0,3)
                                                color: "white"; font.pixelSize: 10; font.bold: true
                                            }
                                        }
                                        Text {
                                            text: {
                                                let t = root.currentIndex>=0 ? resultModel.get(root.currentIndex).type : ""
                                                if (t==="pdf") return "PDF 預覽（轉圖示意）"
                                                if (t==="docx" || t==="doc") return "DOCX 預覽（轉 PDF 圖示意）"
                                                if (t==="text") return "文字預覽"
                                                return "一般檔案預覽"
                                            }
                                            color: "#666"; font.pixelSize: 13
                                        }
                                    }

                                    // 主要 viewer
                                    EmbedViewer {
                                        id: embed
                                        width: parent.width
                                        embedData: root.currentIndex>=0 ? (resultModel.get(root.currentIndex).embedData || {}) : ({})
                                    }
                                }
                            }
                            Item { width: 1; height: 20 }
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

                            // 檔案清單
                            ScrollView {
                                id: fileScroll
                                anchors {
                                    top: sideHeader.bottom; topMargin: 12
                                    left: parent.left; right: parent.right
                                    bottom: footerRow.top; bottomMargin: 12
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
                                            color: index === root.currentIndex ? "#DFF3E5" : "white"
                                            border.width: 1
                                            border.color: index === root.currentIndex ? "#66CC33" : "#D6D6D6"
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8
                                                Text {
                                                    text: name
                                                    color: "#333"
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: parent.width
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.selectFile(index) }
                                        }
                                    }
                                }
                            }

                            // 底部按鈕
                            RowLayout {
                                id: footerRow
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                spacing: 10
                                Button {
                                    id: downloadBtn
                                    Layout.fillWidth: true
                                    text: "下載全部"
                                    enabled: resultModel.count > 0
                                    onClicked: {
                                        if (backend && backend.exportAllAndClear) {
                                            backend.exportAllAndClear()
                                        }
                                    }
                                }
                                Button {
                                    id: homeBtn
                                    Layout.fillWidth: true
                                    text: "返回首頁"
                                    onClicked: {
                                        if (backend && backend.clearTestOutput) {
                                            backend.clearTestOutput(false)   // False=整個 test_output 都清掉
                                        } else {
                                            pageRoot.requestNavigate("home", null)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 窄版
                Column {
                    id: narrowLayout
                    anchors.fill: parent
                    spacing: 20
                    visible: root.narrow

                    // 上：內容
                    Flickable {
                        id: contentFlickN
                        clip: true
                        contentWidth: width
                        contentHeight: contentColumnN.implicitHeight
                        ScrollBar.vertical: ScrollBar {}
                        width: parent.width
                        height: parent.height - sidePanelN.height - narrowLayout.spacing

                        Column {
                            id: contentColumnN
                            width: contentFlickN.width
                            spacing: 12

                            Text {
                                text: root.currentIndex >= 0 ? resultModel.get(root.currentIndex).fileName : ""
                                font.pixelSize: 20; font.bold: true; color: "#66CC33"
                            }
                            EmbedViewer {
                                width: parent.width
                                embedData: root.currentIndex>=0 ? (resultModel.get(root.currentIndex).embedData || {}) : ({})
                            }
                        }
                    }

                    // 下：側欄
                    Rectangle {
                        id: sidePanelN
                        width: parent.width
                        height: Math.min(260, 100 + fileNameModel.count * 36)
                        radius: 10
                        color: "#F8F8F8"
                        border.color: "#D6D6D6"
                        border.width: 1

                        Item {
                            anchors.fill: parent
                            anchors.margins: 16

                            Text {
                                text: "處理檔案"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#333"
                            }

                            ScrollView {
                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 36; bottom: parent.bottom; bottomMargin: 46 }
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
                                            color: index === root.currentIndex ? "#DFF3E5" : "white"
                                            border.width: 1
                                            border.color: index === root.currentIndex ? "#66CC33" : "#D6D6D6"
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8
                                                Text {
                                                    text: name
                                                    color: "#333"
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: parent.width - 16
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.selectFile(index) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        function onExportReady(url) {
            console.log("Export ZIP:", url)
            Qt.openUrlExternally(url)        // 觸發下載/用檔案總管開啟
            // exportAllAndClear 已經清空 test_output，直接回首頁
            pageRoot.requestNavigate("home", null)
        }
        function onExportFailed(msg) {
            console.warn("Export failed:", msg)
        }
        function onOutputsCleared(msg) {
            console.log("[outputsCleared]", msg)
            // 清理完成後再回首頁（對「返回首頁」按鈕）
            pageRoot.requestNavigate("home", null)
        }
        function onOutputsClearFailed(msg) {
            console.warn("[outputsClearFailed]", msg)
            // 即使失敗也避免卡住，仍回首頁
            pageRoot.requestNavigate("home", null)
        }
    }
}
