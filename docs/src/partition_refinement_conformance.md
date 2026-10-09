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

The public solver and group discovery default to `algorithm=:paper`.
Algorithms 1–3 use fresh shared random key vectors on every iteration, with
uniform integer entries in `1:8191` (the pseudocode leaves their range open).
Pass a fresh `rng=Xoshiro(seed)` to replay a search. The default creates a fresh
`Xoshiro(940)` per call; no mutable global RNG is shared between searches.
Initial cells remain in decreasing absolute-Walsh order (Algorithms 5/7);
refined hyperplane cells remain in increasing-size order (Algorithm 3), even
when the floor retains every cell. Ties are resolved stably and identically on
both sides. Signed Walsh scores omit only a common offset and positive scale,
and therefore induce the exact same ordered refinement as incidence counts.

`algorithm=:optimized` preserves the earlier deterministic-weight and
canonical-cell-order choices explicitly. Threaded kernels remain opt-in.
The test-only reference in `test/support/kaleyski_sunde_reference.jl` computes
literal weighted incidences without the native signatures, Walsh transforms
or compact partitions. Tests compare every intermediate ordered partition,
truncation result, consistency decision and RNG consumption.

Algorithms 4–7 use leaf-only `ValidEA` checks in the paper profile. Affine
implications are evaluated to determine the next free point, without the
optimized profile's early graph-cell rejection. Algorithm 5 starts with an
empty group, anchors a quadratic graph's origin without individualizing its
point cell, searches, then adjoins all τₐ actions and finally constructs the
pointwise kernel. The algorithm retains verified affine witnesses as lifts;
this supplies exactly the generators required by Lemma 13 without a second
linear solve for the same action.

The independent reference also transcribes Algorithms 4–7 using explicitly
enumerated partial affine domains, group elements and point stabilizers.
Tests exhaust all ordered pairs of tables in dimensions (1,2) and (2,1),
comparing decisions, first graph actions, DFS counts and full graph groups
under multiple seeds. Full ambient orders are separately checked against
exhaustive AGL oracles, including EA restrictions and kernel lifts.

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
