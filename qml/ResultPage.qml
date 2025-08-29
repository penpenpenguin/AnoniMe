import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "./components"

Item {
    id: pageRoot
    anchors.fill: parent

    property var results: []
    property int selectedIndex: -1
    property string selectedContent: ""
    property var currentEmbedData: ({})
    property int downloadIndex: -1

    FileDialog {
        id: saveDialog
        title: "選擇下載儲存位置"
        nameFilters: ["所有檔案 (*)"]
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
        downloadIndex = idx
        var item = results[idx]
        var fileName = item.fileName ? item.fileName : "downloaded_file"
    // Some Qt versions' FileDialog does not expose a fileName property.
    // Instead, set the dialog title to indicate the default filename to the user.
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
            selectedIndex = -1
            selectedContent = ""
            currentEmbedData = ({})
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
            return
        }
        var item = results[idx]
        currentEmbedData = item.embedData ? item.embedData : ({})
        if (!currentEmbedData || !currentEmbedData.viewType) {
            var pathToRead = item.outputPath ? item.outputPath : (item.fileUrl ? item.fileUrl : null)
            if (pathToRead) {
                if (typeof backend !== "undefined" && backend.readFileContent) {
                    try {
                        var content = backend.readFileContent(pathToRead)
                        selectedContent = content !== undefined ? content : pathToRead
                        currentEmbedData = {"viewType": "text", "content": selectedContent, "syntaxType": "text", "lineCount": (selectedContent ? selectedContent.split("\n").length : 0)}
                    } catch (e) {
                        console.error("readFileContent failed:", e)
                        selectedContent = pathToRead
                        currentEmbedData = {"viewType": "text", "content": selectedContent, "syntaxType": "text", "lineCount": 1}
                    }
                } else {
                    selectedContent = pathToRead
                    currentEmbedData = {"viewType": "text", "content": selectedContent, "syntaxType": "text", "lineCount": 1}
                }
            } else {
                selectedContent = "(無 outputPath 或 fileUrl)"
                currentEmbedData = {"viewType": "error", "error": "無可用的預覽資料"}
            }
        } else {
            selectedContent = ""
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
            Rectangle {
                id: leftPanel
                width: parent.width * 0.35
                height: parent.height
                color: Qt.rgba(0.15, 0.2, 0.25, 0.8)
                radius: 12
                border.width: 1
                border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                Item {
                    anchors.fill: parent
                    anchors.margins: 20
                    property int headerHeight: 32
                    Text {
                        id: leftHeader
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "檔案列表"
                        font.pixelSize: 20
                        color: "#66FCF1"
                        height: parent.headerHeight
                    }
                    ListView {
                        id: fileListView
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: leftHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 8
                        model: results
                        delegate: Rectangle {
                            width: parent.width
                            height: 40
                            color: index === selectedIndex ? "#66FCF1" : (index % 2 === 0 ? Qt.rgba(0.15, 0.2, 0.25, 0.8) : Qt.rgba(0.07, 0.08, 0.1, 0.8))
                            border.width: 1
                            border.color: Qt.rgba(0.4, 0.99, 0.95, 0.2)
                            Row {
                                anchors.fill: parent
                                spacing: 12
                                MouseArea {
                                    id: fileNameArea
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 180
                                    height: parent.height
                                    onClicked: {
                                        selectedIndex = index
                                        loadFileContent(index)
                                    }
                                    Text {
                                        text: model.fileName ? model.fileName : (model.name ? model.name : (model.file_name ? model.file_name : "檔案"))
                                        color: index === selectedIndex ? "#222" : "#FFFFFF"
                                        font.pixelSize: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Button {
                                    text: "下載"
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        downloadFile(index)
                                    }
                                }
                                Button {
                                    text: "✕"
                                    anchors.verticalCenter: parent.verticalCenter
                                    background: Rectangle { color: "transparent" }
                                    onClicked: {
                                        removeFile(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: rightPanel
                width: parent.width - leftPanel.width - parent.spacing
                height: parent.height
                color: Qt.rgba(0.07, 0.08, 0.1, 0.8)
                radius: 12
                border.width: 1
                border.color: Qt.rgba(0.4, 0.99, 0.95, 0.3)
                Item {
                    anchors.fill: parent
                    anchors.margins: 20
                    property int headerHeight: 36
                    Text {
                        id: rightHeader
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: selectedIndex >= 0 ? (results[selectedIndex].fileName ? results[selectedIndex].fileName : (results[selectedIndex].name ? results[selectedIndex].name : (results[selectedIndex].file_name ? results[selectedIndex].file_name : "檔案"))) : "未選擇檔案"
                        font.pixelSize: 20
                        color: "#66FCF1"
                        height: parent.headerHeight
                    }
                    
                    Flickable {
                        id: contentFlickable
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: rightHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 8
                        contentWidth: width
                        contentHeight: Math.max((selectedContent.length > 0 ? (selectedContent.length * 0.6) : 80), height)
                        clip: true
                        EmbedViewer {
                            id: embedViewer
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 0
                            embedData: currentEmbedData
                        }
                        Text {
                            id: fallbackText
                            visible: !currentEmbedData || !currentEmbedData.viewType
                            text: selectedContent
                            wrapMode: Text.Wrap
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}