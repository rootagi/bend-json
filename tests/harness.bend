# tests/harness.bend: Test harness for bend-json.
# Reads input from file named in JSON_IN environment variable.
# Prints OK / FAIL: <err> for parse, and for OK docs prints stringify and pretty.

import Base
import ../json.bend as Json

def show_res(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{+v}:
      do IO<Unit>:
        IO.print("OK")
        IO.print("--- STRINGIFY ---")
        IO.print(Json.stringify(v))
        IO.print("--- PRETTY ---")
        IO.print(Json.pretty(v))
    case Fail{err}:
      IO.print("FAIL: " ++ err)

def on_content(r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Done{content}:
      show_res(Json.parse(content))
    case Fail{_}:
      IO.print("HARNESS_ERROR: failed to read file")

def process_file(m: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    _ : Unit <- File.close(f)
    on_content(r)

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
