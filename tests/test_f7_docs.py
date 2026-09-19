#!/usr/bin/env python3
import sys
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    r = subprocess.run([str(REPO_DIR / "tools" / "check_readme.py")], capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: check_readme.py failed")
        sys.exit(1)
    print("PASS: F7")
    sys.exit(0)

if __name__ == "__main__":
    main()
