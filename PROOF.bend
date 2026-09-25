# PROOF.bend: Formal machine proofs for all laws defined in LAWS.bend.
# In Bend 2, definitional equalities normalize at compile time and are
# verified by the proof term {==}. Universally quantified laws over inductive
# types use pattern matching and case analysis.

import Base
import ./json.bend as Json
import ./LAWS.bend as Laws
import ./Lemmas.bend as Lemmas

# ==============================================================================
# 1. Proofs of Round-Trip Laws
# ==============================================================================

def Laws.roundtrip_null():
  {==}

def Laws.roundtrip_true():
  {==}

def Laws.roundtrip_false():
  {==}

def Laws.roundtrip_bool(b):
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.roundtrip_num_0():
  {==}

def Laws.roundtrip_num_42():
  {==}

def Laws.roundtrip_neg_7():
  {==}

def Laws.roundtrip_str_empty():
  {==}

def Laws.roundtrip_str_hello():
  {==}

def Laws.roundtrip_arr_empty():
  {==}

def Laws.roundtrip_arr_items():
  {==}

def Laws.roundtrip_obj_empty():
  {==}

def Laws.roundtrip_obj_single():
  {==}

def Laws.roundtrip_raw_decimal():
  {==}

def Laws.roundtrip_complex():
  {==}

# ==============================================================================
# 2. Proofs of Type Guard Soundness Laws
# ==============================================================================

def Laws.is_null_sound():
  {==}

def Laws.is_bool_true_sound(b):
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.is_bool_false_sound(b):
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.is_num_sound(n):
  {==}

def Laws.is_neg_sound(n):
  {==}

def Laws.is_str_sound(s):
  {==}

def Laws.is_arr_sound(vals):
  {==}

def Laws.is_obj_sound(kvs):
  {==}

def Laws.is_raw_sound(s):
  {==}

def Laws.as_raw_sound(s):
  {==}

def Laws.raw_checked_invalid():
  {==}

def Laws.raw_checked_valid():
  {==}

# ==============================================================================
# 3. Proofs of Query and Accessor Soundness Laws
# ==============================================================================

def Laws.get_found(v):
  {==}

def Laws.get_missing(key):
  {==}

def Laws.has_found(v):
  {==}

def Laws.has_missing(key):
  {==}

def Laws.arr_len_empty():
  {==}

def Laws.arr_len_two(x, y):
  {==}

def Laws.arr_get_zero(x, xs):
  {==}

# ==============================================================================
# 4. Proofs of RFC 6901 JSON Pointer Laws
# ==============================================================================

def Laws.pointer_root(j):
  {==}

def Laws.pointer_obj(v):
  {==}

def Laws.pointer_arr(v0, v1):
  {==}

def Laws.pointer_nested(v):
  {==}

def Laws.pointer_missing():
  {==}

def Laws.pointer_escape(v):
  {==}

def Laws.pointer_set_leaf(v):
  {==}

# ==============================================================================
# 5. Proofs of Object Operations & Dictionary Laws
# ==============================================================================

def Laws.obj_len_sound(v1, v2):
  {==}

def Laws.remove_sound(v):
  {==}

def Laws.merge_override(v1, v2):
  {==}

def Laws.sort_keys_order(v1, v2):
  {==}

# ==============================================================================
# 6. Proofs of Array Operations & Mutation Laws
# ==============================================================================

def Laws.arr_set_sound(old, val, tail):
  {==}

def Laws.arr_pop_sound(v1, v2):
  {==}

def Laws.arr_insert_sound(val, xs):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      {==}

def Laws.arr_remove_sound(h, t):
  {==}

# ==============================================================================
# 7. Proofs of Ergonomic Typed Extractors Laws
# ==============================================================================

def Laws.get_str_sound(s):
  {==}

def Laws.get_num_sound(n):
  {==}

def Laws.get_num_or_sound(k, d):
  {==}

# ==============================================================================
# 8. Proofs of Validation and Streaming NDJSON Laws
# ==============================================================================

def Laws.validate_valid():
  {==}

def Laws.validate_invalid():
  {==}

def Laws.validate_reject_leading_zero():
  {==}

def Laws.validate_reject_lone_minus():
  {==}

def Laws.validate_reject_obj_trailing_comma():
  {==}

def Laws.validate_reject_arr_trailing_comma():
  {==}

def Laws.ndjson_stringify():
  {==}

def Laws.ndjson_step(h, t):
  {==}
