#!/usr/bin/env python3
import sys
import os
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def run_test(inp):
    tmp = Path("/tmp/input_ws.json")
    tmp.write_text(inp)
    env = {**os.environ, "JSON_IN": str(tmp)}
    r = subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True)
    lines = r.stdout.splitlines()
    return len(lines) > 0 and lines[0] == "OK", lines[0] if lines else "NONE"

def main():
    errors = []

    # Valid whitespace: space, \t, \n, \r
    valid_cases = [
        (" \t\r\n42 \t\r\n", "valid whitespace around number"),
        (" \t{\"key\"\r\n:\t[1,\n 2\r]} \n", "valid whitespace inside structure"),
        ("[\n1,\n2\n]", "newlines in array"),
    ]
    for inp, desc in valid_cases:
        ok, msg = run_test(inp)
        if not ok:
            print(f"FAIL: {desc}: {msg}")
            errors.append(desc)
        else:
            print(f"PASS: {desc}")

    # Invalid whitespace: \x0b (vertical tab) and \x0c (form feed)
    invalid_cases = [
        ("\x0b42", "leading vertical tab \x0b"),
        ("42\x0b", "trailing vertical tab \x0b"),
        ("[1,\x0b2]", "vertical tab \x0b between array elements"),
        ("{\"a\":\x0b1}", "vertical tab \x0b between key and value"),
        ("\x0c[1, 2]", "leading form feed \x0c"),
        ("[1, 2]\x0c", "trailing form feed \x0c"),
        ("[1\x0c, 2]", "form feed \x0c between elements"),
        ("{\"a\"\x0c: 1}", "form feed \x0c between key and colon"),
    ]
    for inp, desc in invalid_cases:
        ok, msg = run_test(inp)
        if ok:
            print(f"FAIL: {desc} was accepted but should fail")
            errors.append(desc)
        else:
            print(f"PASS: {desc} correctly rejected ({msg})")

    if errors:
        sys.exit(1)
    print("PASS: all whitespace tests")
    sys.exit(0)

if __name__ == "__main__":
    main()
