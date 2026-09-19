#!/usr/bin/env python3
import sys
import subprocess

def main():
    # 1.5 must parse successfully
    cmd = """cat << 'EOF' > /tmp/input_f3.json\n1.5\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f3.json bend tests/harness.bend"""
    r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
    lines = r.stdout.splitlines()
    if not lines or lines[0] != "OK":
        print(f"FAIL: 1.5 did not parse: {lines}")
        sys.exit(1)
    print("PASS: F3")
    sys.exit(0)

if __name__ == "__main__":
    main()
