#!/usr/bin/env python3
import sys
import subprocess
import json
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    # Test array of 1001 ones
    arr_json = "[" + ",".join(["1"] * 1001) + "]"
    cmd = f"""cat << 'EOF' > /tmp/input_f1.json\n{arr_json}\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f1.json bend tests/harness.bend"""
    r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
    lines = r.stdout.splitlines()
    if not lines or lines[0] != "OK":
        print("FAIL: parse failed")
        sys.exit(1)
    if "--- STRINGIFY ---" not in lines:
        print("FAIL: no stringify output")
        sys.exit(1)
    idx = lines.index("--- STRINGIFY ---")
    str_out = lines[idx + 1]
    if len(str_out) != 2003 or not str_out.endswith("]"):
        print(f"FAIL: stringify truncated (length {len(str_out)}, expected 2003)")
        sys.exit(1)
    print("PASS: F1")
    sys.exit(0)

if __name__ == "__main__":
    main()
