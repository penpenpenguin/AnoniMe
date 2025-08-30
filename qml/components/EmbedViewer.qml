import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var embedData: ({})
    
    height: viewLoader.height + 20
    
    // 去除外框線，避免背景出現條紋
    Rectangle {
        anchors.fill: parent
        color: "#FAFAFA"
        border.color: "transparent"
        border.width: 0
        radius: 8
    }
    
    Loader {
        id: viewLoader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        
        sourceComponent: {
            if (!embedData || !embedData.viewType) return errorView
            
            switch (embedData.viewType) {
                case "text": return textView
                case "pdf": return pdfView
                case "docx": return docxView
                case "doc": return docView
                case "hex": return hexView
                case "error": return errorView
                case "unsupported": return unsupportedView
                default: return errorView
            }
        }
    }
    
    // 文字檢視器（支援語法高亮提示）
    Component {
        id: textView
        ScrollView {
            height: Math.min(400, textEdit.contentHeight + 20)
            clip: true
            
            TextArea {
                id: textEdit
                text: embedData.content || ""
                readOnly: true
                selectByMouse: true
                wrapMode: TextArea.WrapAtWordBoundaryOrAnywhere
                textFormat: TextArea.PlainText
                font.family: "Consolas, Monaco, monospace"
                font.pixelSize: 12
                
                background: Rectangle {
                    color: root.getSyntaxBgColor(embedData.syntaxType || "text")
                    border.color: "#D0D0D0"
                    border.width: 1
                    radius: 4
                }
                
                // 行號背景
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 50
                    color: "#F5F5F5"
                    border.color: "#E0E0E0"
                    border.width: 1
                    z: -1
                    
                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 5
                        spacing: 0
                        Repeater {
                            model: embedData.lineCount || 0
                            Text {
                                text: index + 1
                                font.family: textEdit.font.family
                                font.pixelSize: 10
                                color: "#999"
                                width: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
                
                leftPadding: 60
            }
        }
    }
    
    
    // PDF 檢視器
    Component {
        id: pdfView
        Column {
            spacing: 10
            height: childrenRect.height
            
            // 元資料
            Rectangle {
                width: parent.width
                // metaLayout was undefined in some contexts; use a safe fixed/min height
                height: Math.max(60, childrenRect.height)
                color: "#F0F8FF"
                border.color: "#B0C4DE"
                border.width: 1
                radius: 6
            }
            
            // 頁面圖像
            ScrollView {
                width: parent.width
                height: Math.min(500, pageColumn.height)
                clip: true
                
                Column {
                    id: pageColumn
                    width: parent.width
                    spacing: 15
                    
                    Repeater {
                        model: embedData.pageImages || []
                        delegate: Rectangle {
                            width: parent.width
                            height: pageImg.paintedHeight + 20
                            color: "white"
                            border.color: "transparent"  // 移除每頁外框，避免大量線條感
                            border.width: 0
                            radius: 4
                            
                            Image {
                                id: pageImg
                                anchors.centerIn: parent
                                anchors.margins: 10
                                source: modelData
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                width: parent.width - 20
                                smooth: true
                                mipmap: true
                                // 讓採樣品質更好，減少縮放造成的條紋
                                sourceSize.width: width
                            }
                            
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 5
                                text: "第 " + (index + 1) + " 頁"
                                font.pixelSize: 10
                                color: "#999"
                            }
                        }
                    }
                }
            }
        }
    }
    
    // DOCX 檢視器
    Component {
        id: docxView
        ScrollView {
            height: Math.min(400, docxColumn.height + 20)
            clip: true
            
            Column {
                id: docxColumn
                width: parent.width
                spacing: 15
                                
                // 段落：移除外框，避免一段一框造成橫線堆疊視覺
                Column {
                    width: parent.width
                    spacing: 10
                    
                    Repeater {
                        model: embedData.paragraphs || []
                        delegate: Rectangle {
                            width: parent.width
                            height: paraText.height + 20
                            color: "transparent"
                            border.color: "transparent"
                            border.width: 0
                            radius: 0
                            
                            Text {
                                id: paraText
                                anchors.fill: parent
                                anchors.margins: 10
                                text: modelData.text || ""
                                wrapMode: Text.Wrap
                                font.pixelSize: modelData.style === "Heading 1" ? 16 : 
                                              modelData.style === "Heading 2" ? 14 : 12
                                font.bold: modelData.style && modelData.style.includes("Heading")
                                color: "#333"
                            }
                        }
                    }
                }
                
                // 表格：移除每格邊框，避免密集格線造成條紋；僅保留間距
                Column {
                    width: parent.width
                    spacing: 15
                    
                    Repeater {
                        model: embedData.tables || []
                        delegate: Rectangle {
                            width: parent.width
                            height: tableGrid.height + 20
                            color: "transparent"
                            border.color: "transparent"
                            border.width: 0
                            radius: 0
                            
                            Grid {
                                id: tableGrid
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: modelData && modelData.length > 0 ? modelData[0].length : 0
                                spacing: 2
                                
                                Repeater {
                                    model: {
                                        var flattened = []
                                        if (modelData) {
                                            for (var i = 0; i < modelData.length; i++) {
                                                for (var j = 0; j < modelData[i].length; j++) {
                                                    flattened.push({text: modelData[i][j], isHeader: i === 0})
                                                }
                                            }
                                        }
                                        return flattened
                                    }
                                    
                                    delegate: Rectangle {
                                        width: (parent.width - (tableGrid.columns - 1) * tableGrid.spacing) / tableGrid.columns
                                        height: cellText.height + 10
                                        color: modelData.isHeader ? "#F6F6FA" : "transparent"
                                        border.color: "transparent"
                                        border.width: 0
                                        
                                        Text {
                                            id: cellText
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            text: modelData.text || ""
                                            wrapMode: Text.Wrap
                                            font.pixelSize: 11
                                            font.bold: modelData.isHeader
                                            color: "#333"
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
    
    // DOC 檢視器
    Component {
        id: docView
        ScrollView {
            height: Math.min(400, docText.contentHeight + 40)
            clip: true
            
            Column {
                width: parent.width
                spacing: 10
                
                TextArea {
                    id: docText
                    width: parent.width
                    text: embedData.content || ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 12
                    color: "#333"
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#D0D0D0"
                        border.width: 1
                        radius: 4
                    }
                }
            }
        }
    }
    
    // 十六進制檢視器
    Component {
        id: hexView
        ScrollView {
            height: Math.min(300, hexColumn.height + 20)
            clip: true
            
            Column {
                id: hexColumn
                width: parent.width
                spacing: 10
                
                
                Rectangle {
                    width: parent.width
                    height: hexRepeater.height + 20
                    color: "black"
                    border.color: "#555"
                    border.width: 1
                    radius: 4
                    
                    Column {
                        id: hexRepeater
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        
                        Repeater {
                            model: embedData.hexLines || []
                            delegate: Row {
                                spacing: 15
                                Text {
                                    text: modelData.offset
                                    font.family: "Consolas, Monaco, monospace"
                                    font.pixelSize: 11
                                    color: "#00FF00"
                                    width: 80
                                }
                                Text {
                                    text: modelData.hex
                                    font.family: "Consolas, Monaco, monospace"
                                    font.pixelSize: 11
                                    color: "#FFFF00"
                                    width: 400
                                }
                                Text {
                                    text: modelData.ascii
                                    font.family: "Consolas, Monaco, monospace"
                                    font.pixelSize: 11
                                    color: "#FF69B4"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 錯誤檢視
    Component {
        id: errorView
        Rectangle {
            width: parent.width
            height: 100
            color: "#FFE4E1"
            border.color: "#FF6347"
            border.width: 1
            radius: 6
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "⚠️ 檔案檢視錯誤"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#DC143C"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: embedData.error || "未知錯誤"
                    font.pixelSize: 12
                    color: "#8B0000"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    
    // 不支援檢視
    Component {
        id: unsupportedView
        Rectangle {
            width: parent.width
            height: 120
            color: "#F0F8FF"
            border.color: "#4682B4"
            border.width: 1
            radius: 6
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "🔧 檔案類型暫不支援內嵌檢視"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#2F4F4F"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: embedData.reason || "需要安裝額外套件"
                    font.pixelSize: 12
                    color: "#696969"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "檔案: " + (embedData.fileName || "") + " (" + (embedData.fileSize || 0) + " bytes)"
                    font.pixelSize: 10
                    color: "#808080"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    
    // 根據語法類型提供背景色
    function getSyntaxBgColor(syntaxType) {
        switch (syntaxType) {
            case "python": return "#FFF8E7"
            case "javascript": return "#F0F8E7"
            case "html": return "#FFF0E7"
            case "css": return "#E7F0FF"
            case "json": return "#F0FFF0"
            case "xml": return "#FFF8F0"
            case "markdown": return "#F8F8FF"
            default: return "#FFFFFF"
        }
    }
}
