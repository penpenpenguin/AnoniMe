import os
import json
from datetime import datetime
import tempfile
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot

try:
    from docx import Document  # for .docx
except ImportError:
    Document = None

# Optional PDF support
try:
    from pypdf import PdfReader  # lightweight PDF text extraction
except Exception:
    PdfReader = None

# Optional PDF rasterizer (image previews)
try:
    import fitz  # PyMuPDF
except Exception:
    fitz = None

# Optional .doc (Word 97-2003) via COM on Windows if MS Word is installed
try:
    import win32com.client  # type: ignore
except Exception:
    win32com = None  # noqa: N816

# 與前端相同的選項定義（測試版本僅用於輸出說明）
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


class TestBackend(QObject):
    """測試後端：接受 QML 上傳的檔案並回傳可顯示的預覽文字。

    介面完全比照 main.py 的 Backend，讓前端可以直接替換測試後端。
    支援 txt/md/log、docx、pdf，.doc 以 Windows COM（若可用）嘗試；否則回覆提示。
    """

    filesChanged = Signal(list)
    resultsReady = Signal(str)  # JSON: [{fileName, type, originalText, maskedText}]

    def __init__(self):
        super().__init__()
        self._files: list[str] = []
        self._options: list[str] = []

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
        print("TestBackend: processFiles() start, files =", len(self._files), "options =", self._options)
        results = []
        for path in self._files:
            file_name = os.path.basename(path)
            ext = file_name.lower().rsplit('.', 1)[-1] if '.' in file_name else ''
            if ext in ('txt', 'md', 'log'):
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

            extra = {}
            # 提供原檔 fileUrl，方便外部開啟
            extra['fileUrl'] = self._to_file_url(path)
            # 影像型 PDF：補回多頁影像預覽
            if ftype == 'pdf':
                text_len = len(original.strip()) if isinstance(original, str) else 0
                # 若是錯誤訊息或文字極少，嘗試渲染圖片預覽
                if text_len < 30 or original.startswith('['):
                    imgs = self._render_pdf_pages(path, max_pages=10, zoom=1.6)
                    if imgs:
                        extra['pageImageUrls'] = imgs

            # 新增內嵌檢視資料
            embed_data = self._create_embed_data(path, ftype)
            
            results.append({
                "fileName": file_name,
                "type": ftype,
                "originalText": original,
                "maskedText": masked,
                "embedData": embed_data,
                **extra,
            })

        print("TestBackend: emit resultsReady count =", len(results))
        self.resultsReady.emit(json.dumps(results, ensure_ascii=False))

    # 讀取 -----------------------------------------------------
    def _read_file_preview(self, path: str, ftype: str, max_chars: int = 4000) -> str:
        try:
            if ftype == 'text':
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    data = f.read(max_chars + 1024)  # 多讀少量以便截斷提示
                return self._truncate(data, max_chars) or "(空白)"

            if ftype == 'docx':
                if Document is None:
                    return "[缺少 python-docx 套件：pip install python-docx]"
                doc = Document(path)
                parts, length = [], 0
                for p in doc.paragraphs:
                    t = (p.text or '').strip()
                    if t:
                        parts.append(t)
                        length += len(t)
                    if length > max_chars:
                        break
                return self._truncate("\n".join(parts), max_chars) or "(空白 DOCX)"

            if ftype == 'doc':
                # 嘗試透過 Word COM（需要 Windows + 已安裝 Word + pywin32）
                if win32com is None:
                    return "[DOC 讀取需要 pywin32 以及安裝 Microsoft Word]"
                try:
                    word = win32com.gencache.EnsureDispatch('Word.Application')  # type: ignore[attr-defined]
                    word.Visible = False
                    doc = word.Documents.Open(path, ReadOnly=True)
                    text = doc.Content.Text if doc and doc.Content else ''
                    doc.Close(False)
                    word.Quit()
                    return self._truncate(text.replace("\r", "\n"), max_chars) or "(空白 DOC)"
                except Exception as e:
                    try:
                        # 盡力關閉殘留的 Word 實例
                        word.Quit()
                    except Exception:
                        pass
                    return f"[DOC 讀取失敗] {e}"

            if ftype == 'pdf':
                if PdfReader is None:
                    return "[缺少 pypdf 套件：pip install pypdf]"
                try:
                    reader = PdfReader(path)
                    parts, length = [], 0
                    for page in reader.pages:
                        try:
                            t = page.extract_text() or ''
                        except Exception:
                            t = ''
                        if t:
                            parts.append(t.strip())
                            length += len(t)
                        if length > max_chars:
                            break
                    return self._truncate("\n".join(parts), max_chars) or ""
                except Exception as e:
                    return f"[PDF 讀取錯誤] {e}"

            # 其他類型
            size = os.path.getsize(path)
            return f"[非文字類型，大小 {size} bytes]"
        except Exception as e:
            return f"[讀取錯誤] {e}"

    def _truncate(self, data: str, max_chars: int) -> str:
        if data is None:
            return ''
        if len(data) > max_chars:
            return data[:max_chars] + "\n...(截斷)"
        return data

    def _to_file_url(self, path: str) -> str:
        try:
            return Path(path).absolute().as_uri()
        except Exception:
            # 後備：手動組 file:///
            p = os.path.abspath(path).replace('\\', '/')
            if not p.startswith('/'):
                p = '/' + p
            return 'file://' + p

    def _render_pdf_pages(self, path: str, max_pages: int = 10, zoom: float = 1.5) -> list:
        """使用 PyMuPDF 產出多頁 PNG，回傳 file:// URL 陣列。無 PyMuPDF 則回空陣列。"""
        if fitz is None:
            return []
        try:
            doc = fitz.open(path)
            out_dir = tempfile.mkdtemp(prefix='AnoniMe_pdf_')
            urls = []
            page_count = min(len(doc), max_pages)
            mat = fitz.Matrix(zoom, zoom)
            for i in range(page_count):
                page = doc.load_page(i)
                pix = page.get_pixmap(matrix=mat, alpha=False)
                img_path = os.path.join(out_dir, f'page_{i+1}.png')
                pix.save(img_path)
                urls.append(Path(img_path).as_uri())
            doc.close()
            return urls
        except Exception:
            return []

    # 建立簡單測試版本（僅前置/後置說明） -----------------------
    def _build_test_version(self, original: str, filename: str) -> str:
        if not original:
            return original
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        header = [
            "[測試版本輸出]",
            f"[檔案: {filename}]",
            f"[時間: {now}]",
            f"[原文字元數: {len(original)}]",
        ]
        if self._options:
            header.append("[已勾選項目] " + ", ".join(OPTION_META[o]['label'] for o in self._options))
            header.append("--- 選項測試行開始 ---")
            for o in self._options:
                meta = OPTION_META[o]
                header.append(f"[TEST-{o.upper()}] {meta['desc']} (未修改正文)")
            header.append("--- 選項測試行結束 ---")
        else:
            header.append("[未勾選任何項目]")

        footer = [
            "",
            "------ TEST SUMMARY ------",
            f"選項數: {len(self._options)}",
            "本測試版本僅在前方加入描述，正文保持原樣。",
            "--------------------------",
        ]
        return "\n".join(header) + "\n\n" + original + "\n\n" + "\n".join(footer)

    def _create_embed_data(self, path: str, ftype: str) -> dict:
        """創建內嵌檔案檢視資料，支援多種檔案類型的內嵌顯示。"""
        try:
            base_data = {
                "type": ftype,
                "fileName": os.path.basename(path),
                "fileSize": os.path.getsize(path),
                "lastModified": datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d %H:%M:%S")
            }

            if ftype == 'text':
                # 文字檔：完整內容 + 語法高亮提示
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                ext = os.path.splitext(path)[1].lower()
                syntax_type = self._detect_syntax_type(ext)
                return {
                    **base_data,
                    "viewType": "text",
                    "content": content,
                    "syntaxType": syntax_type,
                    "lineCount": len(content.splitlines())
                }

            elif ftype == 'pdf':
                # PDF：頁面圖像 + 基本資訊
                if fitz is not None:
                    try:
                        doc = fitz.open(path)
                        page_images = self._render_pdf_pages(path, max_pages=20, zoom=1.8)
                        metadata = doc.metadata
                        doc.close()
                        return {
                            **base_data,
                            "viewType": "pdf",
                            "pageCount": len(page_images),
                            "pageImages": page_images,
                            "metadata": {
                                "title": metadata.get('title', ''),
                                "author": metadata.get('author', ''),
                                "subject": metadata.get('subject', ''),
                                "creator": metadata.get('creator', '')
                            }
                        }
                    except Exception:
                        pass
                return {**base_data, "viewType": "unsupported", "reason": "需要安裝 PyMuPDF"}

            elif ftype == 'docx':
                # DOCX：結構化內容 + 樣式資訊
                if Document is not None:
                    try:
                        doc = Document(path)
                        paragraphs = []
                        tables = []
                        
                        for para in doc.paragraphs:
                            if para.text.strip():
                                paragraphs.append({
                                    "text": para.text,
                                    "style": para.style.name if para.style else "Normal",
                                    "alignment": str(para.alignment) if para.alignment else "LEFT"
                                })
                        
                        for table in doc.tables:
                            table_data = []
                            for row in table.rows:
                                row_data = [cell.text.strip() for cell in row.cells]
                                table_data.append(row_data)
                            if table_data:
                                tables.append(table_data)
                        
                        return {
                            **base_data,
                            "viewType": "docx",
                            "paragraphs": paragraphs,
                            "tables": tables,
                            "paraCount": len(paragraphs),
                            "tableCount": len(tables)
                        }
                    except Exception:
                        pass
                return {**base_data, "viewType": "unsupported", "reason": "需要安裝 python-docx"}

            elif ftype == 'doc':
                # DOC：透過 COM 讀取（若可用）
                if win32com is not None:
                    try:
                        word = win32com.gencache.EnsureDispatch('Word.Application')
                        word.Visible = False
                        doc = word.Documents.Open(path, ReadOnly=True)
                        content = doc.Content.Text if doc and doc.Content else ''
                        page_count = doc.Range().Information(win32com.constants.wdNumberOfPagesInDocument) if doc else 0
                        doc.Close(False)
                        word.Quit()
                        
                        return {
                            **base_data,
                            "viewType": "doc",
                            "content": content.replace("\r", "\n"),
                            "pageCount": page_count,
                            "wordCount": len(content.split()) if content else 0
                        }
                    except Exception:
                        pass
                return {**base_data, "viewType": "unsupported", "reason": "需要 Windows + MS Word + pywin32"}

            else:
                # 二進位檔案：十六進制檢視器
                return self._create_hex_view(path, base_data)

        except Exception as e:
            return {
                "type": ftype,
                "viewType": "error",
                "error": str(e),
                "fileName": os.path.basename(path)
            }

    def _detect_syntax_type(self, ext: str) -> str:
        """根據副檔名偵測語法類型，用於語法高亮提示。"""
        syntax_map = {
            '.py': 'python',
            '.js': 'javascript', 
            '.ts': 'typescript',
            '.html': 'html',
            '.css': 'css',
            '.json': 'json',
            '.xml': 'xml',
            '.yml': 'yaml',
            '.yaml': 'yaml',
            '.md': 'markdown',
            '.sql': 'sql',
            '.sh': 'bash',
            '.bat': 'batch',
            '.ps1': 'powershell',
            '.cpp': 'cpp',
            '.c': 'c',
            '.h': 'c',
            '.java': 'java',
            '.cs': 'csharp',
            '.php': 'php',
            '.rb': 'ruby',
            '.go': 'go',
            '.rs': 'rust'
        }
        return syntax_map.get(ext, 'text')

    def _create_hex_view(self, path: str, base_data: dict, max_bytes: int = 1024) -> dict:
        """為二進位檔案創建十六進制檢視。"""
        try:
            with open(path, 'rb') as f:
                data = f.read(max_bytes)
            
            hex_lines = []
            for i in range(0, len(data), 16):
                chunk = data[i:i+16]
                hex_part = ' '.join(f'{b:02X}' for b in chunk)
                ascii_part = ''.join(chr(b) if 32 <= b <= 126 else '.' for b in chunk)
                hex_lines.append({
                    "offset": f"{i:08X}",
                    "hex": hex_part,
                    "ascii": ascii_part
                })
            
            return {
                **base_data,
                "viewType": "hex",
                "hexLines": hex_lines,
                "totalBytes": len(data),
                "isPartial": len(data) >= max_bytes
            }
        except Exception:
            return {**base_data, "viewType": "error", "error": "無法讀取檔案"}
