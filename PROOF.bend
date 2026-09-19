# PROOF.bend: Formal machine proofs for all laws defined in LAWS.bend.
# In Bend 2, definitional equalities normalize at compile time and are
# verified by the proof term {==}.

import Base
import ./json.bend as Json
import ./LAWS.bend as Laws

# ==============================================================================
# 1. Proofs of Round-Trip Laws
# ==============================================================================

def Laws.roundtrip_null():
  {==}

def Laws.roundtrip_true():
  {==}

def Laws.roundtrip_false():
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

def Laws.roundtrip_complex():
  {==}

# ==============================================================================
# 2. Proofs of Type Guard Soundness Laws
# ==============================================================================

def Laws.is_null_sound():
  {==}

def Laws.is_bool_true_sound():
  {==}

def Laws.is_bool_false_sound():
  {==}

def Laws.is_num_sound():
  {==}

def Laws.is_neg_sound():
  {==}

def Laws.is_str_sound():
  {==}

def Laws.is_arr_sound():
  {==}

def Laws.is_obj_sound():
  {==}

# ==============================================================================
# 3. Proofs of Query and Accessor Soundness Laws
# ==============================================================================

def Laws.get_found():
  {==}

def Laws.get_missing():
  {==}

def Laws.has_found():
  {==}

def Laws.has_missing():
  {==}

def Laws.arr_len_empty():
  {==}

def Laws.arr_len_two():
  {==}

def Laws.arr_get_zero():
  {==}

# ==============================================================================
# 4. Proofs of RFC 6901 JSON Pointer Laws
# ==============================================================================

def Laws.pointer_root():
  {==}

def Laws.pointer_obj():
  {==}

def Laws.pointer_arr():
  {==}

def Laws.pointer_nested():
  {==}

def Laws.pointer_missing():
  {==}

def Laws.pointer_escape():
  {==}

def Laws.pointer_set_leaf():
  {==}

# ==============================================================================
# 5. Proofs of Object Operations & Dictionary Laws
# ==============================================================================

def Laws.obj_len_sound():
  {==}

def Laws.remove_sound():
  {==}

def Laws.merge_override():
  {==}

def Laws.sort_keys_order():
  {==}

# ==============================================================================
# 6. Proofs of Array Operations & Mutation Laws
# ==============================================================================

def Laws.arr_set_sound():
  {==}

def Laws.arr_pop_sound():
  {==}

def Laws.arr_insert_sound():
  {==}

def Laws.arr_remove_sound():
  {==}

# ==============================================================================
# 7. Proofs of Ergonomic Typed Extractors Laws
# ==============================================================================

def Laws.get_str_sound():
  {==}

def Laws.get_num_sound():
  {==}

def Laws.get_num_or_sound():
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
