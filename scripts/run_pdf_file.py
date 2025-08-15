from file_handlers.pdf_handler_1 import PdfHandler


def run_pdf_file(path):

    # 測試用 PDF input 路徑
    input_path = path
    # 測試 output 路徑
    output_path = "test_output/sample_test_deid.pdf"
    
    detector = PdfHandler()
    
    # 執行去識別化
    detector.deidentify(input_path=input_path, output_path=output_path)
    
    # pii_list = detector.extract_pii(input_path=input_path, output_path=output_path)
    # 以易讀格式輸出
    # for item in pii_list:
    #     print(f"Page {item['page']}: {item['entity_type']} ({item['start']}-{item['end']}) -> {item['text']}")

    # 若需存檔，可取消以下註解
    # with open("test_output/sample_test_pii.json", "w", encoding="utf-8") as f:
    #     json.dump(pii_list, f, ensure_ascii=False, indent=2)
    # print("\n✅ PII 偵測完成！共偵測到", len(pii_list), "個實體。")
    return output_path
