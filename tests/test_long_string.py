#!/usr/bin/env python3
import sys
import os
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def test_size(size):
    # Test JSON string of given size
    content = '"' + "a" * size + '"'
    tmp = Path(f"/tmp/input_str_{size}.json")
    tmp.write_text(content)
    env = {**os.environ, "JSON_IN": str(tmp)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=120)
    lines = r.stdout.splitlines()
    if not lines or lines[0] != "OK":
        return False, f"parse failed: {lines}"
    if "--- STRINGIFY ---" not in lines:
        return False, "missing stringify output"
    idx = lines.index("--- STRINGIFY ---")
    str_out = lines[idx + 1]
    expected_len = size + 2
    if len(str_out) != expected_len:
        return False, f"stringify length {len(str_out)} != expected {expected_len}"
    return True, f"length {len(str_out)}"

def main():
    sizes = [30000, 60000, 120000, 240000]
    errors = []
    for s in sizes:
        ok, msg = test_size(s)
        if ok:
            print(f"PASS: string size {s} ({msg})")
        else:
            print(f"FAIL: string size {s} ({msg})")
            errors.append(s)

    if errors:
        sys.exit(1)
    print("PASS: all long-string tests")
    sys.exit(0)

if __name__ == "__main__":
    main()
