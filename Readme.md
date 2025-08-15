# 建立虛擬環境
python -m venv .venv
.venv\Scripts\activate
python.exe -m pip install --upgrade pip
pip install PySide6 python-docx pymupdf pywin32 pypdf

# 開啟專案
python.exe .\main.py   

# 從 venv 啟動設計畫面(要設計 layout 再開)
.venv\Scripts\pyside6-designer.exe
