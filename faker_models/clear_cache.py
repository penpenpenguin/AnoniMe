# clear_cache.py
import os

def clear_cache():
    path = os.path.expanduser("~/.pii_map.json")
    try:
        os.remove(path)
        print(f"[Cache] 已刪除快取檔案: {path}")
    except FileNotFoundError:
        print("[Cache] 沒有找到快取檔案，不需刪除")
    except Exception as e:
        print(f"[Cache] 刪除快取檔案時發生錯誤: {e}")

if __name__ == "__main__":
    clear_cache()
