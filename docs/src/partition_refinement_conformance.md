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

Decision and certificate APIs also accept rectangular tables. EA certificates
retain `G(x) = L1(F(A2(x))) ⊻ A_drift(x)` with independent input and output
widths; graph certificates retain F → G orientation. Legacy square predicates
using `strategy=:auto` may short-circuit on equality or existing invariants.
Use the native solver directly, or `strategy=:partition_refinement`, when
replaying the paper's actual search steps.

### Pointwise-kernel construction (Algorithm 5 / Lemma 13)

Write the graph's affine hull as `p₀ + S`, with `s = dim(S)` and
`r = n+m-s`. Fixing every graph point means fixing `S` linearly and choosing
the affine constant `p₀ ⊻ L(p₀)`. In a basis adapted to `S`, the remaining
linear blocks are an arbitrary shear into `S` and an arbitrary GL(r,2) map.
Thus the CCZ kernel has order `2^(s*r) * |GL(r,2)|`.

For EA, let `O` be the low-bit output subspace and `k = dim(S ∩ O) = s-n`.
The graph projects onto all inputs, so `S+O` is the whole ambient space. A
basis adapted to both subspaces restricts the shear to `S ∩ O`; the EA kernel
has order `2^(k*r) * |GL(r,2)|`. Elementary transvections generate these
blocks. The existing GF(2) basis/kernel solvers implement the induced linear
constraints, parametrizing all invertible solutions rather than enumerating
them. This supplies the complete kernel required by Algorithm 5, not merely
one affine extension of each graph action.

## Conformance work and commit boundaries

### Necessary correction to the printed branching condition

Algorithms 4 and 6 print `|Pᵢ \ Domain(A)| > 1` when selecting a source cell.
This must be `> 0`. Algorithm 5 anchors `(0,F(0))` without individualizing it;
the anchor can therefore share a cell with the only remaining free point.
Section 3's search description and Lemma 16's induction require selecting any
undetermined graph point whenever the map is not yet determined on the graph.

Counterexample: `F = SBox{2}([0,0,0,1])`. Its four graph points are affine
independent. After anchoring the first and individually fixing the second and
third, refinement retains the cells `[second]`, `[third]`, `[first,fourth]`.
Their free-point counts are `[0,0,1]`: the printed condition selects no cell.
The independent reference, treating that stuck node as a dead end, returns a
graph group of order 4 after adjoining translations; the corrected condition
returns order 24, verified independently by enumerating AGL(4,2). The full
ambient group has order 192. A dedicated regression test reconstructs this
node and compares the printed and corrected reference executions.

This is a correctness correction, isolated in its own commit. It is not a
heuristic or optimization. The implementation follows the mathematical search
described and proved in the paper rather than reproducing this printed defect.

### Figure 1 differs from Algorithm 2

For Example 1's seven-bit Gold functions, Figure 1 reports a depth-one
hyperplane cell of size 16,510. These are the zero-Walsh hyperplanes. With a
singleton point of weight `u` and the remaining points of weight `v`, the
two opposite zero-Walsh hyperplanes have weighted intersections `u+63v`
and `64v`. Algorithm 2 therefore splits that cell into two cells of size
8,255 whenever `u≠v`. Direct incidence counts verify this: `u=7,v=2` gives
133 and 128. The paper-profile trace accordingly has hyperplane cell sizes
`[3556,3556,4572,4572,8255,8255]`, with point cells `[1,127]`.

The implementation follows the signed incidence formula in Algorithm 2 and
Lemmas 8–10. It does not introduce absolute-value signatures to reproduce the
figure's unsplit cell. A separate test records this discrepancy and verifies
both the direct counts and the native trace. Example 2's 21-node search and
the order-113,792 group are independently recovered.

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

## Section 6.2 discovery policy outside Algorithm 7

With `automorphism_timeout_seconds>0` and no supplied target subgroup, the
paper profile runs bounded discovery on both F and G, compares their known
graph-action orders, and uses the larger subgroup (source on ties). A source
group reverses the internal search; the returned certificate is inverted back
to the public F → G convention. Both discovery runs and the equivalence DFS
share the overall time and node budget. The allowance is per discovery run,
bounded by the remaining query time. Unknown orders provide no largest-group
guarantee; the chosen verified subgroup remains safe for pruning.

The optimized profile preserves target-only discovery. Explicitly supplied
target generators are always validated and used on the original target.
`search_region(result).params` records the internal orientation and separate
discovery node counts. This policy implements the prose of Section 6.2; the
Algorithm 7 entry point itself still accepts an optional pruning subgroup.
