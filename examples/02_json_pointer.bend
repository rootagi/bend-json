# examples/02_json_pointer.bend
# Demonstrates RFC 6901 JSON Pointer querying and in-place deep mutation.

import Base
import ../json.bend as Json

def print_pointer_result(label: String, m: Maybe<&2, Json.Json>) -> IO(Unit):
  match m:
    case Some{v}:
      do IO<Unit>:
        IO.print(label ++ ": " ++ Json.stringify(v))
    case None{}:
      do IO<Unit>:
        IO.print(label ++ ": (not found)")

def handle_doc(j: Json.Json) -> IO(Unit):
  +j = j
  # Query nested properties
  host_res = Json.pointer(j, "/server/host")
  p0_res   = Json.pointer(j, "/server/ports/0")
  p1_res   = Json.pointer(j, "/server/ports/1")
  esc_res  = Json.pointer(j, "/escaped~1key")
  
  # Mutate nested property in place
  updated = Json.pointer_set(j, "/server/ports/0", Json.num(90n))
  
  do IO<Unit>:
    IO.print("--- JSON Pointer Queries ---")
    print_pointer_result("Pointer '/server/host'", host_res)
    print_pointer_result("Pointer '/server/ports/0'", p0_res)
    print_pointer_result("Pointer '/server/ports/1'", p1_res)
    print_pointer_result("Pointer '/escaped~1key' (unescaping ~1 to /)", esc_res)
    IO.print("\n--- After pointer_set('/server/ports/0', 90) ---")
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
    IO.print("=== Example 2: RFC 6901 JSON Pointer ===")
    IO.print("Input Document:\n" ++ raw ++ "\n")
    run_parsed(Json.parse(raw))

def main() -> IO(Unit):
  run_demo("{\"server\": {\"host\": \"localhost\", \"ports\": [80, 443]}, \"escaped/key\": 100}")
