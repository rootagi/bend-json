#!/usr/bin/env python3
import time
import subprocess
import json

def run_ssh(cmd, timeout=300):
    return subprocess.run(["/tmp/vm_ssh.sh", cmd], capture_output=True, text=True, timeout=timeout)

def test_scale():
    print("=== Testing F5: Scale Benchmark ===")
    
    # 1. Strings: 30k, 60k, 120k
    print("--- String Scaling ---")
    str_times = {}
    for size in [30000, 60000, 120000]:
        # Generate raw string json
        s = '"' + "a" * size + '"'
        cmd = f"""cat << 'EOF' > /tmp/str_{size}.json\n{s}\nEOF\ncd /root/bend && /usr/bin/time -f '%e' bend tests/harness.bend < /dev/null 2>&1"""
        # Actually harness needs JSON_IN
        cmd = f"""cat << 'EOF' > /tmp/str_{size}.json\n{s}\nEOF\ncd /root/bend && JSON_IN=/tmp/str_{size}.json /usr/bin/time -f '%e' bend tests/harness.bend 2>&1"""
        t0 = time.time()
        res = run_ssh(cmd, timeout=180)
        elapsed = time.time() - t0
        # Parse output
        lines = res.stdout.strip().splitlines()
        last_line = lines[-1] if lines else "N/A"
        try:
            time_val = float(last_line)
        except ValueError:
            time_val = elapsed
        str_times[size] = time_val
        print(f"  String {size}: {time_val:.2f}s (output: {lines[0] if lines else 'NONE'})")
    
    if 30000 in str_times and 60000 in str_times and 120000 in str_times:
        r1 = str_times[60000] / max(str_times[30000], 0.001)
        r2 = str_times[120000] / max(str_times[60000], 0.001)
        print(f"  String Doubling ratios: 30k->60k: {r1:.2f}x, 60k->120k: {r2:.2f}x")

    # 2. Arrays: 25k, 50k, 100k, 200k, 400k
    print("--- Array Scaling ---")
    arr_times = {}
    for size in [25000, 50000, 100000]: # test up to 100k first
        # Write array directly via python in VM to save ssh bandwidth
        cmd = f"""python3 -c '
with open("/tmp/arr_{size}.json", "w") as f:
    f.write("[" + ",".join(["1"] * {size}) + "]")
' && cd /root/bend && JSON_IN=/tmp/arr_{size}.json /usr/bin/time -f '%e' bend tests/harness.bend 2>&1"""
        t0 = time.time()
        res = run_ssh(cmd, timeout=180)
        elapsed = time.time() - t0
        lines = res.stdout.strip().splitlines()
        last_line = lines[-1] if lines else "N/A"
        try:
            time_val = float(last_line)
        except ValueError:
            time_val = elapsed
        arr_times[size] = time_val
        print(f"  Array {size}: {time_val:.2f}s (output: {lines[0] if lines else 'NONE'})")

    print(f"F5 Baseline Recorded.\n")

if __name__ == "__main__":
    test_scale()
