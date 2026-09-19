import os
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def run_bend(input_path, timeout=300):
    env = {**os.environ, "JSON_IN": str(input_path)}
    return subprocess.run(["bend", "tests/harness.bend"], cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=timeout)

def test_scale():
    print("=== Testing F5: Scale Benchmark ===")
    
    # 1. Strings: 30k, 60k, 120k
    print("--- String Scaling ---")
    str_times = {}
    for size in [30000, 60000, 120000]:
        input_file = Path(f"/tmp/str_{size}.json")
        input_file.write_text('"' + "a" * size + '"')
        t0 = time.time()
        res = run_bend(input_file, timeout=180)
        elapsed = time.time() - t0
        lines = res.stdout.strip().splitlines()
        str_times[size] = elapsed
        print(f"  String {size}: {elapsed:.2f}s (output: {lines[0] if lines else 'NONE'})")
    
    if 30000 in str_times and 60000 in str_times and 120000 in str_times:
        r1 = str_times[60000] / max(str_times[30000], 0.001)
        r2 = str_times[120000] / max(str_times[60000], 0.001)
        print(f"  String Doubling ratios: 30k->60k: {r1:.2f}x, 60k->120k: {r2:.2f}x")

    # 2. Arrays: 25k, 50k, 100k
    print("--- Array Scaling ---")
    arr_times = {}
    for size in [25000, 50000, 100000]:
        input_file = Path(f"/tmp/arr_{size}.json")
        input_file.write_text("[" + ",".join(["1"] * size) + "]")
        t0 = time.time()
        res = run_bend(input_file, timeout=180)
        elapsed = time.time() - t0
        lines = res.stdout.strip().splitlines()
        arr_times[size] = elapsed
        print(f"  Array {size}: {elapsed:.2f}s (output: {lines[0] if lines else 'NONE'})")

    print(f"F5 Baseline Recorded.\n")

if __name__ == "__main__":
    test_scale()
