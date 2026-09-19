#!/usr/bin/env python3
import sys
import os
import subprocess
import json
import time
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent

def run_ssh(cmd, timeout=120):
    return subprocess.run(
        ["/tmp/vm_ssh.sh", cmd],
        capture_output=True,
        text=True,
        timeout=timeout
    )

def sync():
    subprocess.run([str(REPO_DIR / "tools" / "sync.sh")], check=True)

def run_harness(json_str, ptr=None, timeout=60):
    # Write to a temp file in VM
    escaped_json = json_str.replace("'", "'\"'\"'")
    setup_cmd = f"cat << 'EOF_JSON' > /tmp/input.json\n{json_str}\nEOF_JSON\n"
    run_cmd = f"cd /root/bend && JSON_IN=/tmp/input.json "
    if ptr is not None:
        run_cmd += f"JSON_PTR='{ptr}' bend tests/test_pointer.bend"
    else:
        run_cmd += f"bend tests/harness.bend"
    full_cmd = setup_cmd + run_cmd
    return run_ssh(full_cmd, timeout=timeout)

def test_f1():
    print("=== Testing F1: Fuel limit in stringify/pretty ===")
    results = {}
    
    # 1. Array of N ones
    for N in [999, 1000, 1001, 5000]:
        arr_json = "[" + ",".join(["1"] * N) + "]"
        expected_len = 2 * N + 1 # e.g. [1] is 3, [1,1] is 5
        res = run_harness(arr_json, timeout=120)
        lines = res.stdout.splitlines()
        is_ok = len(lines) > 0 and lines[0] == "OK"
        stringify_out = ""
        if "--- STRINGIFY ---" in lines:
            idx = lines.index("--- STRINGIFY ---")
            if idx + 1 < len(lines):
                stringify_out = lines[idx + 1]
        
        actual_len = len(stringify_out)
        ends_with_bracket = stringify_out.endswith("]")
        print(f"  Array N={N}: parsed={is_ok}, str_len={actual_len} (expected {expected_len}), ends_with_]='{ends_with_bracket}'")
        results[f"arr_{N}"] = (is_ok and actual_len == expected_len and ends_with_bracket)

    # 2. Object with 1500 keys
    obj_dict = {f"k{i}": 1 for i in range(1500)}
    obj_json = json.dumps(obj_dict)
    res = run_harness(obj_json, timeout=120)
    lines = res.stdout.splitlines()
    is_ok = len(lines) > 0 and lines[0] == "OK"
    str_ok = False
    if "--- STRINGIFY ---" in lines:
        idx = lines.index("--- STRINGIFY ---")
        if idx + 1 < len(lines):
            str_ok = lines[idx + 1].endswith("}")
    print(f"  Object 1500 keys: parsed={is_ok}, stringify_ends_with_}}={str_ok}")
    results["obj_1500"] = (is_ok and str_ok)

    # 3. Nesting depth 1500
    nested_json = "[" * 1500 + "1" + "]" * 1500
    res = run_harness(nested_json, timeout=120)
    lines = res.stdout.splitlines()
    is_ok = len(lines) > 0 and lines[0] == "OK"
    str_ok = False
    if "--- STRINGIFY ---" in lines:
        idx = lines.index("--- STRINGIFY ---")
        if idx + 1 < len(lines):
            str_ok = lines[idx + 1].endswith("]" * 1500)
    print(f"  Nesting 1500: parsed={is_ok}, stringify_ok={str_ok}")
    results["nest_1500"] = (is_ok and str_ok)

    # 4. 5000-char string
    s_5000 = '"' + "a" * 5000 + '"'
    res = run_harness(s_5000, timeout=120)
    lines = res.stdout.splitlines()
    is_ok = len(lines) > 0 and lines[0] == "OK"
    str_ok = False
    if "--- STRINGIFY ---" in lines:
        idx = lines.index("--- STRINGIFY ---")
        if idx + 1 < len(lines):
            str_ok = (len(lines[idx + 1]) == 5002)
    print(f"  String 5000 chars: parsed={is_ok}, stringify_len_5002={str_ok}")
    results["str_5000"] = (is_ok and str_ok)

    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F1 Result: {status}\n")
    return status

def test_f2():
    print("=== Testing F2: Integer overflow (2^48 - 1) ===")
    tests = [
        ("281474976710655", True, "2^48-1"),
        ("281474976710656", False, "2^48"),
        ("-281474976710656", False, "-2^48"),
        ("99999999999999999999", False, "large int"),
        ("[123456789012345678901234567890]", False, "array with huge int")
    ]
    results = {}
    for inp, expect_ok, desc in tests:
        res = run_harness(inp)
        lines = res.stdout.splitlines()
        is_ok = len(lines) > 0 and lines[0] == "OK"
        print(f"  {desc} ({inp[:20]}...): output={lines[0] if lines else 'NONE (exit ' + str(res.returncode) + ')'}")
        results[desc] = (is_ok == expect_ok)

    # Test pointer
    res_ptr = run_harness('{"281474976710656": 1}', ptr="/281474976710656")
    lines_ptr = res_ptr.stdout.splitlines()
    ptr_ok = any("PTR_NONE" in line for line in lines_ptr)
    print(f"  Pointer /281474976710656: output={lines_ptr}")
    results["pointer_overflow"] = ptr_ok

    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F2 Result: {status}\n")
    return status

def test_f3():
    print("=== Testing F3: Decimals and scientific notation ===")
    should_pass = ["1.5", "-0.25", "1e10", "1E-2", "0.0", "-0", "12.5e+3"]
    should_fail = ["1.", ".5", "1e", "+1", "1e+"]
    results = {}
    for s in should_pass:
        res = run_harness(s)
        lines = res.stdout.splitlines()
        passed = (len(lines) > 0 and lines[0] == "OK")
        print(f"  Should pass: {s} -> {lines[0] if lines else 'NONE'}")
        results[s] = passed
    for s in should_fail:
        res = run_harness(s)
        lines = res.stdout.splitlines()
        passed = (len(lines) > 0 and lines[0].startswith("FAIL"))
        print(f"  Should fail: {s} -> {lines[0] if lines else 'NONE'}")
        results[s] = passed

    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F3 Result: {status}\n")
    return status

def test_f4a():
    print("=== Testing F4a: Strict number grammar ===")
    should_fail = ["007", "-", "[-]", "-01", "1.e2"]
    results = {}
    for s in should_fail:
        res = run_harness(s)
        lines = res.stdout.splitlines()
        passed = (len(lines) > 0 and lines[0].startswith("FAIL"))
        print(f"  Should fail: {s} -> {lines[0] if lines else 'NONE'}")
        results[s] = passed
    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F4a Result: {status}\n")
    return status

def test_f4b():
    print("=== Testing F4b: Trailing and leading commas ===")
    should_fail = ['{"a":1,}', "[1,]", "[,1]", "{,}"]
    results = {}
    for s in should_fail:
        res = run_harness(s)
        lines = res.stdout.splitlines()
        passed = (len(lines) > 0 and lines[0].startswith("FAIL"))
        print(f"  Should fail: {s} -> {lines[0] if lines else 'NONE'}")
        results[s] = passed
    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F4b Result: {status}\n")
    return status

def test_f4c():
    print("=== Testing F4c: Escape sequences and surrogate pairs ===")
    tests = [
        (r'"\u0041"', "OK", "unicode escape"),
        (r'"\ud83d\ude00"', "OK", "surrogate pair"),
        (r'"\b \f \/"', "OK", "escapes b, f, /"),
        (r'"\q"', "FAIL", "invalid escape \\q"),
        (r'"\u12"', "FAIL", "short \\u12"),
        (r'"\uZZZZ"', "FAIL", "non-hex \\uZZZZ"),
        (r'"\ud83d"', "FAIL", "lone surrogate")
    ]
    results = {}
    for s, expected_prefix, desc in tests:
        res = run_harness(s)
        lines = res.stdout.splitlines()
        actual = lines[0] if lines else "EMPTY"
        passed = actual.startswith(expected_prefix)
        print(f"  {desc} ({s}) -> {actual}")
        results[desc] = passed
    all_passed = all(results.values())
    status = "CONFIRMED" if not all_passed else "NOT REPRODUCED"
    print(f"F4c Result: {status}\n")
    return status

def test_f4d():
    print("=== Testing F4d: Control characters < 0x20 in strings ===")
    # Raw byte 0x01 inside string
    raw_ctrl = '"\x01"'
    res = run_harness(raw_ctrl)
    lines = res.stdout.splitlines()
    actual = lines[0] if lines else "EMPTY"
    passed = actual.startswith("FAIL")
    print(f"  Raw 0x01 inside string: {actual} (expected FAIL)")
    status = "CONFIRMED" if not passed else "NOT REPRODUCED"
    print(f"F4d Result: {status}\n")
    return status

def test_f6():
    print("=== Testing F6: Indentation depth 0..64 and step 0,1,2,4,8 ===")
    # Depth 15 with step 2
    # Today make_custom_indent fuel is 10n, so depth 15 will have wrong indent
    nested = '{"a":' * 15 + '1' + '}' * 15
    res = run_harness(nested)
    lines = res.stdout.splitlines()
    passed = False
    if "--- PRETTY ---" in lines:
        pretty_lines = lines[lines.index("--- PRETTY ---") + 1:]
        # Find line with 1
        for pl in pretty_lines:
            if "1" in pl:
                leading_spaces = len(pl) - len(pl.lstrip(" "))
                print(f"  Depth 15 step 2: leading spaces = {leading_spaces} (expected 30)")
                passed = (leading_spaces == 30)
                break
    status = "CONFIRMED" if not passed else "NOT REPRODUCED"
    print(f"F6 Result: {status}\n")
    return status

def test_f7():
    print("=== Testing F7: check_readme.py ===")
    r = subprocess.run([str(REPO_DIR / "tools" / "check_readme.py")], capture_output=True, text=True)
    print(r.stdout.strip())
    # Should fail today
    status = "CONFIRMED" if r.returncode != 0 else "NOT REPRODUCED"
    print(f"F7 Result: {status}\n")
    return status

def main():
    sync()
    findings = {}
    findings["F1"] = test_f1()
    findings["F2"] = test_f2()
    findings["F3"] = test_f3()
    findings["F4a"] = test_f4a()
    findings["F4b"] = test_f4b()
    findings["F4c"] = test_f4c()
    findings["F4d"] = test_f4d()
    findings["F6"] = test_f6()
    findings["F7"] = test_f7()
    print("=== SUMMARY OF REPRODUCTIONS ===")
    for k, v in findings.items():
        print(f"{k}: {v}")

if __name__ == "__main__":
    main()
