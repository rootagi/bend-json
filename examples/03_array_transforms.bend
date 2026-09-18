# examples/03_array_transforms.bend
# Demonstrates array combinators: arr_len, arr_get, arr_map, arr_filter, and arr_push.

import Base
import ../json.bend as Json

def double_num(j: Json.Json) -> Json.Json:
  match j:
    case Json.JNum{n}:
      Json.num(Nat.mul(n, 2n))
    case _:
      j

def is_gt_fifteen(j: Json.Json) -> Bool:
  match j:
    case Json.JNum{n}:
      Nat.is_gt(n, 15n)
    case _:
      False{}

def handle_arr(arr: Json.Json) -> IO(Unit):
  +arr = arr
  len = Json.arr_len(arr)
  
  # Functional mapping: double each element
  doubled = Json.arr_map(~double_num, arr)
  
  # Functional filtering: keep elements > 15
  filtered = Json.arr_filter(~is_gt_fifteen, arr)
  
  # Push a new element
  appended = Json.arr_push(arr, Json.num(99n))
  
  do IO<Unit>:
    IO.print("Original Array:   " ++ Json.stringify(arr))
    IO.print("Array Length:     " ++ Nat.show(len))
    IO.print("Doubled (map):    " ++ Json.stringify(doubled))
    IO.print("Filtered (>15):   " ++ Json.stringify(filtered))
    IO.print("After push(99):   " ++ Json.stringify(appended))

def run_parsed(r: Result<&2, &2, String, Json.Json>) -> IO(Unit):
  match r:
    case Done{val}:
      handle_arr(val)
    case Fail{err}:
      do IO<Unit>:
        IO.print("Parse error: " ++ err)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("=== Example 3: Array Combinators & Transformations ===")
    run_parsed(Json.parse("[10, 20, 30]"))
