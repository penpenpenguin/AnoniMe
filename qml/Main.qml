import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "./components" 
import "."

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    color: "black"
    title: "AnoniMe"

    property string currentPage: "home"
    property var pendingPayload: null      // 暫存結果資料
    property var lastResultPayload: null   // 保險再存一份

    function navigate(target, payload) {
        console.log("Main.navigate ->", target,
                    "payloadType =", typeof payload,
                    (payload && payload.length !== undefined) ? ("len=" + payload.length) : "")
        if (target === "result" && payload) {
            pendingPayload = payload
            lastResultPayload = payload    // 再備份
        } else {
            pendingPayload = payload
        }
        currentPage = target

        // 若已在結果頁且 item 已存在（例如同頁刷新）立即載入
        if (target === "result" && pageLoader.item && pageLoader.item.loadResults && pendingPayload) {
            console.log("Main.navigate: 即時呼叫 loadResults (page 已載)")
            pageLoader.item.loadResults(pendingPayload)
            pendingPayload = null
            lastResultPayload = null
        }
    }

    function hasPendingResults() {
        return (pendingPayload && pendingPayload.length !== undefined && pendingPayload.length > 0)
               || (lastResultPayload && lastResultPayload.length !== undefined && lastResultPayload.length > 0)
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        source: currentPage === "home"
                ? "HomePage.qml"
                : currentPage === "upload"
                  ? "UploadPage.qml"
                  : "ResultPage.qml"

        onLoaded: {
            console.log("Loader.onLoaded page =", currentPage,
                        "pendingPayload exist?", !!pendingPayload)
            if (item && item.requestNavigate)
                item.requestNavigate.connect(navigate)

            if (currentPage === "result" && item.loadResults) {
                if (pendingPayload) {
                    console.log("Loader: 直接 loadResults()")
                    item.loadResults(pendingPayload)
                    pendingPayload = null
                    lastResultPayload = null
                } else if (lastResultPayload) {
                    console.log("Loader: 使用備份 lastResultPayload")
                    item.loadResults(lastResultPayload)
                    pendingPayload = null
                    lastResultPayload = null
                } else {
                    // 嘗試直接從後端取得上次結果（若有），避免使用者看不到已處理的檔案
                    if (typeof backend !== 'undefined' && backend.getLastResults) {
                        try {
                            var last = backend.getLastResults()
                            if (last) {
                                var parsed = JSON.parse(last)
                                if (parsed && parsed.length) {
                                    console.log("Loader: 從 backend.getLastResults() 補呼叫 loadResults()")
                                    item.loadResults(parsed)
                                    pendingPayload = null
                                    lastResultPayload = null
                                    return
                                }
                            }
                            
                        } catch (e) {
                            console.log("Loader: backend.getLastResults() 取回失敗", e)
                        }
                    }
                    // 延遲再試一次（保險）
                    Qt.callLater(function() {
                        if (pendingPayload && item.loadResults) {
                            console.log("Loader: 延遲補呼叫 loadResults()")
                            item.loadResults(pendingPayload)
                            pendingPayload = null
                            lastResultPayload = null
                        }
                    })
                }
            }
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("Loader Error:", source)
            }
        }
    }
}