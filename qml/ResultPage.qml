import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: pageRoot
    anchors.fill: parent

    property var results: []
    property int selectedIndex: -1
    property string selectedContent: ""
    property var selectedPreviewData: null

    // 檔案格式檢測函數
    function getFileExtension(fileName) {
        if (!fileName) return ""
        var lastDot = fileName.lastIndexOf('.')
        return lastDot > 0 ? fileName.substring(lastDot + 1).toLowerCase() : ""
    }

    function getFileTypeInfo(ext) {
        switch(ext) {
            case "txt":
                return { category: "text", color: "#4CAF50", icon: "TXT", displayName: "文字檔案" }
            case "docx":
            case "doc":
                return { category: "document", color: "#2196F3", icon: "DOC", displayName: "Word文件" }
            case "pdf":
                return { category: "pdf", color: "#E53E3E", icon: "PDF", displayName: "PDF文件" }
            default:
                return { category: "other", color: "#757575", icon: "FILE", displayName: "檔案" }
        }
    }

    function formatContentForDisplay(content, ext) {
        if (!content) return ""
        
        switch(ext) {
            case "txt":
                return content
            case "docx":
            case "doc":
                return "[Word 文件內容]\n\n" + content + "\n\n[注意：純文字版本，完整格式請使用內嵌檢視]"
            case "pdf":
                return "[PDF 文件內容]\n\n" + content + "\n\n[注意：純文字版本，完整格式請使用內嵌檢視]"
            default:
                return content
        }
    }

    function getSelectedFilePath() {
        if (selectedIndex < 0 || selectedIndex >= results.length) return ""
        var item = results[selectedIndex]
        var path = item.outputPath || item.fileUrl || ""
        
        // 轉換為 file:// URL 格式
        if (path && !path.startsWith("file://") && !path.startsWith("http")) {
            if (path.indexOf(":\\") > 0) {
                path = "file:///" + path.replace(/\\/g, "/")
            } else {
                path = "file://" + path
            }
        }
        return path
    }

    // 檔案下載對話框
    FileDialog {
        id: saveDialog
        title: "選擇下載儲存位置"
        nameFilters: ["所有檔案 (*)"]
        property int downloadIndex: -1
        onAccepted: {
            if (downloadIndex >= 0 && downloadIndex < results.length) {
                var item = results[downloadIndex]
                var pathToDownload = item.outputPath ? item.outputPath : (item.fileUrl ? item.fileUrl : null)
                if (typeof backend !== "undefined" && backend.saveFileTo) {
                    backend.saveFileTo(pathToDownload, saveDialog.fileUrl)
                }
            }
            downloadIndex = -1
        }
        onRejected: {
            downloadIndex = -1
        }
    }

    function downloadFile(idx) {
        if (idx < 0 || idx >= results.length) return
        saveDialog.downloadIndex = idx
        var item = results[idx]
        var fileName = item.fileName ? item.fileName : "downloaded_file"
        saveDialog.title = "儲存為: " + fileName
        saveDialog.open()
    }

    function removeFile(idx) {
        if (idx < 0 || idx >= results.length) return
        var item = results[idx]
        var pathToRemove = item.outputPath ? item.outputPath : (item.fileUrl ? item.fileUrl : null)
        if (!pathToRemove) return
        if (typeof backend !== "undefined" && backend.removeFile) {
            backend.removeFile(pathToRemove)
        }
        results.splice(idx, 1)
        if (selectedIndex === idx) {
            selectedIndex = results.length > 0 ? 0 : -1
            loadFileContent(selectedIndex)
        }
    }

    function loadResults(arr) {
        results = arr
        selectedIndex = arr.length > 0 ? 0 : -1
        selectedContent = ""
        if (selectedIndex >= 0) {
            loadFileContent(selectedIndex)
        }
        console.log("loadResults called with:", arr)
    }

    function loadFileContent(idx) {
        if (idx < 0 || idx >= results.length) {
            selectedContent = ""
            selectedPreviewData = null
            return
        }
        var item = results[idx]
        var pathToRead = item.outputPath ? item.outputPath : (item.fileUrl ? item.fileUrl : null)
        if (pathToRead) {
            // 載入基本文字內容（向下相容）
            if (typeof backend !== "undefined" && backend.readFileContent) {
                try {
                    var content = backend.readFileContent(pathToRead)
                    var fileName = item.fileName || item.name || item.file_name || "檔案"
                    var ext = getFileExtension(fileName)
                    selectedContent = formatContentForDisplay(content !== undefined ? content : pathToRead, ext)
                } catch (e) {
                    console.error("readFileContent failed:", e)
                    selectedContent = pathToRead
                }
            } else {
                selectedContent = pathToRead
            }
            
            // 載入內嵌預覽資料
            if (typeof backend !== "undefined" && backend.getFilePreviewData) {
                try {
                    console.log("Calling getFilePreviewData with path:", pathToRead)
                    var previewJsonStr = backend.getFilePreviewData(pathToRead)
                    console.log("Received preview JSON:", previewJsonStr)
                    selectedPreviewData = JSON.parse(previewJsonStr)
                    console.log("Loaded preview data:", selectedPreviewData)
                } catch (e) {
                    console.error("getFilePreviewData failed:", e)
                    selectedPreviewData = null
                }
            } else {
                console.log("backend.getFilePreviewData not available")
                selectedPreviewData = null
            }
        } else {
            selectedContent = "(無 outputPath 或 fileUrl)"
            selectedPreviewData = null
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0B0C10" }
            GradientStop { position: 0.3; color: "#1F2833" }
            GradientStop { position: 0.7; color: "#2C3E50" }
            GradientStop { position: 1.0; color: "#34495E" }
        }
        
        Row {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 40
            
            // 左側檔案列表
            Rectangle {
                id: leftPanel
                width: parent.width * 0.35
                height: parent.height
                color: Qt.rgba(0.15, 0.2, 0.25, 0.8)
                radius: 12
                border.width: 1
                border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8
                    
                    Text {
                        text: "處理完成的檔案"
                        font.pixelSize: 20
                        color: "#66FCF1"
                        height: 32
                    }
                    // 下載全部按鈕
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        Button {
                            text: "下載全部"
                            width: 90
                            height: 28
                            icon.source: "qrc:/icons/download.svg"
                            onClicked: {
                                if (typeof backend !== "undefined" && backend.exportAll) {
                                    backend.exportAll()
                                }
                            }
                            background: Rectangle {
                                color: "#4CAF50"
                                radius: 6
                            }
                        }
                    }
                    
                    ListView {
                        id: fileListView
                        width: parent.width
                        height: parent.height - 40
                        model: results
                        
                        delegate: Rectangle {
                            width: fileListView.width
                            height: 60
                            color: index === selectedIndex ? "#66FCF1" : (index % 2 === 0 ? Qt.rgba(0.15, 0.2, 0.25, 0.8) : Qt.rgba(0.07, 0.08, 0.1, 0.8))
                            border.width: 1
                            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.2)
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                // 檔案類型圖標
                                Rectangle {
                                    width: 40
                                    height: 28
                                    radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: {
                                        var fileName = model.fileName || model.name || model.file_name || ""
                                        var ext = getFileExtension(fileName)
                                        return getFileTypeInfo(ext).color
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            var fileName = model.fileName || model.name || model.file_name || ""
                                            var ext = getFileExtension(fileName)
                                            return getFileTypeInfo(ext).icon
                                        }
                                        color: "#FFFFFF"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                                
                                // 檔案資訊
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120
                                    spacing: 2
                                    
                                    Text {
                                        text: model.fileName ? model.fileName : (model.name ? model.name : (model.file_name ? model.file_name : "檔案"))
                                        color: index === selectedIndex ? "#222" : "#FFFFFF"
                                        font.pixelSize: 14
                                        font.bold: index === selectedIndex
                                        width: 120
                                        elide: Text.ElideMiddle
                                    }
                                    
                                    Text {
                                        text: {
                                            var fileName = model.fileName || model.name || model.file_name || ""
                                            var ext = getFileExtension(fileName)
                                            return getFileTypeInfo(ext).displayName
                                        }
                                        color: index === selectedIndex ? "#666" : "#AAA"
                                        font.pixelSize: 10
                                        width: 120
                                        elide: Text.ElideRight
                                    }
                                }
                                
                                // 操作按鈕
                                // 刪除按鈕（小叉叉 icon）
                                Button {
                                    width: 28; height: 28
                                    icon.source: "qrc:/icons/close.svg"
                                    background: Rectangle { color: "transparent" }
                                    onClicked: removeFile(index)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "刪除"
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedIndex = index
                                    loadFileContent(index)
                                }
                            }
                        }
                    }
                }
            }
            
            // 右側檔案內容檢視
            Rectangle {
                id: rightPanel
                width: parent.width - leftPanel.width - parent.spacing
                height: parent.height
                color: Qt.rgba(0.07, 0.08, 0.1, 0.8)
                radius: 12
                border.width: 1
                border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    
                    // 標題列
                    Row {
                        width: parent.width
                        height: 36
                        spacing: 12
                        
                        Text {
                            id: rightHeader
                            anchors.verticalCenter: parent.verticalCenter
                            text: selectedIndex >= 0 ? (results[selectedIndex].fileName || results[selectedIndex].name || results[selectedIndex].file_name || "檔案") : "未選擇檔案"
                            font.pixelSize: 20
                            color: "#66FCF1"
                            width: parent.width - fileTypeIndicator.width - openButton.width - 24
                        }
                        
                        // 檔案類型指示器
                        Rectangle {
                            id: fileTypeIndicator
                            width: fileTypeText.width + 16
                            height: 24
                            radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: selectedIndex >= 0
                            color: {
                                if (selectedIndex >= 0) {
                                    var fileName = results[selectedIndex].fileName || results[selectedIndex].name || results[selectedIndex].file_name || ""
                                    var ext = getFileExtension(fileName)
                                    return getFileTypeInfo(ext).color
                                }
                                return "#757575"
                            }
                            
                            Text {
                                id: fileTypeText
                                anchors.centerIn: parent
                                text: {
                                    if (selectedIndex >= 0) {
                                        var fileName = results[selectedIndex].fileName || results[selectedIndex].name || results[selectedIndex].file_name || ""
                                        var ext = getFileExtension(fileName)
                                        return getFileTypeInfo(ext).icon
                                    }
                                    return ""
                                }
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                        
                        // 外部開啟按鈕
                        Button {
                            id: openButton
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            visible: selectedIndex >= 0
                            text: "外部開啟"
                            onClicked: {
                                if (typeof backend !== "undefined" && backend.openFileInSystem) {
                                    var item = results[selectedIndex]
                                    var path = item.outputPath || item.fileUrl || ""
                                    backend.openFileInSystem(path)
                                }
                            }
                            background: Rectangle {
                                color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                                radius: 6
                                border.width: 1
                                border.color: "#66FCF1"
                            }
                        }
                    }
                    
                    // 內容檢視區域
                    Rectangle {
                        width: parent.width
                        height: parent.height - 48
                        color: Qt.rgba(0.05, 0.05, 0.05, 0.9)
                        radius: 8
                        border.width: 1
                        border.color: Qt.rgba(0.4, 0.99, 0.95, 0.2)
                        
                        StackLayout {
                            id: contentStack
                            anchors.fill: parent
                            anchors.margins: 8
                            currentIndex: {
                                if (selectedIndex < 0) return 0
                                
                                // 統一使用 PDF 預覽格式，不論原始檔案類型
                                if (selectedPreviewData && selectedPreviewData.viewType) {
                                    console.log("Using unified PDF preview for viewType:", selectedPreviewData.viewType)
                                    return 1  // 統一使用 PDF 預覽
                                }
                                
                                return 0  // 預設檢視
                            }
                            
                            // 預設檢視（無檔案選擇時）
                            Rectangle {
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "請選擇檔案以檢視內容"
                                    color: "#AAA"
                                    font.pixelSize: 16
                                }
                            }
                            
                            // TXT 檔案檢視
                            Flickable {
                                contentWidth: width
                                contentHeight: Math.max(txtContent.contentHeight, height)
                                clip: true
                                
                                TextArea {
                                    id: txtContent
                                    anchors.fill: parent
                                    text: selectedContent
                                    wrapMode: TextArea.WrapAtWordBoundaryOrAnywhere
                                    textFormat: TextArea.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    color: "#FFFFFF"
                                    font.family: "Consolas, Monaco, monospace"
                                    font.pixelSize: 14
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }
                            }
                            
                            // DOCX 檔案內嵌檢視 - 使用 python-docx 解析的結構
                            Rectangle {
                                color: "#F8F9FA"
                                border.width: 1
                                border.color: "#DEE2E6"
                                radius: 4
                                
                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    contentWidth: width
                                    contentHeight: docxColumn.height
                                    clip: true
                                    
                                    Column {
                                        id: docxColumn
                                        width: parent.width
                                        spacing: 16
                                        
                                        
                                        
                                        // 段落內容
                                        Repeater {
                                            model: selectedPreviewData && selectedPreviewData.viewType === "docx" ? selectedPreviewData.paragraphs || [] : []
                                            
                                            Rectangle {
                                                width: docxColumn.width
                                                height: Math.max(paraText.contentHeight + 16, 40)
                                                color: "#FFFFFF"
                                                border.width: 1
                                                border.color: "#E9ECEF"
                                                radius: 4
                                                
                                                Text {
                                                    id: paraText
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    text: modelData.text || ""
                                                    color: "#333333"
                                                    font.family: modelData.style === "Heading 1" ? "Arial Black" : 
                                                                modelData.style === "Heading 2" ? "Arial Bold" : "Arial"
                                                    font.pixelSize: modelData.style === "Heading 1" ? 18 : 
                                                                   modelData.style === "Heading 2" ? 16 : 13
                                                    font.bold: modelData.style && modelData.style.includes("Heading")
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                        
                                        // 表格內容
                                        Repeater {
                                            model: selectedPreviewData && selectedPreviewData.viewType === "docx" ? selectedPreviewData.tables || [] : []
                                            
                                            Rectangle {
                                                width: docxColumn.width
                                                height: tableColumn.height + 16
                                                color: "#F8F9FA"
                                                border.width: 2
                                                border.color: "#2196F3"
                                                radius: 6
                                                
                                                Column {
                                                    id: tableColumn
                                                    anchors.centerIn: parent
                                                    width: parent.width - 16
                                                    spacing: 2
                                                    
                                                    Text {
                                                        text: "📊 表格 " + (index + 1)
                                                        color: "#2196F3"
                                                        font.bold: true
                                                        font.pixelSize: 14
                                                    }
                                                    
                                                    // 表格行
                                                    Repeater {
                                                        model: modelData || []
                                                        
                                                        Row {
                                                            spacing: 1
                                                            
                                                            Repeater {
                                                                model: modelData || []
                                                                
                                                                Rectangle {
                                                                    width: Math.max(80, cellText.contentWidth + 16)
                                                                    height: Math.max(30, cellText.contentHeight + 8)
                                                                    color: "#FFFFFF"
                                                                    border.width: 1
                                                                    border.color: "#CCC"
                                                                    
                                                                    Text {
                                                                        id: cellText
                                                                        anchors.centerIn: parent
                                                                        text: modelData || ""
                                                                        color: "#333"
                                                                        font.pixelSize: 11
                                                                        wrapMode: Text.WordWrap
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
                            }
                            
                            // PDF 檔案內嵌檢視 - 使用 PyMuPDF 生成的頁面圖片
                            Rectangle {
                                color: "#F8F9FA"
                                border.width: 1
                                border.color: "#DEE2E6"
                                radius: 4
                                
                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    contentWidth: width
                                    contentHeight: pdfColumn.height
                                    clip: true
                                    
                                    Column {
                                        id: pdfColumn
                                        width: parent.width
                                        spacing: 16
                                        
                                        
                                        
                                        // PDF 頁面圖片
                                        Repeater {
                                            model: selectedPreviewData && selectedPreviewData.viewType === "pdf" ? selectedPreviewData.pageImages || [] : []
                                            
                                            Rectangle {
                                                width: pdfColumn.width
                                                height: pdfImage.height + pageInfo.height + 20
                                                color: "#FFFFFF"
                                                border.width: 1
                                                border.color: "#CCC"
                                                radius: 6
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 8
                                                    
                                                    Text {
                                                        id: pageInfo
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "第 " + (index + 1) + " 頁"
                                                        color: "#E53E3E"
                                                        font.bold: true
                                                        font.pixelSize: 12
                                                    }
                                                    
                                                    Image {
                                                        id: pdfImage
                                                        source: modelData || ""
                                                        fillMode: Image.PreserveAspectFit
                                                        width: Math.min(sourceSize.width, pdfColumn.width - 40)
                                                        height: sourceSize.height > 0 ? width * (sourceSize.height / sourceSize.width) : 0
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        
                                                        onStatusChanged: {
                                                            if (status === Image.Error) {
                                                                console.error("PDF 頁面載入失敗:", source)
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onDoubleClicked: {
                                                                // 雙擊放大縮小
                                                                if (pdfImage.width === pdfImage.sourceSize.width) {
                                                                    pdfImage.width = Math.min(pdfImage.sourceSize.width, pdfColumn.width - 40)
                                                                } else {
                                                                    pdfImage.width = pdfImage.sourceSize.width
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // 提示訊息
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
