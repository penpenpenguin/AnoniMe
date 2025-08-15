# run_txt_test.py
from file_handlers.txt_handler import TextHandler

def run_text_file(path) :   # 測試示例
    input_path = path
    output_path = "test_output/sample_deid.txt"
    handler = TextHandler()
    handler.deidentify(input_path=input_path, output_path=output_path)
    return output_path
