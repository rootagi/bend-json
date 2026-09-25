# bend-json

A reusable JSON library for **Bend 2** featuring machine-checked example laws, RFC 6901 JSON Pointer navigation, array combinators, typed extractors, configurable indentation, and streaming NDJSON.

> **Note on Verification & AI Development:**  
> This library was primarily developed with AI assistance (using advanced language models), following Bend’s intended workflow of AI-generated code verified by formal proofs.  
> The laws in `LAWS.bend` are concrete example cases, mechanically checked by `bend PROOF.bend`.  
> An independent test suite (`tests/run_tests.py`) additionally compares the library against Python's `json` module.

---

## Key Features

- **JSON AST**: Supports `null`, booleans (`true`/`false`), non-negative integers (`Nat`) and negative integers (`-Nat`) up to 2^48 - 1 in magnitude, decimal and exponent numbers (kept verbatim as `JRaw`), strings with all RFC 8259 escapes (including `\uXXXX` and surrogate pairs), heterogeneous arrays, and key-value objects. Integers of 2^48 or more are rejected with `Fail{"number too large"}`.
- **Machine-Checked Specifications**: 58 formal laws in `LAWS.bend`, including universally quantified properties and compile-time regression checks, all verified by `bend PROOF.bend`.
- **RFC 6901 JSON Pointer**:
  - `pointer(j, ptr)`: Deep querying supporting standard escaping (`~1` for `/`, `~0` for `~`) and array indexing.
  - `pointer_set(j, ptr, val)`: Returns the document with the value at the pointer path replaced.
- **Rich Object Dictionary APIs**:
  - `get`, `has`, `set`, `remove`, `obj_len`, `keys`, `values`, `entries`.
  - `merge(base, overrides)`: Object merging with override semantics.
  - `sort_keys(j)`: Deterministic canonical lexicographical key sorting.
- **Array Operations & Combinators**:
  - Element access & mutation: `arr_get`, `arr_len`, `arr_push`, `arr_set`, `arr_pop`, `arr_remove`, `arr_insert`.
  - Functional combinators: `arr_map`, `arr_filter`, `arr_fold`.
- **Ergonomic Typed Extractors**:
  - Type-safe extractors: `get_str`, `get_num`, `get_neg`, `get_bool`, `get_arr`, `get_obj`.
  - Safe fallbacks: `get_str_or`, `get_num_or`, `get_bool_or`.
- **Configurable Pretty Printing**:
  - `stringify(j)`: Compact serializer.
  - `pretty(j)`: Standard 2-space indented formatter.
  - `pretty_indent(j, step)`: Custom indentation width (e.g. 4 spaces).
- **Validation & Streaming NDJSON**:
  - `validate(s) -> Bool`: Returns whether `s` is valid JSON (implemented by running `parse`).
  - `stringify_ndjson` and `parse_ndjson`: Line-delimited JSON stream processing.
- **State-Machine Parsing**:
  - String parsing, line splitting, and pointer tokenization use explicit state machines instead of deep recursion. Tested with 20,000 levels of nesting (compact output) and 200,000-character strings. Very large inputs (hundreds of thousands of array elements) are slow.

---

## Installation & Import

### Option 1: Direct from Bend Hub (Recommended)

Import directly by content hash without copying any files:

```bend
import Base
import 0x1f4d6c03caf955232d0b0dc6e6f36cf4/json.bend as Json
```

### Option 2: Local File Import

Alternatively, place `json.bend` into your project directory and import it locally:

```bend
import Base
import ./json.bend as Json
```

If importing from a subdirectory (such as `examples/`):

```bend
import ../json.bend as Json
```

---

## Quick Start

### 1. Parsing and Querying

```bend
import Base
import ./json.bend as Json

def run_doc(j: Json.Json) -> IO(Unit):
  +j = j
  name    = Json.get_str_or(j, "name", "unknown")
  version = Json.get_num_or(j, "version", 0n)
  active  = Json.get_bool_or(j, "active", False{})
  
  do IO<Unit>:
    IO.print("Project: " ++ name ++ " v" ++ Nat.show(version))
    IO.print("Active:  " ++ Bool.show(active))

def main() -> IO(Unit):
  raw = "{\"name\": \"Bend\", \"version\": 2, \"active\": true}"
  match Json.parse(raw):
    case Done{val}:
      run_doc(val)
    case Fail{err}:
      do IO<Unit>:
        IO.print("Error: " ++ err)
```

### 2. RFC 6901 JSON Pointer

```bend
# Deep lookup
port = Json.pointer(doc, "/server/ports/0")

# Deep in-place mutation
updated = Json.pointer_set(doc, "/server/ports/0", Json.num(80n))
```

### 3. Functional Array Transformations

```bend
def double_num(j: Json.Json) -> Json.Json:
  match j:
    case Json.JNum{n}:
      Json.num(Nat.mul(n, 2n))
    case _:
      j

# Maps double_num over every element
doubled = Json.arr_map(~double_num, my_array)
```

### 4. Serialization

```bend
# Compact minified JSON
compact_str = Json.stringify(doc)

# 2-space indented pretty JSON
pretty_str = Json.pretty(doc)

# 4-space indented pretty JSON
custom_str = Json.pretty_indent(doc, 4n)
```

---

## Examples

Runnable example programs are located in the `examples/` directory:

| Example | Command | Description |
| :--- | :--- | :--- |
| **Basic Usage** | `bend examples/01_basic_usage.bend` | Parsing, typed field extraction, mutation, and pretty printing. |
| **JSON Pointer** | `bend examples/02_json_pointer.bend` | Deep RFC 6901 pointer lookups, escaping (`~1`), and `pointer_set`. |
| **Array Transforms** | `bend examples/03_array_transforms.bend` | Array combinators: `arr_map`, `arr_filter`, `arr_push`, `arr_len`. |
| **Streaming NDJSON** | `bend examples/04_ndjson_streaming.bend` | Streaming line-delimited JSON parsing and serialization. |
| **Full Showcase** | `bend main.bend` | Comprehensive 9-section integration test suite. |

---

## API Reference

### Abstract Syntax Tree (AST)

```bend
type Json is Data:
  JNull{}
  JBool{val: Bool}
  JNum{val: Nat}
  JNeg{val: Nat}
  JStr{val: String}
  JArr{vals: List<&2, Json>}
  JObj{kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  JRaw{raw: String}
```

### Constructors & Helpers
- `null`: `JNull{}`
- `bool(b: Bool) -> Json`: `JBool{b}`
- `num(n: Nat) -> Json`: `JNum{n}` (non-negative integer)
- `neg(n: Nat) -> Json`: `JNeg{n}` (negative integer, `-n`)
- `str(s: String) -> Json`: `JStr{s}`
- `arr(xs: List<&2, Json>) -> Json`: `JArr{xs}`
- `obj(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> Json`: `JObj{kvs}`
- `kv(key: String, val: Json) -> Sigma<&2, &2, String, _ => Json>`: Key-value tuple
- `raw(s: String) -> Json`: `JRaw{s}` (decimal or exponent number stored verbatim). The text is not validated, so pass only valid JSON number text such as `1.5` or `2e10`.

### Type Guards & Safe Unwrapping
- `is_null`, `is_bool`, `is_num`, `is_neg`, `is_str`, `is_arr`, `is_obj`, `is_raw`: Returns `Bool`
- `as_bool`, `as_num`, `as_neg`, `as_str`, `as_arr`, `as_obj`, `as_raw`: Returns `Maybe<&2, T>`

### Object Dictionary APIs
- `get(j: Json, key: String) -> Maybe<&2, Json>`: Lookup object property.
- `has(j: Json, key: String) -> Bool`: Check object property existence.
- `set(j: Json, key: String, val: Json) -> Json`: Upsert key-value pair.
- `remove(j: Json, key: String) -> Json`: Remove property by key.
- `obj_len(j: Json) -> Nat`: Number of object entries.
- `keys(j: Json) -> List<&2, String>`: Extract list of keys.
- `values(j: Json) -> List<&2, Json>`: Extract list of values.
- `entries(j: Json) -> List<&2, Sigma<&2, &2, String, _ => Json>>`: Extract key-value pairs.
- `merge(base: Json, overrides: Json) -> Json`: Merge two objects with override semantics.
- `sort_keys(j: Json) -> Json`: Lexicographical sort of object keys.

### Array Combinators
- `arr_len(j: Json) -> Nat`: Count array elements.
- `arr_get(j: Json, idx: Nat) -> Maybe<&2, Json>`: Access element at 0-based index.
- `arr_push(j: Json, item: Json) -> Json`: Append item to array.
- `arr_set(j: Json, idx: Nat, val: Json) -> Json`: Replace element at index.
- `arr_pop(j: Json) -> Pair(Maybe<&2, Json>, Json)`: Remove the trailing element. Returns `(Some{last}, remaining_array)`, or `(None{}, j)` if `j` is empty or not an array.
- `arr_remove(j: Json, idx: Nat) -> Json`: Remove element at index.
- `arr_insert(j: Json, idx: Nat, val: Json) -> Json`: Insert element at index.
- `arr_map(~f: Json -> Json, j: Json) -> Json`: Map function over elements.
- `arr_filter(~f: Json -> Bool, j: Json) -> Json`: Filter elements matching predicate.
- `arr_fold(~f: Json -> Json -> Json, acc: Json, j: Json) -> Json`: Left fold over elements.

### RFC 6901 JSON Pointer
- `pointer(j: Json, ptr: String) -> Maybe<&2, Json>`: Deep navigation with RFC 6901 pointer syntax.
- `pointer_set(j: Json, ptr: String, val: Json) -> Json`: Returns the document with the value at the pointer path replaced. With the empty pointer `""` it replaces the whole document.

### Serialization & Validation
- `parse(s: String) -> Result<&2, &2, String, Json>`: Parse JSON string into AST.
- `stringify(j: Json) -> String`: Compact JSON stringification with character escaping.
- `pretty(j: Json) -> String`: Formatted 2-space indented JSON string.
- `pretty_indent(j: Json, step: Nat) -> String`: Indented JSON with customizable indentation width.
- `validate(s: String) -> Bool`: Fast boolean syntax check.
- `stringify_ndjson(items: List<&2, Json>) -> String`: Format list of items as newline-delimited JSON.
- `parse_ndjson(s: String) -> List<&2, Result<&2, &2, String, Json>>`: Parse newline-delimited stream.

---

## Formal Invariants & Proofs

Bend's proof system verifies that code satisfies properties specified in `LAWS.bend`.

To verify all proofs:

```bash
bend PROOF.bend
```

Expected output:

```console
All terms check.
```

### Behaviour Notes

- `arr_set` and `arr_remove` with an out-of-range index return the array unchanged.
- `arr_insert` with an index past the end appends the element.
- Object keys keep their order and duplicate keys are preserved by `parse` and `stringify`.
- `stringify` escapes control characters below U+0020 (as `\uXXXX` or the short forms), so strings always serialize as valid JSON strings.
- Integers of 2^48 or more are rejected by `parse` with `Fail{"number too large"}`; decimals and exponent numbers are kept as `JRaw` text.

### Checked Laws Overview

Laws in `LAWS.bend` are mechanically checked by `bend PROOF.bend`. Where tractable within the current Base library, properties are stated as universally quantified laws (`for x: T`) and proven by case analysis and structural induction. The remaining laws are explicitly documented as compile-time regression test examples.

- **Universally Quantified Laws**:
  - **Type Guard Soundness** (`is_null_sound`, `is_bool_true_sound`, `is_bool_false_sound`, `is_num_sound`, `is_neg_sound`, `is_str_sound`, `is_arr_sound`, `is_obj_sound`, `is_raw_sound`, `as_raw_sound`):
    Proved universally for all inhabitants of `Bool`, `Nat`, `String`, `List<Json>`, `List<Sigma<String, Json>>`, etc.
  - **Array Operations & Invariants** (`arr_len_empty`, `arr_len_two`, `arr_get_zero`, `arr_set_sound`, `arr_pop_sound`, `arr_insert_sound`, `arr_remove_sound`):
    Proved universally over arbitrary list tails, head elements, and values.
  - **Object Operations & Dictionary Invariants** (`get_found`, `get_missing`, `has_found`, `has_missing`, `obj_len_sound`, `remove_sound`, `merge_override`, `sort_keys_order`):
    Proved universally over arbitrary values, keys, and key-value lists.
  - **JSON Pointer Operations** (`pointer_root`, `pointer_obj`, `pointer_arr`, `pointer_nested`, `pointer_escape`, `pointer_set_leaf`):
    Proved universally over arbitrary documents and property values.
  - **Typed Extractors** (`get_str_sound`, `get_num_sound`, `get_num_or_sound`):
    Proved universally over arbitrary strings, natural numbers, keys, and default values.
  - **Round-Trip Base Cases** (`roundtrip_null`, `roundtrip_bool`, `roundtrip_arr_empty`, `roundtrip_obj_empty`):
    Proved universally for all inhabitants of `JNull`, `JBool{b}`, `JArr{Nil}`, and `JObj{Nil}`.
  - **NDJSON Step Property** (`ndjson_step`):
    Proved universally for any head element and list of JSON documents.

- **Supporting Lemma Library (`Lemmas.bend`)**:
  - `arr_len_append` & `obj_len_append`: Inductive proofs that appending an element increments array length and object key count.
  - RFC 8259 §7 two-character escape inverses (`\"`, `\\`, `\n`, `\t`, `\r`, `\b`, `\f`) and control character escape/unescape round-trips (`\u0000` to `\u001f`).
  - UTF-16 surrogate pair encoding/decoding definitions and round-trips for scalar endpoints (U+10000, U+1F600, U+10FFFF).
  - Digit character encode/decode round-trip proofs for all decimal digits (`0n`..`9n`).

### Known Gaps & Upstream Base Blockers

The remaining laws are preserved as honest, concrete compile-time regression tests. They cannot currently be generalized to universal proofs due to missing foundations in Bend's upstream Base library:

1. **Natural Number Round-Trip (`roundtrip_num_0`, `roundtrip_num_42`, `roundtrip_neg_7`)**:
   - *Blocker*: Proving `for n: Nat { parse(stringify(JNum{n})) == Done{JNum{n}} }` requires Euclidean division and remainder theorems for `Nat.divmod` (showing `q * 10 + r == n` and `r < 10`), base-10 Horner accumulation lemmas, and parser fuel invariant proofs. Upstream `Base.bend` currently has no general `Nat` arithmetic lemmas beyond `Word.add_comm` / `U32.add_comm`.
2. **String Round-Trip (`roundtrip_str_empty`, `roundtrip_str_hello`)**:
   - *Blocker*: Proving `for s: String { parse(stringify(JStr{s})) == Done{JStr{s}} }` requires structural induction over character lists, character comparison lemmas, and proof that the string parser's fuel (`100n + 8 * len`) is sufficient for any escape expansion.
3. **Array, Object, and Complex Document Round-Trip (`roundtrip_arr_items`, `roundtrip_obj_single`, `roundtrip_raw_decimal`, `roundtrip_complex`)**:
   - *Blocker*: Mutual structural induction over recursive AST structures (`Json` containing `List<Json>` containing `Json`) requires dependent induction schemes and parser state machine transition invariants that are currently beyond Base's capabilities.
4. **Validation Predicates (`validate_valid`, `validate_invalid`, `validate_reject_*`, `pointer_missing`)**:
   - *Blocker*: Formalizing validation for arbitrary strings requires a mechanized grammar specification of RFC 8259 and proofs that invalid prefixes cause deterministic parser rejections.
5. **Safety Net**:
   - The property-based and differential test suite in `tests/run_tests.py` serves as the primary verification safety net for these unproven areas, validating millions of operations against Python's oracle.

### Testing

```bash
# Machine-checked laws
bend PROOF.bend

# Independent conformance, scale and fuzz suite (needs Python 3 and `bend` on PATH)
python3 tests/run_tests.py
# or point it at a specific Bend command:
BEND="bun /path/to/bend2/main.ts" python3 tests/run_tests.py
```

The suite compares `parse`, `stringify`, `pretty` and `validate` with Python's `json` module on RFC 8259 valid and invalid documents, large and deeply nested inputs, and seeded random documents. `tests/api_checks.bend` covers JSON Pointer (RFC 6901), objects, arrays and NDJSON.

---

## License

This project is licensed under the Apache 2.0 License.
