# custom_recognizer.py
from presidio_analyzer import Pattern, PatternRecognizer, AnalyzerEngine, RecognizerResult
from typing import List, Optional
import re

# ---------- helpers: validators / scoring tweaks ----------

def validate_tw_ubn(ubn: str) -> bool:
    """
    Taiwan UBN checksum:
    multiply digits by [1,2,1,2,1,2,4,1], sum digits of products,
    total % 10 == 0, or special case: if 7th digit product sums to 10, allow (total+1) % 10 == 0
    """
    if not re.fullmatch(r"\d{8}", ubn):
        return False
    coef = [1,2,1,2,1,2,4,1]
    s = 0
    for i, c in enumerate(ubn):
        p = int(c) * coef[i]
        s += (p // 10) + (p % 10)
    # special case: if 7th position (index 6) contributes 10, allow +1
    if (int(ubn[6]) * 4) >= 10:
        return s % 10 == 0 or (s + 1) % 10 == 0
    return s % 10 == 0

def normalize_mac(mac: str) -> str:
    mac = mac.lower()
    mac = mac.replace("-", ":")
    if "." in mac:  # cisco dotted -> convert to colon
        mac = mac.replace(".", "")
        mac = ":".join([mac[i:i+2] for i in range(0, 12, 2)])
    return mac

# ---------- main registration ----------

def register_custom_entities(analyzer: AnalyzerEngine):
    # ==== Existing: TW_ID & UBN (keep your patterns but add validator awareness) ====
    tw_id_pattern = Pattern(
        name="tw_id_pattern",
        regex=r"\b[A-Z][12]\d{8}\b",
        score=0.85
    )
    tw_ubn_pattern = Pattern(
        name="tw_ubn_pattern",
        regex=r"\b\d{8}\b",
        score=0.90  # base score放低，通過校驗後再加權
    )

    # ==== NEW: Taiwan Mobile (行動電話) ====
    # 支援：09xxxxxxxx、09xx-xxx-xxx、+886 9xxxxxxxx、(+886)9xxxxxxxx、+8869xxxxxxxx（空白/連字號/括號皆可）
    tw_mobile_patterns = [
        Pattern(
            name="tw_mobile_domestic",
            regex=r"\b09\d{2}[-\s]?\d{3}[-\s]?\d{3}\b",
            score=0.85
        ),
        Pattern(
            name="tw_mobile_intl_spaced",
            regex=r"\b(?:\+886|\(\+886\))\s*9\d{2}\s*\d{3}\s*\d{3}\b",
            score=0.85
        ),
        Pattern(
            name="tw_mobile_intl_compact",
            regex=r"\b\+886\s*9\d{8}\b",
            score=0.85
        ),
        Pattern(
            name="tw_mobile_intl_no_space",
            regex=r"\b\+8869\d{8}\b",  # 新增允許無空格的情況
            score=0.95  # 提高分數
        ),
    ]
    
    # ==== NEW: Duration (時間長度) ====
    # 專門處理如 "15 years of experience", "3 months", "2 weeks" 等時間長度表達
    duration_patterns = [
        Pattern(
            name="duration_years_experience_variations",
            regex=r"\b\d+\s+years?\s+of\s+(?:working\s+)?experiences?\b",  # 支援 working + 複數
            score=0.98
        ),
        Pattern(
            name="duration_years_experience",
            regex=r"\b\d+\s+years?\s+of\s+experiences?\b",
            score=0.98  # 非常高的分數
        ),
        Pattern(
            name="duration_years_old",
            regex=r"\b\d+\s+years?\s+old\b",
            score=0.98
        ),
        Pattern(
            name="duration_years_experience_with_adjectives",
            regex=r"\b\d+\s+years?\s+of\s+(?:working|professional|relevant|related|practical)\s+experiences?\b",
            score=0.98
        ),
        Pattern(
            name="duration_years_work",
            regex=r"\b\d+\s+years?\s+(?:of\s+)?(?:work|working|service|training|study|employment)\b",
            score=0.96
        ),
        Pattern(
            name="duration_time_ago",
            regex=r"\b\d+\s+(?:years?|months?|weeks?|days?)\s+ago\b",
            score=0.95
        ),
        Pattern(
            name="duration_months_experience",
            regex=r"\b\d+\s+months?\s+(?:of\s+)?(?:experience|work|service)\b",
            score=0.95
        ),
        Pattern(
            name="duration_months_experience_1",
            regex=r"\b\d+\s+months?\s+(?:of\s+)?(?:working\s+)?experiences?\b",
            score=0.95
        ),
        Pattern(
            name="duration_general_with_context",
            regex=r"\b\d+\s+(?:years?|months?|weeks?|days?)\s+(?:of\s+)?(?:working\s+)?(?:experiences?|work|service|training|study|employment|ago)\b",
            score=0.90
        )
    ]

    # ==== NEW: Taiwan Landline (市話) ====
    # 形式：0X~0XXX 區碼 + 6~8碼；可為 (0X)xxxxxxx、0X-xxxx-xxxx、+886 X xxxxxxxx 等
    # 排除 09 開頭避免吃到手機
    tw_home_patterns = [
        Pattern(
            name="tw_home_basic",
            regex=r"\b(?!09)\d(?:0\d{1,3}|\d)\b",  # 防止與其他數字干擾的錨點（後面再具體化）
            score=0.01
        ),
        Pattern(
            name="tw_home_parenthesized",
            regex=r"\(\s?0\d{1,3}\s?\)\s?\d{6,8}\b",
            score=0.80
        ),
        Pattern(
            name="tw_home_dash_or_space",
            regex=r"\b0(?!9)\d{1,3}[-\s]?\d{6,8}\b",
            score=0.80
        ),
        Pattern(
            name="tw_home_intl",
            regex=r"\b\+886\s?(?:[2-8]|[2-8]\d|\d{2})\s?\d{6,8}\b",
            score=0.80
        ),
    ]

    # ==== NEW: MAC address ====
    mac_patterns = [
        Pattern(
            name="mac_colon_or_dash",
            regex=r"\b(?:[0-9A-Fa-f]{2}([:-]))(?:[0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2}\b",
            score=0.90
        ),
        Pattern(
            name="mac_cisco_dotted",
            regex=r"\b(?:[0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}\b",
            score=0.90
        ),
    ]

    # ==== NEW: Taiwan NHI card number (健保卡卡號) 12位純數字 ====
    tw_nhi_patterns = [
        Pattern(
            name="tw_nhi_12_digits",
            regex=r"\b0000\d{8}\b",
            score=0.51  # 基礎分數不高，以「上下文」拉分，避免一般12碼數字誤擊
        )
    ]

    # ---------- Recognizers with context & validation ----------

    # zh/en 都註冊（Presidio 會依語言分流）
    for lang in ("zh", "en"):
        # 時間長度識別器
        duration_recognizer = PatternRecognizer(
            supported_entity="DURATION_TIME",
            patterns=duration_patterns,
            supported_language=lang,
            context=["experience", "work", "service", "training", "employment", "old", "ago", "years", "months", "weeks", "days"]
        )
        
        # 身分證
        tw_id_recognizer = PatternRecognizer(
            supported_entity="TW_ID_NUMBER",
            patterns=[tw_id_pattern],
            supported_language=lang,
            context=["身分證", "身份證", "ID", "ID number"]
        )

        # 統編（含校驗加權）
        class TWUBNRecognizer(PatternRecognizer):
            def __init__(self, **kwargs):
                super().__init__(supported_entity="UNIFIED_BUSINESS_NO",
                                 patterns=[tw_ubn_pattern],
                                 supported_language=lang,
                                 context=["統編", "統一編號", "UBN", "company", "tax", "Unified Business No"],
                                 **kwargs)

            def validate_result(self, pattern_text: str) -> Optional[bool]:
                return validate_tw_ubn(pattern_text)

            def enhance_confidence(self, result: RecognizerResult, text: str) -> RecognizerResult:
                # 通過校驗 → 拉到高分；未通過 → 壓低
                if validate_tw_ubn(text[result.start:result.end]):
                    result.score = max(result.score, 0.90)
                else:
                    result.score = min(result.score, 0.20)
                return result

            def analyze(self, text: str, entities: List[str], nlp_artifacts=None) -> List[RecognizerResult]:
                results = super().analyze(text, entities, nlp_artifacts)
                for r in results:
                    r = self.enhance_confidence(r, text)
                return results

        tw_ubn_recognizer = TWUBNRecognizer()

        # 行動電話
        tw_phone_recognizer = PatternRecognizer(
            supported_entity="TW_PHONE_NUMBER",
            patterns=tw_mobile_patterns,
            supported_language=lang,
            context=["手機", "行動", "phone", "mobile", "tel", "臺灣", "台灣手機", "行動電話"]
        )

        # 市話
        tw_home_recognizer = PatternRecognizer(
            supported_entity="TW_HOME_NUMBER",
            patterns=tw_home_patterns[1:],  # 去掉那個保護性極低的basic pattern
            supported_language=lang,
            context=["市話", "電話", "tel", "phone", "landline"]
        )

        # MAC
        class MACRecognizer(PatternRecognizer):
            def __init__(self, **kwargs):
                super().__init__(supported_entity="MAC_ADDRESS",
                                 patterns=mac_patterns,
                                 supported_language=lang,
                                 context=["MAC", "網卡", "乙太網路", "Ethernet"], **kwargs)

            def enhance_confidence(self, result: RecognizerResult, text: str) -> RecognizerResult:
                norm = normalize_mac(text[result.start:result.end])
                # 00:00:00:00:00:00 類型給低分
                if norm in {"00:00:00:00:00:00", "ff:ff:ff:ff:ff:ff"}:
                    result.score = min(result.score, 0.20)
                else:
                    result.score = max(result.score, 0.90)
                return result

            def analyze(self, text: str, entities: List[str], nlp_artifacts=None) -> List[RecognizerResult]:
                results = super().analyze(text, entities, nlp_artifacts)
                for r in results:
                    r = self.enhance_confidence(r)
                return results

        mac_recognizer = MACRecognizer()

        # 健保卡卡號（12碼）
        tw_nhi_recognizer = PatternRecognizer(
            supported_entity="TW_NHI_NUMBER",
            patterns=tw_nhi_patterns,
            supported_language=lang,
            # 強化上下文，降低一般12碼數字誤擊
            context=["健保", "健保卡", "NHI", "NHIC", "健康保險", "health insurance"]
        )

        # ---- register all ----
        # 在註冊部分加入
        analyzer.registry.add_recognizer(duration_recognizer)
        analyzer.registry.add_recognizer(tw_id_recognizer)
        analyzer.registry.add_recognizer(tw_ubn_recognizer)
        analyzer.registry.add_recognizer(tw_phone_recognizer)
        analyzer.registry.add_recognizer(tw_home_recognizer)
        analyzer.registry.add_recognizer(mac_recognizer)
        analyzer.registry.add_recognizer(tw_nhi_recognizer)

