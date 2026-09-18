# examples/01_basic_usage.bend
# Demonstrates basic JSON parsing, typed extraction, mutation, and pretty printing.

import Base
import ../json.bend as Json

def handle_doc(j: Json.Json) -> IO(Unit):
  +j = j
  name = Json.get_str_or(j, "name", "unknown")
  ver  = Json.get_num_or(j, "version", 0n)
  fast = Json.get_bool_or(j, "fast", False{})
  updated = Json.set(j, "status", Json.str("ready"))
  do IO<Unit>:
    IO.print("--- Extracted Properties ---")
    IO.print("Name:    " ++ name)
    IO.print("Version: " ++ Nat.show(ver))
    IO.print("Fast:    " ++ Bool.show(fast))
    IO.print("\n--- Updated Document (Pretty Printed) ---")
    IO.print(Json.pretty(updated))

def run_parsed(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{val}:
      handle_doc(val)
    case Fail{err}:
      do IO<Unit>:
        IO.print("Parse error: " ++ err)

def run_demo(+raw: String) -> IO(Unit):
  do IO<Unit>:
    IO.print("=== Example 1: Basic Usage ===")
    IO.print("Input JSON: " ++ raw ++ "\n")
    run_parsed(Json.parse(raw))

def main() -> IO(Unit):
  run_demo("{\"name\": \"Bend\", \"version\": 2, \"fast\": true}")
