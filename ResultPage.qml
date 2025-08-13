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
    property int currentIndex: -1
    signal requestNavigate(string target, var payload)

    Component.onCompleted: {
        console.log("ResultPage loaded. 現有 resultModel.count =", resultModel.count)
        // 150ms 後再檢查一次，有需要再補載
        Qt.createQmlObject('import QtQuick 2.15; Timer { interval:150; running:true; repeat:false; onTriggered: root._lateTryLoad() }', root, "LateLoadTimer")
    }

    function _lateTryLoad() {
        if (resultModel.count > 0) return
        console.log("ResultPage: 嘗試從 backend.getLastResults() 補抓")
        if (typeof backend !== "undefined" && backend.getLastResults) {
            try {
                let json = backend.getLastResults()
                if (json && json.length > 2) {
                    let arr = JSON.parse(json)
                    console.log("ResultPage: backend 快取筆數 =", arr.length)
                    if (arr.length > 0)
                        loadResults(arr)
                }
            } catch(e) {
                console.log("ResultPage: 快取解析失敗", e)
            }
        }
    }

    ListModel { id: resultModel }     // { fileName, originalText, maskedText, type, expanded, viewMode }
    ListModel { id: fileNameModel }   // { name }

    // 新增：全域顯示模式 (masked / original)
    property string currentViewMode: "masked"

    // 顯示資料模型
    ListModel { id: headerModel }   // { text, kind }
    ListModel { id: bodyModel }     // { lineNumber, text, kind }

    // 對外 API
    function loadResults(arr) {
        resultModel.clear()
        fileNameModel.clear()
        if (!arr || !arr.length) {
            console.log("ResultPage.loadResults: 空資料")
            currentIndex = -1
            return
        }
        for (let i=0;i<arr.length;i++) {
            const o = arr[i]
            resultModel.append({
                fileName: o.fileName || ("Result_" + (i+1)),
                originalText: o.originalText || o.previewText || "(無原始內容)",
                maskedText: o.maskedText || o.previewText || "(無去識別化內容)",
                type: o.type || "text"
            })
            fileNameModel.append({ name: o.fileName || ("Result_" + (i+1)) })
        }
        currentIndex = 0
        if (contentFlick) contentFlick.contentY = 0
        if (contentFlickN) contentFlickN.contentY = 0
        console.log("ResultPage.loadResults: 成功載入 =", resultModel.count)
        rebuildPreview()   // 新增：立即建構預覽
    }

    function selectFile(idx) {
        if (idx < 0 || idx >= resultModel.count) return
        currentIndex = idx
        currentViewMode = "masked"   // 切換檔案時預設回測試版
        if (contentFlick) contentFlick.contentY = 0
        if (contentFlickN) contentFlickN.contentY = 0
        rebuildPreview()
    }

    function rebuildPreview() {
        headerModel.clear()
        bodyModel.clear()
        if (currentIndex < 0 || currentIndex >= resultModel.count) return
        const rec = resultModel.get(currentIndex)
        const raw = currentViewMode === "masked" ? rec.maskedText : rec.originalText
        if (!raw || raw.length === 0) return

        const lines = raw.split(/\r?\n/)
        // 將連續開頭為 "[" 的前段視為 header
        let i = 0
        for (; i < lines.length; i++) {
            const L = lines[i]
            if (L.startsWith("[")) {
                let kind = "meta"
                if (/\bTEST SUMMARY\b/.test(L)) kind = "summary"
                else if (/\bTEST-|測試行|選項測試行|已勾選項目/.test(L)) kind = "test"
                headerModel.append({ text: L, kind: kind })
            } else if (L.trim() === "") {
                // 空行仍視為 header 分隔線
                if (headerModel.count > 0) headerModel.append({ text: "", kind: "gap" })
            } else {
                break
            }
        }
        // Body (剩餘)
        for (let j = i; j < lines.length; j++) {
            const line = lines[j]
            let kind = ""
            if (/\[TEST-|測試|DEMO\]/i.test(line)) kind = "hl"
            bodyModel.append({
                lineNumber: j - i + 1,
                text: line,
                kind: kind
            })
        }
    }

    function _debugCountTitleTexts() {
        // 簡易檢查：在 root 下遞迴找 text 等於目前檔名的 Text 元件數
        if (currentIndex < 0) return
        var name = resultModel.get(currentIndex).fileName
        function walk(obj) {
            var cnt = 0
            if (!obj) return 0
            if (obj.metaObject && obj.text !== undefined && obj.text === name) cnt++
            if (obj.children) {
                for (var i=0;i<obj.children.length;i++)
                    cnt += walk(obj.children[i])
            }
            return cnt
        }
        var total = walk(root)
        console.log("ResultPage Debug: 檔名 Text 數 =", total)
    }

    onCurrentIndexChanged: {
        rebuildPreview()
        _debugCountTitleTexts()
    }

    onCurrentViewModeChanged: rebuildPreview()

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
                    contentHeight: contentColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    width: parent.width - sidePanel.width - wideLayout.spacing
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        id: contentColumn
                        width: contentFlick.width
                        spacing: 18
                        padding: 0

                        // 無選擇提示
                        Text {
                            visible: currentIndex < 0
                            width: parent.width
                            text: "尚無結果，請於右側選擇檔案。"
                            color: "#999"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 16
                            padding: 60
                        }

                        // 預覽容器
                        Rectangle {
                            id: previewCard
                            width: parent.width
                            visible: currentIndex >= 0
                            radius: 12
                            color: "#111"          // 深底讓內容顯示像檢視器
                            border.width: 1
                            border.color: "#222"
                            Column {
                                id: previewCol
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                // 檔案標題 + 版本切換
                                Row {
                                    id: titleRow
                                    width: parent.width
                                    spacing: 16

                                    // 唯一的檔名 Text
                                    Text {
                                        id: fileTitle
                                        text: currentIndex >= 0 ? resultModel.get(currentIndex).fileName : ""
                                        font.pixelSize: 22
                                        font.bold: true
                                        color: "#66CC33"
                                        elide: Text.ElideRight
                                        // 防止被覆蓋用的背景除錯（完成後可移除）
                                        // background: Rectangle { color: "#222A" }
                                        width: parent.width - versionSwitch.width - 24
                                    }

                                    Row {
                                        id: versionSwitch
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { label: "測試版", mode: "masked" },
                                                { label: "原文",   mode: "original" }
                                            ]
                                            delegate: Rectangle {
                                                property bool active: modelData.mode === currentViewMode
                                                width: 68; height: 30
                                                radius: 6
                                                color: active ? "#66CC33" : "#2A2A2A"
                                                border.width: active ? 0 : 1
                                                border.color: "#444"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: active ? "white" : "#BBBBBB"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: currentViewMode = modelData.mode
                                                }
                                            }
                                        }
                                    }
                                }

                                // 類型橫幅
                                Rectangle {
                                    visible: currentIndex >= 0
                                    width: parent.width
                                    radius: 6
                                    color: "#1D1D1D"
                                    border.width: 1
                                    border.color: "#303030"
                                    height: 40
                                    Row {
                                        id: typeRow
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10
                                        property string ftype: currentIndex>=0 ? resultModel.get(currentIndex).type : ""
                                        Rectangle {
                                            width: 20; height: 20; radius: 4
                                            color: typeRow.ftype==="pdf" ? "#E74C3C"
                                                  : typeRow.ftype==="docx" ? "#2E6EE7"
                                                  : typeRow.ftype==="text" ? "#888" : "#555"
                                            Text {
                                                anchors.centerIn: parent
                                                text: typeRow.ftype.length>0 ? typeRow.ftype.toUpperCase().slice(0,3) : ""
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "white"
                                            }
                                        }
                                        Text {
                                            text: {
                                                switch (typeRow.ftype) {
                                                case "pdf": return "PDF 預覽（文字抽取示意，不含原版面）"
                                                case "docx": return "DOCX 預覽（段落合併示意）"
                                                case "text": return "純文字預覽"
                                                default: return "一般檔案預覽"
                                                }
                                            }
                                            font.pixelSize: 13
                                            color: "#CCCCCC"
                                        }
                                    }
                                }

                                // Header 區
                                Rectangle {
                                    id: headerBox
                                    visible: headerModel.count > 0
                                    width: parent.width
                                    radius: 8
                                    color: "#1E1E1E"
                                    border.width: 1
                                    border.color: "#2C2C2C"
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 6
                                        Repeater {
                                            model: headerModel
                                            delegate: Rectangle {
                                                id: headerLine
                                                width: parent.width
                                                radius: 4
                                                property string lineText: model.text
                                                property string lineKind: model.kind
                                                visible: lineText.length > 0
                                                color: lineKind==="test" ? "#264d33"
                                                      : lineKind==="summary" ? "#3a2d18"
                                                      : lineKind==="gap" ? "transparent"
                                                      : "#222"
                                                border.width: (lineKind==="test"||lineKind==="summary") ? 1 : 0
                                                border.color: lineKind==="summary" ? "#C29232"
                                                          : lineKind==="test" ? "#3FA665" : "#444"
                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: headerLine.lineText
                                                    wrapMode: Text.Wrap
                                                    font.pixelSize: 12
                                                    color: lineKind==="summary" ? "#F2D28A"
                                                          : lineKind==="test" ? "#7EE2A8" : "#BEBEBE"
                                                }
                                            }
                                        }
                                    }
                                }

                                // 內容行 (帶行號)
                                Rectangle {
                                    id: bodyBox
                                    width: parent.width
                                    radius: 8
                                    color: "#101010"
                                    border.width: 1
                                    border.color: "#222"
                                    implicitHeight: bodyCol.implicitHeight + 16
                                    Column {
                                        id: bodyCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        spacing: 2
                                        Repeater {
                                            model: bodyModel
                                            delegate: Row {
                                                width: parent.width
                                                spacing: 12
                                                // 緩存 model 資料，避免 Text 自我引用造成 binding loop
                                                property string lineContent: model.text
                                                property string lineKind: model.kind

                                                Rectangle {
                                                    width: 46
                                                    height: lineTxt.implicitHeight + 4
                                                    radius: 4
                                                    color: "#1F1F1F"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: model.lineNumber
                                                        font.pixelSize: 11
                                                        color: "#6A6A6A"
                                                        font.family: "Consolas"
                                                    }
                                                }
                                                Rectangle {
                                                    width: parent.width - 46 - 12
                                                    color: lineKind==="hl" ? "#182e21" : "transparent"
                                                    radius: lineKind==="hl" ? 4 : 0
                                                    border.width: lineKind==="hl" ? 1 : 0
                                                    border.color: "#2E7B4E"
                                                    Text {
                                                        id: lineTxt
                                                        width: parent.width - 12
                                                        text: lineContent.length===0 ? "\u200B" : lineContent
                                                        font.pixelSize: 13
                                                        wrapMode: Text.Wrap
                                                        color: lineKind==="hl" ? "#CFEFD9" : "#CCCCCC"
                                                        font.family: "Consolas"
                                                    }
                                                }
                                            }
                                        }
                                        // 空 body
                                        Text {
                                            visible: bodyModel.count === 0
                                            text: "(無內文)"
                                            font.pixelSize: 13
                                            color: "#666"
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width
                                            padding: 40
                                        }
                                    }
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
                                        color: delegateIndex === currentIndex
                                               ? "#D5F2E1"
                                               : (hover ? "#E9F7EE" : "white")
                                        border.color: delegateIndex === currentIndex ? "#66CC33" : "#D0E3D8"
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
                                                onClicked: selectFile(delegateIndex)
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.hover = true
                                            onExited: parent.hover = false
                                            onClicked: selectFile(delegateIndex)
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
                            radius: 10
                            color: "#F8F8F8"
                            border.color: "#DCDCDC"
                            border.width: 1
                            visible: currentIndex >= 0
                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14
                                Text {
                                    text: currentIndex >=0 ? resultModel.get(currentIndex).fileName : ""
                                    font.pixelSize: 20
                                    font.bold: true
                                    color: "#333"
                                }
                                Text {
                                    text: currentIndex >=0 ? resultModel.get(currentIndex).maskedText : ""
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 14
                                    color: "#222"
                                }
                            }
                        }
                        Text {
                            visible: currentIndex < 0
                            width: parent.width
                            text: "尚無結果"
                            color: "#999"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 14
                            padding: 40
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
                                        color: delegateIndex === currentIndex
                                               ? "#D5F2E1"
                                               : (hover ? "#E9F7EE" : "white")
                                        border.color: delegateIndex === currentIndex ? "#66CC33" : "#D0E3D8"
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
                                                onClicked: selectFile(delegateIndex)
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.hover = true
                                            onExited: parent.hover = false
                                            onClicked: selectFile(delegateIndex)
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
}