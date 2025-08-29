import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "./components"

/**
 * 檔案上傳頁面 - 主要功能：
 * 1. 檔案拖放上傳
 * 2. 遮蔽選項設定
 * 3. 處理進度顯示
 * 4. 結果導航
 */
Item {
    id: root
    anchors.fill: parent

    // ==================== 公開接口 ====================
    signal requestNavigate(string target, var payload)

    // ==================== 狀態屬性 ====================
    readonly property bool canGenerate: _hasFiles && _hasOptions && !_uploading
    readonly property int fileCount: fileManager.count
    
    // 私有狀態
    property bool _hasFiles: fileManager.count > 0
    property bool _hasOptions: optionManager.hasSelectedOptions
    property bool _uploading: uploadManager.uploading

    // ==================== 資料模型 ====================
    
    ListModel { id: fileModel }
    
    // 檔案管理器
    QtObject {
        id: fileManager
        property alias model: fileModel
        property int count: fileModel.count
        property var acceptedExtensions: ["txt", "pdf", "doc", "docx"]
        property int maxFiles: 20

        function addFile(fileName, filePath) {
            if (count >= maxFiles) return false
            if (hasFile(fileName)) return false
            
            fileModel.append({ name: fileName, path: filePath })
            root._hasFiles = Qt.binding(function() { return count > 0 })
            
            if (typeof backend !== "undefined") {
                backend.addFile(filePath)
            }
            return true
        }

        function removeFile(index) {
            if (index < 0 || index >= count) return
            
            var item = fileModel.get(index)
            var filePath = item.path
            fileModel.remove(index)
            
            root._hasFiles = Qt.binding(function() { return count > 0 })
            
            if (typeof backend !== "undefined" && filePath) {
                backend.removeFile(filePath)
            }
        }

        function hasFile(fileName) {
            for (var i = 0; i < count; i++) {
                if (fileModel.get(i).name === fileName) return true
            }
            return false
        }

        function clear() {
            fileModel.clear()
            root._hasFiles = false
        }

        function isValidFile(fileName) {
            var ext = fileName.split('.').pop() || ""
            ext = ext.toLowerCase()
            return acceptedExtensions.indexOf(ext) !== -1
        }
    }

    // 選項管理器
    QtObject {
        id: optionManager
    property bool hasSelectedOptions: _checkSelectedOptions()
    // 實時保持被選取項目的顯示文字陣列
    property var selectedOptionTexts: []

        property var commonOptions: [
            { key: "name", text: "姓名", selected: false },
            { key: "email", text: "Email", selected: false },
            { key: "phone", text: "電話", selected: false },
            { key: "address", text: "地址", selected: false }
        ]

        property var otherOptions: [
            { key: "birthday", text: "生日", selected: false },
            { key: "id", text: "身分證/SSN", selected: false },
            { key: "company", text: "公司名稱", selected: false },
            { key: "bank", text: "銀行帳號", selected: false }
        ]

        function toggleOption(category, index) {
            var options = category === "common" ? commonOptions : otherOptions
            options[index].selected = !options[index].selected
            
            if (category === "common") {
                var newCommonOptions = []
                for (var i = 0; i < options.length; i++) {
                    newCommonOptions.push(options[i])
                }
                commonOptions = newCommonOptions
            } else {
                var newOtherOptions = []
                for (var j = 0; j < options.length; j++) {
                    newOtherOptions.push(options[j])
                }
                otherOptions = newOtherOptions
            }
            
            hasSelectedOptions = _checkSelectedOptions()
            root._hasOptions = hasSelectedOptions
            // 更新選取文字列表
            selectedOptionTexts = getSelectedOptionTexts()
        }

        function _checkSelectedOptions() {
            for (var i = 0; i < commonOptions.length; i++) {
                if (commonOptions[i].selected) return true
            }
            for (var j = 0; j < otherOptions.length; j++) {
                if (otherOptions[j].selected) return true
            }
            return false
        }

        function getSelectedOptionKeys() {
            var selected = []
            for (var i = 0; i < commonOptions.length; i++) {
                if (commonOptions[i].selected) {
                    selected.push(commonOptions[i].key)
                }
            }
            for (var j = 0; j < otherOptions.length; j++) {
                if (otherOptions[j].selected) {
                    selected.push(otherOptions[j].key)
                }
            }
            return selected
        }

        // 回傳被選取項目的顯示文字 (text 屬性)
        function getSelectedOptionTexts() {
            var selected = []
            for (var i = 0; i < commonOptions.length; i++) {
                if (commonOptions[i].selected) selected.push(commonOptions[i].text)
            }
            for (var j = 0; j < otherOptions.length; j++) {
                if (otherOptions[j].selected) selected.push(otherOptions[j].text)
            }
            return selected
        }
    }

    // 上傳管理器
    QtObject {
        id: uploadManager
        property bool uploading: false
        property int total: 0
        property int completed: 0
        property int progress: completed > 0 ? Math.round(completed * 100 / total) : 0
        property string status: ""

        function beginUpload(fileCount) {
            if (fileCount <= 0) return
            
            uploading = true
            total = fileCount
            completed = 0
            status = "上傳中..."
            
            root._uploading = true
        }

        function fileCompleted() {
            if (!uploading) return
            
            completed++
            if (completed >= total) {
                uploading = false
                status = "上傳完成"
                hideTimer.start()
                root._uploading = false
            }
        }

        function hide() {
            status = ""
            root._uploading = false
        }
    }

    Timer {
        id: hideTimer
        interval: 900
        onTriggered: uploadManager.hide()
    }

    // ==================== 後端連接 ====================
    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend.resultsReady) {
            console.log("UploadPage: 連接後端")
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        function onResultsReady(json) {
            try {
                var results = JSON.parse(json)
                console.log("UploadPage: 收到處理結果", results.length, "筆")
                root.requestNavigate("result", results)
            } catch (e) {
                console.error("UploadPage: JSON 解析失敗", e)
            }
        }
    }

    // ==================== 外部接口 ====================
    function addFilesFromUrls(urls) {
        if (!urls || urls.length === 0) return

        var validFiles = []
        for (var i = 0; i < urls.length; i++) {
            var url = urls[i]
            var fileName = url.toString().split(/[\\/]/).pop()
            if (fileManager.isValidFile(fileName) && !fileManager.hasFile(fileName)) {
                validFiles.push(url)
            }
        }

        if (validFiles.length === 0) return

        uploadManager.beginUpload(validFiles.length)
        
        var addedCount = 0
        for (var j = 0; j < validFiles.length; j++) {
            var urlStr = validFiles[j].toString()
            var fileName = urlStr.split(/[\\/]/).pop()
            var localPath = decodeURIComponent(urlStr.replace(/^file:\/+/, ""))
            
            if (fileManager.addFile(fileName, localPath)) {
                addedCount++
                uploadManager.fileCompleted()
            }
        }

        if (addedCount === 0) {
            uploadManager.hide()
        }
    }

    // ==================== UI 佈局 ====================
    
    // 背景
    TechBackground {
        anchors.fill: parent
    }

    // 主內容
    Item {
        id: mainContent
        anchors.fill: parent
        anchors.topMargin: 40
        anchors.bottomMargin: 40
        
        // 基於窗口寬度動態計算兩邊留白，確保完全對稱
        property real contentWidthRatio: 0.85  // 內容區域佔窗口寬度的比例
        property int calculatedMargin: Math.floor((parent.width * (1 - contentWidthRatio)) / 2)
        
        anchors.leftMargin: calculatedMargin
        anchors.rightMargin: calculatedMargin

        // 頂部導航欄
        TopNavigationBar {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60

            showProgress: uploadManager.uploading
            progressValue: uploadManager.progress
            statusText: uploadManager.status

            onBackClicked: root.requestNavigate("home", null)
        }

        // 主內容區域
        Row {
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 30
            spacing: 40

            // 左側：檔案上傳區域
            FileUploadArea {
                width: parent.width * 0.5
                height: parent.height

                fileModel: fileManager.model
                acceptedExtensions: fileManager.acceptedExtensions
                maxFiles: fileManager.maxFiles
                uploading: uploadManager.uploading

                onFileAdded: function(fileName, filePath) {
                    if (fileManager.addFile(fileName, filePath)) {
                        uploadManager.fileCompleted()
                    }
                }

                onFileRemoved: function(index) { fileManager.removeFile(index) }
                
                onFilesDropped: function(urls) {
                    var validFiles = []
                    for (var i = 0; i < urls.length; i++) {
                        var url = urls[i]
                        var fileName = url.toString().split(/[\\/]/).pop()
                        if (fileManager.isValidFile(fileName) && !fileManager.hasFile(fileName)) {
                            validFiles.push(url)
                        }
                    }

                    if (validFiles.length > 0) {
                        uploadManager.beginUpload(validFiles.length)
                        
                        for (var j = 0; j < validFiles.length; j++) {
                            var url = validFiles[j]
                            var fileName = url.toString().split(/[\\/]/).pop()
                            var localPath = decodeURIComponent(url.toString().replace(/^file:\/+/, ""))
                            
                            if (fileManager.addFile(fileName, localPath)) {
                                uploadManager.fileCompleted()
                            }
                        }
                    }
                }

                onBrowseFiles: fileDialog.open()
            }

            // 右側：遮蔽選項設定
            OptionSelectionArea {
                width: parent.width * 0.5
                height: parent.height

                commonOptions: optionManager.commonOptions
                otherOptions: optionManager.otherOptions

                onOptionToggled: function(category, index) { optionManager.toggleOption(category, index) }

                onGenerateClicked: {
                    if (!root.canGenerate) return
                    
                    var selectedOptions = optionManager.getSelectedOptionKeys()
                    console.log("生成處理 - 選中選項:", selectedOptions.join(", "))
                    
                    if (typeof backend !== "undefined" && backend.processFiles) {
                        if (backend.setOptions) {
                            backend.setOptions(selectedOptions)
                        }
                        // 傳送選項顯示文字給後端，以供替換器使用
                        if (backend.setOptionsText) {
                            try {
                                backend.setOptionsText(optionManager.getSelectedOptionTexts())
                            } catch (e) {
                                console.warn("setOptionsText failed:", e)
                            }
                        }
                        backend.processFiles()
                    }
                }

                canGenerate: root.canGenerate
            }
        }
    }

    // ==================== 對話框 ====================
    FileDialog {
        id: fileDialog
        title: "選擇檔案"
        fileMode: FileDialog.OpenFiles
        nameFilters: [
            "文字與文件 (*.txt *.pdf *.doc *.docx)",
            "所有檔案 (*)"
        ]

        onAccepted: {
            var validFiles = []
            for (var i = 0; i < selectedFiles.length; i++) {
                var url = selectedFiles[i]
                var fileName = url.toString().split(/[\\/]/).pop()
                if (fileManager.isValidFile(fileName) && !fileManager.hasFile(fileName)) {
                    validFiles.push(url)
                }
            }

            if (validFiles.length > 0) {
                uploadManager.beginUpload(validFiles.length)
                
                for (var k = 0; k < validFiles.length; k++) {
                    var url = validFiles[k]
                    var fileName = url.toString().split(/[\\/]/).pop()
                    var localPath = decodeURIComponent(url.toString().replace(/^file:\/+/, ""))
                    
                    if (fileManager.addFile(fileName, localPath)) {
                        uploadManager.fileCompleted()
                    }
                }
            }
        }

        onRejected: console.log("取消檔案選擇")
    }
}