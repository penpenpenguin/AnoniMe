![範例圖片](./MainPage.png)

AnoniMe 是一個專門用來保護文件中 個人資料（PII） 的工具。很多人會不小心在沒有隱私保護的情況下，把包含姓名、電話、地址等敏感資訊的檔案上傳到 AI 工具或第三方平台，這些資料可能被濫用。

如果要自己手動刪改，不但很花時間，還常常因為不同檔案格式（txt、docx、pdf）而變得麻煩，而且容易有漏網之魚。其實並不是所有資料都需要完全去識別化，所以 AnoniMe 提供了可自訂的規則，幫你在需要的地方做去識別化，避免浪費時間也降低風險。
為了讓去識別化後的文件更貼近真實情境，AnoniMe 整合了 [Kuwa GenAI OS](https://kuwaai.org/zh-Hant/) 的 Llama 3.1 8B @NPU 模型，能自動生成符合語境的假資料，確保處理後的文件仍然自然流暢，便於後續分析與應用。

## Maintainers

| Name | Email | GitHub |
|------|-------|--------|
| 林佳蓁 | linjiazhen012815@gmail.com | <a href="https://github.com/penpenpenguin"><img src="https://github.com/penpenpenguin.png?size=100" width="60"/></a> |
| 吳承軒 | dsw1328201@gmail.com | <a href="https://github.com/tonywuwutony"><img src="https://github.com/tonywuwutony.png?size=100" width="60"/></a> |
| 褚家豪 | lucasauriant0209@gmail.com | <a href="https://github.com/Lucas-Chu-0209"><img src="https://github.com/Lucas-Chu-0209.png?size=100" width="60"/></a> |

## 專案結構（Organization）

- app — 主程式與（選用）後端
  - app/run_with_test_backend.py — 主程式入口（啟動處理流程）
  - app/backend/ — 後端服務端點

- core：匿名化核心與管線
  - pii_models/ — 自訂辨識器與規則（如 custom_recognizer.py、custom_recognizer_plus.py）
  - faker_models/ — 替換策略與映射快取（如 presidio_replacer_plus.py、muiltAI_pii_replace.py）

- communication：與外部服務/模型的通訊
  - faker_models/muiltAI_pii_replace.py — 透過 KuwaClient 串接聊天模型，批次產生替換字串
  - app/backend/ — 後端服務端點（若有需要與前端或外部整合）

- handlers：檔案處理器
  - file_handlers/ — 文字、Word、PDF 等格式的抽取與寫回（txt_handler.py、docx_handler.py、pdf_handler.py）

- userinterface：使用者介面資源
  - qml/ — QML 介面與資源（若用於桌面或嵌入式 UI）

## 使用方式 (要放安裝及操作)

**AnoniMe** 會 **搭配 [Kuwa GenAI OS (kuwa-aios)](https://github.com/kuwaai/kuwa-aios)** 一起使用，並透過其中的 **Llama 3.1 8B @ NPU 模型**來自動產生或替換文件中的假資料，讓去識別化後的內容更貼近真實情境。

> ⚠️ 注意事項  
> - **Kuwa GenAI OS 的安裝與使用，請參考 [官方文件](https://github.com/kuwaai/kuwa-aios)，本專案不再重複說明。**  
> - 本專案目前使用 **NPU 模型**，因此需要具備支援 NPU 的設備。  
> - 如果你的環境沒有支援 NPU，建議改用 **其他不依賴 NPU 的模型**


### .env 檔案
請在專案根目錄建立 `.env` 檔，範例如下：
```env
# 你的 Kuwa 伺服器位址
KUWA_BASE_URL=http://127.0.0.1

# 在 Kuwa 後台建立/複製的使用者 API Token
KUWA_API_KEY= <API Token>

# 在 Kuwa「模型清單 / Bot 設定」看到的模型名稱，只需替換後面的Llama 3.1 8B @NPU
KUWA_MODEL=.bot/Llama 3.1 8B @NPU
```

### Kuwa Client 路徑設定

由於目前 KuwaClient 並不是透過 `pip install` 提供，而是直接從 **Kuwa GenAI OS 原始碼**引入，所以需要手動指定路徑。

請打開 `faker_models/muiltAI_pii_replace.py`，找到以下程式碼區塊：

```python
import sys
sys.path.append(r"C:\kuwa\GenAI OS\src\library\client\src\kuwa")  # 請依實際路徑修改
from client.base import KuwaClient  
```

## 快速開始
- 建立虛擬環境並安裝套件（略，推薦 3.11 / 3.10）
- 執行 KUWA
- pip install -r requirements.txt     # 安裝需求套件
- python app/run_with_test_backend.py


## License
This project is licensed under the GNU GPLv3 License for open-source use.  
For commercial licensing, please contact linjiazhen012815@gmail.com .

