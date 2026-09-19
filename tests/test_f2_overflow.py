#!/usr/bin/env python3
import sys
import subprocess
import os
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    # 281474976710656 (2^48) must fail gracefully with FAIL:, never abort/crash
    input_file = Path("/tmp/input_f2.json")
    input_file.write_text("281474976710656")
    env = {**os.environ, "JSON_IN": str(input_file)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
    lines = r.stdout.splitlines()
    # Must exit 0 and report FAIL: number too large
    if r.returncode != 0:
        print(f"FAIL: bend aborted with exit code {r.returncode}")
        sys.exit(1)
    if not lines or not lines[0].startswith("FAIL:"):
        print(f"FAIL: expected FAIL: message, got {lines}")
        sys.exit(1)
    print("PASS: F2")
    sys.exit(0)

if __name__ == "__main__":
    main()
