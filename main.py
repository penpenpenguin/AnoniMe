import os, sys, json
from datetime import datetime
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtCore import QObject, Signal, Slot

try:
    from docx import Document
except ImportError:
    Document = None

# 勾選項目對應的顯示文字
OPTION_META = {
    "name":       {"label": "姓名",     "desc": "姓名測試行"},
    "email":      {"label": "Email",    "desc": "Email 測試行"},
    "phone":      {"label": "電話",     "desc": "電話測試行"},
    "address":    {"label": "地址",     "desc": "地址測試行"},
    "birthday":   {"label": "生日",     "desc": "生日測試行"},
    "id":         {"label": "身分證",   "desc": "身分證測試行"},
    "student_id": {"label": "學號",     "desc": "學號測試行"},
    "org":        {"label": "機構",     "desc": "機構測試行"},
}

class Backend(QObject):
    filesChanged = Signal(list)
    resultsReady = Signal(str)  # JSON: [{fileName, type, originalText, maskedText}]

    def __init__(self):
        super().__init__()
        self._files = []
        self._options = []

    # 檔案操作 -------------------------------------------------
    @Slot(str)
    def addFile(self, path: str):
        if path and os.path.isfile(path) and path not in self._files:
            self._files.append(path)
            self.filesChanged.emit(self._files)

    @Slot('QStringList')
    def addFiles(self, paths):
        changed = False
        for p in paths:
            if p and os.path.isfile(p) and p not in self._files:
                self._files.append(p)
                changed = True
        if changed:
            self.filesChanged.emit(self._files)

    @Slot(str)
    def removeFile(self, path: str):
        if path in self._files:
            self._files.remove(path)
            self.filesChanged.emit(self._files)

    @Slot()
    def clearFiles(self):
        if self._files:
            self._files.clear()
            self.filesChanged.emit(self._files)

    @Slot(result='QStringList')
    def files(self):
        return self._files

    # 選項 -----------------------------------------------------
    @Slot('QStringList')
    def setOptions(self, opts):
        self._options = [o for o in opts if o in OPTION_META]

    @Slot(result='QStringList')
    def getOptions(self):
        return self._options

    # 主流程 ---------------------------------------------------
    @Slot()
    def processFiles(self):
        results = []
        for path in self._files:
            file_name = os.path.basename(path)
            ext = file_name.lower().rsplit('.', 1)[-1] if '.' in file_name else ''
            if ext in ('txt','md','log'):
                ftype = 'text'
            elif ext == 'docx':
                ftype = 'docx'
            elif ext == 'pdf':
                ftype = 'pdf'
            else:
                ftype = 'binary'

            original = self._read_file_preview(path, ftype)
            masked = self._build_test_version(original, file_name)

            results.append({
                "fileName": file_name,
                "type": ftype,
                "originalText": original,
                "maskedText": masked
            })

        self.resultsReady.emit(json.dumps(results, ensure_ascii=False))

    # 讀取 -----------------------------------------------------
    def _read_file_preview(self, path, ftype, max_chars=4000):
        try:
            if ftype == 'text':
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    data = f.read(max_chars + 1)
                if len(data) > max_chars:
                    data = data[:max_chars] + "\n...(截斷)"
                return data or "(空白)"
            if ftype == 'docx':
                if Document is None:
                    return "[缺少 python-docx 套件：pip install python-docx]"
                doc = Document(path)
                parts, length = [], 0
                for p in doc.paragraphs:
                    t = p.text.strip()
                    if t:
                        parts.append(t)
                        length += len(t)
                    if length > max_chars:
                        break
                data = "\n".join(parts)
                if len(data) > max_chars:
                    data = data[:max_chars] + "\n...(截斷)"
                return data or "(空白 DOCX)"
            if ftype == 'pdf':
                return f"[PDF 預覽占位] {os.path.basename(path)}"
            size = os.path.getsize(path)
            return f"[非文字類型，大小 {size} bytes]"
        except Exception as e:
            return f"[讀取錯誤] {e}"

    # 建立簡單測試版本（僅前置/後置說明） -----------------------
    def _build_test_version(self, original: str, filename: str) -> str:
        if not original:
            return original
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        header = [
            "[測試版本輸出]",
            f"[檔案: {filename}]",
            f"[時間: {now}]",
            f"[原文字元數: {len(original)}]"
        ]
        if self._options:
            header.append("[已勾選項目] " + ", ".join(OPTION_META[o]['label'] for o in self._options))
            header.append("--- 選項測試行開始 ---")
            for o in self._options:
                meta = OPTION_META[o]
                # 直接一行，不做任何內文搜尋 / 替換
                header.append(f"[TEST-{o.upper()}] {meta['desc']} (未修改正文)")
            header.append("--- 選項測試行結束 ---")
        else:
            header.append("[未勾選任何項目]")

        footer = [
            "",
            "------ TEST SUMMARY ------",
            f"選項數: {len(self._options)}",
            "本測試版本僅在前方加入描述，正文保持原樣。",
            "--------------------------"
        ]
        return "\n".join(header) + "\n\n" + original + "\n\n" + "\n".join(footer)

# 啟動 --------------------------------------------------------
if __name__ == "__main__":
    QQuickStyle.setStyle("Fusion")
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load("Main.qml")
    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())