# LAWS.bend: Formal specifications and invariant laws for the Bend 2 JSON library.
# The user/human states the laws; PROOF.bend mechanically proves each one.
#
# Covers:
#   1. Round-trip serialization & parsing (stringify -> parse -> identity)
#   2. Type checker / guard soundness
#   3. Query and inspection properties (get, has, arr_len, arr_get)
#   4. RFC 6901 JSON Pointer operations
#   5. Object operations and dictionary laws
#   6. Array operations and mutation laws
#   7. Ergonomic typed field extractors
#   8. Validation and streaming NDJSON laws
#
# NOTE ON UNIVERSAL QUANTIFICATION VS. CONCRETE EXAMPLES:
# Wherever tractable with Bend 2's Base library, laws are universally quantified
# via `for x: T` and proven by case analysis / structural induction.
# Where Base lacks foundational lemmas (such as general Euclidean division/modulo
# lemmas for Nat or string induction lemmas for state machines), laws remain as
# explicit, honestly documented concrete examples with the exact blocker named.

import Base
import ./json.bend as Json
import ./Lemmas.bend as Lemmas

# ==============================================================================
# 1. Round-Trip Laws: parse(stringify(x)) == Done{x}
# ==============================================================================

# LAW: Null round-trips through stringify and parse (universal for JNull)
law roundtrip_null:
  {Json.parse(Json.stringify(Json.JNull{})) == Done{Json.JNull{}} : Result<&2, &2, String, Json.Json>}

# LAW: Boolean True round-trips
law roundtrip_true:
  {Json.parse(Json.stringify(Json.JBool{True{}})) == Done{Json.JBool{True{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Boolean False round-trips
law roundtrip_false:
  {Json.parse(Json.stringify(Json.JBool{False{}})) == Done{Json.JBool{False{}}} : Result<&2, &2, String, Json.Json>}

# LAW: General Boolean round-trip (universal for any Bool)
law roundtrip_bool:
  for b: Bool
  {Json.parse(Json.stringify(Json.JBool{b})) == Done{Json.JBool{b}} : Result<&2, &2, String, Json.Json>}

# LAW: Number 0 round-trips (concrete example)
# Blocker for `for n: Nat`: Base lacks general Nat Euclidean division (Nat.divmod)
# and Horner accumulation lemmas to prove Nat.show and parse_number are inverses.
law roundtrip_num_0:
  {Json.parse(Json.stringify(Json.JNum{0n})) == Done{Json.JNum{0n}} : Result<&2, &2, String, Json.Json>}

# LAW: Number 42 round-trips (concrete example)
# Blocker: see roundtrip_num_0 note.
law roundtrip_num_42:
  {Json.parse(Json.stringify(Json.JNum{42n})) == Done{Json.JNum{42n}} : Result<&2, &2, String, Json.Json>}

# LAW: Negative number -7 round-trips (concrete example)
# Blocker: see roundtrip_num_0 note.
law roundtrip_neg_7:
  {Json.parse(Json.stringify(Json.JNeg{7n})) == Done{Json.JNeg{7n}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty string round-trips (concrete example)
# Blocker for `for s: String`: Base lacks string induction and parser fuel invariant lemmas.
law roundtrip_str_empty:
  {Json.parse(Json.stringify(Json.JStr{""})) == Done{Json.JStr{""}} : Result<&2, &2, String, Json.Json>}

# LAW: Non-empty string round-trips (concrete example)
# Blocker: see roundtrip_str_empty note.
law roundtrip_str_hello:
  {Json.parse(Json.stringify(Json.JStr{"hello"})) == Done{Json.JStr{"hello"}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty array round-trips (universal for empty JArr)
law roundtrip_arr_empty:
  {Json.parse(Json.stringify(Json.JArr{Nil{}})) == Done{Json.JArr{Nil{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Non-empty array round-trips (concrete example)
# Blocker for `for vals: List<Json>`: requires mutual structural induction over Json and List<Json>.
law roundtrip_arr_items:
  {Json.parse(Json.stringify(Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]})) == Done{Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty object round-trips (universal for empty JObj)
law roundtrip_obj_empty:
  {Json.parse(Json.stringify(Json.JObj{Nil{}})) == Done{Json.JObj{Nil{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Single key-value object round-trips (concrete example)
# Blocker: depends on general string key parsing and object entry induction.
law roundtrip_obj_single:
  {Json.parse(Json.stringify(Json.JObj{[Tuple{"name", Json.JStr{"bend"}}]})) == Done{Json.JObj{[Tuple{"name", Json.JStr{"bend"}}]}} : Result<&2, &2, String, Json.Json>}

# LAW: Raw decimal number round-trips (concrete example)
# Blocker: depends on RFC 8259 decimal/exponent grammar parsing invariants.
law roundtrip_raw_decimal:
  {Json.parse(Json.stringify(Json.JRaw{"1.5"})) == Done{Json.JRaw{"1.5"}} : Result<&2, &2, String, Json.Json>}

# LAW: Nested complex JSON structure round-trips (concrete example)
# Blocker: requires mutual structural induction over nested Json AST.
law roundtrip_complex:
  {Json.parse(Json.stringify(Json.JObj{[Tuple{"a", Json.JNum{10n}}, Tuple{"b", Json.JArr{[Json.JBool{True{}}, Json.JNull{}]}}]})) == Done{Json.JObj{[Tuple{"a", Json.JNum{10n}}, Tuple{"b", Json.JArr{[Json.JBool{True{}}, Json.JNull{}]}}]}} : Result<&2, &2, String, Json.Json>}

# ==============================================================================
# 2. Type Guard Soundness Laws (Universally Quantified)
# ==============================================================================

# LAW: is_null is sound (universal for JNull)
law is_null_sound:
  {Json.is_null(Json.JNull{}) == True{} : Bool}

# LAW: is_bool is sound for True (universal over Bool)
law is_bool_true_sound:
  for b: Bool
  {Json.is_bool(Json.JBool{b}) == True{} : Bool}

# LAW: is_bool is sound for False (universal over Bool)
law is_bool_false_sound:
  for b: Bool
  {Json.is_bool(Json.JBool{b}) == True{} : Bool}

# LAW: is_num is sound for all natural numbers
law is_num_sound:
  for n: Nat
  {Json.is_num(Json.JNum{n}) == True{} : Bool}

# LAW: is_neg is sound for all natural numbers
law is_neg_sound:
  for n: Nat
  {Json.is_neg(Json.JNeg{n}) == True{} : Bool}

# LAW: is_str is sound for all strings
law is_str_sound:
  for s: String
  {Json.is_str(Json.JStr{s}) == True{} : Bool}

# LAW: is_arr is sound for all array lists
law is_arr_sound:
  for vals: List<&2, Json.Json>
  {Json.is_arr(Json.JArr{vals}) == True{} : Bool}

# LAW: is_obj is sound for all object entry lists
law is_obj_sound:
  for kvs: List<&2, Sigma<&2, &2, String, _ => Json.Json>>
  {Json.is_obj(Json.JObj{kvs}) == True{} : Bool}

# LAW: is_raw is sound for all raw strings
law is_raw_sound:
  for s: String
  {Json.is_raw(Json.JRaw{s}) == True{} : Bool}

# LAW: as_raw is sound for all raw strings
law as_raw_sound:
  for s: String
  {Json.as_raw(Json.JRaw{s}) == Some{s} : Maybe<&2, String>}

# LAW: raw_checked rejects non-number text
law raw_checked_invalid:
  {Json.raw_checked("abc") == None{} : Maybe<&2, Json.Json>}

# LAW: raw_checked parses valid decimal into JRaw
law raw_checked_valid:
  {Json.raw_checked("1.5") == Some{Json.JRaw{"1.5"}} : Maybe<&2, Json.Json>}

# ==============================================================================
# 3. Query and Accessor Soundness Laws (Universally Quantified)
# ==============================================================================

# LAW: get returns existing property in object for any value
law get_found:
  for v: Json.Json
  {Json.get(Json.JObj{[Tuple{"k", v}]}, "k") == Some{v} : Maybe<&2, Json.Json>}

# LAW: get returns None for missing property for any key
law get_missing:
  for key: String
  {Json.get(Json.JObj{Nil{}}, key) == None{} : Maybe<&2, Json.Json>}

# LAW: has returns True for existing property for any value
law has_found:
  for v: Json.Json
  {Json.has(Json.JObj{[Tuple{"k", v}]}, "k") == True{} : Bool}

# LAW: has returns False for missing property for any key
law has_missing:
  for key: String
  {Json.has(Json.JObj{Nil{}}, key) == False{} : Bool}

# LAW: arr_len of empty array is 0 (universal for empty JArr)
law arr_len_empty:
  {Json.arr_len(Json.JArr{Nil{}}) == 0n : Nat}

# LAW: arr_len counts elements correctly for any two elements
law arr_len_two:
  for x: Json.Json
  for y: Json.Json
  {Json.arr_len(Json.JArr{[x, y]}) == 2n : Nat}

# LAW: arr_get accesses index 0 correctly for any head and tail
law arr_get_zero:
  for x: Json.Json
  for xs: List<&2, Json.Json>
  {Json.arr_get(Json.JArr{x <> xs}, 0n) == Some{x} : Maybe<&2, Json.Json>}

# ==============================================================================
# 4. RFC 6901 JSON Pointer Laws (Universally Quantified)
# ==============================================================================

# LAW: Empty pointer resolves root document for any document
law pointer_root:
  for j: Json.Json
  {Json.pointer(j, "") == Some{j} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves object property by key for any value
law pointer_obj:
  for v: Json.Json
  {Json.pointer(Json.JObj{[Tuple{"name", v}]}, "/name") == Some{v} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves array element by index for any elements
law pointer_arr:
  for v0: Json.Json
  for v1: Json.Json
  {Json.pointer(Json.JArr{[v0, v1]}, "/1") == Some{v1} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves nested paths for any value
law pointer_nested:
  for v: Json.Json
  {Json.pointer(Json.JObj{[Tuple{"a", Json.JArr{[v]}}]}, "/a/0") == Some{v} : Maybe<&2, Json.Json>}

# LAW: Pointer returns None for non-existent path in empty object (concrete example)
law pointer_missing:
  {Json.pointer(Json.JObj{Nil{}}, "/missing") == None{} : Maybe<&2, Json.Json>}

# LAW: Pointer unescapes ~1 as / for any value
law pointer_escape:
  for v: Json.Json
  {Json.pointer(Json.JObj{[Tuple{"a/b", v}]}, "/a~1b") == Some{v} : Maybe<&2, Json.Json>}

# LAW: Pointer deep update sets value at path for any value
law pointer_set_leaf:
  for v: Json.Json
  {Json.pointer(Json.pointer_set(Json.JObj{Nil{}}, "/x", v), "/x") == Some{v} : Maybe<&2, Json.Json>}

# ==============================================================================
# 5. Object Operations & Dictionary Laws (Universally Quantified)
# ==============================================================================

# LAW: obj_len counts keys correctly for any two values
law obj_len_sound:
  for v1: Json.Json
  for v2: Json.Json
  {Json.obj_len(Json.JObj{[Tuple{"a", v1}, Tuple{"b", v2}]}) == 2n : Nat}

# LAW: remove deletes key from object for any value
law remove_sound:
  for v: Json.Json
  {Json.has(Json.remove(Json.JObj{[Tuple{"a", v}]}, "a"), "a") == False{} : Bool}

# LAW: merge overrides matching keys with second object for any values
law merge_override:
  for v1: Json.Json
  for v2: Json.Json
  {Json.get(Json.merge(Json.JObj{[Tuple{"a", v1}]}, Json.JObj{[Tuple{"a", v2}]}), "a") == Some{v2} : Maybe<&2, Json.Json>}

# LAW: sort_keys sorts keys alphabetically for any values
law sort_keys_order:
  for v1: Json.Json
  for v2: Json.Json
  {Json.keys(Json.sort_keys(Json.JObj{[Tuple{"z", v1}, Tuple{"a", v2}]})) == ["a", "z"] : List<&2, String>}

# ==============================================================================
# 6. Array Operations & Mutation Laws (Universally Quantified)
# ==============================================================================

# LAW: arr_set updates element at index 0 for any old value, new value, and tail
law arr_set_sound:
  for old: Json.Json
  for val: Json.Json
  for tail: List<&2, Json.Json>
  {Json.arr_get(Json.arr_set(Json.JArr{old <> tail}, 0n, val), 0n) == Some{val} : Maybe<&2, Json.Json>}

# LAW: arr_pop pops last element for any two elements
law arr_pop_sound:
  for v1: Json.Json
  for v2: Json.Json
  {Json.arr_pop(Json.JArr{[v1, v2]}) == Tuple{Some{v2}, Json.JArr{[v1]}} : Pair(Maybe<&2, Json.Json>, Json.Json)}

# LAW: arr_insert inserts element at index 0 for any value and array list
law arr_insert_sound:
  for val: Json.Json
  for xs: List<&2, Json.Json>
  {Json.arr_get(Json.arr_insert(Json.JArr{xs}, 0n, val), 0n) == Some{val} : Maybe<&2, Json.Json>}

# LAW: arr_remove removes element at index 0 for any head and tail
law arr_remove_sound:
  for h: Json.Json
  for t: List<&2, Json.Json>
  {Json.arr_len(Json.arr_remove(Json.JArr{h <> t}, 0n)) == Json.arr_len(Json.JArr{t}) : Nat}

# ==============================================================================
# 7. Ergonomic Typed Extractors Laws (Universally Quantified)
# ==============================================================================

# LAW: get_str extracts string property for any string value
law get_str_sound:
  for s: String
  {Json.get_str(Json.JObj{[Tuple{"msg", Json.JStr{s}}]}, "msg") == Some{s} : Maybe<&2, String>}

# LAW: get_num extracts number property for any natural number
law get_num_sound:
  for n: Nat
  {Json.get_num(Json.JObj{[Tuple{"count", Json.JNum{n}}]}, "count") == Some{n} : Maybe<&2, Nat>}

# LAW: get_num_or returns default when property is missing for any key and default
law get_num_or_sound:
  for k: String
  for d: Nat
  {Json.get_num_or(Json.JObj{Nil{}}, k, d) == d : Nat}

# ==============================================================================
# 8. Validation and Streaming NDJSON Laws
# ==============================================================================

# LAW: validate returns True for valid JSON (concrete example)
# Blocker for universal string predicate: requires formal grammar specification
# and parser state machine fuel bound invariants.
law validate_valid:
  {Json.validate("{\"ok\": true}") == True{} : Bool}

# LAW: validate returns False for invalid JSON (concrete example)
# Blocker: see validate_valid note.
law validate_invalid:
  {Json.validate("{invalid") == False{} : Bool}

# LAW: validate rejects numbers with leading zeros (RFC 8259 §6 concrete example)
# Blocker: see validate_valid note.
law validate_reject_leading_zero:
  {Json.validate("007") == False{} : Bool}

# LAW: validate rejects lone minus signs (concrete example)
# Blocker: see validate_valid note.
law validate_reject_lone_minus:
  {Json.validate("-") == False{} : Bool}

# LAW: validate rejects trailing commas in objects (concrete example)
# Blocker: see validate_valid note.
law validate_reject_obj_trailing_comma:
  {Json.validate("{\"a\": 1,}") == False{} : Bool}

# LAW: validate rejects trailing commas in arrays (concrete example)
# Blocker: see validate_valid note.
law validate_reject_arr_trailing_comma:
  {Json.validate("[1,]") == False{} : Bool}

# LAW: stringify_ndjson formats newline-delimited stream correctly (concrete example)
law ndjson_stringify:
  {Json.stringify_ndjson([Json.JNum{1n}, Json.JNum{2n}]) == "1\n2\n" : String}

# LAW: stringify_ndjson step property (universal for any head and tail)
law ndjson_step:
  for h: Json.Json
  for t: List<&2, Json.Json>
  {Json.stringify_ndjson(h <> t) == String.append(Json.stringify(h), String.append("\n", Json.stringify_ndjson(t))) : String}
