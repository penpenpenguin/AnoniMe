# AnoniMe - Personal Information Anonymization Tool

---

## English

### Overview
AnoniMe is a desktop application for document de-identification that automatically detects and replaces Personal Identifiable Information (PII) in documents. Built with PySide6 and QML, it provides a user-friendly interface for processing TXT, DOCX, and PDF files while maintaining document structure and formatting.

### Key Features
- **Multi-format Support**: Process TXT, DOCX, and PDF files
- **Advanced PII Detection**: Powered by Microsoft Presidio with custom Taiwan-specific recognizers
- **Intelligent Replacement**: Context-aware fake data generation using Faker library
- **Document Preview**: Built-in preview functionality for processed documents
- **Multilingual Support**: English and Chinese language processing

### Architecture

```
AnoniMe/
├── main.py                    # Main application entry point
├── Main.qml                   # QML UI main window
├── HomePage.qml               # Home page interface
├── UploadPage.qml            # File upload interface
├── ResultPage.qml            # Results display interface
├── EmbedViewer.qml           # Document preview component
├── test_backend.py           # Enhanced backend with preview
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
    └── pdf_handler.py      # PDF processing handler

```

### Core Technologies

#### PII Detection Pipeline
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

#### Custom Taiwan Recognizers
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
# - Taiwan ID Numbers (身分證字號)
# - Business Registration Numbers (統一編號)
# - Taiwan Phone Numbers (台灣電話號碼)
# - MAC Addresses (網路卡位址)
```

#### Intelligent Data Replacement
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

### API Contract

#### Input JSON Structure
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

#### Output JSON Structure
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

### Installation & Usage

#### Prerequisites
```bash
pip install PySide6 presidio-analyzer presidio-anonymizer spacy faker PyMuPDF python-docx
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
```

#### Running the Application
```bash
# Enhanced mode with preview
python run_with_test_backend.py
```

#### Minimal Test Script
```bash
python scripts/minimal_text_demo.py
```

### Testing
```bash
# Run comprehensive tests
python simple_test.py

# Test specific file handlers
python test_file_routing.py

# Backend functionality test
python test_backend.py
```

---
