#!/usr/bin/env python3
import sys
import subprocess

def main():
    # depth 15 with step 2: must have 30 leading spaces
    nested = '{"a":' * 15 + '1' + '}' * 15
    cmd = f"""cat << 'EOF' > /tmp/input_f6.json\n{nested}\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f6.json bend tests/harness.bend"""
    r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
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
