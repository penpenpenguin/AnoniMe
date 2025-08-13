# 專案與 venv
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir     = Join-Path $ProjectRoot ".venv"

# 兩種啟動器都準備（有些環境 pyside6-designer.exe 會包一層）
$DesignerPySide = Join-Path $VenvDir "Scripts\pyside6-designer.exe"
$DesignerNative = Join-Path $VenvDir "Lib\site-packages\PySide6\designer.exe"

# 指定翻譯檔目錄（你已經有了）
$env:QT_TRANSLATIONS_PATH = Join-Path $VenvDir "Lib\site-packages\PySide6\translations"

# 重點：強制語系（繁中/簡中擇一）
$env:LANG     = "zh_TW"   # 或改成 "zh_CN"
$env:LC_ALL   = $env:LANG

# （可保留）QT_LOCALE 有些版本會忽略，但留著不妨
$env:QT_LOCALE = "zh_TW"

# 先用原生 designer.exe，失敗再退回 pyside6-designer.exe
if (Test-Path $DesignerNative) {
  Write-Host "以中文介面啟動 Qt Designer (designer.exe)..." -ForegroundColor Cyan
  & $DesignerNative
} elseif (Test-Path $DesignerPySide) {
  Write-Host "以中文介面啟動 Qt Designer (pyside6-designer.exe)..." -ForegroundColor Cyan
  & $DesignerPySide
} else {
  Write-Host "找不到 Designer 可執行檔，請確認已安裝 PySide6。" -ForegroundColor Yellow
  exit 1
}
