#!/usr/bin/env python3
import sys
import os
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    # Test array of 1001 ones
    arr_json = "[" + ",".join(["1"] * 1001) + "]"
    input_file = Path("/tmp/input_f1.json")
    input_file.write_text(arr_json)
    env = {**os.environ, "JSON_IN": str(input_file)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
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
