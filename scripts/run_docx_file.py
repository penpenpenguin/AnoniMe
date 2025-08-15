from file_handlers.docx_handler import DocxHandler
import os


def run_docx_file(path):
    # 1) 指定要處理的 Word 檔案
    input_path = path
    # 2) 指定輸出路徑
    output_path = "test_output/pii_test_deid.docx"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # 3) 建立 handler 並執行去識別化
    handler = DocxHandler()
    result_path = handler.deidentify(input_path=input_path, output_path=output_path)

    return result_path