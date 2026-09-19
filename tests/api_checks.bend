# tests/api_checks.bend: prints one "label=value" line per API check.
# tests/run_tests.py compares every line against the expected value.
# (Bend has no runtime String equality, so the assertions live in Python.)
import Base
import ../json.bend as Json

# ---------- helpers ----------
def show_m(m: Maybe<&2, Json.Json>) -> String:
  match m:
    case Some{+v}:
      "Some " ++ Json.stringify(v)
    case None{}:
      "None"

def show_res(r: Result<&2, &2, String, Json.Json>) -> String:
  match r:
    case Done{+v}:
      "Done " ++ Json.stringify(v)
    case Fail{_}:
      "Fail"

def show_lines(xs: List<&2, Result<&2, &2, String, Json.Json>>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      show_res(h) ++ "|" ++ show_lines(t)

def show_keys(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      h ++ "," ++ show_keys(t)

def show_ms(m: Maybe<&2, String>) -> String:
  match m:
    case Some{s}:
      "Some " ++ s
    case None{}:
      "None"

def show_pop(p: Pair(Maybe<&2, Json.Json>, Json.Json)) -> String:
  Tuple{m, rest} = p
  show_m(m) ++ " / " ++ Json.stringify(rest)

def ptr(+d: Json.Json, p: String) -> String:
  show_m(Json.pointer(d, p))

def set_show(+d: Json.Json, p: String, v: Json.Json) -> String:
  Json.stringify(Json.pointer_set(d, p, v))

# ---------- RFC 6901 section 5 document ----------
def rfc_pointer(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+d}:
      do IO<Unit>:
        IO.print("ptr_root=" ++ ptr(d, ""))
        IO.print("ptr_foo=" ++ ptr(d, "/foo"))
        IO.print("ptr_foo0=" ++ ptr(d, "/foo/0"))
        IO.print("ptr_foo1=" ++ ptr(d, "/foo/1"))
        IO.print("ptr_emptykey=" ++ ptr(d, "/"))
        IO.print("ptr_slash=" ++ ptr(d, "/a~1b"))
        IO.print("ptr_percent=" ++ ptr(d, "/c%d"))
        IO.print("ptr_caret=" ++ ptr(d, "/e^f"))
        IO.print("ptr_pipe=" ++ ptr(d, "/g|h"))
        IO.print("ptr_backslash=" ++ ptr(d, "/i\\j"))
        IO.print("ptr_quote=" ++ ptr(d, "/k\"l"))
        IO.print("ptr_space=" ++ ptr(d, "/ "))
        IO.print("ptr_tilde=" ++ ptr(d, "/m~0n"))
        IO.print("ptr_no_leading_slash=" ++ ptr(d, "foo"))
        IO.print("ptr_leading_zero=" ++ ptr(d, "/foo/01"))
        IO.print("ptr_dash=" ++ ptr(d, "/foo/-"))
        IO.print("ptr_out_of_range=" ++ ptr(d, "/foo/2"))
        IO.print("ptr_negative=" ++ ptr(d, "/foo/-1"))
        IO.print("ptr_non_numeric=" ++ ptr(d, "/foo/x"))
        IO.print("ptr_bad_escape=" ++ ptr(d, "/a~2b"))
        IO.print("ptr_trailing_tilde=" ++ ptr(d, "/m~"))
        IO.print("ptr_missing=" ++ ptr(d, "/nope"))
        IO.print("ptr_into_scalar=" ++ ptr(d, "/foo/0/x"))
        IO.print("ptr_trailing_slash=" ++ ptr(d, "/foo/"))
    case Fail{e}:
      IO.print("ptr_setup=Fail " ++ e)

def rfc_order(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+d}:
      IO.print("ptr_unescape_order=" ++ ptr(d, "/~01"))
    case Fail{e}:
      IO.print("ptr_order_setup=Fail " ++ e)

# ---------- objects / arrays / extractors ----------
def obj_checks(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+d}:
      do IO<Unit>:
        IO.print("obj_len=" ++ Nat.show(Json.obj_len(d)))
        IO.print("obj_has_a=" ++ Bool.show(Json.has(d, "a")))
        IO.print("obj_has_z=" ++ Bool.show(Json.has(d, "z")))
        IO.print("obj_get_b=" ++ show_m(Json.get(d, "b")))
        IO.print("obj_set_new_get=" ++ show_m(Json.get(Json.set(d, "z", Json.JNum{3n}), "z")))
        IO.print("obj_set_new_len=" ++ Nat.show(Json.obj_len(Json.set(d, "z", Json.JNum{3n}))))
        IO.print("obj_set_existing_get=" ++ show_m(Json.get(Json.set(d, "a", Json.JNum{9n}), "a")))
        IO.print("obj_set_existing_len=" ++ Nat.show(Json.obj_len(Json.set(d, "a", Json.JNum{9n}))))
        IO.print("obj_remove_has=" ++ Bool.show(Json.has(Json.remove(d, "a"), "a")))
        IO.print("obj_remove_len=" ++ Nat.show(Json.obj_len(Json.remove(d, "a"))))
        IO.print("obj_remove_missing_len=" ++ Nat.show(Json.obj_len(Json.remove(d, "zzz"))))
        IO.print("obj_sorted_keys=" ++ show_keys(Json.keys(Json.sort_keys(d))))
        IO.print("obj_get_on_array=" ++ show_m(Json.get(Json.JArr{Nil{}}, "a")))
        IO.print("obj_len_on_array=" ++ Nat.show(Json.obj_len(Json.JArr{Nil{}})))
        IO.print("obj_get_str_wrongtype=" ++ show_ms(Json.get_str(d, "a")))
        IO.print("obj_get_num_or_wrongtype=" ++ Nat.show(Json.get_num_or(Json.JObj{[Tuple{"n", Json.JStr{"x"}}]}, "n", 77n)))
        IO.print("obj_get_bool_or_missing=" ++ Bool.show(Json.get_bool_or(d, "nope", True{})))
    case Fail{e}:
      IO.print("obj_setup=Fail " ++ e)

def merge_checks(r1: Result<&2, &2, String, Json.Json>, r2: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r1 r2:
    case Done{+a} Done{+b}:
      do IO<Unit>:
        IO.print("merge_a=" ++ show_m(Json.get(Json.merge(a, b), "a")))
        IO.print("merge_b=" ++ show_m(Json.get(Json.merge(a, b), "b")))
        IO.print("merge_c=" ++ show_m(Json.get(Json.merge(a, b), "c")))
        IO.print("merge_len=" ++ Nat.show(Json.obj_len(Json.merge(a, b))))
    case _ _:
      IO.print("merge_setup=Fail")

def arr_checks(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+a}:
      do IO<Unit>:
        IO.print("arr_len=" ++ Nat.show(Json.arr_len(a)))
        IO.print("arr_get1=" ++ show_m(Json.arr_get(a, 1n)))
        IO.print("arr_get_oob=" ++ show_m(Json.arr_get(a, 3n)))
        IO.print("arr_push=" ++ Json.stringify(Json.arr_push(a, Json.JNum{4n})))
        IO.print("arr_set_mid=" ++ Json.stringify(Json.arr_set(a, 1n, Json.JNum{9n})))
        IO.print("arr_insert_front=" ++ Json.stringify(Json.arr_insert(a, 0n, Json.JNum{0n})))
        IO.print("arr_insert_mid=" ++ Json.stringify(Json.arr_insert(a, 1n, Json.JNum{7n})))
        IO.print("arr_insert_end=" ++ Json.stringify(Json.arr_insert(a, 3n, Json.JNum{8n})))
        IO.print("arr_remove_mid=" ++ Json.stringify(Json.arr_remove(a, 1n)))
        IO.print("arr_remove_first=" ++ Json.stringify(Json.arr_remove(a, 0n)))
        IO.print("arr_remove_last=" ++ Json.stringify(Json.arr_remove(a, 2n)))
        IO.print("arr_pop=" ++ show_pop(Json.arr_pop(a)))
        IO.print("arr_pop_empty=" ++ show_pop(Json.arr_pop(Json.JArr{Nil{}})))
        IO.print("arr_len_on_object=" ++ Nat.show(Json.arr_len(Json.JObj{Nil{}})))
        IO.print("arr_oob_set=" ++ Json.stringify(Json.arr_set(a, 10n, Json.JNum{5n})))
        IO.print("arr_oob_remove=" ++ Json.stringify(Json.arr_remove(a, 10n)))
        IO.print("arr_oob_insert=" ++ Json.stringify(Json.arr_insert(a, 10n, Json.JNum{5n})))
    case Fail{e}:
      IO.print("arr_setup=Fail " ++ e)

def set_checks(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+d}:
      do IO<Unit>:
        IO.print("pset_replace_arr=" ++ set_show(d, "/a/1", Json.JNum{9n}))
        IO.print("pset_replace_obj=" ++ set_show(d, "/b/k", Json.JStr{"v"}))
        IO.print("pset_root=" ++ set_show(d, "", Json.JNull{}))
    case Fail{e}:
      IO.print("pset_setup=Fail " ++ e)

# ---------- NDJSON ----------
def nd(+s: String) -> String:
  show_lines(Json.parse_ndjson(s))

def ndjson_checks() -> IO(Unit):
  do IO<Unit>:
    IO.print("nd_three=" ++ nd("1\n2\n3"))
    IO.print("nd_trailing_newline=" ++ nd("1\n2\n"))
    IO.print("nd_crlf=" ++ nd("1\r\n2\r\n"))
    IO.print("nd_blank_lines=" ++ nd("1\n\n2\n"))
    IO.print("nd_bad_line=" ++ nd("1\nx\n3"))
    IO.print("nd_empty=" ++ nd(""))
    IO.print("nd_objects=" ++ nd("{\"a\":1}\n[2]\n"))
    IO.print("nd_out_begin\n" ++ Json.stringify_ndjson([Json.JNum{1n}, Json.JNum{2n}]) ++ "nd_out_end")

def main() -> IO(Unit):
  do IO<Unit>:
    rfc_pointer(Json.parse("{\"foo\":[\"bar\",\"baz\"],\"\":0,\"a/b\":1,\"c%d\":2,\"e^f\":3,\"g|h\":4,\"i\\\\j\":5,\"k\\\"l\":6,\" \":7,\"m~n\":8}"))
    rfc_order(Json.parse("{\"~1\":5,\"/\":6}"))
    obj_checks(Json.parse("{\"b\":1,\"a\":2}"))
    merge_checks(Json.parse("{\"a\":1,\"b\":2}"), Json.parse("{\"b\":3,\"c\":4}"))
    arr_checks(Json.parse("[1,2,3]"))
    set_checks(Json.parse("{\"a\":[1,2],\"b\":{\"k\":1}}"))
    ndjson_checks()
