#!/usr/bin/env python3
"""
Independent conformance / differential test-suite for bend-json.

  python3 tests/run_tests.py                       # uses `bend` on PATH
  BEND="bun /path/to/bend2/main.ts" python3 tests/run_tests.py
  python3 tests/run_tests.py --filter fuzz --jobs 8

How it works
  * Python's `json` module is the oracle (strict: no NaN/Infinity, no dup-key collapsing).
  * Every case runs in its OWN bend process, so a runtime abort (e.g. a stack overflow
    or a Nat overflow) is reported as CRASH instead of hiding the rest of the suite.
  * Cases are RFC 8259 conformance, integer/decimal numbers, string escapes, scale,
    depth, and a seeded random-document fuzzer.  tests/api_checks.bend covers
    JSON Pointer (RFC 6901), objects, arrays, extractors and NDJSON.

Exit code 0 only if every non-"stretch" case passes.
"""
import argparse, concurrent.futures as cf, json, os, random, re, shlex, subprocess, sys, tempfile, time

sys.setrecursionlimit(100000)
HERE = os.path.dirname(os.path.abspath(__file__))

# --------------------------------------------------------------------------- oracle
class Obj(list):
    """A JSON object as an ordered list of (key, value) pairs (keeps duplicates)."""

def _reject(x):
    raise ValueError("non-standard constant " + x)

def oracle(b: bytes):
    return json.loads(b.decode("utf-8"), object_pairs_hook=Obj, parse_constant=_reject)

def oracle_ok(b: bytes) -> bool:
    try:
        oracle(b)
        return True
    except Exception:
        return False

def strict_eq(a, b) -> bool:
    if isinstance(a, Obj) or isinstance(b, Obj):
        if not (isinstance(a, Obj) and isinstance(b, Obj)) or len(a) != len(b):
            return False
        return all(x[0] == y[0] and strict_eq(x[1], y[1]) for x, y in zip(a, b))
    if type(a) is not type(b):
        return False
    if isinstance(a, list):
        return len(a) == len(b) and all(strict_eq(x, y) for x, y in zip(a, b))
    return a == b

# --------------------------------------------------------------------------- bend harness
TEMPLATE = """import Base
import ../../json.bend as Json

def emit(r: Result<&2, &2, String, Json.Json>) -> String:
  match r:
    case Done{+v}:
      __OK__
    case Fail{err}:
      "STATUS:FAIL " ++ err

def analyze(+data: String) -> IO(Unit):
  do IO<Unit>:
    IO.print("VALIDATE:" ++ Bool.show(Json.validate(data)))
    IO.print(emit(Json.parse(data)))

law run_go:
  for m: File & Result<&1, &1, (U32 & String), String>
  IO(Unit)

def run_go(m):
  (f, r) = m
  do IO<Unit>:
    data : String <- IO.pass(String, r)
    x    : Unit   <- File.close(f)
    analyze(data)

def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("__PATH__", "r"))
    m : File & Result<&1, &1, (U32 & String), String> <- File.read(f, 400000000)
    run_go(m)
"""
OK_PRETTY = ('"STATUS:OK\\nCOMPACT:" ++ Json.stringify(v) ++ "\\nPRETTY:" ++ Json.pretty(v)'
             ' ++ "\\nEND_PRETTY\\nPRETTY4:" ++ Json.pretty_indent(v, 4n) ++ "\\nEND_PRETTY4"')
OK_COMPACT = '"STATUS:OK\\nCOMPACT:" ++ Json.stringify(v)'


class Case:
    def __init__(self, name, data, kind, pretty=True, canon=False, ptext=False, stretch=False, timeout=120,
                 no_oracle=False):
        self.name, self.data, self.kind = name, data if isinstance(data, bytes) else data.encode("utf-8"), kind
        self.pretty, self.canon, self.ptext, self.stretch, self.timeout = pretty, canon, ptext, stretch, timeout
        self.no_oracle = no_oracle   # data too deep for Python's json: check exact text instead


def run_bend(bend_cmd, repo, gen_dir, case):
    base = re.sub(r"[^A-Za-z0-9_.-]", "_", case.name)
    data_path = os.path.join(gen_dir, base + ".json")
    src_path = os.path.join(gen_dir, base + ".bend")
    with open(data_path, "wb") as f:
        f.write(case.data)
    with open(src_path, "w") as f:
        f.write(TEMPLATE.replace("__OK__", OK_PRETTY if case.pretty else OK_COMPACT).replace("__PATH__", data_path))
    t0 = time.time()
    try:
        p = subprocess.run(shlex.split(bend_cmd) + [src_path], cwd=repo, capture_output=True, timeout=case.timeout)
        out = (p.stdout + p.stderr).decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "", time.time() - t0
    return "RAN", out, time.time() - t0


def parse_out(out):
    v = re.search(r"^VALIDATE:(True|False)\s*$", out, re.M)
    s = re.search(r"^STATUS:(OK|FAIL)(.*)$", out, re.M)
    res = {"validate": (v.group(1) == "True") if v else None, "status": s.group(1) if s else None,
           "msg": s.group(2).strip() if s else out[:200].replace("\n", " ")}
    if res["status"] == "OK":
        body = out[out.index("COMPACT:") + 8:]
        if "\nPRETTY:" in body:
            compact, rest = body.split("\nPRETTY:", 1)
            pretty, rest = rest.split("\nEND_PRETTY\nPRETTY4:", 1)
            pretty4 = rest.split("\nEND_PRETTY4", 1)[0]
        else:
            compact, pretty, pretty4 = body.rstrip("\n"), None, None
        res.update(compact=compact, pretty=pretty, pretty4=pretty4)
    return res


def judge(case, out):
    r = parse_out(out)
    if r["status"] is None:
        return "CRASH", "no result: " + r["msg"]
    orc_ok = oracle_ok(case.data)
    if case.kind == "invalid":
        if r["status"] != "FAIL":
            return "FAIL", "accepted invalid JSON"
        if r["validate"] is not False:
            return "FAIL", "validate() returned True for invalid JSON"
        return "PASS", ""
    if case.kind == "equal_or_fail":
        if r["status"] == "FAIL":
            return ("PASS", "") if r["validate"] is False else ("FAIL", "validate/parse disagree")
    elif r["status"] != "OK":
        return "FAIL", "rejected valid JSON: " + r["msg"]
    if (r["validate"] is True) != (r["status"] == "OK"):
        return "FAIL", "validate() disagrees with parse()"
    if case.no_oracle:
        assert case.canon, "no_oracle cases must be canonical"
        if r["compact"] != case.data.decode("utf-8"):
            return "FAIL", "compact output not byte-identical to input (len %d vs %d)" % (len(r["compact"]), len(case.data))
        return "PASS", ""
    if not orc_ok:
        return "FAIL", "test bug: oracle rejects data"
    want = oracle(case.data)
    for label in ("compact", "pretty", "pretty4"):
        text = r.get(label)
        if text is None:
            continue
        try:
            got = oracle(text.encode("utf-8"))
        except Exception as e:
            return "FAIL", "%s output is not valid JSON (%s); starts %r ... ends %r" % (
                label, str(e)[:60], text[:40], text[-40:])
        if not strict_eq(got, want):
            return "FAIL", "%s output differs semantically from input" % label
    if case.canon and r["compact"] != case.data.decode("utf-8"):
        return "FAIL", "compact output not byte-identical to canonical input (len %d vs %d)" % (
            len(r["compact"]), len(case.data))
    if case.ptext and r.get("pretty") is not None:
        for label, ind in (("pretty", 2), ("pretty4", 4)):
            exp = json.dumps(json.loads(case.data.decode("utf-8")), indent=ind, ensure_ascii=False)
            if r[label] != exp:
                return "FAIL", "%s text differs from json.dumps(indent=%d)" % (label, ind)
    return "PASS", ""

# --------------------------------------------------------------------------- manifest
def build_cases():
    C = []
    def eq(name, s, **kw):      C.append(Case("eq_" + name, s, "equal", **kw))
    def bad(name, s, **kw):     C.append(Case("bad_" + name, s, "invalid", **kw))
    def eqf(name, s, **kw):     C.append(Case("eqf_" + name, s, "equal_or_fail", **kw))

    # ---- valid documents (semantic + canonical text where the input is canonical)
    for n, s in [("null", "null"), ("true", "true"), ("false", "false"), ("zero", "0"), ("int", "42"), ("neg", "-7"),
                 ("max48", "281474976710655"), ("min48", "-281474976710655"), ("empty_str", '""'),
                 ("str", '"hello"'), ("empty_arr", "[]"), ("empty_obj", "{}"), ("arr", "[1,2,3]"),
                 ("obj", '{"a":1}'), ("mixed", '{"a":[1,{"b":null}],"c":"x","d":true,"e":false}'),
                 ("empty_key", '{"":1}'), ("nested_empty", '[[],{},[[]],{"a":{}}]'),
                 ("raw_unicode", '"h\u00e9llo \u2713 \u65e5\u672c\u8a9e \U0001F600"'),
                 ("bigstr_escapes", '"\\"\\\\\\n\\r\\t"')]:
        eq(n, s, canon=True, ptext=True)
    eq("dup_keys", '{"a":1,"a":2}', canon=True)                       # order + duplicates preserved
    for n, s in [("ws_all_kinds", ' \t\r\n[ \t\r\n1 \t\r\n, \t\r\n2 \t\r\n] \t\r\n'), ("ws_obj", ' { "a" : 1 , "b" : [ ] } '),
                 ("esc_slash", '"a\\/b"'), ("esc_bf", '"\\b\\f"'), ("esc_u_basic", '"\\u0041\\u00e9\\u2713"'),
                 ("esc_u_upper", '"\\u00E9\\u00Ff"'), ("esc_surrogate_pair", '"\\ud83d\\ude00"'),
                 ("esc_surrogate_upper", '"\\uD83D\\uDE00"'), ("esc_nul", '"\\u0000"'),
                 ("esc_ctrl_range", '"\\u0001\\u001f\\u007f"'), ("esc_key", '{"a\\"b":1,"\\u00e9":2,"\\n":3}'),
                 ("esc_u_in_row", '"\\u0041\\u0042\\u0043"'), ("pair_then_text", '"x\\ud83d\\ude00y"'),
                 ("neg_zero", "-0"), ("nonbmp_key", '{"\U0001F600":"\U0010FFFF"}'),
                 ("u2028", '"\u2028\u2029"'), ("bmp_edge", '"\\uffff\\ufffe"'),
                 # numbers: integers, decimals, exponents (all valid RFC 8259)
                 ("dec", "1.5"), ("dec_neg", "-0.25"), ("dec_in_arr", "[1.5, 2, -3.75e2]"), ("exp", "1e10"),
                 ("exp_upper_plus", "1E+2"), ("exp_neg", "2.5e-3"), ("zero_dec", "0.0"), ("zero_exp", "0e0"),
                 ("neg_dec_exp", "-1.5e-10"), ("many_digits", "3.14159265358979323846264338327950288"),
                 ("dec_obj", '{"price":19.99,"qty":3,"rate":-0.5e-2}')]:
        eq(n, s)
    # ---- numbers beyond the 2^48 fast path: must be preserved exactly or rejected cleanly, never crash
    for n, s in [("2p48", "281474976710656"), ("2p64", "18446744073709551616"), ("neg_2p48", "-281474976710656"),
                 ("huge39", "9" * 39), ("neg_huge39", "-" + "9" * 39), ("in_arr", "[281474976710656, 1]"),
                 ("in_obj", '{"n":281474976710656}'), ("huge_dec", "1" + "0" * 30 + ".5"), ("exp_huge", "1e999999")]:
        eqf("bignum_" + n, s)
    eqf("lone_high_surrogate", '"\\ud800"')
    eqf("lone_low_surrogate", '"\\udc00"')
    eqf("high_then_non_low", '"\\ud800\\u0041"')

    # ---- invalid documents (all rejected by the Python oracle too)
    for n, s in [("empty", ""), ("ws_only", "   \n"), ("nul", "nul"), ("nulll", "nulll"), ("truex", "truex"),
                 ("True_cap", "True"), ("NULL_cap", "NULL"), ("trail_comma_arr", "[1,]"), ("lead_comma_arr", "[,1]"),
                 ("missing_comma", "[1 2]"), ("trail_comma_obj", '{"a":1,}'), ("lone_comma_obj", "{,}"),
                 ("missing_colon", '{"a" 1}'), ("unquoted_key", "{a:1}"), ("single_quotes", "{'a':1}"),
                 ("unclosed_arr", "[1"), ("unclosed_obj", '{"a":1'), ("unclosed_str", '"abc'), ("bad_escape_q", '"a\\qb"'),
                 ("bad_escape_x", '"\\x41"'), ("short_u", '"\\u12"'), ("bad_hex_u", '"\\u12G4"'), ("u_eof", '"\\u"'),
                 ("raw_tab", '"a\tb"'), ("raw_newline", '"a\nb"'), ("raw_ctrl01", '"a\x01b"'), ("raw_nul", '"a\x00b"'),
                 ("lead_zero", "007"), ("lead_zero_neg", "-01"), ("lone_minus", "-"), ("minus_in_arr", "[-]"),
                 ("double_minus", "--1"), ("plus", "+1"), ("dot_lead", ".5"), ("dot_trail", "1."), ("dot_e", "1.e5"),
                 ("exp_no_digits", "1e"), ("exp_sign_only", "1e+"), ("hex", "0x10"), ("underscore", "1_000"),
                 ("space_in_num", "- 1"), ("two_values", "1 2"), ("extra_close", "[1]]"), ("trailing_junk", "[1] x"),
                 ("nan", "NaN"), ("infinity", "Infinity"), ("neg_infinity", "-Infinity"), ("line_comment", "[1] // c"),
                 ("block_comment", "/* c */ [1]"), ("formfeed_prefix", "\x0c[1]"), ("vtab_prefix", "\x0b[1]"),
                 ("nbsp_prefix", "\u00a0[1]"), ("ideographic_space", "\u3000[1]"), ("formfeed_suffix", "[1]\x0c"),
                 ("key_not_string", "{1:2}"), ("nested_unclosed", "[[[[1]]]"), ("colon_only", ":"), ("comma_only", ","),
                 ("close_only", "]"), ("obj_in_key", '{{"a":1}:2}'), ("arr_colon", "[1:2]"), ("obj_no_value", '{"a":}'),
                 ("dup_comma", "[1,,2]"), ("str_then_junk", '"a"b'), ("trailing_backslash", '"a\\"')]:
        bad(n, s)

    # ---- scale: correctness, not just "does not crash"
    eq("arr_1000_ints", "[" + ",".join(map(str, range(1000))) + "]", canon=True, ptext=True)
    eq("arr_5000_ints", "[" + ",".join(map(str, range(5000))) + "]", canon=True, ptext=True)
    eq("arr_20000_ints", "[" + ",".join(map(str, range(20000))) + "]", canon=True, ptext=True)
    eq("arr_5000_strings", "[" + ",".join('"s%d"' % i for i in range(5000)) + "]", canon=True, ptext=True)
    eq("obj_2000_keys", "{" + ",".join('"k%d":%d' % (i, i) for i in range(2000)) + "}", canon=True, ptext=True)
    eq("obj_5000_keys", "{" + ",".join('"k%d":%d' % (i, i) for i in range(5000)) + "}", canon=True, ptext=True)
    eq("deep_1200", "[" * 1200 + "]" * 1200, canon=True, ptext=True)
    eq("deep_obj_500", '{"a":' * 500 + "1" + "}" * 500, canon=True, ptext=True)
    eq("str_30k", '"' + "a" * 30000 + '"', canon=True, ptext=True)
    eq("str_100k", '"' + "a" * 100000 + '"', canon=True, ptext=True)
    eq("str_200k", '"' + "a" * 200000 + '"', canon=True, ptext=True, timeout=180)
    eq("str_escapes_20k", '"' + '\\n\\t\\"\\\\' * 5000 + '"', canon=True, ptext=True)
    eq("str_unicode_30k", '"' + "\u00e9\u2713\U0001F600" * 10000 + '"', canon=True, ptext=True)
    eq("arr_of_long_strings", "[" + ",".join('"' + "x" * 5000 + '"' for _ in range(20)) + "]", canon=True, ptext=True)
    C.append(Case("eq_deep_20000_compact", "[" * 20000 + "]" * 20000, "equal", pretty=False, canon=True,
                  no_oracle=True, timeout=180))
    C.append(Case("eq_arr_100k_compact", "[" + ",".join(["1"] * 100000) + "]", "equal", pretty=False, canon=True,
                  timeout=180))
    # stretch goals: reported, never fail the suite
    for n, d, kw in [("arr_400k_compact", "[" + ",".join(["1"] * 400000) + "]", {}),
                     ("str_1m", '"' + "a" * 1000000 + '"', {}),
                     ("deep_100k_compact", "[" * 100000 + "]" * 100000, {})]:
        C.append(Case("stretch_" + n, d, "equal", pretty=False, canon=True, stretch=True, timeout=180,
                      no_oracle=n.startswith("deep"), **kw))

    # ---- seeded random documents (differential fuzz vs Python json)
    alphabet = (list("abcXYZ019 _-.,:;!?/'[]{}~^|%$#@") + ['"', "\\", "\\", "/", "\x00", "\x01", "\x08", "\x0c", "\n",
                "\r", "\t", "\x1f", "\x7f", "\u00e9", "\u2713", "\u65e5", "\U0001F600", "\u2028", "\uffff", "\U0010FFFF"])
    def rstr(rng):
        return "".join(rng.choice(alphabet) for _ in range(rng.choice([0, 1, 2, 5, 12, 40])))
    def rval(rng, depth):
        c = rng.random()
        if depth <= 0 or c < 0.45:
            k = rng.randrange(7)
            if k == 0: return None
            if k == 1: return rng.random() < 0.5
            if k == 2: return rng.randrange(-(2**48 - 1), 2**48)
            if k == 3: return rng.randrange(-1000, 1000)
            if k == 4: return rng.uniform(-1e6, 1e6)
            if k == 5: return rng.choice([1e-7, 1.5e300, -2.5e-300, 0.1, 123456789.123456789, 1e16])
            return rstr(rng)
        if c < 0.75:
            return [rval(rng, depth - 1) for _ in range(rng.choice([0, 1, 2, 3, 6, 15]))]
        d = {}
        for _ in range(rng.choice([0, 1, 2, 4, 9])):
            d[rstr(rng)] = rval(rng, depth - 1)
        return d
    for seed in range(60):
        rng = random.Random(seed)
        doc = rval(rng, 5)
        ascii_only = seed % 2 == 0
        text = json.dumps(doc, ensure_ascii=ascii_only, separators=(",", ":") if seed % 3 else (", ", ": "))
        C.append(Case("eq_fuzz_%02d" % seed, text, "equal"))
    return C

# --------------------------------------------------------------------------- api checks
API_EXPECT = {
 "ptr_root": '{"foo":["bar","baz"],"":0,"a/b":1,"c%d":2,"e^f":3,"g|h":4,"i\\\\j":5,"k\\"l":6," ":7,"m~n":8}',
 "ptr_foo": '["bar","baz"]', "ptr_foo0": '"bar"', "ptr_foo1": '"baz"', "ptr_emptykey": "0", "ptr_slash": "1",
 "ptr_percent": "2", "ptr_caret": "3", "ptr_pipe": "4", "ptr_backslash": "5", "ptr_quote": "6", "ptr_space": "7",
 "ptr_tilde": "8", "ptr_unescape_order": "5",
 "obj_len": "2", "obj_has_a": "True", "obj_has_z": "False", "obj_get_b": "Some 1", "obj_set_new_get": "Some 3",
 "obj_set_new_len": "3", "obj_set_existing_get": "Some 9", "obj_set_existing_len": "2", "obj_remove_has": "False",
 "obj_remove_len": "1", "obj_remove_missing_len": "2", "obj_sorted_keys": "a,b,", "obj_get_on_array": "None",
 "obj_len_on_array": "0", "obj_get_str_wrongtype": "None", "obj_get_num_or_wrongtype": "77",
 "obj_get_bool_or_missing": "True",
 "merge_a": "Some 1", "merge_b": "Some 3", "merge_c": "Some 4", "merge_len": "3",
 "arr_len": "3", "arr_get1": "Some 2", "arr_get_oob": "None", "arr_push": "[1,2,3,4]", "arr_set_mid": "[1,9,3]",
 "arr_insert_front": "[0,1,2,3]", "arr_insert_mid": "[1,7,2,3]", "arr_insert_end": "[1,2,3,8]",
 "arr_remove_mid": "[1,3]", "arr_remove_first": "[2,3]", "arr_remove_last": "[1,2]", "arr_pop": "Some 3 / [1,2]",
 "arr_pop_empty": "None / []", "arr_len_on_object": "0",
 "pset_replace_arr": '{"a":[1,9],"b":{"k":1}}', "pset_replace_obj": '{"a":[1,2],"b":{"k":"v"}}',
 "nd_three": "Done 1|Done 2|Done 3|", "nd_trailing_newline": "Done 1|Done 2|", "nd_crlf": "Done 1|Done 2|",
 "nd_blank_lines": "Done 1|Done 2|", "nd_bad_line": "Done 1|Fail|Done 3|", "nd_empty": "",
 "nd_objects": 'Done {"a":1}|Done [2]|',
}
API_NEGATIVE_PTR = ["ptr_no_leading_slash", "ptr_leading_zero", "ptr_dash", "ptr_out_of_range", "ptr_negative",
                    "ptr_non_numeric", "ptr_bad_escape", "ptr_trailing_tilde", "ptr_missing", "ptr_into_scalar",
                    "ptr_trailing_slash"]
API_INFO = ["arr_oob_set", "arr_oob_remove", "arr_oob_insert", "pset_root"]   # semantics not specified: informational


def run_api(bend_cmd, repo, gen_dir):
    src = open(os.path.join(HERE, "api_checks.bend")).read().replace("import ../json.bend", "import ../../json.bend")
    path = os.path.join(gen_dir, "api_checks.bend")
    open(path, "w").write(src)
    p = subprocess.run(shlex.split(bend_cmd) + [path], cwd=repo, capture_output=True, timeout=300)
    out = (p.stdout + p.stderr).decode("utf-8", "replace")
    got = {}
    for line in out.split("\n"):
        if "=" in line:
            k, v = line.split("=", 1)
            got[k.strip()] = v
    m = re.search(r"nd_out_begin\n(.*?)nd_out_end", out, re.S)
    got["nd_out"] = m.group(1) if m else None
    res = []
    for k, exp in API_EXPECT.items():
        g = got.get(k)
        if g is None:
            res.append((k, "FAIL", "missing (crash or compile error?): " + out[:160].replace("\n", " ")))
            continue
        g = g[5:] if g.startswith("Some ") and not exp.startswith(("Some", "None", "Done")) and not k.startswith(
            ("nd_", "arr_", "obj_", "merge_", "pset_")) else g
        res.append((k, "PASS" if g == exp else "FAIL", "" if g == exp else "got %r expected %r" % (g, exp)))
    for k in API_NEGATIVE_PTR:
        g = got.get(k)
        res.append((k, "PASS" if g == "None" else "FAIL", "" if g == "None" else "got %r expected 'None'" % g))
    res.append(("nd_out", "PASS" if got.get("nd_out") == "1\n2\n" else "FAIL", "got %r" % got.get("nd_out")))
    info = {k: got.get(k) for k in API_INFO}
    return res, info

# --------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.path.dirname(HERE))
    ap.add_argument("--bend", default=os.environ.get("BEND", "bend"))
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--filter", default="")
    ap.add_argument("--no-stretch", action="store_true")
    ap.add_argument("--no-api", action="store_true")
    a = ap.parse_args()
    repo = os.path.abspath(a.repo)
    gen = os.path.join(repo, "tests", "_gen")
    os.makedirs(gen, exist_ok=True)

    cases = [c for c in build_cases() if a.filter in c.name and not (a.no_stretch and c.stretch)]
    for c in cases:
        if c.kind == "invalid" and oracle_ok(c.data):
            sys.exit("TEST BUG: oracle accepts 'invalid' case " + c.name)
    results, t0 = [], time.time()

    def work(c):
        st, out, dt = run_bend(a.bend, repo, gen, c)
        if st == "TIMEOUT":
            return c, "TIMEOUT", "exceeded %ds" % c.timeout, dt
        v, why = judge(c, out)
        return c, v, why, dt

    with cf.ThreadPoolExecutor(a.jobs) as ex:
        for c, v, why, dt in ex.map(work, cases):
            results.append((c, v, why, dt))
            mark = {"PASS": " ok ", "FAIL": "FAIL", "CRASH": "CRSH", "TIMEOUT": "TIME"}[v]
            if v != "PASS" or a.filter:
                print("[%s] %-34s %5.1fs %s%s" % (mark, c.name, dt, "(stretch) " if c.stretch else "", why), flush=True)

    hard = [r for r in results if not r[0].stretch]
    soft = [r for r in results if r[0].stretch]
    npass = sum(1 for r in hard if r[1] == "PASS")
    print("\nconformance/scale/fuzz: %d/%d passed  (%d crashed, %d timed out)   [%.0fs]" % (
        npass, len(hard), sum(1 for r in hard if r[1] == "CRASH"), sum(1 for r in hard if r[1] == "TIMEOUT"),
        time.time() - t0))
    for c, v, why, dt in soft:
        print("stretch  %-26s %s" % (c.name, v))
    failed = len(hard) - npass

    if not a.no_api and not a.filter:
        api, info = run_api(a.bend, repo, gen)
        bad = [x for x in api if x[1] != "PASS"]
        print("api checks (RFC 6901 pointer, objects, arrays, ndjson): %d/%d passed" % (len(api) - len(bad), len(api)))
        for k, v, why in bad:
            print("[FAIL] %-28s %s" % (k, why))
        print("informational (unspecified semantics; document them): %s" % json.dumps(info))
        failed += len(bad)

    print("\nRESULT:", "ALL PASS" if failed == 0 else "%d FAILURES" % failed)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
