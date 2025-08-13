import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    color: "black"
    title: "AnoniMe"

    property string currentPage: "home"
    property var pendingPayload: null   // 暫存傳遞資料（主要給 result）

    function navigate(target, payload) {
        pendingPayload = payload ?? null
        if (currentPage === target) {
            // 若重覆導航同頁（例如重新載入結果），直接觸發更新
            if (target === "result" && pageLoader.item && pendingPayload)
                pageLoader.item.loadResults(pendingPayload)
            return
        }
        currentPage = target
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
            if (item && item.requestNavigate) {
                item.requestNavigate.connect(navigate)
            }
            // 若是結果頁且有資料
            if (currentPage === "result" && pendingPayload && item.loadResults) {
                item.loadResults(pendingPayload)
            }
        }
    }
}