# pii_models/presidio_detector.py

from presidio_analyzer import AnalyzerEngine, RecognizerRegistry, PatternRecognizer, Pattern
from presidio_analyzer.nlp_engine import NlpEngineProvider
from pii_models.custom_recognizer_plus import register_custom_entities

# 篩選重疊實體的函數
PRIORITY = {
    "TW_PHONE_NUMBER": 1,
    "DURATION_TIME": 1,
    "DATE_TIME": 2,
    "UNIFIED_BUSINESS_NO": 1,
    "TW_HOME_NUMBER": 2,
    "EMAIL_ADDRESS": 1,
    "PERSON": 1,
    "LOCATION": 2,
    "ORGANIZATION": 3,
}

# 1) 定義 spaCy 多語模型
nlp_config = {
    "nlp_engine_name": "spacy",
    "models": [
        {"lang_code": "en", "model_name": "en_core_web_sm"},
        {"lang_code": "zh", "model_name": "zh_core_web_sm"},
    ],
}

# 2) 用 Provider 建立 NlpEngine
provider = NlpEngineProvider(nlp_configuration=nlp_config)
nlp_engine = provider.create_engine()

# 3) 用這個引擎去初始化 Analyzer
analyzer = AnalyzerEngine(
    nlp_engine=nlp_engine,
    supported_languages=["en", "zh"]
)

# 4) 註冊自訂實體
register_custom_entities(analyzer)

def detect_pii(
    text: str,
    language: str = "auto",
    score_threshold: float = 0.5,
):
    # # 測試特定文字
    # test_cases = ["15 years of experience", "22 years old", "5 years ago", "Experienced administrative assistant with over 15 years of experience in office management"]
    
    # for test_text in test_cases:
    #     print(f"\n測試文字: '{test_text}'")
    #     test_results = analyzer.analyze(text=test_text, language="en")
    #     for r in test_results:
    #         print(f"  - {r.entity_type}: {test_text[r.start:r.end]} (score: {r.score})")
    
    # Always pass a real language code here:
    results = analyzer.analyze(
        text=text,
        entities=None,
        language=language,
    )
    # NEW!!!
    # 用 dict 包裝每個 result，加上 raw_txt
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
    # 篩選重疊實體
    filtered = filter_entities_by_priority(filtered)
            
    print(f"*** Start ***\n偵測到的 PII 實體：{len(filtered)} 個")
    print(f"--- 篩選後的實體：{filtered}")
    # if there's no entity -> print end
    if not filtered:
        print("*** End ***\n")
    # return [r for r in results if r.score >= score_threshold]
    return filtered

def filter_entities_by_priority(entities):
    """篩選重疊實體，保留優先級高且分數高的實體"""
    if not entities:
        return []
    
    # 按優先級和分數排序（優先級低的數字代表高優先級）
    sorted_entities = sorted(
        entities, 
        key=lambda e: (PRIORITY.get(e["entity_type"], 99), -e["score"])
    )
    
    filtered = []
    
    for current_entity in sorted_entities:
        current_start = current_entity["start"]
        current_end = current_entity["end"]
        
        # 檢查是否與已選擇的實體重疊
        is_overlapping = False
        
        for selected_entity in filtered:
            selected_start = selected_entity["start"]
            selected_end = selected_entity["end"]
            
            # 檢查重疊：如果兩個範圍有任何交集就算重疊
            if not (current_end <= selected_start or current_start >= selected_end):
                is_overlapping = True
                print(f"發現重疊：{current_entity['entity_type']} ({current_start}-{current_end}) 與 {selected_entity['entity_type']} ({selected_start}-{selected_end})")
                break
        
        # 如果沒有重疊，則加入結果
        if not is_overlapping:
            filtered.append(current_entity)
            print(f"保留實體：{current_entity['entity_type']} - '{current_entity['raw_txt']}' (score: {current_entity['score']})")
        else:
            print(f"跳過重疊實體：{current_entity['entity_type']} - '{current_entity['raw_txt']}' (score: {current_entity['score']})")
    
    return filtered

if __name__ == "__main__":
    print("=== Registered recognizers ===")
    for r in analyzer.registry.recognizers:
        print(f"{r.name} → supports: {r.supported_entities}; langs: {r.supported_language}")

