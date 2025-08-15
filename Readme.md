## Chinese

### 專案概述
AnoniMe 是一款桌面文件去識別化應用程式，能自動檢測並替換文件中的個人識別資訊（PII）。採用 PySide6 和 QML 建構，提供友善的使用者介面來處理 TXT、DOCX 和 PDF 檔案，同時保持文件結構和格式。

### 主要功能
- **多格式支援**：處理 TXT、DOCX 和 PDF 檔案
- **進階 PII 檢測**：基於 Microsoft Presidio 並結合台灣特有識別器
- **智慧替換**：使用 Faker 函式庫進行上下文感知的假資料生成
- **文件預覽**：內建處理後文件的預覽功能
- **多語言支援**：支援中英文語言處理

### 架構說明

```
AnoniMe/
├── main.py                    # 主程式進入點
├── Main.qml                   # QML 使用者介面主視窗
├── HomePage.qml               # 首頁介面
├── UploadPage.qml            # 檔案上傳介面
├── ResultPage.qml            # 結果顯示介面
├── EmbedViewer.qml           # 文件預覽元件
├── test_backend.py           # 增強版後端含預覽功能
├── pii_models/               # PII 檢測模組
│   ├── presidio_detector.py  # 核心 PII 檢測引擎
│   ├── custom_recognizer_plus.py # 台灣特有識別器
│   └── detector.py           # 檢測工具
├── faker_models/             # 資料替換模組
│   ├── presidio_replacer.py  # 主要替換引擎
│   └── tony_faker.py         # 自訂假資料產生器
└── file_handlers/            # 檔案處理模組
    ├── txt_handler.py        # 文字檔處理器
    ├── docx_handler.py       # Word 文件處理器
    └── pdf_handler.py      # PDF 處理器
  
```

### 核心技術

#### PII 檢測管線
```python
# presidio_detector.py - 多語言 PII 檢測
from presidio_analyzer import AnalyzerEngine, RecognizerRegistry
from presidio_analyzer.nlp_engine import NlpEngineProvider

nlp_config = {
    "nlp_engine_name": "spacy",
    "models": [
        {"lang_code": "en", "model_name": "en_core_web_sm"},
        {"lang_code": "zh", "model_name": "zh_core_web_sm"},
    ],
}

provider = NlpEngineProvider(nlp_configuration=nlp_config)
nlp_engine = provider.create_engine()
analyzer = AnalyzerEngine(nlp_engine=nlp_engine, supported_languages=["en", "zh"])
```

#### 台灣自訂識別器
```python
# custom_recognizer_plus.py - 台灣特有實體識別
def validate_tw_ubn(ubn: str) -> bool:
    """台灣統一編號檢驗器"""
    if not re.fullmatch(r"\d{8}", ubn):
        return False
    coef = [1,2,1,2,1,2,4,1]
    s = 0
    for i, c in enumerate(ubn):
        p = int(c) * coef[i]
        s += (p // 10) + (p % 10)
    return s % 10 == 0 or (s + 1) % 10 == 0

# 支援的台灣實體：
# - 身分證字號
# - 統一編號（公司行號）
# - 台灣電話號碼
# - 網路卡位址
```

#### 智慧資料替換
```python
# presidio_replacer.py - 上下文感知假資料生成
from presidio_anonymizer import AnonymizerEngine
from faker import Faker

def replace_pii(text, analyzer_results):
    """將檢測到的 PII 替換為符合上下文的假資料"""
    anonymizer = AnonymizerEngine()
    
    # 台灣特有實體的自訂操作器
    operators = {
        "TW_ID": OperatorConfig("custom", {"lambda": fake_tw_id}),
        "TW_UBN": OperatorConfig("custom", {"lambda": fake_ubn}),
        "PHONE_NUMBER": OperatorConfig("custom", {"lambda": fake_phone}),
    }
    
    return anonymizer.anonymize(
        text=text,
        analyzer_results=analyzer_results,
        operators=operators
    )
```

### API 契約

#### 輸入 JSON 結構
```json
{
  "file_path": "檔案路徑字串",
  "language": "en|zh|auto",
  "options": {
    "name": true,
    "email": true,
    "phone": true,
    "id_number": true,
    "address": true
  }
}
```

#### 輸出 JSON 結構
```json
{
  "status": "success|error",
  "original_file": "原始檔案路徑",
  "processed_file": "處理後檔案路徑",
  "preview_file": "預覽檔案路徑",
  "entities_found": [
    {
      "entity_type": "實體類型",
      "text": "匹配文字",
      "start": "起始位置",
      "end": "結束位置",
      "confidence": "信心分數"
    }
  ],
  "processing_time": "處理時間（秒）",
  "error_message": "錯誤訊息"
}
```

### 安裝與使用

#### 環境需求
```bash
pip install PySide6 presidio-analyzer presidio-anonymizer spacy faker PyMuPDF python-docx
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
```

#### 執行應用程式
```bash
# 增強模式含預覽功能
python run_with_test_backend.py
```

#### 最小測試腳本
```bash
python scripts/minimal_text_demo.py
```

### 測試
```bash
# 執行完整測試
python simple_test.py

# 測試特定檔案處理器
python test_file_routing.py

# 後端功能測試
python test_backend.py
```

---

## Dependencies | 相依套件

- **PySide6**: Desktop application framework | 桌面應用程式框架
- **Microsoft Presidio**: PII detection and anonymization | PII 檢測與匿名化
- **spaCy**: Natural language processing | 自然語言處理
- **Faker**: Fake data generation | 假資料生成
- **PyMuPDF**: PDF processing | PDF 處理
- **python-docx**: Word document processing | Word 文件處理

## License | 授權
This project is licensed under the MIT License | 本專案採用 MIT 授權條款
  - `start: int`, `end: int` — 原文中的字元起迄位置
  - `score: float` — 信心分數
  - `raw_txt: str` — 原始片段

- 傳回給 QML 的後端結果（`resultsReady` 中每個元素）：
  - `fileName: str` — 輸出檔名
  - `type: "text" | "docx" | "pdf" | "binary"`
  - `originalText: str` —（可選）原文預覽
  - `maskedText: str` —（可選）替換後文字預覽
  - `embedData: object` — 供 `EmbedViewer.qml` 使用的預覽資料，例如：
    - 文字：`{ viewType: "text", content: str, syntaxType: str, lineCount: int }`
    - PDF：`{ viewType: "pdf", pageImages: string[], pageCount: int, metadata?: object }`
  - `outputPath?: str` — 去識別化後檔案的絕對路徑

- 文字處理器 API：
  - `TextHandler.deidentify(input_path: str, output_path: str, language: str = "auto") -> str`
  - 回傳實際寫入完成的 `output_path`。

快速示範（中文）：

```powershell
python scripts/minimal_text_demo.py --mode detect-replace
python scripts/minimal_text_demo.py --mode file
```
- UI：PySide6 + QML（`Main.qml`/`HomePage.qml`/`UploadPage.qml`/`ResultPage.qml`）
- 後端：`main.py`（正式流程）與 `test_backend.py`（預覽強化版）
- PII 偵測：Microsoft Presidio（spacy 多語）+ 自訂辨識器
- 假資料替換：Presidio Anonymizer + Faker；PDF 另含一組 Faker 替換管線

## 目錄總覽

```
.
├─ main.py                         # 正式 Backend（檔案路由、預覽資料、轉檔）
├─ run_with_test_backend.py        # 啟動 QML + 測試後端
├─ test_backend.py                 # 測試 Backend：統一產生 PDF 預覽與頁圖回傳
├─ Main.qml / HomePage.qml / UploadPage.qml / ResultPage.qml / EmbedViewer.qml / MaskCheckBox.qml
├─ file_handlers/                  # 各格式處理器
│  ├─ txt_handler.py               # 純文字偵測→替換→輸出
│  ├─ docx_handler.py              # 遍歷 runs、表格 cells 偵測→替換→輸出 DOCX
│  └─ pdf_handler.py               #（變體）使用 faker mapping 替換
│
├─ pii_models/                     # PII 偵測
│  ├─ presidio_detector.py         # Presidio AnalyzerEngine（spacy 多語）+ detect_pii()
│  ├─ custom_recognizer_plus.py    # 台灣常見：身分證/統編/手機/市話/MAC/健保卡…（regex + context + 校驗）
│  ├─ custom_recognizer.py         # 精簡自訂識別器版本
│  └─ detector.py                  # spacy + regex 的另一條路（未進主流程）
│
├─ faker_models/                   # 假資料替換
│  ├─ presidio_replacer.py         # Presidio Anonymizer + Faker（以 entity type 決定替換策略）
│  └─ tony_faker.py                # 依偵測結果產生對應假值、取最高分、映射替換
│
└─ test_output/                    # 處理結果與預覽
  ├─ *_deid.(txt|docx|pdf)
  └─ _previews/ ...
```

## 安裝與執行（Windows, PowerShell）

> 需求重點：Python 3.10+、pip；建議安裝 `en_core_web_sm` 與 `zh_core_web_sm` spacy 模型。PDF 預覽使用 PyMuPDF，不需額外字型。

1) 建立環境與安裝套件

```powershell
python -m venv .venv

2) 正式後端（若你的環境有 Word 或 LibreOffice，可用較貼近正式流程的轉檔）

```powershell
python run_with_test_backend.py
- DOCX→PDF 預覽策略：
  - Windows + Word（pywin32 COM）優先；
  - 失敗則嘗試 LibreOffice（將 `soffice.exe` 加入 PATH 或以環境變數 `SOFFICE_PATH` 指定）。
- PDF handler 中若有硬編碼字型路徑（macOS 範例），請改為系統可用字型或使用標準字型名（如 `helv`）。

## 使用流程與 UI

- 在 `UploadPage` 拖放或選取檔案，勾選要處理的項目（姓名/Email/電話/ID…），按「生成結果」。
- 後端把檔案路由到 `file_handlers/*_handler.py`，偵測→替換→輸出到 `test_output/`。
- 前端顯示處理後檔案的 PDF 頁圖或文字預覽（`EmbedViewer.qml`）。

## PII 偵測與假資料替換（核心設計）

本專案對文字、DOCX、PDF 都使用「先偵測 span，再替換」的策略：

- 偵測：`pii_models/presidio_detector.py` 建立 Presidio `AnalyzerEngine`，載入 `en_core_web_sm` / `zh_core_web_sm`，並呼叫 `custom_recognizer_plus.register_custom_entities()` 註冊台灣常見 PII 識別規則（含校驗與語境強化）。
- 替換：
  - 文字/DOCX：`faker_models/presidio_replacer.py` 以 Presidio Anonymizer + Faker，依 `entity_type` 提供合理假值或遮蔽。
  - PDF：`file_handlers/pdf_handler_1.py` 會先以 `tony_faker.py` 針對偵測結果產生假值 mapping，再依 span 定位替換文字，保持原座標與字級。

### Detect：`pii_models/presidio_detector.py`

```python
# 建立 spacy 多語引擎 + Presidio Analyzer
nlp_config = {
  "nlp_engine_name": "spacy",
  "models": [
    {"lang_code": "en", "model_name": "en_core_web_sm"},
    {"lang_code": "zh", "model_name": "zh_core_web_sm"},
  ],
}
provider = NlpEngineProvider(nlp_configuration=nlp_config)
nlp_engine = provider.create_engine()

analyzer = AnalyzerEngine(
  nlp_engine=nlp_engine,
  supported_languages=["en", "zh"]
)

# 註冊自訂實體（台灣身分證、統編、手機/市話、MAC、健保卡…）
register_custom_entities(analyzer)

def detect_pii(text: str, language: str = "auto", score_threshold: float = 0.5):
  results = analyzer.analyze(text=text, entities=None, language=language)
  # 整理為統一 dict 格式（含 raw_txt）
  filtered = []
  for r in results:
    if r.score >= score_threshold:
      filtered.append({
                "entity_type": r.entity_type,
                "start": r.start,
                "end": r.end,
        "score": r.score,
        "raw_txt": text[r.start:r.end]
      })
  return filtered
```

重點：
- `register_custom_entities` 加強台灣特有實體（例如統編含校驗、手機支援 +886 多種格式、MAC 正規化與低質特例降分）。
- 回傳為統一 dict，後續替換端可以不依賴 Presidio 的物件型別。

### Custom Recognizers：`pii_models/custom_recognizer_plus.py`

```python
# 以 PatternRecognizer + context/validator 強化：
# - UNIFIED_BUSINESS_NO：校驗合法統編後拉高信心，否則壓低
# - TW_PHONE_NUMBER：支援國際/本地多種格式（+886, 09xx-xxx-xxx, ...）
# - TW_HOME_NUMBER：市話（含括號/破折/國碼）
# - MAC_ADDRESS：支援冒號、破折、Cisco dotted；00..00 等例外降分
# - TW_NHI_NUMBER：健保卡（以 context 避免誤擊）

for lang in ("zh", "en"):
  analyzer.registry.add_recognizer(tw_id_recognizer)
  analyzer.registry.add_recognizer(tw_ubn_recognizer)
  analyzer.registry.add_recognizer(tw_phone_recognizer)
  analyzer.registry.add_recognizer(tw_home_recognizer)
  analyzer.registry.add_recognizer(mac_recognizer)
  analyzer.registry.add_recognizer(tw_nhi_recognizer)
```

重點：
- 以 context（關鍵字上下文）降低一般數字串誤判。
- UBN 透過 checksum 驗證控制分數，提升精確度。

### Replace（文字/DOCX）：`faker_models/presidio_replacer.py`

```python
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import OperatorConfig
from presidio_analyzer import RecognizerResult
from faker import Faker

anonymizer = AnonymizerEngine()
fake = Faker()

def replace_pii(text: str, analyzer_results: list[dict]) -> str:
  # 將偵測結果（dict）轉 Presidio RecognizerResult
  recognizer_results = [
    RecognizerResult(
      entity_type=r["entity_type"], start=r["start"], end=r["end"], score=r["score"]
    ) for r in analyzer_results
  ]

  # 依 entity 決定替換策略（示意）
  operators = {
    "EMAIL_ADDRESS": OperatorConfig("replace", {"new_value": "user@example.com"}),
    "PHONE_NUMBER": OperatorConfig("replace", {"new_value": fake.phone_number()}),
    "PERSON":       OperatorConfig("replace", {"new_value": fake.name()}),
    "LOCATION":     OperatorConfig("replace", {"new_value": fake.address()}),
    "IP_ADDRESS":   OperatorConfig("replace", {"new_value": fake.ipv4()}),
    "CREDIT_CARD":  OperatorConfig("replace", {"new_value": fake.credit_card_number()}),
    # 台灣常見：
    "TW_ID_NUMBER":         OperatorConfig("replace", {"new_value": _fake_tw_id()}),
    "UNIFIED_BUSINESS_NO":  OperatorConfig("replace", {"new_value": _fake_ubn()}),
    "TW_PHONE_NUMBER":      OperatorConfig("replace", {"new_value": _fake_tw_mobile()}),
    # 其他未知型別：保留原文或以『★』遮蔽
  }

  return anonymizer.anonymize(
    text=text, analyzer_results=recognizer_results, operators=operators
  ).text
```

重點：
- 使用 Presidio Anonymizer 的 OperatorConfig，以「替換」為主，也可改 mask。
- 對地區特有（TW）提供專屬產生器，以保持格式合理性。

### Replace（PDF）：`file_handlers/pdf_handler_1.py`

```python
# 逐頁逐 span：先 detect，再用 faker 生成對應 fake_map，依原起訖位置替換文字，
# 並維持原有 bbox / 字級，最後以 PyMuPDF 重建新 PDF。
entities = detect_pii(text, language="en", score_threshold=0.6)
faker_results = test_all_methods(entities)
best_results = keep_highest_score_per_raw_txt(faker_results)
fake_map = {item["raw_txt"]: item["fake_value"] for item in best_results}

masked_text = text
offset = 0
for ent in entities:
  start, end = ent["start"] + offset, ent["end"] + offset
  raw_txt = ent["raw_txt"]
  fake_value = fake_map.get(raw_txt, "*" * (end - start))
  fake_value = fake_value[:len(raw_txt)].ljust(len(raw_txt))
  masked_text = masked_text[:start] + fake_value + masked_text[end:]
  offset += len(fake_value) - (end - start)
```

重點：
- 以 `offset` 處理替換後長度差，避免後續 span 位置錯位。
- 具體替換策略可插拔：可改為全遮蔽或按類型產值得更精細。

## 後端路由與輸出

`main.Backend._process_file_with_deidentification()` 依副檔名路由：

- text → `TextHandler.deidentify()` → `*_deid.txt`
- docx → `DocxHandler.deidentify()` → `*_deid.docx`
- pdf → `PdfHandler.deidentify()` → `*_deid.pdf`

預覽：
- PDF 直接轉頁圖（PyMuPDF）。
- DOC/DOCX 嘗試轉 PDF 再轉頁圖；若無 Word/LibreOffice，改為 unsupported 訊息。
- TXT 直接提供內容預覽（行號/語法色底）。

## 常見問題（FAQ）
- 如有特殊字型，偵測結果可能失真。
- spacy 模型下載錯誤？請確認網路或改用離線安裝，確保 `en_core_web_sm`、`zh_core_web_sm` 可用。
- PDF handler 出現字型路徑錯誤？將硬編碼字型改為本機可用檔案，或簡化為標準字型名 `helv`/`times`。
- DOCX→PDF 轉檔失敗？
  - Windows + Word（pywin32）較穩定；
  - 無 Word 時請安裝 LibreOffice，並將 `soffice.exe` 加入 PATH 或以 `SOFFICE_PATH` 指定。

## 授權

此專案包含第三方套件（Presidio、spaCy、PyMuPDF、Faker 等），其授權條款請依原專案為準。
