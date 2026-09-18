# main.bend: Comprehensive showcase and tests for the Bend 2 JSON library.
# Demonstrates parsing, serialization, RFC 6901 JSON Pointer,
# object dictionary operations, array combinators, typed extractors,
# pretty printing with configurable indentation, validation, and NDJSON streaming.

import Base
import ./json.bend as Json

def print_result(+label: String, +input: String, r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+v}:
      do IO<Unit>:
        IO.print("--- " ++ label ++ " ---")
        IO.print("Input: " ++ input)
        IO.print("Parsed successfully!")
        IO.print("Compact: " ++ Json.stringify(v))
        IO.print("Pretty (2-space):")
        IO.print(Json.pretty(v))
    case Fail{err}:
      do IO<Unit>:
        IO.print("--- " ++ label ++ " ---")
        IO.print("Input: " ++ input)
        IO.print("Parse error: " ++ err)

def test_parse(+label: String, +input: String) -> IO(Unit):
  print_result(label, input, Json.parse(input))

def print_maybe_json(label: String, m: Maybe<&2, Json.Json>) -> IO(Unit):
  match m:
    case Some{+v}:
      IO.print(label ++ ": Some(" ++ Json.stringify(v) ++ ")")
    case None{}:
      IO.print(label ++ ": None")

def print_maybe_str(label: String, m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case Some{s}:
      IO.print(label ++ ": Some(\"" ++ s ++ "\")")
    case None{}:
      IO.print(label ++ ": None")

def print_maybe_nat(label: String, m: Maybe<&2, Nat>) -> IO(Unit):
  match m:
    case Some{n}:
      IO.print(label ++ ": Some(" ++ Nat.show(n) ++ ")")
    case None{}:
      IO.print(label ++ ": None")

def print_maybe_bool(label: String, m: Maybe<&2, Bool>) -> IO(Unit):
  match m:
    case Some{b}:
      IO.print(label ++ ": Some(" ++ Bool.show(b) ++ ")")
    case None{}:
      IO.print(label ++ ": None")

def show_str_list_rest(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      ", \"" ++ h ++ "\"" ++ show_str_list_rest(t)

def show_str_list(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case h <> t:
      "[\"" ++ h ++ "\"" ++ show_str_list_rest(t) ++ "]"

def double_num(j: Json.Json) -> Json.Json:
  match j:
    case Json.JNum{n}:
      Json.num(Nat.mul(n, 2n))
    case _:
      j

def is_gt_fifteen(j: Json.Json) -> Bool:
  match j:
    case Json.JNum{n}:
      Nat.is_gt(n, 15n)
    case _:
      False{}

def print_ndjson_line(h: Result<&2, &2, String, Json.Json>, count: Nat) -> IO(Unit):
  match h:
    case Done{j}:
      IO.print("  Line " ++ Nat.show(count) ++ ": " ++ Json.stringify(j))
    case Fail{err}:
      IO.print("  Line " ++ Nat.show(count) ++ " Error: " ++ err)

def print_ndjson_results(items: List<&2, Result<&2, &2, String, Json.Json>>, +count: Nat) -> IO(Unit):
  match items:
    case Nil{}:
      IO.print("Finished parsing NDJSON stream.")
    case h <> t:
      do IO<Unit>:
        print_ndjson_line(h, count)
        print_ndjson_results(t, {count + 1n : Nat})

def print_merged(overrides: Json.Json, +merged: Json.Json) -> IO(Unit):
  do IO<Unit>:
    IO.print("Overrides: " ++ Json.stringify(overrides))
    IO.print("Merged Object: " ++ Json.stringify(merged))
    IO.print("Canonical sorted keys: " ++ Json.stringify(Json.sort_keys(merged)))

def run_object_merge(r: Result<&2, &2, String, Json.Json>, +obj1: Json.Json) -> IO(Unit):
  match r:
    case Done{+overrides}:
      print_merged(overrides, Json.merge(obj1, overrides))
    case Fail{_}:
      IO.print("Error parsing overrides")

def print_object_details(+obj1: Json.Json, +obj_no_b: Json.Json) -> IO(Unit):
  do IO<Unit>:
    IO.print("Initial Object: " ++ Json.stringify(obj1))
    IO.print("Keys: " ++ show_str_list(Json.keys(obj1)))
    IO.print("Object Length: " ++ Nat.show(Json.obj_len(obj1)))
    IO.print("has('b'): " ++ Bool.show(Json.has(obj1, "b")))
    IO.print("has('z'): " ++ Bool.show(Json.has(obj1, "z")))
    IO.print("After remove('b'): " ++ Json.stringify(obj_no_b))
    IO.print("Length after remove: " ++ Nat.show(Json.obj_len(obj_no_b)))
    run_object_merge(Json.parse("{\"b\": 20, \"d\": 4}"), obj1)

def run_object_ops(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+obj1}:
      print_object_details(obj1, Json.remove(obj1, "b"))
    case Fail{_}:
      IO.print("Error parsing obj1")

def print_pop_result(p: Pair(Maybe<&2, Json.Json>, Json.Json)) -> IO(Unit):
  match p:
    case Tuple{popped_item, arr_popped}:
      do IO<Unit>:
        print_maybe_json("Popped item", popped_item)
        IO.print("Remaining array after pop: " ++ Json.stringify(arr_popped))

def print_array_details(+arr1: Json.Json) -> IO(Unit):
  do IO<Unit>:
    IO.print("Initial Array: " ++ Json.stringify(arr1))
    IO.print("Array Length: " ++ Nat.show(Json.arr_len(arr1)))
    print_maybe_json("arr_get(1)", Json.arr_get(arr1, 1n))
    print_maybe_json("arr_get(5)", Json.arr_get(arr1, 5n))
    IO.print("After arr_set(idx=1, val=99): " ++ Json.stringify(Json.arr_set(arr1, 1n, Json.num(99n))))
    IO.print("After arr_insert(idx=1, val=15): " ++ Json.stringify(Json.arr_insert(arr1, 1n, Json.num(15n))))
    IO.print("After arr_remove(idx=0): " ++ Json.stringify(Json.arr_remove(arr1, 0n)))
    print_pop_result(Json.arr_pop(arr1))
    IO.print("arr_map (~double_num): " ++ Json.stringify(Json.arr_map(~double_num, arr1)))
    IO.print("arr_filter (~is_gt_fifteen): " ++ Json.stringify(Json.arr_filter(~is_gt_fifteen, arr1)))

def run_array_ops(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{arr1}:
      print_array_details(arr1)
    case Fail{_}:
      IO.print("Error parsing array")

def print_typed_details(+j_typed: Json.Json) -> IO(Unit):
  do IO<Unit>:
    IO.print("Target Object: " ++ Json.stringify(j_typed))
    print_maybe_str("get_str('name')", Json.get_str(j_typed, "name"))
    print_maybe_str("get_str('missing')", Json.get_str(j_typed, "missing"))
    IO.print("get_str_or('name', 'Default'): " ++ Json.get_str_or(j_typed, "name", "Default"))
    IO.print("get_str_or('missing', 'Default'): " ++ Json.get_str_or(j_typed, "missing", "Default"))
    print_maybe_nat("get_num('version')", Json.get_num(j_typed, "version"))
    IO.print("get_num_or('version', 1n): " ++ Nat.show(Json.get_num_or(j_typed, "version", 1n)))
    IO.print("get_num_or('missing', 100n): " ++ Nat.show(Json.get_num_or(j_typed, "missing", 100n)))
    print_maybe_bool("get_bool('is_fast')", Json.get_bool(j_typed, "is_fast"))
    IO.print("get_bool_or('is_fast', false): " ++ Bool.show(Json.get_bool_or(j_typed, "is_fast", False{})))
    IO.print("get_bool_or('missing', false): " ++ Bool.show(Json.get_bool_or(j_typed, "missing", False{})))

def run_typed_ops(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{j_typed}:
      print_typed_details(j_typed)
    case Fail{_}:
      IO.print("Error parsing typed object")

def print_pointer_details(+ptr_doc: Json.Json, +mutated1: Json.Json) -> IO(Unit):
  do IO<Unit>:
    IO.print("Pointer Document: " ++ Json.stringify(ptr_doc))
    print_maybe_json("Pointer \"\"", Json.pointer(ptr_doc, ""))
    print_maybe_json("Pointer \"/app/server/port\"", Json.pointer(ptr_doc, "/app/server/port"))
    print_maybe_json("Pointer \"/app/server/tags/0\"", Json.pointer(ptr_doc, "/app/server/tags/0"))
    print_maybe_json("Pointer \"/app/server/tags/1\"", Json.pointer(ptr_doc, "/app/server/tags/1"))
    print_maybe_json("Pointer \"/escaped~1key\" (escaped /)", Json.pointer(ptr_doc, "/escaped~1key"))
    print_maybe_json("Pointer \"/m~0n\" (escaped ~)", Json.pointer(ptr_doc, "/m~0n"))
    print_maybe_json("Pointer \"/app/server/missing\"", Json.pointer(ptr_doc, "/app/server/missing"))
    IO.print("After pointer_set('/app/server/port', 90):")
    IO.print("  " ++ Json.stringify(mutated1))
    IO.print("After pointer_set('/app/server/tags/1', 'v2-ready'):")
    IO.print("  " ++ Json.stringify(Json.pointer_set(mutated1, "/app/server/tags/1", Json.str("v2-ready"))))

def run_pointer_ops(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+ptr_doc}:
      print_pointer_details(ptr_doc, Json.pointer_set(ptr_doc, "/app/server/port", Json.num(90n)))
    case Fail{_}:
      IO.print("Error parsing pointer test doc")

def run_pretty_ops(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+pretty_doc}:
      do IO<Unit>:
        IO.print("Pretty with 2 spaces (default):")
        IO.print(Json.pretty(pretty_doc))
        IO.print("Pretty with 4 spaces (pretty_indent):")
        IO.print(Json.pretty_indent(pretty_doc, 4n))
    case Fail{_}:
      IO.print("Error parsing pretty doc")

def test_ndjson_stream() -> IO(Unit):
  rec1 = Json.obj([Json.kv("id", Json.num(1n)), Json.kv("user", Json.str("alice"))])
  rec2 = Json.obj([Json.kv("id", Json.num(2n)), Json.kv("user", Json.str("bob"))])
  rec3 = Json.obj([Json.kv("id", Json.num(3n)), Json.kv("user", Json.str("charlie"))])
  +ndjson_data = Json.stringify_ndjson([rec1, rec2, rec3])
  do IO<Unit>:
    IO.print("Generated NDJSON stream:")
    IO.print(ndjson_data)
    IO.print("Parsing NDJSON stream line-by-line:")
    print_ndjson_results(Json.parse_ndjson(ndjson_data), 1n)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("==================================================")
    IO.print("       Bend 2 Production JSON Library Showcase     ")
    IO.print("==================================================")
    
    # ----------------------------------------------------
    # Part 1: Core Parsing & Stringify
    # ----------------------------------------------------
    IO.print("\n>>> [1] Core Types Parsing & Serializing")
    test_parse("1.1 Null", "null")
    test_parse("1.2 Bool True", "true")
    test_parse("1.3 Bool False", "false")
    test_parse("1.4 Positive Number", "42")
    test_parse("1.5 Negative Number", "-105")
    test_parse("1.6 Escaped String", "\"Hello \\\"Bend 2\\\"!\\nNewline & Tab\\tOk.\"")
    test_parse("1.7 Heterogeneous Array", "[10, 20, true, null, \"item\"]")
    
    # ----------------------------------------------------
    # Part 2: Complex Nested Document
    # ----------------------------------------------------
    IO.print("\n>>> [2] Complex Nested Document")
    test_parse("2.1 Project Document", "{\"project\": \"Bend\", \"version\": 2, \"verified\": true, \"authors\": [\"HigherOrderCO\"], \"features\": {\"parallel\": true, \"proofs\": true, \"stars\": 99}}")

    # ----------------------------------------------------
    # Part 3: Object Dictionary APIs
    # ----------------------------------------------------
    IO.print("\n>>> [3] Object Dictionary Operations")
    run_object_ops(Json.parse("{\"a\": 1, \"b\": 2, \"c\": 3}"))

    # ----------------------------------------------------
    # Part 4: Array Operations & Functional Combinators
    # ----------------------------------------------------
    IO.print("\n>>> [4] Array Operations & Combinators")
    run_array_ops(Json.parse("[10, 20, 30]"))

    # ----------------------------------------------------
    # Part 5: Ergonomic Typed Extractors & Defaults
    # ----------------------------------------------------
    IO.print("\n>>> [5] Ergonomic Typed Extractors & Defaults")
    run_typed_ops(Json.parse("{\"name\": \"Bend\", \"version\": 2, \"is_fast\": true}"))

    # ----------------------------------------------------
    # Part 6: RFC 6901 JSON Pointer Traversal & In-Place Mutation
    # ----------------------------------------------------
    IO.print("\n>>> [6] RFC 6901 JSON Pointer Traversal & Mutation")
    run_pointer_ops(Json.parse("{\"app\": {\"server\": {\"port\": 80, \"tags\": [\"primary\", \"api\"]}}, \"escaped/key\": 42, \"m~n\": 99}"))

    # ----------------------------------------------------
    # Part 7: Configurable Indentation
    # ----------------------------------------------------
    IO.print("\n>>> [7] Configurable Pretty Printing")
    run_pretty_ops(Json.parse("{\"compiler\": \"Bend 2\", \"parallel\": true, \"opt_level\": 3}"))

    # ----------------------------------------------------
    # Part 8: Validation API
    # ----------------------------------------------------
    IO.print("\n>>> [8] Fast Validation API")
    IO.print("validate('{\"status\": \"ok\", \"code\": 200}'): " ++ Bool.show(Json.validate("{\"status\": \"ok\", \"code\": 200}")))
    IO.print("validate('{\"status\": \"broken\", code: 200}'): " ++ Bool.show(Json.validate("{\"status\": \"broken\", code: 200}")))
    IO.print("validate('[1, 2, 3, ]'): " ++ Bool.show(Json.validate("[1, 2, 3, ]")))

    # ----------------------------------------------------
    # Part 9: Streaming NDJSON (Newline Delimited JSON)
    # ----------------------------------------------------
    IO.print("\n>>> [9] Streaming NDJSON Support")
    test_ndjson_stream()

    IO.print("\n==================================================")
    IO.print("    All Tests & Demonstrations Completed Successfully!    ")
    IO.print("==================================================")

