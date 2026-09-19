# bend-json

A reusable JSON library for **Bend 2** featuring machine-checked example laws, RFC 6901 JSON Pointer navigation, array combinators, typed extractors, configurable indentation, and streaming NDJSON.

> **Note on Verification & AI Development:**  
> This library was primarily developed with AI assistance (using advanced language models), following Bend’s intended workflow of AI-generated code verified by formal proofs.  
> The laws in `LAWS.bend` are concrete example cases, mechanically checked by `bend PROOF.bend`.  
> An independent test suite (`tests/run_tests.py`) additionally compares the library against Python's `json` module.

---

## Key Features

- **JSON AST**: Supports `null`, booleans (`true`/`false`), non-negative integers (`Nat`) and negative integers (`-Nat`) up to 2^48 - 1 in magnitude, decimal and exponent numbers (kept verbatim as `JRaw`), strings with all RFC 8259 escapes (including `\uXXXX` and surrogate pairs), heterogeneous arrays, and key-value objects. Integers of 2^48 or more are rejected with `Fail{"number too large"}`.
- **Machine-Checked Examples**: 56 formal laws in `LAWS.bend`, each stating one concrete example, all checked by `bend PROOF.bend`.
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

Each law in `LAWS.bend` states one concrete example, and `bend PROOF.bend` checks it. They act as machine-checked regression tests and do not prove the property for every possible input.

- **Round-Trip Examples** (14 laws):
  `parse(stringify(x))` gives back `x` for `null`, booleans, integers, strings, arrays, objects, a decimal (`JRaw`), and one nested document.
- **Type Guard Soundness** (10 laws):
  `is_null`, `is_bool`, `is_num`, `is_neg`, `is_str`, `is_arr`, `is_obj`, `is_raw` and `as_raw` return the expected result on example values.
- **Dictionary Soundness** (8 laws):
  `get` and `has` (found and missing), `obj_len`, `remove`, `merge` override behaviour, and `sort_keys` ordering.
- **Array Soundness** (7 laws):
  `arr_len`, `arr_get`, `arr_set`, `arr_pop`, `arr_insert` and `arr_remove`.
- **JSON Pointer** (7 laws):
  Root, object key, array index, nested path, missing key, escaped keys (`~0`, `~1`), and `pointer_set` on a leaf.
- **Typed Extractors** (3 laws):
  `get_str`, `get_num` and `get_num_or`.
- **Validation & NDJSON** (7 laws):
  `validate` accepts valid input and rejects invalid input, leading zeros, a lone minus, and trailing commas in objects and arrays; plus `stringify_ndjson`.

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
