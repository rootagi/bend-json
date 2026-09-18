# AI Agent Guidelines for Bend 2

When developing in this repository:
- Run `bend guide` to learn Bend 2 syntax, affine types, and proof rules.
- State all critical safety properties, invariants, and round-trip specifications in `LAWS.bend`.
- Mechanically check every property by running `bend PROOF.bend` before committing.
- Ensure all loops and string traversals use linear state machines to avoid deep stack recursion.
- Parallelize operations where applicable using Bend's parallel call notation.
