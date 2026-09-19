#!/usr/bin/env python3
import sys
import subprocess
import os
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    # depth 15 with step 2: must have 30 leading spaces
    nested = '{"a":' * 15 + '1' + '}' * 15
    input_file = Path("/tmp/input_f6.json")
    input_file.write_text(nested)
    env = {**os.environ, "JSON_IN": str(input_file)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
    lines = r.stdout.splitlines()
    if "--- PRETTY ---" not in lines:
        print("FAIL: no pretty output")
        sys.exit(1)
    pretty_lines = lines[lines.index("--- PRETTY ---") + 1:]
    found_spaces = None
    for pl in pretty_lines:
        if "1" in pl:
            found_spaces = len(pl) - len(pl.lstrip(" "))
            break
    if found_spaces != 30:
        print(f"FAIL: depth 15 has {found_spaces} spaces, expected 30")
        sys.exit(1)
    print("PASS: F6")
    sys.exit(0)

if __name__ == "__main__":
    main()
