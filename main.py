import os, sys, json, re
from datetime import datetime
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtCore import QObject, Signal, Slot

try:
    from docx import Document
except ImportError:
    Document = None

# 定義每個選項的中文名稱與測試訊息
OPTION_META = {
    "name":       {"label": "姓名",     "header": "[NAME] 已選：模擬姓名處理 (未真正替換)"},
    "email":      {"label": "Email",    "header": "[EMAIL] 已選：模擬 Email 處理"},
    "phone":      {"label": "電話",     "header": "[PHONE] 已選：模擬電話處理"},
    "address":    {"label": "地址",     "header": "[ADDRESS] 已選：模擬地址處理"},
    "birthday":   {"label": "生日",     "header": "[BIRTHDAY] 已選：模擬生日處理"},
    "id":         {"label": "身分證",   "header": "[ID] 已選：模擬 ID 處理"},
    "student_id": {"label": "學號",     "header": "[STUDENT_ID] 已選：模擬學號處理"},
    "org":        {"label": "機構",     "header": "[ORG] 已選：模擬機構處理"}
}

# 針對插入示例（第一次匹配才加註）
OPTION_INLINE_PATTERNS = {
    "email":      (re.compile(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'), "[EMAIL_DEMO]"),
    "phone":      (re.compile(r'\b\d{8,11}\b'), "[PHONE_DEMO]"),
    "id":         (re.compile(r'\b[A-Z][0-9]{9}\b'), "[ID_DEMO]"),
    "birthday":   (re.compile(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b'), "[DATE_DEMO]"),
    "student_id": (re.compile(r'\b[ABCD]\d{7,8}\b', re.IGNORECASE), "[STUDENT_ID_DEMO]"),
}

# 簡單中文姓名 + (先生|小姐) 示意
OPTION_INLINE_PATTERNS["name"] = (re.compile(r'([\u4e00-\u9fff]{2,3})(先生|小姐)'), "[NAME_DEMO]")
# 地址只抓城市名（示意）
OPTION_INLINE_PATTERNS["address"] = (re.compile(r'(台北市|新北市|桃園市|台中市|台南市|高雄市)'), "[ADDR_DEMO]")

class Backend(QObject):
    filesChanged = Signal(list)
    resultsReady = Signal(str)  # JSON: [{fileName, type, originalText, maskedText}]

    def __init__(self):
        super().__init__()
        self._files = []
        self._options = []  # 勾選的 optionKey

    # ---------- 檔案 ----------
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

    # ---------- 遮蔽選項 (測試用：只影響 maskedText 的附加文字) ----------
    @Slot('QStringList')
    def setOptions(self, opts):
        self._options = [o for o in opts if o in OPTION_META]

    @Slot(result='QStringList')
    def getOptions(self):
        return self._options

    # ---------- 主處理 ----------
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
            masked = self._build_masked_test(original, file_name)

            results.append({
                "fileName": file_name,
                "type": ftype,
                "originalText": original,
                "maskedText": masked
            })

        self.resultsReady.emit(json.dumps(results, ensure_ascii=False))

    # ---------- 檔案讀取 ----------
    def _read_file_preview(self, path, ftype, max_chars=4000):
        try:
            if ftype == 'text':
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    data = f.read(max_chars+1)
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

    # ---------- 產生 maskedText：加測試說明 + 單次 inline 標記 ----------
    def _build_masked_test(self, original: str, filename: str) -> str:
        if not original:
            return original
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        header = [
            "[測試 / 去識別化模擬輸出 (僅加入文字, 原文未修改)]",
            f"[檔案: {filename}]",
            f"[時間: {now}]",
            f"[原文長度: {len(original)} chars]"
        ]
        if self._options:
            header.append("[已勾選項目] " + ", ".join(OPTION_META[o]["label"] for o in self._options))
            header.append("--- 以下為針對選項插入的測試行 ---")
            for o in self._options:
                header.append(OPTION_META[o]["header"])
        else:
            header.append("[未勾選任何選項]")

        # 只對第一個匹配的每個選項插入一次 inline 標記，不真正遮蔽
        modified_once = original
        for o in self._options:
            pat_tuple = OPTION_INLINE_PATTERNS.get(o)
            if not pat_tuple:
                continue
            pattern, tag = pat_tuple
            # 用 sub 只替換第一次，加上括號顯示 (DEMO)
            def _repl(m):
                return f"{tag}{{{m.group(0)}}}"
            modified_once, count = pattern.subn(_repl, modified_once, count=1)
            if count == 0:
                # 沒找到示例位置 → 在 header 加提示
                header.append(f"[{o} 無符合示例可插入 inline 標記]")
        if self._options:
            header.append("--- 選項插入示例結束 ---")

        summary = [
            "",
            "---------------- TEST SUMMARY ----------------",
            f"選項數量: {len(self._options)}",
            "此輸出僅用於 UI 瀏覽測試；原文完整附於下方。",
            "----------------------------------------------",
            "",
            "(以下為加入 inline 標記後的原文全文)"
        ]

        return "\n".join(header) + "\n\n" + "\n".join(summary) + "\n" + modified_once

# ---------- 啟動 ----------
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