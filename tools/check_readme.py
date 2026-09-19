#!/usr/bin/env python3
import sys
import re
from pathlib import Path

repo_dir = Path(__file__).resolve().parent.parent
readme_file = repo_dir / "README.md"
laws_file = repo_dir / "LAWS.bend"
json_file = repo_dir / "json.bend"

def check():
    errors = []
    
    readme_text = readme_file.read_text()
    laws_text = laws_file.read_text()
    json_text = json_file.read_text()
    
    # 1. Check law count
    actual_law_count = len(re.findall(r"^law\s+", laws_text, re.MULTILINE))
    # Look for law count in README
    m = re.search(r"(\d+)\s+formal laws in", readme_text)
    if m:
        readme_law_count = int(m.group(1))
        if readme_law_count != actual_law_count:
            errors.append(f"README law count ({readme_law_count}) != LAWS.bend law count ({actual_law_count})")
    else:
        errors.append("Could not find law count in README.md")

    # 2. Check README listed laws
    # Laws mentioned in README section "Verified Laws Overview":
    # get_bool_sound, arr_map_id, arr_set_preserves_length, empty-merge identity
    suspect_laws = [
        "get_bool_sound",
        "arr_map_id",
        "arr_set_preserves_length",
        "merge_empty_id" # or empty merge identity
    ]
    for law in suspect_laws:
        # Check if mentioned in README
        if law in readme_text:
            if f"law {law}" not in laws_text:
                errors.append(f"README lists law '{law}' but it is not defined in LAWS.bend")
        elif "empty merge" in readme_text.lower() or "empty-merge" in readme_text.lower():
            if "empty" not in laws_text.lower():
                errors.append("README mentions empty merge identity but it is not in LAWS.bend")

    # Specifically check the ones noted in review:
    # `get_bool_sound`, `arr_map_id`, `arr_set_preserves_length`, empty-merge identity
    if "arr_map_id" in readme_text and "arr_map_id" not in laws_text:
        errors.append("README mentions arr_map_id but missing in LAWS.bend")
    if "arr_set_preserves_length" in readme_text and "arr_set_preserves_length" not in laws_text:
        errors.append("README mentions arr_set_preserves_length but missing in LAWS.bend")
    if "get_bool" in readme_text and "get_bool_sound" not in laws_text and "get_bool" in readme_text:
        pass

    # 3. Check "without allocating"
    if "without allocating" in readme_text:
        # Check if validate calls parse(s)
        if "def validate(s: String)" in json_text and "parse(s)" in json_text:
            errors.append("README claims validate runs 'without allocating intermediate AST', but validate calls parse(s)")

    # 4. Check "Full JSON AST"
    if "Full JSON AST" in readme_text:
        # Check if JRaw or JDec exists in json.bend
        if "JRaw" not in json_text and "JDec" not in json_text:
            errors.append("README claims 'Full JSON AST' but numbers only support Nat/Neg Nat (no float/decimal/exponent AST)")

    # 5. Check "for all"
    if "for all" in readme_text.lower():
        # Check if universal quantification exists in LAWS.bend or if all laws are ground terms
        # In LAWS.bend, do we have any 'for x: ...' ?
        if "for " not in laws_text:
            errors.append("README claims properties hold 'for all', but LAWS.bend contains only ground example instances, not universal laws")

    if errors:
        print("FAIL: check_readme.py found consistency errors:")
        for err in errors:
            print(f"  - {err}")
        return False
    else:
        print("OK: check_readme.py passed")
        return True

if __name__ == "__main__":
    if not check():
        sys.exit(1)
