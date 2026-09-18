# json.bend: A production-grade, highly reusable JSON library for Bend 2.
# Compliant with RFC 8259 (JSON specification) and RFC 6901 (JSON Pointer).
#
# Supports:
#   - Full JSON AST: Null, Bool, Number (Pos Nat, Neg Nat), String, Array, Object
#   - Full RFC 8259 character escaping and unescaping
#   - Safe type guards and typed value unwrapping
#   - Comprehensive Object operations: get, has, set, remove, obj_len, keys, values, entries, merge, sort_keys
#   - Functional Array combinators: arr_len, arr_get, arr_push, arr_set, arr_pop, arr_remove, arr_insert, arr_map, arr_filter, arr_fold
#   - Ergonomic typed field extractors with fallback defaults: get_str, get_num, get_bool, etc.
#   - RFC 6901 JSON Pointer queries and deep path updates: pointer, pointer_set
#   - High-performance compact serialization: stringify
#   - Configurable pretty printing with arbitrary indentation: pretty, pretty_indent
#   - Streaming NDJSON (Newline Delimited JSON): parse_ndjson, stringify_ndjson
#   - Fast JSON validation: validate
#   - Linear recursive-descent parser: parse

import Base

# ==============================================================================
# 1. AST Data Types
# ==============================================================================

type Json is Data:
  JNull{}
  JBool{val: Bool}
  JNum{val: Nat}
  JNeg{val: Nat}
  JStr{val: String}
  JArr{vals: List<&2, Json>}
  JObj{kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}

# Parser stack frames
type Frame is Data:
  FArr{items: List<&2, Json>}
  FObjVal{key: String, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}

# String parser types
type StrCharKind is Data:
  SCQuote{}
  SCSlash{}
  SCOther{}

type StrRes is Data:
  SErr{msg: String}
  SOk{val: String, rest: String}

type StrState is Data:
  StrNormal{}
  StrEscaping{}
  StrChar{kind: StrCharKind, c: U32}

type PtrUnescState is Data:
  PUNormal{}
  PUTilde{}
  PUChar{is_tilde: Bool, c: U32}
  PUTildeChar{is_one: Bool, is_zero: Bool, c: U32}

type PtrSplitState is Data:
  PSNormal{}
  PSChar{is_slash: Bool, c: U32}

type NatState is Data:
  NParseDigits{}
  NCheckDigit{is_d: Bool, c: U32}

type LineSplitState is Data:
  LSNormal{}
  LSCheckNl{is_nl: Bool, c: U32}
  LSEmpty{is_empty: Bool, line: String}

# Number parser result
type NumRes is Data:
  NRes{val: Nat, rest: String}

# General character classification
type CharKind is Data:
  KindLBracket{}
  KindRBracket{}
  KindLBrace{}
  KindRBrace{}
  KindQuote{}
  KindComma{}
  KindColon{}
  KindNull{}
  KindTrue{}
  KindFalse{}
  KindMinus{}
  KindDigit{}
  KindOther{}

# Parser state machine actions
type StepAct is Data:
  ActValStart{}
  ActValChar{kind: CharKind, c: U32}
  ActArrOpen{}
  ActArrOpenChar{kind: CharKind, c: U32}
  ActArrNext{v: Json, items: List<&2, Json>}
  ActArrNextChar{kind: CharKind, v: Json, items: List<&2, Json>}
  ActObjOpen{}
  ActObjOpenChar{kind: CharKind, c: U32}
  ActKeyStart{kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActKeyStartChar{kind: CharKind, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActKeyParsed{res: StrRes, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActColon{key: String, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActColonChar{kind: CharKind, key: String, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActObjNext{key: String, v: Json, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActObjNextChar{kind: CharKind, key: String, v: Json, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  ActHaveVal{v: Json}
  ActCheckEof{v: Json}
  ActStrParsed{res: StrRes}
  ActNumParsed{neg_flag: Bool, res: NumRes}
  ActLitCheck{expected: String, val: Json, ok: Bool, rest: String}

# Serializer stack task
type PrintTask is Data:
  PVal{j: Json}
  PArr{items: List<&2, Json>}
  PObj{kvs: List<&2, Sigma<&2, &2, String, _ => Json>>}
  PLit{s: String}

# Pretty printer stack task
type PrettyTask is Data:
  PrVal{j: Json, indent: Nat}
  PrArr{items: List<&2, Json>, indent: Nat}
  PrObj{kvs: List<&2, Sigma<&2, &2, String, _ => Json>>, indent: Nat}
  PrLit{s: String}

# ==============================================================================
# 2. Constructors and Builders
# ==============================================================================

def null() -> Json:
  JNull{}

def bool(b: Bool) -> Json:
  JBool{b}

def true_val() -> Json:
  JBool{True{}}

def false_val() -> Json:
  JBool{False{}}

def num(n: Nat) -> Json:
  JNum{n}

def neg(n: Nat) -> Json:
  JNeg{n}

def str(s: String) -> Json:
  JStr{s}

def arr(vals: List<&2, Json>) -> Json:
  JArr{vals}

def obj(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> Json:
  JObj{kvs}

def kv(key: String, val: Json) -> Sigma<&2, &2, String, _ => Json>:
  Tuple{key, val}

# ==============================================================================
# 3. Type Checking and Guards
# ==============================================================================

def is_null(j: Json) -> Bool:
  match j:
    case JNull{}:
      True{}
    case _:
      False{}

def is_bool(j: Json) -> Bool:
  match j:
    case JBool{_}:
      True{}
    case _:
      False{}

def is_num(j: Json) -> Bool:
  match j:
    case JNum{_}:
      True{}
    case _:
      False{}

def is_neg(j: Json) -> Bool:
  match j:
    case JNeg{_}:
      True{}
    case _:
      False{}

def is_str(j: Json) -> Bool:
  match j:
    case JStr{_}:
      True{}
    case _:
      False{}

def is_arr(j: Json) -> Bool:
  match j:
    case JArr{_}:
      True{}
    case _:
      False{}

def is_obj(j: Json) -> Bool:
  match j:
    case JObj{_}:
      True{}
    case _:
      False{}

# ==============================================================================
# 4. Value Extraction
# ==============================================================================

def as_bool(j: Json) -> Maybe<&2, Bool>:
  match j:
    case JBool{b}:
      Some{b}
    case _:
      None{}

def as_num(j: Json) -> Maybe<&2, Nat>:
  match j:
    case JNum{n}:
      Some{n}
    case _:
      None{}

def as_neg(j: Json) -> Maybe<&2, Nat>:
  match j:
    case JNeg{n}:
      Some{n}
    case _:
      None{}

def as_str(j: Json) -> Maybe<&2, String>:
  match j:
    case JStr{s}:
      Some{s}
    case _:
      None{}

def as_arr(j: Json) -> Maybe<&2, List<&2, Json>>:
  match j:
    case JArr{vals}:
      Some{vals}
    case _:
      None{}

def as_obj(j: Json) -> Maybe<&2, List<&2, Sigma<&2, &2, String, _ => Json>>>:
  match j:
    case JObj{kvs}:
      Some{kvs}
    case _:
      None{}

# ==============================================================================
# 5. Object Operations & Dictionary Utilities
# ==============================================================================

def get_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>, +key: String) -> Maybe<&2, Json>:
  match kvs:
    case Nil{}:
      None{}
    case Tuple{k, +v} <> t:
      Bool.pick(Maybe<&2, Json>, String.eq(k, key),
        Some{v},
        get_kv(t, key))

def get(j: Json, key: String) -> Maybe<&2, Json>:
  match j:
    case JObj{kvs}:
      get_kv(kvs, key)
    case _:
      None{}

def has.is_some(m: Maybe<&2, Json>) -> Bool:
  match m:
    case Some{_}:
      True{}
    case None{}:
      False{}

def has(j: Json, key: String) -> Bool:
  has.is_some(get(j, key))

def set_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>, +key: String, +val: Json) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match kvs:
    case Nil{}:
      [Tuple{key, val}]
    case Tuple{+k, +v} <> +t:
      Bool.pick(List<&2, Sigma<&2, &2, String, _ => Json>>, String.eq(k, key),
        Tuple{key, val} <> t,
        Tuple{k, v} <> set_kv(t, key, val))

def set(j: Json, key: String, val: Json) -> Json:
  match j:
    case JObj{kvs}:
      JObj{set_kv(kvs, key, val)}
    case _:
      JObj{[Tuple{key, val}]}

def remove_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>, +key: String) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match kvs:
    case Nil{}:
      Nil{}
    case Tuple{+k, +v} <> +t:
      Bool.pick(List<&2, Sigma<&2, &2, String, _ => Json>>, String.eq(k, key),
        t,
        Tuple{k, v} <> remove_kv(t, key))

def remove(j: Json, key: String) -> Json:
  match j:
    case JObj{kvs}:
      JObj{remove_kv(kvs, key)}
    case _:
      j

def obj_len_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> Nat:
  match kvs:
    case Nil{}:
      0n
    case _ <> t:
      1n+obj_len_kv(t)

def obj_len(j: Json) -> Nat:
  match j:
    case JObj{kvs}:
      obj_len_kv(kvs)
    case _:
      0n

def keys_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, String>:
  match kvs:
    case Nil{}:
      Nil{}
    case Tuple{k, _} <> t:
      k <> keys_kv(t)

def keys(j: Json) -> List<&2, String>:
  match j:
    case JObj{kvs}:
      keys_kv(kvs)
    case _:
      Nil{}

def values_kv(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, Json>:
  match kvs:
    case Nil{}:
      Nil{}
    case Tuple{_, v} <> t:
      v <> values_kv(t)

def values(j: Json) -> List<&2, Json>:
  match j:
    case JObj{kvs}:
      values_kv(kvs)
    case _:
      Nil{}

def entries(j: Json) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match j:
    case JObj{kvs}:
      kvs
    case _:
      Nil{}

def merge_kvs(overrides: List<&2, Sigma<&2, &2, String, _ => Json>>, base: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match overrides:
    case Nil{}:
      base
    case Tuple{k, v} <> t:
      merge_kvs(t, set_kv(base, k, v))

def merge(j1: Json, j2: Json) -> Json:
  match j1:
    case JObj{kvs1}:
      match j2:
        case JObj{kvs2}:
          JObj{merge_kvs(kvs2, kvs1)}
        case _:
          j2
    case _:
      j2

def insert_kv_go(+ek: String, +ev: Json, +kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match kvs:
    case Nil{}:
      [Tuple{ek, ev}]
    case Tuple{+k, +v} <> +t:
      Bool.pick(List<&2, Sigma<&2, &2, String, _ => Json>>, String.is_le(ek, k),
        Tuple{ek, ev} <> Tuple{k, v} <> t,
        Tuple{k, v} <> insert_kv_go(ek, ev, t))

def insert_kv(elem: Sigma<&2, &2, String, _ => Json>, kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  Tuple{ek, ev} = elem
  insert_kv_go(ek, ev, kvs)

def sort_kvs(kvs: List<&2, Sigma<&2, &2, String, _ => Json>>) -> List<&2, Sigma<&2, &2, String, _ => Json>>:
  match kvs:
    case Nil{}:
      Nil{}
    case h <> t:
      insert_kv(h, sort_kvs(t))

def sort_keys(j: Json) -> Json:
  match j:
    case JObj{kvs}:
      JObj{sort_kvs(kvs)}
    case _:
      j

def to_map(j: Json) -> Maybe<&2, Map<&2, Json>>:
  match j:
    case JObj{kvs}:
      Some{Map.from_list(&2, Json, kvs)}
    case _:
      None{}

def from_map(m: Map<&2, Json>) -> Json:
  JObj{Map.to_list(&2, Json, m)}

# ==============================================================================
# 6. Array Operations & Functional Combinators
# ==============================================================================

def arr_len_list(vals: List<&2, Json>) -> Nat:
  match vals:
    case Nil{}:
      0n
    case _ <> t:
      1n+arr_len_list(t)

def arr_len(j: Json) -> Nat:
  match j:
    case JArr{vals}:
      arr_len_list(vals)
    case _:
      0n

def arr_get_list(vals: List<&2, Json>, idx: Nat) -> Maybe<&2, Json>:
  match vals:
    case Nil{}:
      None{}
    case h <> t:
      match idx:
        case 0n:
          Some{h}
        case 1n+p:
          arr_get_list(t, p)

def arr_get(j: Json, idx: Nat) -> Maybe<&2, Json>:
  match j:
    case JArr{vals}:
      arr_get_list(vals, idx)
    case _:
      None{}

def arr_push(j: Json, elem: Json) -> Json:
  match j:
    case JArr{vals}:
      JArr{List.append(&2, Json, vals, [elem])}
    case _:
      JArr{[elem]}

def list_set_idx(xs: List<&2, Json>, idx: Nat, +val: Json) -> List<&2, Json>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      match idx:
        case 0n:
          val <> t
        case 1n+p:
          h <> list_set_idx(t, p, val)

def arr_set(j: Json, idx: Nat, val: Json) -> Json:
  match j:
    case JArr{vals}:
      JArr{list_set_idx(vals, idx, val)}
    case _:
      j

def list_pop_step(h: Json, res: Pair(Maybe<&2, Json>, List<&2, Json>)) -> Pair(Maybe<&2, Json>, List<&2, Json>):
  Tuple{m, rem} = res
  Tuple{m, h <> rem}

def list_pop_last(xs: List<&2, Json>) -> Pair(Maybe<&2, Json>, List<&2, Json>):
  match xs:
    case Nil{}:
      Tuple{None{}, Nil{}}
    case h <> t:
      match t:
        case Nil{}:
          Tuple{Some{h}, Nil{}}
        case th <> tt:
          list_pop_step(h, list_pop_last(th <> tt))

def arr_pop_step(res: Pair(Maybe<&2, Json>, List<&2, Json>)) -> Pair(Maybe<&2, Json>, Json):
  Tuple{m, rem} = res
  Tuple{m, JArr{rem}}

def arr_pop(j: Json) -> Pair(Maybe<&2, Json>, Json):
  match j:
    case JArr{vals}:
      arr_pop_step(list_pop_last(vals))
    case _:
      Tuple{None{}, j}

def list_remove(xs: List<&2, Json>, idx: Nat) -> List<&2, Json>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      match idx:
        case 0n:
          t
        case 1n+p:
          h <> list_remove(t, p)

def arr_remove(j: Json, idx: Nat) -> Json:
  match j:
    case JArr{vals}:
      JArr{list_remove(vals, idx)}
    case _:
      j

def list_insert(xs: List<&2, Json>, idx: Nat, +val: Json) -> List<&2, Json>:
  match xs:
    case Nil{}:
      [val]
    case h <> t:
      match idx:
        case 0n:
          val <> h <> t
        case 1n+p:
          h <> list_insert(t, p, val)

def arr_insert(j: Json, idx: Nat, val: Json) -> Json:
  match j:
    case JArr{vals}:
      JArr{list_insert(vals, idx, val)}
    case _:
      JArr{[val]}

def list_map(~f: Json -> Json, xs: List<&2, Json>) -> List<&2, Json>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      f(h) <> list_map(~f, t)

def arr_map(~f: Json -> Json, j: Json) -> Json:
  match j:
    case JArr{vals}:
      JArr{list_map(~f, vals)}
    case _:
      j

def list_filter(~f: Json -> Bool, +xs: List<&2, Json>) -> List<&2, Json>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, Json>, f(h),
        h <> list_filter(~f, t),
        list_filter(~f, t))

def arr_filter(~f: Json -> Bool, j: Json) -> Json:
  match j:
    case JArr{vals}:
      JArr{list_filter(~f, vals)}
    case _:
      j

def list_fold(~f: Json -> Json -> Json, xs: List<&2, Json>, acc: Json) -> Json:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      list_fold(~f, t, f(acc, h))

def arr_fold(~f: Json -> Json -> Json, acc: Json, j: Json) -> Json:
  match j:
    case JArr{vals}:
      list_fold(~f, vals, acc)
    case _:
      acc

# ==============================================================================
# 7. Ergonomic Typed Field Extractors
# ==============================================================================

def get_str_step(m: Maybe<&2, Json>) -> Maybe<&2, String>:
  match m:
    case Some{v}:
      as_str(v)
    case None{}:
      None{}

def get_str(j: Json, key: String) -> Maybe<&2, String>:
  get_str_step(get(j, key))

def get_num_step(m: Maybe<&2, Json>) -> Maybe<&2, Nat>:
  match m:
    case Some{v}:
      as_num(v)
    case None{}:
      None{}

def get_num(j: Json, key: String) -> Maybe<&2, Nat>:
  get_num_step(get(j, key))

def get_neg_step(m: Maybe<&2, Json>) -> Maybe<&2, Nat>:
  match m:
    case Some{v}:
      as_neg(v)
    case None{}:
      None{}

def get_neg(j: Json, key: String) -> Maybe<&2, Nat>:
  get_neg_step(get(j, key))

def get_bool_step(m: Maybe<&2, Json>) -> Maybe<&2, Bool>:
  match m:
    case Some{v}:
      as_bool(v)
    case None{}:
      None{}

def get_bool(j: Json, key: String) -> Maybe<&2, Bool>:
  get_bool_step(get(j, key))

def get_arr_step(m: Maybe<&2, Json>) -> Maybe<&2, List<&2, Json>>:
  match m:
    case Some{v}:
      as_arr(v)
    case None{}:
      None{}

def get_arr(j: Json, key: String) -> Maybe<&2, List<&2, Json>>:
  get_arr_step(get(j, key))

def get_obj_step(m: Maybe<&2, Json>) -> Maybe<&2, List<&2, Sigma<&2, &2, String, _ => Json>>>:
  match m:
    case Some{v}:
      as_obj(v)
    case None{}:
      None{}

def get_obj(j: Json, key: String) -> Maybe<&2, List<&2, Sigma<&2, &2, String, _ => Json>>>:
  get_obj_step(get(j, key))

def get_str_or_step(m: Maybe<&2, String>, dflt: String) -> String:
  match m:
    case Some{s}:
      s
    case None{}:
      dflt

def get_str_or(j: Json, key: String, dflt: String) -> String:
  get_str_or_step(get_str(j, key), dflt)

def get_num_or_step(m: Maybe<&2, Nat>, dflt: Nat) -> Nat:
  match m:
    case Some{n}:
      n
    case None{}:
      dflt

def get_num_or(j: Json, key: String, dflt: Nat) -> Nat:
  get_num_or_step(get_num(j, key), dflt)

def get_bool_or_step(m: Maybe<&2, Bool>, dflt: Bool) -> Bool:
  match m:
    case Some{b}:
      b
    case None{}:
      dflt

def get_bool_or(j: Json, key: String, dflt: Bool) -> Bool:
  get_bool_or_step(get_bool(j, key), dflt)

# ==============================================================================
# 8. RFC 6901 JSON Pointer Traversal & Deep Mutation
# ==============================================================================

def unescape_ptr_loop(fuel: Nat, st: PtrUnescState, s: String, +acc: List<&2, Char>) -> String:
  match fuel:
    case 0n:
      String.from_list(List.reverse(&2, Char, acc))
    case 1n++p:
      match st:
        case PUNormal{}:
          match s:
            case SNil{}:
              String.from_list(List.reverse(&2, Char, acc))
            case SCon{Chr{+c}, +t}:
              unescape_ptr_loop(p, PUChar{U32.is_eq(c, 126), c}, t, acc)
        case PUChar{is_tilde, c}:
          match is_tilde:
            case True{}:
              unescape_ptr_loop(p, PUTilde{}, s, acc)
            case False{}:
              unescape_ptr_loop(p, PUNormal{}, s, Chr{c} <> acc)
        case PUTilde{}:
          match s:
            case SNil{}:
              String.from_list(List.reverse(&2, Char, Chr{126} <> acc))
            case SCon{Chr{+c}, +t}:
              unescape_ptr_loop(p, PUTildeChar{U32.is_eq(c, 49), U32.is_eq(c, 48), c}, t, acc)
        case PUTildeChar{is_one, is_zero, c}:
          match is_one:
            case True{}:
              unescape_ptr_loop(p, PUNormal{}, s, Chr{47} <> acc)
            case False{}:
              match is_zero:
                case True{}:
                  unescape_ptr_loop(p, PUNormal{}, s, Chr{126} <> acc)
                case False{}:
                  unescape_ptr_loop(p, PUNormal{}, s, Chr{c} <> Chr{126} <> acc)

def unescape_ptr_token(+s: String) -> String:
  unescape_ptr_loop(Nat.add(Nat.mul(String.length(s), 2n), 10n), PUNormal{}, s, Nil{})

def split_ptr_loop(fuel: Nat, st: PtrSplitState, s: String, +cur: String) -> List<&2, String>:
  match fuel:
    case 0n:
      [unescape_ptr_token(String.reverse(cur))]
    case 1n++p:
      match st:
        case PSNormal{}:
          match s:
            case SNil{}:
              [unescape_ptr_token(String.reverse(cur))]
            case SCon{Chr{+c}, +t}:
              split_ptr_loop(p, PSChar{U32.is_eq(c, 47), c}, t, cur)
        case PSChar{is_slash, c}:
          match is_slash:
            case True{}:
              unescape_ptr_token(String.reverse(cur)) <> split_ptr_loop(p, PSNormal{}, s, "")
            case False{}:
              split_ptr_loop(p, PSNormal{}, s, SCon{Chr{c}, cur})

def split_ptr_tokens(+s: String) -> List<&2, String>:
  split_ptr_loop(Nat.add(Nat.mul(String.length(s), 2n), 10n), PSNormal{}, s, "")

def parse_ptr_tokens_slash(is_slash: Bool, +t: String) -> Maybe<&2, List<&2, String>>:
  match is_slash:
    case True{}:
      Some{split_ptr_tokens(t)}
    case False{}:
      None{}

def parse_ptr_tokens(+path: String) -> Maybe<&2, List<&2, String>>:
  match path:
    case SNil{}:
      Some{Nil{}}
    case SCon{Chr{+c}, +t}:
      parse_ptr_tokens_slash(U32.is_eq(c, 47), t)

def parse_nat_loop(fuel: Nat, st: NatState, s: String, +acc: Nat) -> Maybe<&2, Nat>:
  match fuel:
    case 0n:
      Some{acc}
    case 1n++p:
      match st:
        case NParseDigits{}:
          match s:
            case SNil{}:
              Some{acc}
            case SCon{Chr{+c}, +t}:
              parse_nat_loop(p, NCheckDigit{Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), c}, t, acc)
        case NCheckDigit{is_d, c}:
          match is_d:
            case True{}:
              parse_nat_loop(p, NParseDigits{}, s, Nat.add(Nat.mul(acc, 10n), U32.to_nat(U32.sub(c, 48))))
            case False{}:
              None{}

def parse_nat_lead(is_zero: Bool, is_digit: Bool, +c: U32, +t: String) -> Maybe<&2, Nat>:
  match is_zero:
    case True{}:
      match t:
        case SNil{}:
          Some{0n}
        case _:
          None{}
    case False{}:
      match is_digit:
        case True{}:
          +fuel = {Nat.add(String.length(t), 10n) : Nat}
          parse_nat_loop(fuel, NParseDigits{}, t, U32.to_nat(U32.sub(c, 48)))
        case False{}:
          None{}

def parse_nat(+s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, +t}:
      is_zero = U32.is_eq(c, 48)
      is_digit = Bool.and(U32.is_ge(c, 49), U32.is_le(c, 57))
      parse_nat_lead(is_zero, is_digit, c, t)

def pointer_resolve_arr(j: Json, m: Maybe<&2, Nat>) -> Maybe<&2, Json>:
  match m:
    case Some{idx}:
      arr_get(j, idx)
    case None{}:
      None{}

def pointer_resolve_token(j: Json, token: String) -> Maybe<&2, Json>:
  match j:
    case JObj{_}:
      get(j, token)
    case JArr{_}:
      pointer_resolve_arr(j, parse_nat(token))
    case _:
      None{}

def pointer_traverse_loop(+tokens: List<&2, String>, cur: Maybe<&2, Json>) -> Maybe<&2, Json>:
  match tokens:
    case Nil{}:
      cur
    case token <> rest:
      match cur:
        case None{}:
          None{}
        case Some{j}:
          pointer_traverse_loop(rest, pointer_resolve_token(j, token))

def pointer_start(m: Maybe<&2, List<&2, String>>, j: Json) -> Maybe<&2, Json>:
  match m:
    case Some{tokens}:
      pointer_traverse_loop(tokens, Some{j})
    case None{}:
      None{}

def pointer(j: Json, path: String) -> Maybe<&2, Json>:
  pointer_start(parse_ptr_tokens(path), j)

def pointer_set_arr_leaf(m: Maybe<&2, Nat>, j: Json, val: Json) -> Json:
  match m:
    case Some{idx}:
      arr_set(j, idx, val)
    case None{}:
      j

def child_or_obj(m: Maybe<&2, Json>) -> Json:
  match m:
    case Some{c}:
      c
    case None{}:
      JObj{Nil{}}

def child_or_null(m: Maybe<&2, Json>) -> Json:
  match m:
    case Some{c}:
      c
    case None{}:
      JNull{}

def arr_child(j: Json, m: Maybe<&2, Nat>) -> Json:
  match m:
    case Some{idx}:
      child_or_null(arr_get(j, idx))
    case None{}:
      JNull{}

def pointer_set_arr_res(m: Maybe<&2, Nat>, j: Json, new_child: Json) -> Json:
  match m:
    case Some{idx}:
      arr_set(j, idx, new_child)
    case None{}:
      j

def pointer_set_traverse(+tokens: List<&2, String>, +j: Json, +val: Json) -> Json:
  match tokens:
    case Nil{}:
      val
    case +token <> rest:
      match rest:
        case Nil{}:
          match j:
            case JObj{_}:
              set(j, token, val)
            case JArr{_}:
              pointer_set_arr_leaf(parse_nat(token), j, val)
            case _:
              j
        case _ <> _:
          match j:
            case JObj{_}:
              +child = child_or_obj(get(j, token))
              set(j, token, pointer_set_traverse(rest, child, val))
            case JArr{_}:
              +idx_m = parse_nat(token)
              +child = arr_child(j, idx_m)
              pointer_set_arr_res(idx_m, j, pointer_set_traverse(rest, child, val))
            case _:
              j

def pointer_set_step(m: Maybe<&2, List<&2, String>>, j: Json, val: Json) -> Json:
  match m:
    case Some{tokens}:
      pointer_set_traverse(tokens, j, val)
    case None{}:
      j

def pointer_set(j: Json, path: String, val: Json) -> Json:
  pointer_set_step(parse_ptr_tokens(path), j, val)

# ==============================================================================
# 9. String Escaping & Serialization (stringify)
# ==============================================================================

def escape_char(+c: Char) -> String:
  match c:
    case Chr{+code}:
      Bool.pick(String, U32.is_eq(code, 34), "\\\"",
        Bool.pick(String, U32.is_eq(code, 92), "\\\\",
          Bool.pick(String, U32.is_eq(code, 10), "\\n",
            Bool.pick(String, U32.is_eq(code, 9), "\\t",
              Bool.pick(String, U32.is_eq(code, 13), "\\r",
                Char.show(Chr{code}))))))

def escape_string(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      escape_char(c) ++ escape_string(t)

def quote_string(s: String) -> String:
  "\"" ++ escape_string(s) ++ "\""

def stringify_loop(fuel: Nat, +tasks: List<&2, PrintTask>, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n++p:
      match tasks:
        case Nil{}:
          acc
        case h <> t:
          match h:
            case PLit{s}:
              stringify_loop(p, t, acc ++ s)
            case PVal{j}:
              match j:
                case JNull{}:
                  stringify_loop(p, t, acc ++ "null")
                case JBool{b}:
                  match b:
                    case True{}:
                      stringify_loop(p, t, acc ++ "true")
                    case False{}:
                      stringify_loop(p, t, acc ++ "false")
                case JNum{n}:
                  stringify_loop(p, t, acc ++ Nat.show(n))
                case JNeg{n}:
                  stringify_loop(p, t, acc ++ "-" ++ Nat.show(n))
                case JStr{s}:
                  stringify_loop(p, t, acc ++ quote_string(s))
                case JArr{vals}:
                  match vals:
                    case Nil{}:
                      stringify_loop(p, t, acc ++ "[]")
                    case vh <> vt:
                      stringify_loop(p, PVal{vh} <> PArr{vt} <> PLit{"]"} <> t, acc ++ "[")
                case JObj{kvs}:
                  match kvs:
                    case Nil{}:
                      stringify_loop(p, t, acc ++ "{}")
                    case Tuple{k, v} <> kt:
                      stringify_loop(p, PVal{v} <> PObj{kt} <> PLit{"}"} <> t, acc ++ "{" ++ quote_string(k) ++ ":")
            case PArr{items}:
              match items:
                case Nil{}:
                  stringify_loop(p, t, acc)
                case vh <> vt:
                  stringify_loop(p, PVal{vh} <> PArr{vt} <> t, acc ++ ",")
            case PObj{kvs}:
              match kvs:
                case Nil{}:
                  stringify_loop(p, t, acc)
                case Tuple{k, v} <> kt:
                  stringify_loop(p, PVal{v} <> PObj{kt} <> t, acc ++ "," ++ quote_string(k) ++ ":")

def stringify(j: Json) -> String:
  stringify_loop(1000n, [PVal{j}], "")

# ==============================================================================
# 10. Pretty Printing with Configurable Indentation
# ==============================================================================

def make_spaces(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      " " ++ make_spaces(p)

def make_custom_indent(fuel: Nat, count: Nat, +step_str: String) -> String:
  match fuel:
    case 0n:
      ""
    case 1n++p:
      match count:
        case 0n:
          ""
        case 1n+cp:
          step_str ++ make_custom_indent(p, cp, step_str)

def pretty_indent_loop(fuel: Nat, +tasks: List<&2, PrettyTask>, +step_str: String, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n++p:
      match tasks:
        case Nil{}:
          acc
        case h <> t:
          match h:
            case PrLit{s}:
              pretty_indent_loop(p, t, step_str, acc ++ s)
            case PrVal{j, +ind}:
              match j:
                case JNull{}:
                  pretty_indent_loop(p, t, step_str, acc ++ "null")
                case JBool{b}:
                  match b:
                    case True{}:
                      pretty_indent_loop(p, t, step_str, acc ++ "true")
                    case False{}:
                      pretty_indent_loop(p, t, step_str, acc ++ "false")
                case JNum{n}:
                  pretty_indent_loop(p, t, step_str, acc ++ Nat.show(n))
                case JNeg{n}:
                  pretty_indent_loop(p, t, step_str, acc ++ "-" ++ Nat.show(n))
                case JStr{s}:
                  pretty_indent_loop(p, t, step_str, acc ++ quote_string(s))
                case JArr{vals}:
                  match vals:
                    case Nil{}:
                      pretty_indent_loop(p, t, step_str, acc ++ "[]")
                    case vh <> vt:
                      +next_ind = {1n+ind : Nat}
                      +ind_str = make_custom_indent(10n, next_ind, step_str)
                      +close_ind = make_custom_indent(10n, ind, step_str)
                      pretty_indent_loop(p, PrVal{vh, next_ind} <> PrArr{vt, next_ind} <> PrLit{"\n" ++ close_ind ++ "]"} <> t, step_str, acc ++ "[\n" ++ ind_str)
                case JObj{kvs}:
                  match kvs:
                    case Nil{}:
                      pretty_indent_loop(p, t, step_str, acc ++ "{}")
                    case Tuple{k, v} <> kt:
                      +next_ind = {1n+ind : Nat}
                      +ind_str = make_custom_indent(10n, next_ind, step_str)
                      +close_ind = make_custom_indent(10n, ind, step_str)
                      pretty_indent_loop(p, PrVal{v, next_ind} <> PrObj{kt, next_ind} <> PrLit{"\n" ++ close_ind ++ "}"} <> t, step_str, acc ++ "{\n" ++ ind_str ++ quote_string(k) ++ ": ")
            case PrArr{items, +ind}:
              match items:
                case Nil{}:
                  pretty_indent_loop(p, t, step_str, acc)
                case vh <> vt:
                  +ind_str = make_custom_indent(10n, ind, step_str)
                  pretty_indent_loop(p, PrVal{vh, ind} <> PrArr{vt, ind} <> t, step_str, acc ++ ",\n" ++ ind_str)
            case PrObj{kvs, +ind}:
              match kvs:
                case Nil{}:
                  pretty_indent_loop(p, t, step_str, acc)
                case Tuple{k, v} <> kt:
                  +ind_str = make_custom_indent(10n, ind, step_str)
                  pretty_indent_loop(p, PrVal{v, ind} <> PrObj{kt, ind} <> t, step_str, acc ++ ",\n" ++ ind_str ++ quote_string(k) ++ ": ")

def pretty_indent(j: Json, step: Nat) -> String:
  pretty_indent_loop(1000n, [PrVal{j, 0n}], make_spaces(step), "")

def pretty(j: Json) -> String:
  pretty_indent(j, 2n)

# ==============================================================================
# 11. Parser Implementation (parse)
# ==============================================================================

def classify_str_char(+c: U32) -> StrCharKind:
  Bool.pick(StrCharKind, U32.is_eq(c, 34), SCQuote{},
    Bool.pick(StrCharKind, U32.is_eq(c, 92), SCSlash{},
      SCOther{}))

def classify_char(+c: U32) -> CharKind:
  Bool.pick(CharKind, U32.is_eq(c, 91), KindLBracket{},
    Bool.pick(CharKind, U32.is_eq(c, 93), KindRBracket{},
      Bool.pick(CharKind, U32.is_eq(c, 123), KindLBrace{},
        Bool.pick(CharKind, U32.is_eq(c, 125), KindRBrace{},
          Bool.pick(CharKind, U32.is_eq(c, 34), KindQuote{},
            Bool.pick(CharKind, U32.is_eq(c, 44), KindComma{},
              Bool.pick(CharKind, U32.is_eq(c, 58), KindColon{},
                Bool.pick(CharKind, U32.is_eq(c, 110), KindNull{},
                  Bool.pick(CharKind, U32.is_eq(c, 116), KindTrue{},
                    Bool.pick(CharKind, U32.is_eq(c, 102), KindFalse{},
                      Bool.pick(CharKind, U32.is_eq(c, 45), KindMinus{},
                        Bool.pick(CharKind, Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), KindDigit{},
                          KindOther{}))))))))))))

def parse_esc(+code: U32) -> Char:
  Bool.pick(Char, U32.is_eq(code, 110), Chr{10},
    Bool.pick(Char, U32.is_eq(code, 116), Chr{9},
      Bool.pick(Char, U32.is_eq(code, 114), Chr{13},
        Bool.pick(Char, U32.is_eq(code, 34), Chr{34},
          Bool.pick(Char, U32.is_eq(code, 92), Chr{92},
            Chr{code})))))

def parse_str.loop(fuel: Nat, st: StrState, s: String, +acc: List<&2, Char>) -> StrRes:
  match fuel:
    case 0n:
      SErr{"fuel exhausted in string parse"}
    case 1n++p:
      match st:
        case StrNormal{}:
          match s:
            case SNil{}:
              SErr{"unterminated string literal"}
            case SCon{Chr{+c}, +t}:
              parse_str.loop(p, StrChar{classify_str_char(c), c}, t, acc)

        case StrEscaping{}:
          match s:
            case SNil{}:
              SErr{"unterminated string escape"}
            case SCon{Chr{+c}, +t}:
              parse_str.loop(p, StrNormal{}, t, parse_esc(c) <> acc)

        case StrChar{kind, c}:
          match kind:
            case SCQuote{}:
              SOk{String.from_list(List.reverse(&2, Char, acc)), s}
            case SCSlash{}:
              parse_str.loop(p, StrEscaping{}, s, acc)
            case SCOther{}:
              parse_str.loop(p, StrNormal{}, s, Chr{c} <> acc)

def skip_ws(s: String) -> String:
  String.trim_start(s)

type DigitsState is Data:
  DStart{}
  DChar{is_d: Bool, code: U32}

def parse_digits.loop(fuel: Nat, st: DigitsState, s: String, +acc: Nat) -> NumRes:
  match fuel:
    case 0n:
      NRes{acc, s}
    case 1n++p:
      match st:
        case DStart{}:
          match s:
            case SNil{}:
              NRes{acc, ""}
            case SCon{Chr{+code}, +t}:
              is_d = Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57))
              parse_digits.loop(p, DChar{is_d, code}, t, acc)
        case DChar{is_d, code}:
          match is_d:
            case True{}:
              +next_acc = Nat.add(Nat.mul(acc, 10n), U32.to_nat(U32.sub(code, 48)))
              parse_digits.loop(p, DStart{}, s, next_acc)
            case False{}:
              NRes{acc, SCon{Chr{code}, s}}

def parse_digits(fuel: Nat, s: String, acc: Nat) -> NumRes:
  parse_digits.loop(fuel, DStart{}, s, acc)

def parse_step(fuel: Nat, act: StepAct, +stack: List<&2, Frame>, s: String) -> Result<&2, &2, String, Json>:
  match fuel:
    case 0n:
      Fail{"fuel exhausted in parser"}
    case 1n++p:
      match act:
        case ActCheckEof{+v}:
          match s:
            case SNil{}:
              Done{v}
            case SCon{c, t}:
              Fail{"unexpected trailing characters after JSON root"}

        case ActHaveVal{+v}:
          match stack:
            case Nil{}:
              parse_step(p, ActCheckEof{v}, Nil{}, skip_ws(s))
            case FArr{items} <> rest_stack:
              parse_step(p, ActArrNext{v, items}, rest_stack, skip_ws(s))
            case FObjVal{key, kvs} <> rest_stack:
              parse_step(p, ActObjNext{key, v, kvs}, rest_stack, skip_ws(s))

        case ActArrOpen{}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF in array: missing ']'"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActArrOpenChar{classify_char(c), c}, stack, t)

        case ActArrOpenChar{kind, c}:
          match kind:
            case KindRBracket{}:
              parse_step(p, ActHaveVal{JArr{Nil{}}}, stack, s)
            case _:
              parse_step(p, ActValStart{}, FArr{Nil{}} <> stack, SCon{Chr{c}, s})

        case ActArrNext{+v, +items}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF in array: missing ']'"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActArrNextChar{classify_char(c), v, items}, stack, t)

        case ActArrNextChar{kind, +v, +items}:
          match kind:
            case KindRBracket{}:
              parse_step(p, ActHaveVal{JArr{List.reverse(&2, Json, v <> items)}}, stack, s)
            case KindComma{}:
              parse_step(p, ActValStart{}, FArr{v <> items} <> stack, skip_ws(s))
            case _:
              Fail{"expected ',' or ']' in array"}

        case ActObjOpen{}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF in object: missing '}'"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActObjOpenChar{classify_char(c), c}, stack, t)

        case ActObjOpenChar{kind, c}:
          match kind:
            case KindRBrace{}:
              parse_step(p, ActHaveVal{JObj{Nil{}}}, stack, s)
            case _:
              parse_step(p, ActKeyStart{Nil{}}, stack, SCon{Chr{c}, s})

        case ActKeyStart{+kvs}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF in object: missing key string"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActKeyStartChar{classify_char(c), kvs}, stack, t)

        case ActKeyStartChar{kind, +kvs}:
          match kind:
            case KindQuote{}:
              parse_step(p, ActKeyParsed{parse_str.loop(p, StrNormal{}, s, Nil{}), kvs}, stack, "")
            case KindRBrace{}:
              parse_step(p, ActHaveVal{JObj{List.reverse(&2, Sigma<&2, &2, String, _ => Json>, kvs)}}, stack, s)
            case _:
              Fail{"expected string key or '}' in object"}

        case ActKeyParsed{res, +kvs}:
          match res:
            case SErr{msg}:
              Fail{msg}
            case SOk{key, rest}:
              parse_step(p, ActColon{key, kvs}, stack, skip_ws(rest))

        case ActColon{key, +kvs}:
          match s:
            case SNil{}:
              Fail{"expected ':' after object key"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActColonChar{classify_char(c), key, kvs}, stack, t)

        case ActColonChar{kind, key, +kvs}:
          match kind:
            case KindColon{}:
              parse_step(p, ActValStart{}, FObjVal{key, kvs} <> stack, skip_ws(s))
            case _:
              Fail{"expected ':' after object key"}

        case ActObjNext{key, +v, +kvs}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF in object: missing '}'"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActObjNextChar{classify_char(c), key, v, kvs}, stack, t)

        case ActObjNextChar{kind, +key, +v, +kvs}:
          match kind:
            case KindRBrace{}:
              parse_step(p, ActHaveVal{JObj{List.reverse(&2, Sigma<&2, &2, String, _ => Json>, Tuple{key, v} <> kvs)}}, stack, s)
            case KindComma{}:
              parse_step(p, ActKeyStart{Tuple{key, v} <> kvs}, stack, skip_ws(s))
            case _:
              Fail{"expected ',' or '}' in object"}

        case ActStrParsed{res}:
          match res:
            case SErr{msg}:
              Fail{msg}
            case SOk{val, rest}:
              parse_step(p, ActHaveVal{JStr{val}}, stack, rest)

        case ActNumParsed{neg_flag, res}:
          match neg_flag res:
            case True{} NRes{n, rest}:
              parse_step(p, ActHaveVal{JNeg{n}}, stack, rest)
            case False{} NRes{n, rest}:
              parse_step(p, ActHaveVal{JNum{n}}, stack, rest)

        case ActLitCheck{expected, +val, ok, rest}:
          match ok:
            case True{}:
              parse_step(p, ActHaveVal{val}, stack, rest)
            case False{}:
              Fail{"invalid literal: expected " ++ expected}

        case ActValStart{}:
          match s:
            case SNil{}:
              Fail{"unexpected EOF: expected a JSON value"}
            case SCon{Chr{+c}, +t}:
              parse_step(p, ActValChar{classify_char(c), c}, stack, t)

        case ActValChar{kind, c}:
          match kind:
            case KindLBracket{}:
              parse_step(p, ActArrOpen{}, stack, skip_ws(s))
            case KindLBrace{}:
              parse_step(p, ActObjOpen{}, stack, skip_ws(s))
            case KindQuote{}:
              parse_step(p, ActStrParsed{parse_str.loop(p, StrNormal{}, s, Nil{})}, stack, "")
            case KindNull{}:
              +full_str = {SCon{Chr{c}, s} : String}
              parse_step(p, ActLitCheck{"null", JNull{}, String.starts_with(full_str, "null"), String.drop(full_str, 4n)}, stack, "")
            case KindTrue{}:
              +full_str = {SCon{Chr{c}, s} : String}
              parse_step(p, ActLitCheck{"true", JBool{True{}}, String.starts_with(full_str, "true"), String.drop(full_str, 4n)}, stack, "")
            case KindFalse{}:
              +full_str = {SCon{Chr{c}, s} : String}
              parse_step(p, ActLitCheck{"false", JBool{False{}}, String.starts_with(full_str, "false"), String.drop(full_str, 5n)}, stack, "")
            case KindMinus{}:
              parse_step(p, ActNumParsed{True{}, parse_digits(p, s, 0n)}, stack, "")
            case KindDigit{}:
              parse_step(p, ActNumParsed{False{}, parse_digits(p, s, U32.to_nat(U32.sub(c, 48)))}, stack, "")
            case _:
              Fail{"unexpected character when reading JSON value"}

def parse(+s: String) -> Result<&2, &2, String, Json>:
  +fuel = {Nat.add(Nat.mul(String.length(s), 8n), 100n) : Nat}
  parse_step(fuel, ActValStart{}, Nil{}, skip_ws(s))

# ==============================================================================
# 12. Validation & Streaming NDJSON Support
# ==============================================================================

def validate_step(r: Result<&2, &2, String, Json>) -> Bool:
  match r:
    case Done{_}:
      True{}
    case Fail{_}:
      False{}

def validate(s: String) -> Bool:
  validate_step(parse(s))

def stringify_ndjson(xs: List<&2, Json>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      stringify(h) ++ "\n" ++ stringify_ndjson(t)

def split_lines_done(is_empty: Bool, +line: String) -> List<&2, String>:
  match is_empty:
    case True{}:
      Nil{}
    case False{}:
      [line]

def split_lines.loop(fuel: Nat, st: LineSplitState, s: String, +cur: String) -> List<&2, String>:
  match fuel:
    case 0n:
      +line = String.trim(String.reverse(cur))
      split_lines_done(String.is_empty(line), line)
    case 1n++p:
      match st:
        case LSNormal{}:
          match s:
            case SNil{}:
              +line = String.trim(String.reverse(cur))
              split_lines_done(String.is_empty(line), line)
            case SCon{Chr{+c}, +t}:
              split_lines.loop(p, LSCheckNl{U32.is_eq(c, 10), c}, t, cur)
        case LSCheckNl{is_nl, c}:
          match is_nl:
            case True{}:
              +line = String.trim(String.reverse(cur))
              split_lines.loop(p, LSEmpty{String.is_empty(line), line}, s, "")
            case False{}:
              split_lines.loop(p, LSNormal{}, s, SCon{Chr{c}, cur})
        case LSEmpty{is_empty, line}:
          match is_empty:
            case True{}:
              split_lines.loop(p, LSNormal{}, s, "")
            case False{}:
              line <> split_lines.loop(p, LSNormal{}, s, "")

def split_lines_loop(+s: String, cur: String) -> List<&2, String>:
  fuel = Nat.add(Nat.mul(String.length(s), 3n), 20n)
  split_lines.loop(fuel, LSNormal{}, s, cur)

def list_parse_lines(lines: List<&2, String>) -> List<&2, Result<&2, &2, String, Json>>:
  match lines:
    case Nil{}:
      Nil{}
    case h <> t:
      parse(h) <> list_parse_lines(t)

def parse_ndjson(s: String) -> List<&2, Result<&2, &2, String, Json>>:
  list_parse_lines(split_lines_loop(s, ""))
