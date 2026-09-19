# Architectural and Design Decisions

## D1: Representation of Decimals and Scientific Notation (JRaw)

### Context
JSON RFC 8259 §6 allows arbitrary precision numbers including decimal points and exponential notation (e.g. `1.5`, `-0.25`, `1e10`, `12.5e+3`). Bend 2 provides native `Nat` (arbitrary-precision natural numbers), `U32`, and `F32` (IEEE 754 single-precision floats). Converting JSON floating point numbers into `F32` would cause loss of precision for 64-bit float numbers and decimal literals, and Bend does not provide a native 64-bit float or arbitrary precision decimal float type.

### Decision
Add constructor `JRaw{raw: String}` to `type Json`.
- Integers within the safe range $[0, 2^{48} - 1]$ continue to parse as `JNum{n: Nat}` or `JNeg{n: Nat}` to preserve performance and exact integer semantics.
- Non-integer numbers (decimals and numbers with scientific notation exponent parts) are parsed strictly according to RFC 8259 §6 and stored verbatim as `JRaw{raw: String}`.
- Serializers (`stringify`, `pretty`, `json_size`) render `JRaw{raw}` directly without quotation.
- Equality and round-trip laws hold: `parse(stringify(JRaw{raw})) == Done{JRaw{raw}}`.
- All `match` statements across `json.bend`, `examples/`, and tests are updated exhaustively.
