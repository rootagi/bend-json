#!/usr/bin/env python3
import sys
import subprocess

def main():
    # 281474976710656 (2^48) must fail gracefully with FAIL:, never abort/crash
    cmd = """cat << 'EOF' > /tmp/input_f2.json\n281474976710656\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f2.json bend tests/harness.bend"""
    r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
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
