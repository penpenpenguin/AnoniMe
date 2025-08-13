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

# 追加：用於 PDF 轉圖與 Word 轉 PDF（可選）
try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None

try:
    import win32com.client  # 需要安裝 pywin32 與本機有 Microsoft Word
except ImportError:
    win32com = None

import tempfile
import shutil

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
        self._last_results = []          # 新增：快取最近一次結果

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
        print("Backend: processFiles() start, files =", len(self._files), "options =", self._options)
        results = []
        for path in self._files:
            file_name = os.path.basename(path)
            ext = file_name.lower().rsplit('.', 1)[-1] if '.' in file_name else ''
            if ext in ('txt','md','log'):
                ftype = 'text'
            elif ext == 'docx':
                ftype = 'docx'
            elif ext == 'doc':
                ftype = 'doc'
            elif ext == 'pdf':
                ftype = 'pdf'
            else:
                ftype = 'binary'

            original = self._read_file_preview(path, ftype)
            masked = self._build_test_version(original, file_name)

            # 產生內嵌檢視資料（優先解決 doc/docx 佈局擠在一起問題：轉 PDF 再轉圖）
            embed_data = self._create_embed_data(path, ftype, file_name)

            results.append({
                "fileName": file_name,
                "type": ftype,
                "originalText": original,
                "maskedText": masked,
                "embedData": embed_data
            })

        self._last_results = results[:]   # 快取
        print("Backend: emit resultsReady count =", len(results))
        self.resultsReady.emit(json.dumps(results, ensure_ascii=False))

    @Slot(result=str)
    def getLastResults(self):
        """ResultPage 補抓"""
        return json.dumps(self._last_results, ensure_ascii=False)

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

    def _create_embed_data(self, path: str, ftype: str, file_name: str):
        try:
            if ftype in ('doc', 'docx'):
                # 嘗試以 Word 轉 PDF（保持版面），再將 PDF 各頁轉為圖像
                pdf_path = self._convert_office_to_pdf(path)
                if pdf_path:
                    pages, meta = self._render_pdf_pages(pdf_path)
                    if pages:
                        return {
                            "viewType": "pdf",
                            "pageImages": pages,
                            "pageCount": len(pages),
                            "metadata": meta,
                            "fileName": file_name
                        }
                    return {"viewType": "error", "error": "PDF 轉圖失敗", "fileName": file_name}
                return {
                    "viewType": "unsupported",
                    "reason": "無法將 Word 轉為 PDF；請安裝 Microsoft Word 與 pywin32",
                    "fileName": file_name
                }

            if ftype == 'pdf':
                pages, meta = self._render_pdf_pages(path)
                if pages:
                    return {
                        "viewType": "pdf",
                        "pageImages": pages,
                        "pageCount": len(pages),
                        "metadata": meta,
                        "fileName": file_name
                    }
                return {"viewType": "error", "error": "PDF 轉圖失敗", "fileName": file_name}

            if ftype == 'text':
                content = self._read_file_preview(path, 'text', 8000)
                return {
                    "viewType": "text",
                    "content": content,
                    "syntaxType": "text",
                    "lineCount": self._estimate_line_count_of_file(path)
                }
        except Exception as e:
            return {"viewType": "error", "error": str(e), "fileName": file_name}
        return {}

    def _render_pdf_pages(self, pdf_path: str):
        if fitz is None:
            return [], {}
        try:
            doc = fitz.open(pdf_path)
            # 圖片輸出資料夾（工作目錄下 tmp_preview）
            out_dir = os.path.join(os.getcwd(), 'tmp_preview')
            os.makedirs(out_dir, exist_ok=True)
            page_paths = []
            meta = {}
            try:
                meta_raw = doc.metadata or {}
                meta = {"title": meta_raw.get("title"), "author": meta_raw.get("author")}
            except Exception:
                meta = {}

            zoom = 2.0  # 提升解析度，減少鋸齒與條紋
            mat = fitz.Matrix(zoom, zoom)
            base = os.path.splitext(os.path.basename(pdf_path))[0]
            for i, page in enumerate(doc):
                pix = page.get_pixmap(matrix=mat, alpha=False)
                img_path = os.path.join(out_dir, f"{base}_page_{i+1}.png")
                pix.save(img_path)
                page_paths.append(img_path)
            doc.close()
            return page_paths, meta
        except Exception:
            return [], {}

    def _convert_office_to_pdf(self, path: str):
        # 僅在 Windows 且安裝 Word + pywin32 時可行
        if sys.platform != 'win32' or win32com is None:
            return None
        word = None
        try:
            word = win32com.client.Dispatch('Word.Application')
            word.Visible = False
            doc = word.Documents.Open(path)
            tmp_dir = os.path.join(os.getcwd(), 'tmp_preview')
            os.makedirs(tmp_dir, exist_ok=True)
            out_pdf = os.path.join(tmp_dir, os.path.splitext(os.path.basename(path))[0] + '.pdf')
            wdFormatPDF = 17
            doc.SaveAs(out_pdf, FileFormat=wdFormatPDF)
            doc.Close(False)
            return out_pdf
        except Exception:
            return None
        finally:
            try:
                if word is not None:
                    word.Quit()
            except Exception:
                pass

    def _estimate_line_count_of_file(self, path: str, max_lines: int = 2000):
        try:
            cnt = 0
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for _ in f:
                    cnt += 1
                    if cnt >= max_lines:
                        break
            return cnt
        except Exception:
            return 0

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