#!/usr/bin/env python3
import sys
import subprocess
import os
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def main():
    errors = []
    # Should fail
    should_fail = [
        "007", "-", "[-]", "-01", "1.e2",
        '{"a":1,}', "[1,]", "[,1]", "{,}",
        r'"\q"', r'"\u12"', r'"\uZZZZ"', r'"\ud83d"',
        '"\x01"'
    ]
    input_file = Path("/tmp/input_f4.json")
    for inp in should_fail:
        input_file.write_text(inp)
        env = {**os.environ, "JSON_IN": str(input_file)}
        r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
        lines = r.stdout.splitlines()
        if lines and lines[0] == "OK":
            errors.append(f"Expected failure for {inp}, but got OK")

    # Should pass
    should_pass = [
        r'"\u0041"', r'"\ud83d\ude00"', r'"\b \f \/"'
    ]
    for inp in should_pass:
        input_file.write_text(inp)
        env = {**os.environ, "JSON_IN": str(input_file)}
        r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
        lines = r.stdout.splitlines()
        if not lines or not lines[0].startswith("OK"):
            errors.append(f"Expected success for {inp}, but got {lines[0] if lines else 'NONE'}")

    if errors:
        for e in errors:
            print("FAIL:", e)
        sys.exit(1)
    print("PASS: F4 (grammar, escapes, surrogates, control chars)")
    sys.exit(0)

if __name__ == "__main__":
    main()
