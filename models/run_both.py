import os
from dotenv import load_dotenv
from fake_en import generate_fake_en
from fake_zh import generate_fake_zh

load_dotenv(override=True)

en_input = "Michael Brown,michael.brown@gmail.com,(312) 555-0199,5678 Oak Street, Chicago, IL 60605,1990-07-15,987-65-4321"
zh_input = "陳偉倫,wei.lun@example.com,0912-345-678,台北市中正區信義路1段1號,1988-05-21,A123456789"

print("[ENV] PROVIDER=", os.getenv("PROVIDER"))
print("[ENV] AIHUB_FULL_URL=", os.getenv("AIHUB_FULL_URL"))
print("[ENV] AIHUB_AUTH=", os.getenv("AIHUB_AUTH"))

en_out = generate_fake_en(en_input)
zh_out = generate_fake_zh(zh_input)

print("\n=== English ===")
print("Input :", en_input)
print("Output:", en_out)

print("\n=== 中文 ===")
print("輸入：", zh_input)
print("輸出：", zh_out)