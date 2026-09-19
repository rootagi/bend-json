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

## D2: Strict RFC 8259 String Escaping, Unicode Surrogate Pairs, and Control Character Handling

### Context
RFC 8259 §7 dictates that all characters within strings with code point < 0x20 must be escaped, and characters may be escaped using two-character escape sequences (`\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`) or 4-digit hexadecimal unicode escapes `\uXXXX`. Characters outside the Basic Multilingual Plane (U+10000 to U+10FFFF) must be encoded as UTF-16 surrogate pairs (`\uD800..\uDBFF\uDC00..\uDFFF`). Lone surrogates or invalid escape sequences are syntax errors.

### Decision
1. In `classify_str_char`, classify characters `< 32` as `SCControl{}` and fail with `SErr{"unescaped control character in string"}`.
2. Only valid RFC 8259 escape characters are permitted after `\`. Any invalid sequence (such as `\q`) fails with `SErr{"invalid escape sequence"}`.
3. Hexadecimal unicode escapes `\uXXXX` validate each digit. Short escapes (`\u12`) or non-hex characters (`\uZZZZ`) fail with an error.
4. UTF-16 surrogate pairs: High surrogates (`0xD800..0xDBFF`) require an immediate subsequent `\u` and low surrogate (`0xDC00..0xDFFF`). They are decoded to their Unicode scalar value: `0x10000 + ((hi - 0xD800) * 1024) + (lo - 0xDC00)`. Lone high surrogates or lone low surrogates fail with `SErr{"lone surrogate"}`.
5. In `escape_char`: escape `\"`, `\\`, `\b`, `\f`, `\n`, `\r`, `\t`, and format any other control character `< 32` as `\u00XX`.
6. Use lazy evaluation through parameter pattern matching (instead of eager `Bool.pick`) when constructing `Chr{scalar}` to prevent runtime evaluation of non-scalar surrogate code points.

