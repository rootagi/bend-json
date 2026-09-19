#!/usr/bin/env python3
import sys
import subprocess
import os
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    # 1.5 must parse successfully
    input_file = Path("/tmp/input_f3.json")
    input_file.write_text("1.5")
    env = {**os.environ, "JSON_IN": str(input_file)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
    lines = r.stdout.splitlines()
    if not lines or lines[0] != "OK":
        print(f"FAIL: 1.5 did not parse: {lines}")
        sys.exit(1)
    print("PASS: F3")
    sys.exit(0)

if __name__ == "__main__":
    main()
