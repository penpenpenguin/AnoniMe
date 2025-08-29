import sys, os
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]   # ...\AnoniMe
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
    
from backend.test_backend import TestBackend

if __name__ == "__main__":
    QQuickStyle.setStyle("Fusion")
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    backend = TestBackend()
    engine.rootContext().setContextProperty("backend", backend)
    
    # 確保載入正確的 QML 檔案路徑
    PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__)) 
    qml_file = os.path.join(PROJECT_ROOT, "qml", "Main.qml")
    engine.load(os.fspath(qml_file))

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
