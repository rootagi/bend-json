#!/usr/bin/env python3
import sys
import subprocess

def main():
    # 007 and {"a":1,} must fail
    errors = []
    for inp in ["007", '{"a":1,}']:
        cmd = f"""cat << 'EOF' > /tmp/input_f4.json\n{inp}\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f4.json bend tests/harness.bend"""
        r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
        lines = r.stdout.splitlines()
        if lines and lines[0] == "OK":
            errors.append(f"{inp} was accepted but must fail")
    if errors:
        for e in errors:
            print("FAIL:", e)
        sys.exit(1)
    print("PASS: F4")
    sys.exit(0)

if __name__ == "__main__":
    main()
