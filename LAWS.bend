# LAWS.bend: Formal specifications and invariant laws for the Bend 2 JSON library.
# The user/human states the laws; PROOF.bend mechanically proves each one.
#
# Covers:
#   1. Round-trip serialization & parsing (stringify -> parse -> identity)
#      for all core JSON types (Null, Bool, Pos/Neg Number, String, Array, Object, Nested)
#   2. Type checker / guard soundness
#   3. Query and inspection properties (get, has, arr_len, arr_get)

import Base
import ./json.bend as Json

# ==============================================================================
# 1. Round-Trip Laws: parse(stringify(x)) == Done{x}
# ==============================================================================

# LAW: Null round-trips through stringify and parse
law roundtrip_null:
  {Json.parse(Json.stringify(Json.JNull{})) == Done{Json.JNull{}} : Result<&2, &2, String, Json.Json>}

# LAW: Boolean True round-trips
law roundtrip_true:
  {Json.parse(Json.stringify(Json.JBool{True{}})) == Done{Json.JBool{True{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Boolean False round-trips
law roundtrip_false:
  {Json.parse(Json.stringify(Json.JBool{False{}})) == Done{Json.JBool{False{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Number 0 round-trips
law roundtrip_num_0:
  {Json.parse(Json.stringify(Json.JNum{0n})) == Done{Json.JNum{0n}} : Result<&2, &2, String, Json.Json>}

# LAW: Number 42 round-trips
law roundtrip_num_42:
  {Json.parse(Json.stringify(Json.JNum{42n})) == Done{Json.JNum{42n}} : Result<&2, &2, String, Json.Json>}

# LAW: Negative number -7 round-trips
law roundtrip_neg_7:
  {Json.parse(Json.stringify(Json.JNeg{7n})) == Done{Json.JNeg{7n}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty string round-trips
law roundtrip_str_empty:
  {Json.parse(Json.stringify(Json.JStr{""})) == Done{Json.JStr{""}} : Result<&2, &2, String, Json.Json>}

# LAW: Non-empty string round-trips
law roundtrip_str_hello:
  {Json.parse(Json.stringify(Json.JStr{"hello"})) == Done{Json.JStr{"hello"}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty array round-trips
law roundtrip_arr_empty:
  {Json.parse(Json.stringify(Json.JArr{Nil{}})) == Done{Json.JArr{Nil{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Non-empty array round-trips
law roundtrip_arr_items:
  {Json.parse(Json.stringify(Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]})) == Done{Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]}} : Result<&2, &2, String, Json.Json>}

# LAW: Empty object round-trips
law roundtrip_obj_empty:
  {Json.parse(Json.stringify(Json.JObj{Nil{}})) == Done{Json.JObj{Nil{}}} : Result<&2, &2, String, Json.Json>}

# LAW: Single key-value object round-trips
law roundtrip_obj_single:
  {Json.parse(Json.stringify(Json.JObj{[Tuple{"name", Json.JStr{"bend"}}]})) == Done{Json.JObj{[Tuple{"name", Json.JStr{"bend"}}]}} : Result<&2, &2, String, Json.Json>}

# LAW: Raw decimal number round-trips
law roundtrip_raw_decimal:
  {Json.parse(Json.stringify(Json.JRaw{"1.5"})) == Done{Json.JRaw{"1.5"}} : Result<&2, &2, String, Json.Json>}

# LAW: Nested complex JSON structure round-trips
law roundtrip_complex:
  {Json.parse(Json.stringify(Json.JObj{[Tuple{"a", Json.JNum{10n}}, Tuple{"b", Json.JArr{[Json.JBool{True{}}, Json.JNull{}]}}]})) == Done{Json.JObj{[Tuple{"a", Json.JNum{10n}}, Tuple{"b", Json.JArr{[Json.JBool{True{}}, Json.JNull{}]}}]}} : Result<&2, &2, String, Json.Json>}

# ==============================================================================
# 2. Type Guard Soundness Laws
# ==============================================================================

# LAW: is_null is sound
law is_null_sound:
  {Json.is_null(Json.JNull{}) == True{} : Bool}

# LAW: is_bool is sound for True
law is_bool_true_sound:
  {Json.is_bool(Json.JBool{True{}}) == True{} : Bool}

# LAW: is_bool is sound for False
law is_bool_false_sound:
  {Json.is_bool(Json.JBool{False{}}) == True{} : Bool}

# LAW: is_num is sound
law is_num_sound:
  {Json.is_num(Json.JNum{10n}) == True{} : Bool}

# LAW: is_neg is sound
law is_neg_sound:
  {Json.is_neg(Json.JNeg{10n}) == True{} : Bool}

# LAW: is_str is sound
law is_str_sound:
  {Json.is_str(Json.JStr{"test"}) == True{} : Bool}

# LAW: is_arr is sound
law is_arr_sound:
  {Json.is_arr(Json.JArr{Nil{}}) == True{} : Bool}

# LAW: is_obj is sound
law is_obj_sound:
  {Json.is_obj(Json.JObj{Nil{}}) == True{} : Bool}

# LAW: is_raw is sound
law is_raw_sound:
  {Json.is_raw(Json.JRaw{"1.5"}) == True{} : Bool}

# LAW: as_raw is sound
law as_raw_sound:
  {Json.as_raw(Json.JRaw{"1.5"}) == Some{"1.5"} : Maybe<&2, String>}

# ==============================================================================
# 3. Query and Accessor Soundness Laws
# ==============================================================================

# LAW: get returns existing property in object
law get_found:
  {Json.get(Json.JObj{[Tuple{"k", Json.JNum{99n}}]}, "k") == Some{Json.JNum{99n}} : Maybe<&2, Json.Json>}

# LAW: get returns None for missing property
law get_missing:
  {Json.get(Json.JObj{Nil{}}, "k") == None{} : Maybe<&2, Json.Json>}

# LAW: has returns True for existing property
law has_found:
  {Json.has(Json.JObj{[Tuple{"k", Json.JNull{}}]}, "k") == True{} : Bool}

# LAW: has returns False for missing property
law has_missing:
  {Json.has(Json.JObj{Nil{}}, "k") == False{} : Bool}

# LAW: arr_len of empty array is 0
law arr_len_empty:
  {Json.arr_len(Json.JArr{Nil{}}) == 0n : Nat}

# LAW: arr_len counts elements correctly
law arr_len_two:
  {Json.arr_len(Json.JArr{[Json.JNull{}, Json.JNull{}]}) == 2n : Nat}

# LAW: arr_get accesses index 0 correctly
law arr_get_zero:
  {Json.arr_get(Json.JArr{[Json.JNum{42n}]}, 0n) == Some{Json.JNum{42n}} : Maybe<&2, Json.Json>}

# ==============================================================================
# 4. RFC 6901 JSON Pointer Laws
# ==============================================================================

# LAW: Empty pointer resolves root document
law pointer_root:
  {Json.pointer(Json.JNum{42n}, "") == Some{Json.JNum{42n}} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves object property by key
law pointer_obj:
  {Json.pointer(Json.JObj{[Tuple{"name", Json.JStr{"bend"}}]}, "/name") == Some{Json.JStr{"bend"}} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves array element by index
law pointer_arr:
  {Json.pointer(Json.JArr{[Json.JNum{10n}, Json.JNum{20n}]}, "/1") == Some{Json.JNum{20n}} : Maybe<&2, Json.Json>}

# LAW: Pointer resolves nested paths
law pointer_nested:
  {Json.pointer(Json.JObj{[Tuple{"a", Json.JArr{[Json.JNum{99n}]}}]}, "/a/0") == Some{Json.JNum{99n}} : Maybe<&2, Json.Json>}

# LAW: Pointer returns None for non-existent path
law pointer_missing:
  {Json.pointer(Json.JObj{Nil{}}, "/missing") == None{} : Maybe<&2, Json.Json>}

# LAW: Pointer unescapes ~1 as /
law pointer_escape:
  {Json.pointer(Json.JObj{[Tuple{"a/b", Json.JBool{True{}}}]}, "/a~1b") == Some{Json.JBool{True{}}} : Maybe<&2, Json.Json>}

# LAW: Pointer deep update sets value at path
law pointer_set_leaf:
  {Json.pointer(Json.pointer_set(Json.JObj{Nil{}}, "/x", Json.JNum{7n}), "/x") == Some{Json.JNum{7n}} : Maybe<&2, Json.Json>}

# ==============================================================================
# 5. Object Operations & Dictionary Laws
# ==============================================================================

# LAW: obj_len counts keys correctly
law obj_len_sound:
  {Json.obj_len(Json.JObj{[Tuple{"a", Json.JNull{}}, Tuple{"b", Json.JNull{}}]}) == 2n : Nat}

# LAW: remove deletes key from object
law remove_sound:
  {Json.has(Json.remove(Json.JObj{[Tuple{"a", Json.JNum{1n}}]}, "a"), "a") == False{} : Bool}

# LAW: merge overrides matching keys with second object
law merge_override:
  {Json.get(Json.merge(Json.JObj{[Tuple{"a", Json.JNum{1n}}]}, Json.JObj{[Tuple{"a", Json.JNum{2n}}]}), "a") == Some{Json.JNum{2n}} : Maybe<&2, Json.Json>}

# LAW: sort_keys sorts keys alphabetically
law sort_keys_order:
  {Json.keys(Json.sort_keys(Json.JObj{[Tuple{"z", Json.JNull{}}, Tuple{"a", Json.JNull{}}]})) == ["a", "z"] : List<&2, String>}

# ==============================================================================
# 6. Array Operations & Mutation Laws
# ==============================================================================

# LAW: arr_set updates element at index
law arr_set_sound:
  {Json.arr_get(Json.arr_set(Json.JArr{[Json.JNum{1n}]}, 0n, Json.JNum{55n}), 0n) == Some{Json.JNum{55n}} : Maybe<&2, Json.Json>}

# LAW: arr_pop pops last element
law arr_pop_sound:
  {Json.arr_pop(Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]}) == Tuple{Some{Json.JNum{2n}}, Json.JArr{[Json.JNum{1n}]}} : Pair(Maybe<&2, Json.Json>, Json.Json)}

# LAW: arr_insert inserts element at index
law arr_insert_sound:
  {Json.arr_get(Json.arr_insert(Json.JArr{[Json.JNum{1n}]}, 0n, Json.JNum{99n}), 0n) == Some{Json.JNum{99n}} : Maybe<&2, Json.Json>}

# LAW: arr_remove removes element at index
law arr_remove_sound:
  {Json.arr_len(Json.arr_remove(Json.JArr{[Json.JNum{1n}, Json.JNum{2n}]}, 0n)) == 1n : Nat}

# ==============================================================================
# 7. Ergonomic Typed Extractors Laws
# ==============================================================================

# LAW: get_str extracts string property
law get_str_sound:
  {Json.get_str(Json.JObj{[Tuple{"msg", Json.JStr{"hello"}}]}, "msg") == Some{"hello"} : Maybe<&2, String>}

# LAW: get_num extracts number property
law get_num_sound:
  {Json.get_num(Json.JObj{[Tuple{"count", Json.JNum{100n}}]}, "count") == Some{100n} : Maybe<&2, Nat>}

# LAW: get_num_or returns default when property is missing
law get_num_or_sound:
  {Json.get_num_or(Json.JObj{Nil{}}, "count", 42n) == 42n : Nat}

# ==============================================================================
# 8. Validation and Streaming NDJSON Laws
# ==============================================================================

# LAW: validate returns True for valid JSON
law validate_valid:
  {Json.validate("{\"ok\": true}") == True{} : Bool}

# LAW: validate returns False for invalid JSON
law validate_invalid:
  {Json.validate("{invalid") == False{} : Bool}

# LAW: validate rejects numbers with leading zeros (RFC 8259 §6)
law validate_reject_leading_zero:
  {Json.validate("007") == False{} : Bool}

# LAW: validate rejects lone minus signs
law validate_reject_lone_minus:
  {Json.validate("-") == False{} : Bool}

# LAW: validate rejects trailing commas in objects
law validate_reject_obj_trailing_comma:
  {Json.validate("{\"a\": 1,}") == False{} : Bool}

# LAW: validate rejects trailing commas in arrays
law validate_reject_arr_trailing_comma:
  {Json.validate("[1,]") == False{} : Bool}

# LAW: stringify_ndjson formats newline-delimited stream correctly
law ndjson_stringify:
  {Json.stringify_ndjson([Json.JNum{1n}, Json.JNum{2n}]) == "1\n2\n" : String}
