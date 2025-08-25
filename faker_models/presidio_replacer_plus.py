from presidio_anonymizer import AnonymizerEngine
from presidio_analyzer import RecognizerResult
from presidio_anonymizer.entities import OperatorConfig
import random, string, re
from faker import Faker

anonymizer = AnonymizerEngine()
fake = Faker()

def fake_tw_id():
    # 亂數產生 A/B 開頭，第二碼 1/2，後面配 8 位數
    letters = random.choice(string.ascii_uppercase)
    gender = random.choice("12")
    nums   = "".join(random.choices(string.digits, k=8))
    return f"{letters}{gender}{nums}"

def fake_ubn():
    # 8 位數統編
    return "".join(random.choices(string.digits, k=8))

def replace_pii(text, analyzer_results):
    # 將 analyzer_results 轉換為 RecognizerResult 物件
    recognizer_results = [
        RecognizerResult(
            entity_type=res["entity_type"],
            start=res["start"],
            end=res["end"],
            score=res["score"]
        )
        for res in analyzer_results
    ]

    # 按照 start 位置倒序排列，避免替換時位置偏移
    recognizer_results.sort(key=lambda x: x.start, reverse=True)
    
    replaced_text = text
    
    for res in recognizer_results:
        et = res.entity_type
        detected_text = text[res.start:res.end]
        
        # 為每個實體生成獨立的替換值
        if et == "EMAIL_ADDRESS":
            new_value = "user@example.com"

        elif et == "DURATION_TIME":
            # 處理時間長度，只替換數字部分
            detected_text = text[res.start:res.end]
            print(f"Processing DURATION_TIME: {detected_text}")
            match = re.search(r"\b(\d+)\b", detected_text)
            if match:
                fake_number = fake.random_int(min=1, max=20)
                fake_value = detected_text.replace(match.group(1), str(fake_number))
            else:
                fake_value = detected_text
            print(f"DURATION_TIME replaced with: {fake_value}")
            new_value = fake_value

        elif et == "PHONE_NUMBER":
            new_value = fake.phone_number()

        elif et == "DATE_TIME":
            # 檢查是否為相對時間表達，如果是則保留原文
            detected_text_lower = detected_text.lower().strip()
            
            # 定義相對時間關鍵詞（更完整的列表）
            relative_time_keywords = {
                # 英文相對時間 - 基本
                "today", "tomorrow", "yesterday", "now", "tonight", "td", "tmr", "rn",
                # 英文相對時間 - 時段
                "this morning", "this afternoon", "this evening", "this noon",
                "last night", "yesterday morning", "yesterday afternoon", "yesterday evening",
                "tomorrow morning", "tomorrow afternoon", "tomorrow evening", "tomorrow night",
                # 英文相對時間 - 週期
                "this week", "this month", "this year", "this quarter", "this semester",
                "next week", "next month", "next year", "next quarter", "next semester",
                "last week", "last month", "last year", "last quarter", "last semester",
                # 英文相對時間 - 模糊時間
                "recently", "lately", "soon", "later", "earlier", "before", "after", 
                "currently", "presently", "nowadays", "these days", "right now",
                "just now", "a moment ago", "a while ago", "in a while", "shortly",
                # 中文相對時間 - 基本
                "今天", "明天", "昨天", "現在", "今晚", "今夜",
                # 中文相對時間 - 時段  
                "今早", "今天早上", "今天上午", "今天中午", "今天下午", "今天晚上",
                "昨天早上", "昨天上午", "昨天中午", "昨天下午", "昨天晚上", "昨晚",
                "明天早上", "明天上午", "明天中午", "明天下午", "明天晚上", "明晚",
                # 中文相對時間 - 週期
                "這週", "這個星期", "這個月", "這一個月", "今年", "這一年",
                "下週", "下個星期", "下個月", "下一個月", "明年", "下一年",
                "上週", "上個星期", "上個月", "上一個月", "去年", "上一年",
                # 中文相對時間 - 模糊時間
                "最近", "近來", "稍後", "等等", "等一下", "之前", "之後", "以前", "以後",
                "目前", "現階段", "當前", "眼前", "剛才", "剛剛", "一會兒", "待會兒"
            }
            
            # 檢查是否包含相對時間關鍵詞（精確匹配或模式匹配）
            is_relative_time = False
            
            # 1. 直接關鍵詞匹配
            is_relative_time = any(keyword in detected_text_lower for keyword in relative_time_keywords)
            
            # 2. 模式匹配 - 檢測相對時間模式
            if not is_relative_time:
                relative_patterns = [
                    r'\b(in|within)\s+\d+\s+(days?|weeks?|months?|years?)\b',  # "in 3 days", "within 2 weeks"
                    r'\b\d+\s+(days?|weeks?|months?|years?)\s+(ago|from now)\b',  # "3 days ago", "2 weeks from now"
                    r'\bthis\s+(coming|past)\s+(week|month|year)\b',  # "this coming week", "this past month"
                    r'\b(next|last)\s+\w+(day|week|end)\b',  # "next weekend", "last weekday"
                    r'\b(early|late)\s+(this|next|last)\s+(week|month|year)\b',  # "early this week"
                    r'\b幾天(前|後|內)\b',  # 中文："幾天前", "幾天後", "幾天內"
                    r'\b\d+天(前|後|內)\b',  # 中文："3天前", "5天後", "一週內"
                    r'\b(下|上)(周|月|年)(初|中|末)\b',  # 中文："下週初", "上月末"
                ]
                
                for pattern in relative_patterns:
                    if re.search(pattern, detected_text_lower):
                        is_relative_time = True
                        break
            
            if is_relative_time:
                print(f"Detected relative time expression: {detected_text}, keeping original text")
                new_value = detected_text  # 保留原始文字
            else:
                # 不是相對時間，生成假數據
                new_value = fake.date()
                print(f"Generated fake date for: {detected_text} -> {new_value}")

        elif et == "UK_NHS":
            new_value = f"{random.randint(100, 999)} {random.randint(100, 999)} {random.randint(0, 9999):04d}"

        elif et == "CREDIT_CARD":
            new_value = fake.credit_card_number()

        elif et == "PERSON":
            new_value = fake.name()

        elif et == "LOCATION":
            new_value = fake.address()
            
        elif et == "IP_ADDRESS":
            new_value = fake.ipv4()

        elif et == "URL":
            new_value = fake.url()

        elif et == "MAC_ADDRESS":
            new_value = fake.mac_address()

        # TW
        # 新增：統一編號
        elif et == "UNIFIED_BUSINESS_NO":
            new_value = fake_ubn()

        # 新增：台灣身分證
        elif et == "TW_ID_NUMBER":
            new_value = fake_tw_id()
        
        elif et == "TW_PHONE_NUMBER":
            new_value = f"09{''.join([str(random.randint(0,9)) for _ in range(8)])}"

        elif et == "TW_ID_NUMBER":
            new_value = f"{random.choice(string.ascii_uppercase)}{random.choice(['1','2'])}{''.join(str(random.randint(0,9)) for _ in range(8))}"

        elif et == "UNIFIED_BUSINESS_NO":
            new_value = f"{''.join([str(random.randint(0,9)) for _ in range(8)])}"

        elif et == "TW_HEALTH_INSURANCE":
            new_value = f"0000{''.join([str(random.randint(0,9)) for _ in range(6)])}"

        elif et == "TW_PASSPORT_NUMBER":
            new_value = f"3{''.join([str(random.randint(0,9)) for _ in range(7)])}"
        else:
            new_value = detected_text  # 保留原始文字
        
        # 直接替換文字
        replaced_text = replaced_text[:res.start] + new_value + replaced_text[res.end:]
        
        print(f"--- 處理實體類別: {et}")
        print(f"    原始文字: {detected_text}")
        print(f"    替換為: {new_value}")
        # if it's the last entity, print end marker
        if res == recognizer_results[-1]:
            print(f"*** End ***\n")
    return replaced_text
