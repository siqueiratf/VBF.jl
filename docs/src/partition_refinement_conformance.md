# Independently implementing ePrint 2026/940

Ground truth: Nikolay Kaleyski and Joakim Sunde, *Efficiently deciding and
recovering CCZ and EA equivalence for arbitrary vectorial Boolean functions
using the partition refinement framework*, [ePrint 2026/940](https://eprint.iacr.org/2026/940).
The Julia implementation is written against the paper, using VBF's existing
GF(2), affine-map, Möbius and Walsh primitives. The authors' C++ source is an
external comparison artifact, not a runtime dependency or vendored source.

## Mathematical scope

`SBox{N}` represents square functions. `VBFTable{N,M}` represents the paper's
general functions F₂ⁿ → F₂ᵐ, with positive independent dimensions. Graphs pack
`(x << m) | F(x)`; EA maps preserve the low `m` output bits. The ambient
representation uses UInt32 (`n+m ≤ 32`), with explicit time, node and memory
limits. A budget hit is not a negative equivalence result or a complete group.

Rectangular tests enumerate every AGL(3,2) affine permutation for every table
with `(n,m) = (1,2)` and `(2,1)`, independently checking the full CCZ and EA
group orders. Existing tests independently enumerate AGL(4,2) and three-bit
graph actions, including the pointwise affine kernel in rank-deficient cases.

## Conformance work and commit boundaries

The original implementation used deterministic weights, restored previous cell
ordering after truncation, seeded quadratic translations before group DFS, and
propagated EA constraints before leaves. Those choices are extensions, not
literal pseudocode. Their separation from the paper path is tracked in later
conformance commits. Earlier optimization commits remain distinct:

- `a552de8`: direct indexing of implied graph images.
- `1dad1ed`: skipping uniform-cell sorting and SIMD Walsh butterflies.
- `34d732a`: group machinery and opt-in parallel refinement kernels.
- `b6ad7b2`: avoiding boxed counters in threaded score construction.

The paper's experimental tables are separate empirical claims. Small fixture
comparisons in `bench/` do not reproduce Section 7's sampled corpora, Magma
comparisons, large-dimension averages or peak RSS measurements. Implementing
Algorithms 1–7 does not imply reproducing those hardware-dependent tables.
