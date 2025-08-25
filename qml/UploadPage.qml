import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs   // Qt6 新 API
import "./components" 
import "."

Item {
    id: uploadRoot
    property int base: 72
    signal requestNavigate(string target, var payload)

    anchors.fill: parent

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
        var hasFile = tagModel.count > 0
        var hasOption = false
        
        // 檢查常用區選項
        if (typeof nameOption !== "undefined" && nameOption.checked) hasOption = true
        if (typeof emailOption !== "undefined" && emailOption.checked) hasOption = true
        if (typeof phoneOption !== "undefined" && phoneOption.checked) hasOption = true
        if (typeof addressOption !== "undefined" && addressOption.checked) hasOption = true
        
        // 檢查其他區選項
        if (typeof birthdayOption !== "undefined" && birthdayOption.checked) hasOption = true
        if (typeof idOption !== "undefined" && idOption.checked) hasOption = true
        if (typeof companyOption !== "undefined" && companyOption.checked) hasOption = true
        if (typeof bankOption !== "undefined" && bankOption.checked) hasOption = true
        
        canGenerate = hasFile && hasOption && !uploading
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
        console.log("beginUpload total =", total)
        updateCanGenerate()
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
            updateCanGenerate()
        }
    }

    function hideProgress() {
        statusOverlay.visible = false
        currentStatus = ""
        updateCanGenerate()
    }

    // 新增：供外部（如 Main 的全域 DropArea）一次加入多個檔案
    function addFilesFromUrls(urls) {
        if (!urls || urls.length === 0) return
        console.log("addFilesFromUrls 接收:", urls.length)

        // 預先計算可加入數量
        var pending = 0
        for (var i = 0; i < urls.length; ++i) {
            var s = urls[i].toString()
            var fileName = s.split(/[\\/]/).pop()
            var ext = fileName.indexOf(".") >= 0 ? fileName.split(".").pop().toLowerCase() : ""
            var dup = false
            for (var j=0;j<tagModel.count;j++)
                if (tagModel.get(j).name === fileName) { dup = true; break }
            if (dropZone.acceptedExt.indexOf(ext) !== -1 && !dup && tagModel.count + pending < dropZone.maxFiles)
                pending++
        }
        if (pending > 0) beginUpload(pending)

        var addedCount = 0
        for (var k = 0; k < urls.length; ++k) {
            if (!uploading) break
            if (dropZone.addFileFromUrl(urls[k].toString())) {
                fileUploadedOne()
                addedCount++
            }
        }
        if (pending > 0 && addedCount === 0) {
            uploading = false
            hideProgress()
        }
    }

    Component.onCompleted: {
        if (typeof backend !== "undefined"
                && backend.resultsReady
                && !backend._uploadConnected) {

            backend._uploadConnected = true
            console.log("UploadPage: 已連接 backend.resultsReady")
        }
    }

    // 取代手動 connect：物件銷毀時自動解除連線
    Connections {
        target: typeof backend !== "undefined" ? backend : null
        function onResultsReady(json) {
            console.log("UploadPage: resultsReady 收到 JSON 長度 =", json.length)
            var arr = []
            try { arr = JSON.parse(json) } catch (e) {
                console.log("UploadPage: JSON 解析失敗", e)
                return
            }
            console.log("UploadPage: 解析後筆數 =", arr.length)
            // 安全呼叫導航（避免 null）
            if (uploadRoot && uploadRoot.requestNavigate) {
                uploadRoot.requestNavigate("result", arr)
            } else {
                console.log("UploadPage: requestNavigate 不可用（頁面尚未就緒或已切換）")
            }
        }
    }

    // 科技感漸層背景（承襲 HomePage 風格）
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0B0C10" }
            GradientStop { position: 0.3; color: "#1F2833" }
            GradientStop { position: 0.7; color: "#2C3E50" }
            GradientStop { position: 1.0; color: "#34495E" }
        }
        
        // 網格線背景
        Canvas {
            anchors.fill: parent
            opacity: 0.02
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#66FCF1"
                ctx.lineWidth = 1
                
                var gridSize = 50
                for (var x = 0; x <= width; x += gridSize) {
                    ctx.beginPath()
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                    ctx.stroke()
                }
                for (var y = 0; y <= height; y += gridSize) {
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }
            }
        }
        
        // 動態粒子
        Repeater {
            model: 8
            Rectangle {
                width: 2 + Math.random() * 3
                height: width
                radius: width / 2
                color: Qt.rgba(0.4, 0.99, 0.95, 0.3 + Math.random() * 0.4)
                x: Math.random() * parent.width
                y: Math.random() * parent.height
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { 
                        from: 0.1; to: 0.6
                        duration: 3000 + Math.random() * 2000
                        easing.type: Easing.InOutSine 
                    }
                    NumberAnimation { 
                        from: 0.6; to: 0.1
                        duration: 3000 + Math.random() * 2000
                        easing.type: Easing.InOutSine 
                    }
                }
            }
        }
    }

    // 主要內容區域
    Item {
        anchors.fill: parent
        anchors.margins: 40
        
        // 頂部導航
        Item {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            
            // 返回按鈕
            Item {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: backContent.width + 20
                height: 40
                
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Qt.rgba(0.4, 0.99, 0.95, backArea.containsMouse ? 0.15 : 0.08)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }
                
                Row {
                    id: backContent
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text {
                        text: "←"
                        color: "#66FCF1"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "返回"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: requestNavigate("home", null)
                }
            }
            
            // 進度條覆蓋層
            Item {
                id: statusOverlay
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                height: 40
                visible: false
                opacity: visible ? 1 : 0
                
                Behavior on opacity { 
                    NumberAnimation { duration: 200 } 
                }
                
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Qt.rgba(0.07, 0.08, 0.1, 0.8)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                }
                
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: currentStatus
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        visible: currentStatus.length > 0
                    }
                    
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 6
                        radius: 3
                        color: Qt.rgba(0.4, 0.99, 0.95, 0.2)
                        
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            radius: 3
                            width: Math.max(6, parent.width * progressValue / 100)
                            color: "#66FCF1"
                            
                            SequentialAnimation on opacity {
                                running: statusOverlay.visible
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.8; to: 1.0; duration: 800 }
                                NumberAnimation { from: 1.0; to: 0.8; duration: 800 }
                            }
                        }
                    }
                }
            }
        }
        
        // 主要內容（雙列佈局）
        Row {
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 30
            spacing: 40
            
            // 左側：檔案上傳區域
            Column {
                width: parent.width * 0.5
                height: parent.height
                spacing: 20
                
                // 上傳區標題（與右側對齊）
                Text {
                    text: "檔案上傳"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
                
                // 拖放上傳框
                Rectangle {
                    id: dropZone
                    width: parent.width
                    height: 280
                    radius: 16
                    color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
                    border.width: 2
                    border.color: dragHover ? "#66FCF1" : Qt.rgba(0.4, 0.99, 0.95, 0.3)
                    
                    property bool dragHover: false
                    property var acceptedExt: ["txt","pdf","doc","docx"]
                    property int maxFiles: 20
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }

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
                    
                    // 發光效果
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0.4, 0.99, 0.95, dragHover ? 0.4 : 0.1)
                        opacity: dragHover ? 1.0 : 0.5
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 300 }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        // 上傳圖標
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 60
                            height: 60
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: 60
                                height: 60
                                radius: 30
                                color: "transparent"
                                border.width: 2
                                border.color: "#66FCF1"
                                opacity: 0.8
                                
                                RotationAnimation on rotation {
                                    running: dropZone.dragHover
                                    loops: Animation.Infinite
                                    from: 0; to: 360
                                    duration: 3000
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "📁"
                                font.pixelSize: 24
                                color: "#66FCF1"
                                scale: dropZone.dragHover ? 1.1 : 1.0
                                
                                Behavior on scale {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }
                        
                        // 上傳文字
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "拖放檔案至此處"
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: "#FFFFFF"
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "支援 TXT • PDF • DOC • DOCX"
                                font.pixelSize: 12
                                color: "#66FCF1"
                                opacity: 0.8
                            }
                        }
                        
                        // 檔案計數
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tagModel.count > 0 ? (tagModel.count + " 個檔案已選擇") : ""
                            font.pixelSize: 10
                            color: "#66FCF1"
                            opacity: 0.6
                            visible: tagModel.count > 0
                        }
                    }
                    
                    DropArea {
                        anchors.fill: parent
                        onEntered: (e)=> {
                            e.acceptProposedAction()
                            dropZone.dragHover = true
                        }
                        onExited: {
                            dropZone.dragHover = false
                        }
                        onDropped: (e)=> {
                            dropZone.dragHover = false
                            if (e.hasUrls && e.urls.length > 0) {
                                var pending = 0
                                for (let u of e.urls) {
                                    var s = u.toString()
                                    var name = s.split(/[\\/]/).pop()
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
                                    if (!uploading) break
                                    if (dropZone.addFileFromUrl(u.toString())) {
                                        fileUploadedOne()
                                        addedCount++
                                    }
                                }
                                if (pending > 0 && addedCount === 0) {
                                    uploading = false
                                    hideProgress()
                                }
                            }
                            e.acceptProposedAction()
                        }
                    }
                    
                    // 點擊上傳
                    MouseArea {
                        anchors.fill: parent
                        onClicked: fileDialog.open()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                
                // 檔案列表
                Rectangle {
                    width: parent.width
                    height: 120
                    radius: 16
                    color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
                    border.width: 2
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                    visible: tagModel.count > 0
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 12
                        
                        // 檔案列表標題
                        Row {
                            spacing: 12
                            
                            Rectangle {
                                width: 4
                                height: 16
                                radius: 2
                                color: "#66FCF1"
                            }
                            
                            Text {
                                text: "已選檔案"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: "#66FCF1"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        ScrollView {
                            width: parent.width
                            height: 60
                            clip: true
                            
                            Flow {
                                width: parent.width
                                spacing: 6
                                
                                Repeater {
                                    model: tagModel
                                    delegate: Rectangle {
                                        radius: 12
                                        color: Qt.rgba(0.4, 0.99, 0.95, 0.15)
                                        border.width: 1
                                        border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                                        height: 24
                                        width: Math.min(chipText.implicitWidth + 40, 160)
                                        
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6
                                            
                                            Text {
                                                id: chipText
                                                text: name
                                                font.pixelSize: 10
                                                color: "#FFFFFF"
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 120)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: "✕"
                                                color: "#66FCF1"
                                                font.pixelSize: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: uploadRoot.removeFile(index)
                                                }
                                            }
                                        }
                                        
                                        ToolTip.visible: hoverHandler.hovered
                                        ToolTip.text: name
                                        HoverHandler { id: hoverHandler }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 右側：遮蔽選項區域
            Column {
                width: parent.width * 0.5
                height: parent.height
                spacing: 20
                
                // 選項標題
                Text {
                    text: "遮蔽選項設定"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
                
                // 常用區
                Rectangle {
                    id: commonArea
                    width: parent.width
                    height: 280
                    radius: 16
                    color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
                    border.width: 2
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16
                        
                        // 常用區標題
                        Row {
                            spacing: 12
                            
                            Rectangle {
                                width: 4
                                height: 24
                                radius: 2
                                color: "#66FCF1"
                            }
                            
                            Text {
                                text: "常用區"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#66FCF1"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        // 常用選項按鈕
                        Flow {
                            id: commonOptions
                            width: parent.width
                            spacing: 12
                            
                            Rectangle { 
                                id: nameOption
                                property string text: "姓名"
                                property string optionKey: "name"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(nameText.implicitWidth + 24, 120)
                                height: 36
                                radius: 18
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.4) : Qt.rgba(0.15, 0.2, 0.25, 0.8)
                                border.width: 2
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.8)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: parent.radius + 3
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0.4, 0.99, 0.95, checked ? 0.6 : 0.0)
                                    opacity: checked ? (nameArea.containsMouse ? 1.0 : 0.7) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                
                                Text {
                                    id: nameText
                                    anchors.centerIn: parent
                                    text: nameOption.text
                                    font.pixelSize: 12
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: nameArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { nameOption.checked = !nameOption.checked; nameOption.toggled() }
                                }
                                
                                scale: nameArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: emailOption
                                property string text: "Email"
                                property string optionKey: "email"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(emailText.implicitWidth + 24, 120)
                                height: 36
                                radius: 18
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.4) : Qt.rgba(0.15, 0.2, 0.25, 0.8)
                                border.width: 2
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.8)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: parent.radius + 3
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0.4, 0.99, 0.95, checked ? 0.6 : 0.0)
                                    opacity: checked ? (emailArea.containsMouse ? 1.0 : 0.7) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                
                                Text {
                                    id: emailText
                                    anchors.centerIn: parent
                                    text: emailOption.text
                                    font.pixelSize: 12
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: emailArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { emailOption.checked = !emailOption.checked; emailOption.toggled() }
                                }
                                
                                scale: emailArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: phoneOption
                                property string text: "電話"
                                property string optionKey: "phone"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(phoneText.implicitWidth + 24, 120)
                                height: 36
                                radius: 18
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.4) : Qt.rgba(0.15, 0.2, 0.25, 0.8)
                                border.width: 2
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.8)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: parent.radius + 3
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0.4, 0.99, 0.95, checked ? 0.6 : 0.0)
                                    opacity: checked ? (phoneArea.containsMouse ? 1.0 : 0.7) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                
                                Text {
                                    id: phoneText
                                    anchors.centerIn: parent
                                    text: phoneOption.text
                                    font.pixelSize: 12
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: phoneArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { phoneOption.checked = !phoneOption.checked; phoneOption.toggled() }
                                }
                                
                                scale: phoneArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: addressOption
                                property string text: "地址"
                                property string optionKey: "address"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(addressText.implicitWidth + 24, 120)
                                height: 36
                                radius: 18
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.4) : Qt.rgba(0.15, 0.2, 0.25, 0.8)
                                border.width: 2
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.8)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: parent.radius + 3
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0.4, 0.99, 0.95, checked ? 0.6 : 0.0)
                                    opacity: checked ? (addressArea.containsMouse ? 1.0 : 0.7) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                
                                Text {
                                    id: addressText
                                    anchors.centerIn: parent
                                    text: addressOption.text
                                    font.pixelSize: 12
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: addressArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { addressOption.checked = !addressOption.checked; addressOption.toggled() }
                                }
                                
                                scale: addressArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }
                
                // 其他區
                Rectangle {
                    id: otherArea
                    width: parent.width
                    height: otherExpanded ? 140 : 60
                    radius: 16
                    color: Qt.rgba(0.07, 0.08, 0.1, 0.6)
                    border.width: 2
                    border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                    
                    property bool otherExpanded: false
                    
                    Behavior on height {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16
                        
                        // 其他區標題（可點擊展開）
                        Row {
                            width: parent.width
                            spacing: 12
                            
                            Rectangle {
                                width: 4
                                height: 24
                                radius: 2
                                color: "#66FCF1"
                            }
                            
                            Text {
                                text: "其他區"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#66FCF1"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Item { width: parent.width - 100 }
                            
                            // 展開/收合按鈕
                            Rectangle {
                                width: 32
                                height: 24
                                radius: 12
                                color: Qt.rgba(0.4, 0.99, 0.95, toggleArea.containsMouse ? 0.2 : 0.1)
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: otherArea.otherExpanded ? "▲" : "▼"
                                    color: "#66FCF1"
                                    font.pixelSize: 12
                                    
                                    RotationAnimation on rotation {
                                        running: otherArea.otherExpanded !== otherExpandedPrev
                                        from: otherArea.otherExpanded ? 0 : 180
                                        to: otherArea.otherExpanded ? 180 : 0
                                        duration: 300
                                        
                                        property bool otherExpandedPrev: false
                                        Component.onCompleted: otherExpandedPrev = otherArea.otherExpanded
                                        onRunningChanged: if (!running) otherExpandedPrev = otherArea.otherExpanded
                                    }
                                }
                                
                                MouseArea {
                                    id: toggleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: otherArea.otherExpanded = !otherArea.otherExpanded
                                }
                            }
                        }
                        
                        // 其他選項按鈕（只在展開時顯示，確保不超出）
                        Flow {
                            id: otherOptions
                            width: parent.width
                            spacing: 8
                            visible: otherArea.otherExpanded
                            opacity: otherArea.otherExpanded ? 1.0 : 0.0
                            clip: true
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 300 }
                            }
                            
                            Rectangle { 
                                id: birthdayOption
                                property string text: "生日"
                                property string optionKey: "birthday"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(birthdayText.implicitWidth + 20, 100)
                                height: 32
                                radius: 16
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.35) : Qt.rgba(0.15, 0.2, 0.25, 0.7)
                                border.width: 1
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.7)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    id: birthdayText
                                    anchors.centerIn: parent
                                    text: birthdayOption.text
                                    font.pixelSize: 10
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: birthdayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { birthdayOption.checked = !birthdayOption.checked; birthdayOption.toggled() }
                                }
                                
                                scale: birthdayArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: idOption
                                property string text: "身分證/SSN"
                                property string optionKey: "id"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(idText.implicitWidth + 20, 100)
                                height: 32
                                radius: 16
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.35) : Qt.rgba(0.15, 0.2, 0.25, 0.7)
                                border.width: 1
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.7)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    id: idText
                                    anchors.centerIn: parent
                                    text: idOption.text
                                    font.pixelSize: 10
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: idArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { idOption.checked = !idOption.checked; idOption.toggled() }
                                }
                                
                                scale: idArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: companyOption
                                property string text: "公司名稱"
                                property string optionKey: "company"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(companyText.implicitWidth + 20, 100)
                                height: 32
                                radius: 16
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.35) : Qt.rgba(0.15, 0.2, 0.25, 0.7)
                                border.width: 1
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.7)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    id: companyText
                                    anchors.centerIn: parent
                                    text: companyOption.text
                                    font.pixelSize: 10
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: companyArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { companyOption.checked = !companyOption.checked; companyOption.toggled() }
                                }
                                
                                scale: companyArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Rectangle { 
                                id: bankOption
                                property string text: "銀行帳號"
                                property string optionKey: "bank"
                                property bool checked: false
                                signal toggled()
                                onToggled: updateCanGenerate()
                                
                                width: Math.min(bankText.implicitWidth + 20, 100)
                                height: 32
                                radius: 16
                                color: checked ? Qt.rgba(0.0, 1.0, 0.9, 0.35) : Qt.rgba(0.15, 0.2, 0.25, 0.7)
                                border.width: 1
                                border.color: checked ? "#00FFE6" : Qt.rgba(0.4, 0.6, 0.7, 0.7)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    id: bankText
                                    anchors.centerIn: parent
                                    text: bankOption.text
                                    font.pixelSize: 10
                                    font.weight: checked ? Font.Bold : Font.Medium
                                    color: checked ? "#00FFE6" : "#E0E0E0"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                MouseArea {
                                    id: bankArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { bankOption.checked = !bankOption.checked; bankOption.toggled() }
                                }
                                
                                scale: bankArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }
                
                // 生成按鈕
                Item {
                    width: parent.width
                    height: 80
                    
                    Rectangle {
                        id: generateButton
                        width: 200
                        height: 50
                        radius: 25
                        anchors.centerIn: parent
                        
                        gradient: Gradient {
                            GradientStop { 
                                position: 0.0
                                color: canGenerate 
                                    ? (generateArea.pressed ? "#4A9B8E" : "#66FCF1")
                                    : "#34495E"
                            }
                            GradientStop { 
                                position: 1.0
                                color: canGenerate 
                                    ? (generateArea.pressed ? "#2F7A6B" : "#4A9B8E")
                                    : "#2C3E50"
                            }
                        }
                        
                        border.width: 2
                        border.color: canGenerate ? "#66FCF1" : "#34495E"
                        
                        // 發光效果
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            radius: parent.radius + 6
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.rgba(0.4, 0.99, 0.95, canGenerate ? 0.3 : 0.1)
                            opacity: canGenerate ? (generateArea.containsMouse ? 1.0 : 0.6) : 0.2
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "生成結果"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: canGenerate ? "#0B0C10" : "#7F8C8D"
                        }
                        
                        MouseArea {
                            id: generateArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: canGenerate ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            
                            onClicked: {
                                if (!canGenerate) return
                                console.log("Generate clicked - 呼叫後端處理")
                                if (typeof backend !== "undefined" && backend.processFiles) {
                                    var opts = []
                                    // 收集常用區選中的選項
                                    if (nameOption.checked) opts.push(nameOption.optionKey)
                                    if (emailOption.checked) opts.push(emailOption.optionKey)
                                    if (phoneOption.checked) opts.push(phoneOption.optionKey)
                                    if (addressOption.checked) opts.push(addressOption.optionKey)
                                    // 收集其他區選中的選項
                                    if (birthdayOption.checked) opts.push(birthdayOption.optionKey)
                                    if (idOption.checked) opts.push(idOption.optionKey)
                                    if (companyOption.checked) opts.push(companyOption.optionKey)
                                    if (bankOption.checked) opts.push(bankOption.optionKey)
                                    
                                    console.log("選取項目 =", opts.join(", "))
                                    if (backend.setOptions) backend.setOptions(opts)
                                    backend.processFiles()
                                }
                            }
                        }
                        
                        // 停用狀態工具提示
                        ToolTip.visible: !canGenerate && generateArea.containsMouse
                        ToolTip.text: "請先選擇檔案與遮蔽選項"
                    }
                }
            }
        }
    }
    
    // 自定義選項按鈕組件
    Component {
        id: optionButtonComponent
        Rectangle {
            id: optionButton
            property string text: ""
            property string optionKey: ""
            property bool checked: false
            signal toggled()
            
            width: Math.min(buttonText.implicitWidth + 24, 120)
            height: 36
            radius: 18
            
            // 背景顏色：未選中時透明，選中時青綠色
            color: checked ? Qt.rgba(0.4, 0.99, 0.95, 0.2) : Qt.rgba(0.07, 0.08, 0.1, 0.3)
            border.width: 2
            border.color: checked ? "#66FCF1" : Qt.rgba(0.4, 0.99, 0.95, 0.4)
            
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
            
            Behavior on border.color {
                ColorAnimation { duration: 200 }
            }
            
            // 發光效果（只在選中時顯示）
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.4, 0.99, 0.95, checked ? 0.6 : 0.0)
                opacity: checked ? (buttonArea.containsMouse ? 1.0 : 0.7) : 0.0
                
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
            
            Text {
                id: buttonText
                anchors.centerIn: parent
                text: optionButton.text
                font.pixelSize: 12
                font.weight: checked ? Font.Bold : Font.Medium
                color: checked ? "#66FCF1" : "#FFFFFF"
                
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
            
            MouseArea {
                id: buttonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    optionButton.checked = !optionButton.checked
                    optionButton.toggled()
                }
            }
            
            // 懸停效果
            scale: buttonArea.containsMouse ? 1.05 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 150 }
            }
        }
    }
    
    // OptionButton 自定義組件
    Component {
        id: optionButton
        Loader {
            property string text: ""
            property string optionKey: ""
            property bool checked: false
            signal toggled()
            
            sourceComponent: optionButtonComponent
            
            onLoaded: {
                item.text = text
                item.optionKey = optionKey
                item.checked = checked
                item.toggled.connect(toggled)
            }
        }
    }
    
    // 檔案對話框
    FileDialog {
        id: fileDialog
        title: "選擇檔案"
        fileMode: FileDialog.OpenFiles
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
                    for (var j = 0; j < tagModel.count; j++)
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