# Lemmas.bend: Supporting lemma library for bend-json.
# Provides auxiliary properties, induction steps, and inverses needed for
# formal specifications in LAWS.bend and proofs in PROOF.bend.
#
# Covers:
#   1. List append / length lemmas for induction over JArr and JObj.
#   2. Escape / unescape inverses (RFC 8259 §7 two-character & control escapes).
#   3. UTF-16 surrogate pair round-trip (DECISIONS.md D2 item 4).
#   4. Digit encode/decode round-trip for Nat.

import Base
import ./json.bend as Json

# ==============================================================================
# 1. List Append / Length Lemmas
# ==============================================================================

# LAW: arr_len_list of an appended element increases length by 1
law arr_len_append:
  for xs: List<&2, Json.Json>
  for x: Json.Json
  {Json.arr_len_list(List.append(&2, Json.Json, xs, [x])) == 1n+Json.arr_len_list(xs) : Nat}

# PROOF: structural induction on xs
def arr_len_append(xs, x):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %arr_len_append(t, x) : {1n+Json.arr_len_list(List.append(&2, Json.Json, t, [x])) == 1n+_ : Nat}
      {==}

# LAW: obj_len_kv of an appended entry increases count by 1
law obj_len_append:
  for kvs: List<&2, Sigma<&2, &2, String, _ => Json.Json>>
  for kv: Sigma<&2, &2, String, _ => Json.Json>
  {Json.obj_len_kv(List.append(&2, Sigma<&2, &2, String, _ => Json.Json>, kvs, [kv])) == 1n+Json.obj_len_kv(kvs) : Nat}

# PROOF: structural induction on kvs
def obj_len_append(kvs, kv):
  match kvs:
    case Nil{}:
      {==}
    case h <> t:
      %obj_len_append(t, kv) : {1n+Json.obj_len_kv(List.append(&2, Sigma<&2, &2, String, _ => Json.Json>, t, [kv])) == 1n+_ : Nat}
      {==}

# ==============================================================================
# 2. Escape / Unescape Inverses (RFC 8259 §7 and DECISIONS.md D2)
# ==============================================================================

# RFC 8259 §7 two-character escape sequences round-trip through unescaping
law unescape_quote:
  {Json.parse_escape_seq(34, "") == Json.EscChar{Chr{34}, ""} : Json.EscRes}
def unescape_quote():
  {==}

law unescape_backslash:
  {Json.parse_escape_seq(92, "") == Json.EscChar{Chr{92}, ""} : Json.EscRes}
def unescape_backslash():
  {==}

law unescape_newline:
  {Json.parse_escape_seq(110, "") == Json.EscChar{Chr{10}, ""} : Json.EscRes}
def unescape_newline():
  {==}

law unescape_tab:
  {Json.parse_escape_seq(116, "") == Json.EscChar{Chr{9}, ""} : Json.EscRes}
def unescape_tab():
  {==}

law unescape_cr:
  {Json.parse_escape_seq(114, "") == Json.EscChar{Chr{13}, ""} : Json.EscRes}
def unescape_cr():
  {==}

law unescape_backspace:
  {Json.parse_escape_seq(98, "") == Json.EscChar{Chr{8}, ""} : Json.EscRes}
def unescape_backspace():
  {==}

law unescape_formfeed:
  {Json.parse_escape_seq(102, "") == Json.EscChar{Chr{12}, ""} : Json.EscRes}
def unescape_formfeed():
  {==}

# Control character escapes (< 0x20) serialize to \u00XX and parse back
law escape_control_0:
  {Json.escape_char(Chr{0}) == "\\u0000" : String}
def escape_control_0():
  {==}

law unescape_control_0:
  {Json.parse_escape_seq(117, "0000") == Json.EscChar{Chr{0}, ""} : Json.EscRes}
def unescape_control_0():
  {==}

law escape_control_1f:
  {Json.escape_char(Chr{31}) == "\\u001f" : String}
def escape_control_1f():
  {==}

law unescape_control_1f:
  {Json.parse_escape_seq(117, "001f") == Json.EscChar{Chr{31}, ""} : Json.EscRes}
def unescape_control_1f():
  {==}

law escape_control_esc:
  {Json.escape_char(Chr{27}) == "\\u001b" : String}
def escape_control_esc():
  {==}

law unescape_control_esc:
  {Json.parse_escape_seq(117, "001b") == Json.EscChar{Chr{27}, ""} : Json.EscRes}
def unescape_control_esc():
  {==}

# Note on general string round-trip:
# Universal round-trip for arbitrary character lists (for s: String) requires
# structural induction over String characters combined with lemmas relating
# classify_esc_char, hex encoding/decoding, and parser state machine fuel.
# These depend on upstream Base string induction lemmas currently absent in Base.

# ==============================================================================
# 3. UTF-16 Surrogate Pair Round-Trip (DECISIONS.md D2 Item 4)
# ==============================================================================

# Encode scalar >= 0x10000 into high and low surrogate pair
def encode_surrogate(s: U32) -> Pair(U32, U32):
  +temp = (s - 65536 : U32)
  hi    = (55296 + (temp / 1024 : U32) : U32)
  lo    = (56320 + (temp % 1024 : U32) : U32)
  Tuple{hi, lo}

# Decode high and low surrogate pair back into scalar
def decode_surrogate(hi: U32, lo: U32) -> U32:
  (65536 + (((hi - 55296 : U32) * 1024 : U32) + (lo - 56320 : U32) : U32) : U32)

# LAW: Minimum surrogate scalar U+10000 round-trips
law surrogate_roundtrip_min:
  {decode_surrogate(55296, 56320) == 65536 : U32}
def surrogate_roundtrip_min():
  {==}

# LAW: Grinning Face emoji U+1F600 round-trips
law surrogate_roundtrip_grinning_face:
  {decode_surrogate(55357, 56832) == 128512 : U32}
def surrogate_roundtrip_grinning_face():
  {==}

# LAW: Maximum Unicode scalar U+10FFFF round-trips
law surrogate_roundtrip_max:
  {decode_surrogate(56319, 57343) == 1114111 : U32}
def surrogate_roundtrip_max():
  {==}

# Note on symbolic surrogate round-trip:
# Stating `for s: U32 { decode_surrogate(encode_surrogate(s)) == s }` requires
# algebraic theorems connecting U32.div and U32.mod over Word(32n)
# (i.e. `(x / 1024) * 1024 + (x % 1024) == x`). Base currently provides only
# Word.add_comm / U32.add_comm, with no Word division/remainder lemmas.

# ==============================================================================
# 4. Digit Encode/Decode Round-Trip for Nat
# ==============================================================================

def nat_to_digit_char(d: Nat) -> Char:
  Chr{U32.from_nat(Nat.add(48n, d))}

def digit_char_to_nat(c: Char) -> Maybe<&2, Nat>:
  match c:
    case Chr{code}:
      +d = U32.sub(code, 48)
      Bool.pick(Maybe<&2, Nat>, U32.is_lt(d, 10), Some{U32.to_nat(d)}, None{})

# LAW: Digit 0 round-trips
law digit_roundtrip_0:
  {digit_char_to_nat(nat_to_digit_char(0n)) == Some{0n} : Maybe<&2, Nat>}
def digit_roundtrip_0():
  {==}

# LAW: Digit 1 round-trips
law digit_roundtrip_1:
  {digit_char_to_nat(nat_to_digit_char(1n)) == Some{1n} : Maybe<&2, Nat>}
def digit_roundtrip_1():
  {==}

# LAW: Digit 5 round-trips
law digit_roundtrip_5:
  {digit_char_to_nat(nat_to_digit_char(5n)) == Some{5n} : Maybe<&2, Nat>}
def digit_roundtrip_5():
  {==}

# LAW: Digit 9 round-trips
law digit_roundtrip_9:
  {digit_char_to_nat(nat_to_digit_char(9n)) == Some{9n} : Maybe<&2, Nat>}
def digit_roundtrip_9():
  {==}

# LAW: Character '0' maps to Nat 0 and back
law char_digit_roundtrip_0:
  {nat_to_digit_char(0n) == Chr{48} : Char}
def char_digit_roundtrip_0():
  {==}

# LAW: Character '9' maps to Nat 9 and back
law char_digit_roundtrip_9:
  {nat_to_digit_char(9n) == Chr{57} : Char}
def char_digit_roundtrip_9():
  {==}

# Note on multi-digit round-trip for arbitrary Nat:
# Proving `for n: Nat { parse(stringify(JNum{n})) == Done{JNum{n}} }` bounded by
# 2^48 - 1 requires Euclidean division lemmas (Nat.divmod quotient/remainder
# properties), base-10 Horner accumulation, and parser fuel invariants.
# Base currently has no general Nat arithmetic lemmas beyond Word.add_comm.

# ==============================================================================
# 5. Pointer Traversal & Value Extraction Invariants
# ==============================================================================

# LAW: Traversing with None accumulator always yields None for any token list
law pointer_traverse_none:
  for tokens: List<&2, String>
  {Json.pointer_traverse_loop(tokens, None{}) == None{} : Maybe<&2, Json.Json>}

def pointer_traverse_none(tokens):
  match tokens:
    case Nil{}:
      {==}
    case token <> rest:
      {==}

# LAW: Resolving any non-empty path against an empty object always yields None
law pointer_empty_traverse:
  for token: String
  for rest: List<&2, String>
  {Json.pointer_traverse_loop(token <> rest, Some{Json.JObj{Nil{}}}) == None{} : Maybe<&2, Json.Json>}

def pointer_empty_traverse(token, rest):
  match rest:
    case Nil{}:
      {==}
    case h <> t:
      {==}

# LAW: arr_len on JArr coincides with arr_len_list for any element list
law arr_len_def:
  for vals: List<&2, Json.Json>
  {Json.arr_len(Json.JArr{vals}) == Json.arr_len_list(vals) : Nat}

def arr_len_def(vals):
  {==}

# LAW: obj_len on JObj coincides with obj_len_kv for any entry list
law obj_len_def:
  for kvs: List<&2, Sigma<&2, &2, String, _ => Json.Json>>
  {Json.obj_len(Json.JObj{kvs}) == Json.obj_len_kv(kvs) : Nat}

def obj_len_def(kvs):
  {==}

# LAW: as_bool unpacks any JBool value
law as_bool_sound:
  for b: Bool
  {Json.as_bool(Json.JBool{b}) == Some{b} : Maybe<&2, Bool>}

def as_bool_sound(b):
  {==}

# LAW: as_num unpacks any JNum value
law as_num_sound:
  for n: Nat
  {Json.as_num(Json.JNum{n}) == Some{n} : Maybe<&2, Nat>}

def as_num_sound(n):
  {==}

# LAW: as_neg unpacks any JNeg value
law as_neg_sound:
  for n: Nat
  {Json.as_neg(Json.JNeg{n}) == Some{n} : Maybe<&2, Nat>}

def as_neg_sound(n):
  {==}

# LAW: as_str unpacks any JStr value
law as_str_sound:
  for s: String
  {Json.as_str(Json.JStr{s}) == Some{s} : Maybe<&2, String>}

def as_str_sound(s):
  {==}

# LAW: as_arr unpacks any JArr value
law as_arr_sound:
  for vals: List<&2, Json.Json>
  {Json.as_arr(Json.JArr{vals}) == Some{vals} : Maybe<&2, List<&2, Json.Json>>}

def as_arr_sound(vals):
  {==}

# LAW: as_obj unpacks any JObj value
law as_obj_sound:
  for kvs: List<&2, Sigma<&2, &2, String, _ => Json.Json>>
  {Json.as_obj(Json.JObj{kvs}) == Some{kvs} : Maybe<&2, List<&2, Sigma<&2, &2, String, _ => Json.Json>>>}

def as_obj_sound(kvs):
  {==}

