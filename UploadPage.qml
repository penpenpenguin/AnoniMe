import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs   // Qt6 新 API

ColumnLayout {
    id: uploadRoot
    property int base: 72
    signal requestNavigate(string target, var payload)

    anchors.fill: parent
    anchors.margins: base * 0.5
    spacing: base * 0.4

    // 狀態 / 模型
    property int progressValue: 0
    property string currentStatus: ""
    property bool canGenerate: false
    property bool uploading: false
    property int uploadTotal: 0
    property int uploadDone: 0
    ListModel { id: tagModel } // { name, path }

    Timer {
        id: progressFadeDelay
        interval: 900
        repeat: false
        onTriggered: hideProgress()
    }

    function updateCanGenerate() {
        canGenerate = tagModel.count > 0
    }

    function removeFile(idx) {
        if (idx < 0 || idx >= tagModel.count) return
        var path = tagModel.get(idx).path
        var name = tagModel.get(idx).name
        tagModel.remove(idx)
        console.log("刪除檔案:", name)
        if (typeof backend !== "undefined" && path)
            backend.removeFile(path)
        updateCanGenerate()
    }

    function beginUpload(total) {
        if (total <= 0) return
        uploading = true
        uploadTotal = total
        uploadDone = 0
        progressValue = 0
        currentStatus = "上傳中..."
        statusOverlay.visible = true
        statusOverlay.updateOverlayPos()
        console.log("beginUpload total =", total)
    }

    function fileUploadedOne() {
        if (!uploading) return
        uploadDone += 1
        progressValue = Math.min(100, Math.round(uploadDone * 100 / uploadTotal))
        console.log("uploaded", uploadDone + "/" + uploadTotal, "=>", progressValue + "%")
        if (uploadDone >= uploadTotal) {
            uploading = false
            currentStatus = "上傳完成"
            progressFadeDelay.start()
        }
    }

    function hideProgress() {
        statusOverlay.visible = false
        currentStatus = ""
        // 保留數值不清除，可視需求重設
    }

    Component.onCompleted: {
        if (typeof backend !== "undefined"
                && backend.resultsReady
                && !backend._uploadConnected) {

            backend.resultsReady.connect(function(json) {
                console.log("UploadPage: resultsReady 收到 JSON 長度 =", json.length)
                let arr
                try {
                    arr = JSON.parse(json)
                } catch(e) {
                    console.log("UploadPage: JSON 解析失敗", e)
                    return
                }
                console.log("UploadPage: 解析後筆數 =", arr.length)
                if (typeof uploadRoot.requestNavigate === "function") {
                    uploadRoot.requestNavigate("result", arr)
                } else {
                    console.log("UploadPage: requestNavigate 不可用")
                }
            })
            backend._uploadConnected = true
            console.log("UploadPage: 已連接 backend.resultsReady")
        }
    }

    // 上方列
    RowLayout {
        Layout.fillWidth: true
        spacing: 20
        Item {
            id: backLink
            implicitWidth: backText.implicitWidth
            implicitHeight: backText.implicitHeight
            Text {
                id: backText
                text: "← Back"
                color: mouse.pressed ? "#2F7A47"
                      : mouse.containsMouse ? "#66CC33"
                      : "white"
                font.pixelSize: base * 0.2
                font.bold: true
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: requestNavigate("home", null)
            }
        }
        Item { Layout.fillWidth: true }
    }

    // 主內容
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 28

        /* 左側 */
        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.38
            Layout.fillHeight: true
            spacing: 14

            // 拖曳區
            Rectangle {
                id: dropZone
                Layout.fillWidth: true
                height: 500
                radius: 10
                color: "white"
                clip: true

                property bool dragHover: false
                property var acceptedExt: ["txt","pdf","doc","docx"]
                property int maxFiles: 20

                function addFileFromUrl(urlInput) {
                    var urlString = (urlInput && urlInput.toString) ? urlInput.toString() : urlInput
                    if (!urlString || urlString.indexOf("file:") !== 0)
                        return false

                    var local = urlString
                    if (local.startsWith("file:///"))
                        local = decodeURIComponent(local.substring(8))
                    else
                        local = decodeURIComponent(local.replace("file://",""))

                    var fileName = local.split(/[\\/]/).pop()
                    var ext = fileName.indexOf(".") >= 0
                              ? fileName.split(".").pop().toLowerCase() : ""

                    if (acceptedExt.indexOf(ext) === -1) {
                        console.log("忽略不接受的副檔名:", ext, fileName)
                        return false
                    }
                    for (var i = 0; i < tagModel.count; i++)
                        if (tagModel.get(i).name === fileName) {
                            console.log("忽略重複檔案:", fileName)
                            return false
                        }
                    if (tagModel.count >= maxFiles) {
                        console.log("已達最大檔案數:", maxFiles)
                        return false
                    }

                    tagModel.append({ name: fileName, path: local })
                    if (typeof backend !== "undefined")
                        backend.addFile(local)
                    updateCanGenerate()
                    console.log("加入檔案:", fileName)
                    return true
                }

                Canvas {
                    id: dashCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0,0,width,height)
                        ctx.setLineDash([6,4])
                        ctx.lineWidth = 2
                        ctx.strokeStyle = dropZone.dragHover ? "#66CC33" : "#000000"
                        ctx.strokeRect(1,1,width-2,height-2)
                    }
                }

                Column {
                    id: dropContent
                    anchors.centerIn: parent
                    spacing: 10
                    property int iconSize: 100
                    width: dropContent.iconSize + 40

                    Text {
                        id: glyph
                        text: "\uE896"
                        font.family: "Segoe MDL2 Assets"
                        font.pixelSize: dropContent.iconSize
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: dropZone.dragHover ? "#66CC33" : "#7A7A7A"
                        scale: dropZone.dragHover ? 1.05 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        id: label
                        text: "請拖曳檔案至此"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 20
                        color: dropZone.dragHover ? "#66CC33" : "#7A7A7A"
                    }
                }
                DropArea {
                    anchors.fill: parent
                    onEntered: (e)=> {
                        e.acceptProposedAction()
                        dropZone.dragHover = true
                        dashCanvas.requestPaint()
                    }
                    onExited: {
                        dropZone.dragHover = false
                        dashCanvas.requestPaint()
                    }
                    onDropped: (e)=> {
                        dropZone.dragHover = false
                        dashCanvas.requestPaint()
                        if (e.hasUrls && e.urls.length > 0) {
                            // 預先計算實際可新增數
                            var pending = 0
                            for (let u of e.urls) {
                                var s = u.toString()
                                var name = s.split(/[\\/]/).pop()
                                // 粗略副檔名及重複檢查（避免多次 decode，簡化）
                                var ext = name.indexOf(".") >= 0 ? name.split(".").pop().toLowerCase() : ""
                                var dup = false
                                for (var i=0;i<tagModel.count;i++)
                                    if (tagModel.get(i).name === name) { dup = true; break }
                                if (dropZone.acceptedExt.indexOf(ext) !== -1 && !dup && tagModel.count + pending < dropZone.maxFiles)
                                    pending++
                            }
                            if (pending > 0)
                                beginUpload(pending)
                            var addedCount = 0
                            for (let u of e.urls) {
                                if (!uploading) break   // 安全防護
                                if (dropZone.addFileFromUrl(u.toString())) {
                                    fileUploadedOne()
                                    addedCount++
                                }
                            }
                            // 若實際一個都沒加成功，關閉進度
                            if (pending > 0 && addedCount === 0) {
                                uploading = false
                                hideProgress()
                            }
                        }
                        e.acceptProposedAction()
                    }
                }
                Text {
                    id: fileCount
                    text: tagModel.count > 0 ? (tagModel.count + " 個檔案") : ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    color: "#555"
                    font.pixelSize: 12
                }
            }

            // 選擇檔案按鈕
            Button {
                id: pickBtn
                Layout.fillWidth: true
                text: "新增檔案"
                padding: 0
                leftPadding: 20; rightPadding: 20
                topPadding: 12; bottomPadding: 12
                font.pixelSize: 16
                font.bold: true
                background: Rectangle {
                    radius: 6
                    color: pickBtn.pressed ? "#4EA773"
                          : pickBtn.hovered ? "#59B481" : "#66CC33"
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    text: pickBtn.text
                    color: "white"
                    font.pixelSize: pickBtn.font.pixelSize
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter

                    
                }
                onClicked: fileDialog.open()
            }

            // 新 API FileDialog
            FileDialog {
                id: fileDialog
                title: "選擇檔案"
                fileMode: FileDialog.OpenFiles   // 允許多選
                nameFilters: [
                    "文字與文件 (*.txt *.pdf *.doc *.docx)",
                    "所有檔案 (*)"
                ]
                onAccepted: {
                    if (selectedFiles.length > 0) {
                        var pending = 0
                        for (var i = 0; i < selectedFiles.length; ++i) {
                            var s = selectedFiles[i].toString()
                            var fileName = s.split(/[\\/]/).pop()
                            var ext = fileName.indexOf(".") >= 0 ? fileName.split(".").pop().toLowerCase() : ""
                            var dup = false
                            for (var j=0;j<tagModel.count;j++)
                                if (tagModel.get(j).name === fileName) { dup = true; break }
                            if (dropZone.acceptedExt.indexOf(ext) !== -1 && !dup && tagModel.count + pending < dropZone.maxFiles)
                                pending++
                        }
                        if (pending > 0)
                            beginUpload(pending)
                        var addedCount = 0
                        for (var k = 0; k < selectedFiles.length; ++k) {
                            if (!uploading) break
                            if (dropZone.addFileFromUrl(selectedFiles[k].toString())) {
                                fileUploadedOne()
                                addedCount++
                            }
                        }
                        if (pending > 0 && addedCount === 0) {
                            uploading = false
                            hideProgress()
                        }
                    }
                }
                onRejected: console.log("取消選擇")
            }
        }

        /* 右側 (覆蓋方式) */
        Item {
            id: rightArea
            Layout.preferredWidth: parent.width * 0.62
            Layout.fillHeight: true

            // 覆蓋進度列（移到 rightArea 裡，避免跨層 anchor）
            Item {
                id: statusOverlay
                // 移除 anchors.top，保留水平對齊
                anchors.left: parent.left
                y: 0
                width: parent.width * 0.55
                z: 100
                visible: false
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                enabled: false

                function updateOverlayPos() {
                    // backText 底部相對於 rightArea 的座標
                    var pt = backText.mapToItem(rightArea, 0, backText.height)
                    var offset = 6    // 想再高一點就加大

                    // 讓進度條底部與 Back 底部對齊
                    statusOverlay.y = pt.y - statusOverlay.height - offset
                }

                onVisibleChanged: if (visible) updateOverlayPos()
                onHeightChanged: updateOverlayPos()

                Column {
                    spacing: 6
                    width: parent.width
                    Text {
                        text: currentStatus
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        visible: currentStatus.length > 0
                    }
                    Rectangle {
                        id: progressBg
                        width: parent.width
                        height: 8
                        radius: 4
                        color: "#333"
                        visible: statusOverlay.visible   // 原本依賴 progressBar.running
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            radius: 4
                            width: Math.max(8, parent.width * progressValue / 100)
                            color: "#66CC33"
                        }
                    }
                }

                // 監聽 Back 高度變動
                Connections {
                    target: backText
                    function onHeightChanged() { statusOverlay.updateOverlayPos() }
                }
            }

            // 原本內容
            ColumnLayout {
                id: rightContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: 14

                // 標籤區
                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    color: "transparent"
                    Flickable {
                        anchors.fill: parent
                        contentWidth: flow.implicitWidth
                        contentHeight: flow.implicitHeight
                        clip: true
                        interactive: true
                        focus: false
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff; visible: false }
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff; visible: false }
                        Flow {
                            id: flow
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: tagModel
                                delegate: Rectangle {
                                    id: chip
                                    radius: 10
                                    color: "#F0F0F0"
                                    height: 34
                                    property int maxContentWidth: 180   // 可調
                                    // 依實際受限寬度 + 左右內距與按鈕空間
                                    width: Math.min(chipText.implicitWidth, maxContentWidth) + 50
                                    clip: true

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        Text {
                                            id: chipText
                                            text: name
                                            font.pixelSize: 12
                                            color: "gray"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            width: Math.min(maxContentWidth, implicitWidth)
                                        }
                                        Button {
                                            text: "✕"
                                            padding: 0
                                            leftPadding: 4; rightPadding: 4
                                            background: Rectangle { color: "transparent" }
                                            contentItem: Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: "gray"
                                                font.pixelSize: 12
                                            }
                                            onClicked: uploadRoot.removeFile(index)
                                        }
                                    }

                                    // 滑過顯示完整檔名
                                    ToolTip.visible: hoverHandler.hovered
                                    ToolTip.text: name
                                    HoverHandler { id: hoverHandler }
                                }
                            }
                        }
                    }
                }

                // 遮蔽選項
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#F8F8F8"
                    radius: 6
                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        Text {
                            text: "遮蔽選項"
                            color: "black"
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Column {
                            id: optionFlow
                            spacing: 6
                            MaskCheckBox { text: "遮蔽 姓名";         optionKey: "name";     onToggled: updateCanGenerate() }
                            MaskCheckBox { text: "遮蔽 Email";        optionKey: "email";    onToggled: updateCanGenerate() }
                            MaskCheckBox { text: "遮蔽 電話";         optionKey: "phone";    onToggled: updateCanGenerate() }
                            MaskCheckBox { text: "遮蔽 地址";         optionKey: "address";  onToggled: updateCanGenerate() }
                            MaskCheckBox { text: "遮蔽 生日";         optionKey: "birthday"; onToggled: updateCanGenerate() }
                            MaskCheckBox { text: "遮蔽 身分證 / SSN"; optionKey: "id";       onToggled: updateCanGenerate() }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // 生成按鈕
                Button {
                    id: generateBtn
                    focusPolicy: Qt.NoFocus
                    activeFocusOnTab: false
                    text: "生成結果"
                    enabled: canGenerate
                    Layout.alignment: Qt.AlignHCenter
                    padding: 0
                    leftPadding: 30; rightPadding: 30
                    topPadding: 10; bottomPadding: 10
                    font.pixelSize: 16
                    font.bold: true
                    ToolTip.visible: hovered
                    ToolTip.text: enabled ? "" : "請先選擇檔案與選項"
                    background: Rectangle {
                        radius: 6
                        color: generateBtn.enabled
                               ? (generateBtn.pressed ? "#4EA773"
                                  : generateBtn.hovered ? "#59B481" : "#66CC33")
                               : "#222"
                        border.width: generateBtn.enabled ? 0 : 1
                        border.color: "#444"
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        text: generateBtn.text
                        color: enabled ? "white" : "#888"
                        font.pixelSize: generateBtn.font.pixelSize
                        font.bold: true
                    }
                    onClicked: {
                        if (!enabled) return
                        console.log("Generate clicked - 呼叫後端處理 (測試模式，僅插入文字)")
                        if (typeof backend !== "undefined" && backend.processFiles) {
                            var opts = []
                            if (optionFlow) {
                                for (var i=0;i<optionFlow.children.length;i++) {
                                    var c = optionFlow.children[i]
                                    if (c.checked && c.optionKey) opts.push(c.optionKey)
                                }
                            }
                            console.log("選取項目 =", opts.join(", "))
                            if (backend.setOptions) backend.setOptions(opts)
                            backend.processFiles()
                        }
                    }
                }
            }
        }
    }

    Item { Layout.fillWidth: true; height: 4 }
}