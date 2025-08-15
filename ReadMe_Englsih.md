# AnoniMe - Personal Information Anonymization Tool

## Project Overview
AnoniMe is a desktop document de-identification application that automatically detects and replaces Personal Identifiable Information (PII) in documents. Built with PySide6 and QML, it provides a user-friendly interface for processing TXT, DOCX, and PDF files while maintaining document structure and formatting.

## Key Features
- **Multi-format Support**: Process TXT, DOCX, and PDF files
- **Advanced PII Detection**: Powered by Microsoft Presidio with custom Taiwan-specific recognizers
- **Intelligent Replacement**: Context-aware fake data generation using Faker library
- **Document Preview**: Built-in preview functionality for processed documents
- **Multilingual Support**: English and Chinese language processing

## Architecture

```
AnoniMe/
├── main.py                    # Main application entry point
├── Main.qml                   # QML UI main window
├── HomePage.qml               # Home page interface
├── UploadPage.qml            # File upload interface
├── ResultPage.qml            # Results display interface
├── EmbedViewer.qml           # Document preview component
├── test_backend.py           # Enhanced backend with preview functionality
├── pii_models/               # PII detection modules
│   ├── presidio_detector.py  # Core PII detection engine
│   ├── custom_recognizer_plus.py # Taiwan-specific recognizers
│   └── detector.py           # Detection utilities
├── faker_models/             # Data replacement modules
│   ├── presidio_replacer.py  # Main replacement engine
│   └── tony_faker.py         # Custom fake data generators
└── file_handlers/            # File processing modules
    ├── txt_handler.py        # Text file handler
    ├── docx_handler.py       # Word document handler
    └── pdf_handler.py        # PDF processor
```

## Core Technologies

### PII Detection Pipeline
```python
# presidio_detector.py - Multilingual PII detection
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

### Taiwan Custom Recognizers
```python
# custom_recognizer_plus.py - Taiwan-specific entity recognition
def validate_tw_ubn(ubn: str) -> bool:
    """Taiwan UBN (Business Registration Number) validator"""
    if not re.fullmatch(r"\d{8}", ubn):
        return False
    coef = [1,2,1,2,1,2,4,1]
    s = 0
    for i, c in enumerate(ubn):
        p = int(c) * coef[i]
        s += (p // 10) + (p % 10)
    return s % 10 == 0 or (s + 1) % 10 == 0

# Supported Taiwan entities:
# - Taiwan ID Numbers
# - Business Registration Numbers
# - Taiwan Phone Numbers
# - MAC Addresses
```

### Intelligent Data Replacement
```python
# presidio_replacer.py - Context-aware fake data generation
from presidio_anonymizer import AnonymizerEngine
from faker import Faker

def replace_pii(text, analyzer_results):
    """Replace detected PII with contextually appropriate fake data"""
    anonymizer = AnonymizerEngine()
    
    # Custom operators for Taiwan-specific entities
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

## API Contract

### Input JSON Structure
```json
{
  "file_path": "string",
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

### Output JSON Structure
```json
{
  "status": "success|error",
  "original_file": "string",
  "processed_file": "string",
  "preview_file": "string",
  "entities_found": [
    {
      "entity_type": "string",
      "text": "string",
      "start": "number",
      "end": "number",
      "confidence": "number"
    }
  ],
  "processing_time": "number",
  "error_message": "string"
}
```

## Installation & Usage

### Prerequisites
```bash
pip install PySide6 presidio-analyzer presidio-anonymizer spacy faker PyMuPDF python-docx
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
```

### Running the Application
```bash
# Enhanced mode with preview functionality
python run_with_test_backend.py
```

### Minimal Test Script
```bash
python scripts/minimal_text_demo.py
```

## Testing
```bash
# Run comprehensive tests
python simple_test.py

# Test specific file handlers
python test_file_routing.py

# Backend functionality test
python test_backend.py
```

## Dependencies

- **PySide6**: Desktop application framework
- **Microsoft Presidio**: PII detection and anonymization
- **spaCy**: Natural language processing
- **Faker**: Fake data generation
- **PyMuPDF**: PDF processing
- **python-docx**: Word document processing

## Backend API Details

### Detection Result Format
- `entity_type: str` — e.g., `PERSON`, `EMAIL_ADDRESS`, `TW_ID_NUMBER`
- `start: int`, `end: int` — Character positions in original text
- `score: float` — Confidence score
- `raw_txt: str` — Original text segment

### Backend Response Format (QML Integration)
- `fileName: str` — Output filename
- `type: "text" | "docx" | "pdf" | "binary"`
- `originalText: str` — (Optional) Original text preview
- `maskedText: str` — (Optional) Replaced text preview
- `embedData: object` — Preview data for `EmbedViewer.qml`:
  - Text: `{ viewType: "text", content: str, syntaxType: str, lineCount: int }`
  - PDF: `{ viewType: "pdf", pageImages: string[], pageCount: int, metadata?: object }`
- `outputPath?: str` — Absolute path to de-identified file

### Text Handler API
- `TextHandler.deidentify(input_path: str, output_path: str, language: str = "auto") -> str`
- Returns the actual written `output_path`

## Quick Demo

```powershell
python scripts/minimal_text_demo.py --mode detect-replace
python scripts/minimal_text_demo.py --mode file
```

## System Architecture
- **UI**: PySide6 + QML (`Main.qml`/`HomePage.qml`/`UploadPage.qml`/`ResultPage.qml`)
- **Backend**: `main.py` (production flow) and `test_backend.py` (preview-enhanced version)
- **PII Detection**: Microsoft Presidio (spaCy multilingual) + custom recognizers
- **Fake Data Replacement**: Presidio Anonymizer + Faker; PDF includes separate Faker replacement pipeline

## Directory Overview

```
.
├─ main.py                         # Production Backend (file routing, preview data, conversion)
├─ run_with_test_backend.py        # Launch QML + test backend
├─ test_backend.py                 # Test Backend: unified PDF preview & page image generation
├─ Main.qml / HomePage.qml / UploadPage.qml / ResultPage.qml / EmbedViewer.qml / MaskCheckBox.qml
├─ file_handlers/                  # Format-specific processors
│  ├─ txt_handler.py               # Plain text detection→replacement→output
│  ├─ docx_handler.py              # Process runs, table cells detection→replacement→output DOCX
│  └─ pdf_handler.py               # (Variant) uses faker mapping replacement
│
├─ pii_models/                     # PII Detection
│  ├─ presidio_detector.py         # Presidio AnalyzerEngine (spaCy multilingual) + detect_pii()
│  ├─ custom_recognizer_plus.py    # Taiwan common: ID/UBN/mobile/landline/MAC/health card... (regex + context + validation)
│  ├─ custom_recognizer.py         # Simplified custom recognizer version
│  └─ detector.py                  # spaCy + regex alternative path (not in main flow)
│
├─ faker_models/                   # Fake Data Replacement
│  ├─ presidio_replacer.py         # Presidio Anonymizer + Faker (replacement strategy by entity type)
│  └─ tony_faker.py                # Generate corresponding fake values by detection results, take highest score, mapping replacement
│
└─ test_output/                    # Processing results and previews
  ├─ *_deid.(txt|docx|pdf)
  └─ _previews/ ...
```

## Installation & Execution (Windows, PowerShell)

> Requirements: Python 3.10+, pip; recommended to install `en_core_web_sm` and `zh_core_web_sm` spaCy models. PDF preview uses PyMuPDF, no additional fonts needed.

1) Create environment and install packages

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
```

2) Production backend (if your environment has Word or LibreOffice, can use closer-to-production conversion flow)

```powershell
python run_with_test_backend.py
```

- DOCX→PDF preview strategy:
  - Windows + Word (pywin32 COM) priority;
  - If failed, try LibreOffice (add `soffice.exe` to PATH or specify with `SOFFICE_PATH` environment variable).
- If PDF handler has hardcoded font paths (macOS examples), please change to system-available fonts or use standard font names (like `helv`).

## Usage Flow & UI

- In `UploadPage`, drag and drop or select files, check items to process (name/email/phone/ID...), click "Generate Results".
- Backend routes files to `file_handlers/*_handler.py`, detect→replace→output to `test_output/`.
- Frontend displays PDF page images or text preview of processed files (`EmbedViewer.qml`).

## PII Detection & Fake Data Replacement (Core Design)

This project uses a "detect spans first, then replace" strategy for text, DOCX, and PDF:

- **Detection**: `pii_models/presidio_detector.py` creates Presidio `AnalyzerEngine`, loads `en_core_web_sm` / `zh_core_web_sm`, and calls `custom_recognizer_plus.register_custom_entities()` to register Taiwan common PII identification rules (including validation and context enhancement).
- **Replacement**:
  - Text/DOCX: `faker_models/presidio_replacer.py` uses Presidio Anonymizer + Faker, providing reasonable fake values or masking by `entity_type`.
  - PDF: `file_handlers/pdf_handler_1.py` first uses `tony_faker.py` to generate fake value mapping for detection results, then replaces text by span positioning, maintaining original coordinates and font size.

### Detect: `pii_models/presidio_detector.py`

```python
# Create spaCy multilingual engine + Presidio Analyzer
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

# Register custom entities (Taiwan ID, UBN, mobile/landline, MAC, health card...)
register_custom_entities(analyzer)

def detect_pii(text: str, language: str = "auto", score_threshold: float = 0.5):
  results = analyzer.analyze(text=text, entities=None, language=language)
  # Organize into unified dict format (including raw_txt)
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

Key points:
- `register_custom_entities` enhances Taiwan-specific entities (e.g., UBN with validation, mobile supporting +886 multiple formats, MAC normalization and low-quality exception downgrading).
- Returns unified dict, so replacement side doesn't depend on Presidio object types.

### Custom Recognizers: `pii_models/custom_recognizer_plus.py`

```python
# Enhanced with PatternRecognizer + context/validator:
# - UNIFIED_BUSINESS_NO: Increase confidence after validating legal UBN, otherwise decrease
# - TW_PHONE_NUMBER: Support international/local multiple formats (+886, 09xx-xxx-xxx, ...)
# - TW_HOME_NUMBER: Landline (including parentheses/dashes/country code)
# - MAC_ADDRESS: Support colon, dash, Cisco dotted; 00..00 etc. exceptions downgrade
# - TW_NHI_NUMBER: Health card (avoid false hits with context)

for lang in ("zh", "en"):
  analyzer.registry.add_recognizer(tw_id_recognizer)
  analyzer.registry.add_recognizer(tw_ubn_recognizer)
  analyzer.registry.add_recognizer(tw_phone_recognizer)
  analyzer.registry.add_recognizer(tw_home_recognizer)
  analyzer.registry.add_recognizer(mac_recognizer)
  analyzer.registry.add_recognizer(tw_nhi_recognizer)
```

Key points:
- Use context (keyword context) to reduce false positives of general number strings.
- UBN controls score through checksum verification, improving accuracy.

### Replace (Text/DOCX): `faker_models/presidio_replacer.py`

```python
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import OperatorConfig
from presidio_analyzer import RecognizerResult
from faker import Faker

anonymizer = AnonymizerEngine()
fake = Faker()

def replace_pii(text: str, analyzer_results: list[dict]) -> str:
  # Convert detection results (dict) to Presidio RecognizerResult
  recognizer_results = [
    RecognizerResult(
      entity_type=r["entity_type"], start=r["start"], end=r["end"], score=r["score"]
    ) for r in analyzer_results
  ]

  # Determine replacement strategy by entity (example)
  operators = {
    "EMAIL_ADDRESS": OperatorConfig("replace", {"new_value": "user@example.com"}),
    "PHONE_NUMBER": OperatorConfig("replace", {"new_value": fake.phone_number()}),
    "PERSON":       OperatorConfig("replace", {"new_value": fake.name()}),
    "LOCATION":     OperatorConfig("replace", {"new_value": fake.address()}),
    "IP_ADDRESS":   OperatorConfig("replace", {"new_value": fake.ipv4()}),
    "CREDIT_CARD":  OperatorConfig("replace", {"new_value": fake.credit_card_number()}),
    # Taiwan common:
    "TW_ID_NUMBER":         OperatorConfig("replace", {"new_value": _fake_tw_id()}),
    "UNIFIED_BUSINESS_NO":  OperatorConfig("replace", {"new_value": _fake_ubn()}),
    "TW_PHONE_NUMBER":      OperatorConfig("replace", {"new_value": _fake_tw_mobile()}),
    # Other unknown types: keep original or mask with '★'
  }

  return anonymizer.anonymize(
    text=text, analyzer_results=recognizer_results, operators=operators
  ).text
```

Key points:
- Uses Presidio Anonymizer's OperatorConfig, mainly "replace", can also change to mask.
- Provides dedicated generators for region-specific (TW) to maintain format reasonableness.

### Replace (PDF): `file_handlers/pdf_handler_1.py`

```python
# Page by page, span by span: first detect, then use faker to generate corresponding fake_map, replace text by original start-end positions,
# maintain original bbox / font size, finally rebuild new PDF with PyMuPDF.
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

Key points:
- Use `offset` to handle length differences after replacement, avoiding subsequent span position misalignment.
- Specific replacement strategy is pluggable: can change to full masking or more refined value generation by type.

## Backend Routing & Output

`main.Backend._process_file_with_deidentification()` routes by file extension:

- text → `TextHandler.deidentify()` → `*_deid.txt`
- docx → `DocxHandler.deidentify()` → `*_deid.docx`
- pdf → `PdfHandler.deidentify()` → `*_deid.pdf`

Preview:
- PDF directly converts to page images (PyMuPDF).
- DOC/DOCX tries to convert to PDF then to page images; if no Word/LibreOffice, changes to unsupported message.
- TXT directly provides content preview (line numbers/syntax highlighting).

## FAQ
- If there are special fonts, detection results may be distorted.
- spaCy model download error? Please check network or use offline installation, ensure `en_core_web_sm`, `zh_core_web_sm` are available.
- PDF handler shows font path error? Change hardcoded fonts to locally available files, or simplify to standard font names `helv`/`times`.
- DOCX→PDF conversion failed?
  - Windows + Word (pywin32) is more stable;
  - Without Word, please install LibreOffice and add `soffice.exe` to PATH or specify with `SOFFICE_PATH`.

## License

This project includes third-party packages (Presidio, spaCy, PyMuPDF, Faker, etc.), please refer to their original project license terms.
