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
            new_value = fake.date()

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
