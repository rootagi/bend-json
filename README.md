# bend-json

A  reusable JSON library for **Bend 2** featuring formal invariant verification, RFC 6901 JSON Pointer navigation, array combinators, typed extractors, configurable indentation, and streaming NDJSON.

> **Note on Verification & AI Development:**  
> This library was primarily developed with AI assistance (using advanced language models), following Bend’s intended workflow of AI-generated code verified by formal proofs.  
> All critical properties are stated in LAWS.bend and mechanically checked in PROOF.bend.

---

## Key Features

- **Full JSON AST**: Supports `null`, booleans (`true`/`false`), arbitrary non-negative integers (`Nat`), negative integers (`-Nat`), strings with complete escape sequences (`"`, `\`, `\n`, `\t`, `\r`), heterogeneous arrays, and key-value objects.
- **Formally Verified Correctness**: 47 formal laws in `LAWS.bend` mechanically proven in `PROOF.bend`. 100% check rate with `bend PROOF.bend`.
- **RFC 6901 JSON Pointer**:
  - `pointer(j, ptr)`: Deep querying supporting standard escaping (`~1` for `/`, `~0` for `~`) and array indexing.
  - `pointer_set(j, ptr, val)`: Deep in-place mutation along any pointer path.
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
  - `stringify(j)`: High-performance compact minifier.
  - `pretty(j)`: Standard 2-space indented formatter.
  - `pretty_indent(j, step)`: Custom indentation width (e.g. 4 spaces).
- **Fast Validation & Streaming NDJSON**:
  - `validate(s) -> Bool`: Syntactic validation without allocating intermediate AST.
  - `stringify_ndjson` and `parse_ndjson`: Line-delimited JSON stream processing.
- **Linear State Machine Architecture**:
  - String parsing, line splitting, and pointer tokenization use explicit linear state machines, guaranteeing $O(N)$ execution and eliminating deep recursion stack issues.

---

## Installation & Import

### Option 1: Direct from Bend Hub (Recommended)

Import directly by content hash without copying any files:

```bend
import Base
import 0x6bcc5639f884b922a3ea766a6acc017c/json.bend as Json
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
type Json:
  case JNull{}
  case JBool{val: Bool}
  case JNum{val: Nat}
  case JNeg{val: Nat}
  case JStr{val: String}
  case JArr{val: List<&2, Json>}
  case JObj{val: List<&2, Pair(String, Json)>}
```

### Constructors & Helpers
- `null`: `JNull{}`
- `bool(b: Bool) -> Json`: `JBool{b}`
- `num(n: Nat) -> Json`: `JNum{n}` (non-negative integer)
- `neg(n: Nat) -> Json`: `JNeg{n}` (negative integer, `-n`)
- `str(s: String) -> Json`: `JStr{s}`
- `arr(xs: List<&2, Json>) -> Json`: `JArr{xs}`
- `obj(kvs: List<&2, Pair(String, Json)>) -> Json`: `JObj{kvs}`
- `kv(key: String, val: Json) -> Pair(String, Json)`: Key-value tuple

### Type Guards & Safe Unwrapping
- `is_null`, `is_bool`, `is_num`, `is_neg`, `is_str`, `is_arr`, `is_obj`: Returns `Bool`
- `as_bool`, `as_num`, `as_neg`, `as_str`, `as_arr`, `as_obj`: Returns `Maybe<&2, T>`

### Object Dictionary APIs
- `get(j: Json, key: String) -> Maybe<&2, Json>`: Lookup object property.
- `has(j: Json, key: String) -> Bool`: Check object property existence.
- `set(j: Json, key: String, val: Json) -> Json`: Upsert key-value pair.
- `remove(j: Json, key: String) -> Json`: Remove property by key.
- `obj_len(j: Json) -> Nat`: Number of object entries.
- `keys(j: Json) -> List<&2, String>`: Extract list of keys.
- `values(j: Json) -> List<&2, Json>`: Extract list of values.
- `entries(j: Json) -> List<&2, Pair(String, Json)>`: Extract key-value pairs.
- `merge(base: Json, overrides: Json) -> Json`: Merge two objects with override semantics.
- `sort_keys(j: Json) -> Json`: Lexicographical sort of object keys.

### Array Combinators
- `arr_len(j: Json) -> Nat`: Count array elements.
- `arr_get(j: Json, idx: Nat) -> Maybe<&2, Json>`: Access element at 0-based index.
- `arr_push(j: Json, item: Json) -> Json`: Append item to array.
- `arr_set(j: Json, idx: Nat, val: Json) -> Json`: Replace element at index.
- `arr_pop(j: Json) -> Pair(Json, Maybe<&2, Json>)`: Remove and return trailing element.
- `arr_remove(j: Json, idx: Nat) -> Json`: Remove element at index.
- `arr_insert(j: Json, idx: Nat, val: Json) -> Json`: Insert element at index.
- `arr_map(~f: Json -> Json, j: Json) -> Json`: Map function over elements.
- `arr_filter(~p: Json -> Bool, j: Json) -> Json`: Filter elements matching predicate.
- `arr_fold(~f: Json -> T -> T, ~init: T, j: Json) -> T`: Left fold over elements.

### RFC 6901 JSON Pointer
- `pointer(j: Json, ptr: String) -> Maybe<&2, Json>`: Deep navigation with RFC 6901 pointer syntax.
- `pointer_set(j: Json, ptr: String, val: Json) -> Json`: In-place deep mutation along the pointer path.

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

### Verified Laws Overview

- **Round-Trip Properties** (13 laws):
  Ensures `parse(stringify(x)) == Done{x}` for all primitives, escaped strings, arrays, objects, and nested structures.
- **Type Guard Soundness** (8 laws):
  Proves that type inspection functions (`is_null`, `is_bool`, `is_num`, etc.) return `True{}` if and only if the constructor matches.
- **Dictionary Soundness** (9 laws):
  Proves object querying, length, removal, and left-identity under empty merge.
- **Array Combinators Soundness** (8 laws):
  Proves `arr_len`, `arr_get`, `arr_pop`, `arr_remove`, `arr_insert`, `arr_set_preserves_length`, and `arr_map_id`.
- **Typed Extractors** (3 laws):
  Proves correctness of `get_str`, `get_num`, and `get_bool`.
- **JSON Pointer** (2 laws):
  Proves root identity (`pointer(j, "") == Some{j}`) and single-step key navigation.
- **Validation & Streaming** (4 laws):
  Proves `validate` soundness and NDJSON round-trip properties.

---

## License

This project is licensed under the Apache 2.0 License.
