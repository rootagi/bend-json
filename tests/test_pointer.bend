# tests/test_pointer.bend: Tests RFC 6901 pointer lookups.
# Reads JSON_IN file and queries pointer specified in JSON_PTR.

import Base
import ../json.bend as Json

def print_ptr(m: Maybe<&2, Json.Json>) -> IO(Unit):
  match m:
    case Some{pv}:
      IO.print("PTR_OK: " ++ Json.stringify(pv))
    case None{}:
      IO.print("PTR_NONE")

def on_ptr(v: Json.Json, r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Done{ptr}:
      print_ptr(Json.pointer(v, ptr))
    case Fail{_}:
      IO.print("HARNESS_ERROR: JSON_PTR environment variable not set")

def on_content(content: String, ptr_res: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match Json.parse(content):
    case Done{v}:
      on_ptr(v, ptr_res)
    case Fail{err}:
      IO.print("FAIL: " ++ err)

def read_ptr(content: String) -> IO(Unit):
  do IO<Unit>:
    ptr_res : Result<&1, &1, U32 & String, String> <- IO.get_env("JSON_PTR")
    on_content(content, ptr_res)

def on_file_content(r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Done{content}:
      read_ptr(content)
    case Fail{_}:
      IO.print("HARNESS_ERROR: failed to read file")

def process_file(m: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    _ : Unit <- File.close(f)
    on_file_content(r)

def on_open(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 2147483647)
        process_file(m)
    case Fail{_}:
      IO.print("HARNESS_ERROR: failed to open file")

def on_env(r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Done{path}:
      do IO<Unit>:
        r2 : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
        on_open(r2)
    case Fail{_}:
      IO.print("HARNESS_ERROR: JSON_IN environment variable not set")

def main() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env("JSON_IN")
    on_env(r)
