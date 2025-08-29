# file_handlers/text_handler.py
import os
from pii_models.presidio_detector import detect_pii
from faker_models.presidio_replacer_plus import replace_pii
from faker_models.muiltAI_pii_replace import replace_entities, MappingStore, LlamaChatClient


class TextHandler:
    """
    處理純文字格式 (.txt, .csv, .html, .json) in-place 去識別化，
    抽取純文字、替換 PII、再輸出純文字檔。
    """
    # 新增：初始化 LlamaChatClient 和 MappingStore
    def __init__(self):                                   
        self.client = LlamaChatClient()
        self.mapping = MappingStore()

    def deidentify(self, input_path: str, output_path: str, language: str = "auto") -> str:
        # 檢查檔案是否存在
        if not os.path.exists(input_path):
            raise FileNotFoundError(f"找不到輸入檔: {input_path}")

        # 1) 讀取純文字內容
        with open(input_path, "r", encoding="utf-8") as f:
            text = f.read()

        # 2) 偵測 PII
        entities = detect_pii(text, language="en", score_threshold=0.6)
        
        # 3) 使用假資料或遮蔽進行替換
        # cleaned = replace_pii(text, entities)
        cleaned = replace_entities(                   # ★ (新)
                    text,
                    entities,
                    chat_client=self.client,
                    mapping=self.mapping,        # ★ 同一份 mapping，保持一致性
                    # batch_size=30,             # 可調；大量文件時 20~50 都可
                )

        # 4) 寫入輸出檔
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(cleaned)

        return output_path


