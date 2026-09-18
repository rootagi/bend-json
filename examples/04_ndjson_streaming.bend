# examples/04_ndjson_streaming.bend
# Demonstrates streaming Newline-Delimited JSON (NDJSON) serialization and parsing.

import Base
import ../json.bend as Json

def print_line(res: Result<&2, &2, String, Json.Json>, idx: Nat) -> IO(Unit):
  match res:
    case Done{+v}:
      do IO<Unit>:
        IO.print("  Record #" ++ Nat.show(idx) ++ ": " ++ Json.stringify(v))
    case Fail{err}:
      do IO<Unit>:
        IO.print("  Record #" ++ Nat.show(idx) ++ " Error: " ++ err)

def print_all(records: List<&2, Result<&2, &2, String, Json.Json>>, +idx: Nat) -> IO(Unit):
  match records:
    case Nil{}:
      do IO<Unit>:
        IO.print("--- End of Stream ---")
    case h <> t:
      do IO<Unit>:
        print_line(h, idx)
        print_all(t, Nat.add(idx, 1n))

def run_ndjson(+stream: String) -> IO(Unit):
  parsed = Json.parse_ndjson(stream)
  do IO<Unit>:
    IO.print("=== Example 4: Streaming NDJSON ===")
    IO.print("Raw NDJSON input:\n" ++ stream)
    IO.print("\n--- Parsed Records Line-by-Line ---")
    print_all(parsed, 1n)

def main() -> IO(Unit):
  run_ndjson("{\"id\": 1, \"event\": \"login\"}\n{\"id\": 2, \"event\": \"click\"}\n{\"id\": 3, \"event\": \"logout\"}")
