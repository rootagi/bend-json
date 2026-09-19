#!/usr/bin/env python3
import sys
import subprocess

def main():
    errors = []
    # Should fail
    should_fail = [
        "007", "-", "[-]", "-01", "1.e2",
        '{"a":1,}', "[1,]", "[,1]", "{,}",
        r'"\q"', r'"\u12"', r'"\uZZZZ"', r'"\ud83d"',
        '"\x01"'
    ]
    for inp in should_fail:
        cmd = f"""cat << 'EOF' > /tmp/input_f4.json\n{inp}\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f4.json bend tests/harness.bend"""
        r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
        lines = r.stdout.splitlines()
        if lines and lines[0] == "OK":
            errors.append(f"Expected failure for {inp}, but got OK")

    # Should pass
    should_pass = [
        r'"\u0041"', r'"\ud83d\ude00"', r'"\b \f \/"'
    ]
    for inp in should_pass:
        cmd = f"""cat << 'EOF' > /tmp/input_f4.json\n{inp}\nEOF\ncd /root/bend && JSON_IN=/tmp/input_f4.json bend tests/harness.bend"""
        r = subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True)
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
