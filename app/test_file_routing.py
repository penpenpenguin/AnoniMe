#!/usr/bin/env python3
# 批次測試 Backend 檔案路由與去識別化：讀取 test_input，輸出至 test_output

import os
import sys
from pathlib import Path

from file_handlers.docx_handler import DocxHandler
from file_handlers.pdf_handler import PdfHandler

# 將當前目錄加入 Python 路徑
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

INPUT_DIR = os.path.join(current_dir, "test_input")
OUTPUT_DIR = os.path.join(current_dir, "test_output")

def _detect_ftype(path: str) -> str:
    ext = Path(path).suffix.lower()
    if ext in (".txt", ".md", ".log", ".csv", ".json", ".py"):
        return "text"
    if ext == ".docx":
        return "docx"
    if ext == ".pdf":
        return "pdf"
    return "binary"

def main():
    # 檢查輸入資料夾
    if not os.path.isdir(INPUT_DIR):
        print(f"❌ 找不到輸入資料夾：{INPUT_DIR}")
        os.makedirs(INPUT_DIR, exist_ok=True)
        print("已建立輸入資料夾，請將要處理的檔案放入後再執行。")
        return

    files = [os.path.join(INPUT_DIR, n)
             for n in os.listdir(INPUT_DIR)
             if os.path.isfile(os.path.join(INPUT_DIR, n))]
    if not files:
        print(f"❌ 輸入資料夾為空：{INPUT_DIR}")
        print("請放入要處理的檔案後再執行。")
        return

    # 準備輸出資料夾
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 匯入並建立 Backend
    from app.main import Backend
    backend = Backend()
    backend._files = files
    backend._options = ["name", "email", "phone", "id", "address"]  # 依需求調整

    print("=== 測試檔案路由功能 ===")
    print(f"輸入資料夾: {INPUT_DIR}")
    print(f"輸出資料夾: {OUTPUT_DIR}")
    print(f"待處理檔案數：{len(files)}")

    for file_path in files:
        file_name = os.path.basename(file_path)
        ftype = _detect_ftype(file_path)
        print(f"\n檔案: {file_name}, 類型: {ftype}")

        try:
            result_path, content_preview = backend._process_file_with_deidentification(
                file_path, ftype, OUTPUT_DIR
            )
            print(f"處理結果輸出檔: {result_path}")
            print(f"內容預覽（前 120 字）: {(content_preview or '')[:120].replace(chr(10),' ')}")
            print("✅ 處理成功")
        except Exception as e:
            print(f"❌ 處理失敗: {e}")

    print("\n=== 測試完成 ===")
    print("請至 test_output 查看輸出檔。")

if __name__ == "__main__":
    main()
