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
`(x << m) | F(x)`; EA maps preserve the subspace formed by the low `m` output bits. The ambient
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

## Algorithm mapping

| Paper | Native Julia routine | Independent check |
| :--- | :--- | :--- |
| Algorithm 1, RefinePoints | `_pr_point_scores!` | Direct weighted incidences |
| Algorithm 2, RefineHyperplanes | `_pr_plane_scores!` | Direct weighted intersections |
| Algorithm 3, Refine | `_pr_refine!` | Every ordered split, trim and RNG state |
| Algorithm 4, DFS-Auto | `_pr_auto_dfs!` | Explicit affine spans and enumerated groups |
| Algorithm 5, CCZ-Automorphism | `partition_refinement_automorphisms` | Graph groups, AGL ambient groups, kernel orders |
| Algorithm 6, DFS | `_pr_dfs!` | First actions and DFS counts |
| Algorithm 7, CCZ-Equivalence | `partition_refinement_equivalence` | All small rectangular table pairs |

Section 6's `Update` uses the independently tested incremental GF(2)
isomorphism primitive. `ValidEA` establishes the input quotient at leaves
before ambient completion. Section 8.2's group operations use native
Schreier–Sims on graph points. Lemma 13 supplies the full affine lift.

## Paper profile and independent validation

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

The package regression after the conformance implementation on Julia 1.13.1 passed **131,050 assertions in
92 test items**. Only the pre-existing `linear_backtracking` and `extensions`
failures were excluded; both were reproduced on the unchanged base commit
`f0401a2`. The regression command was:

```sh
VBF_TEST_NAME='(?!linear_backtracking$|extensions$).*' \
RETESTITEMS_NWORKERS=4 \
JULIA_DEPOT_PATH=/tmp/vbf-julia-depot:/home/zambonin/.julia \
julia --threads=4 --startup-file=no --compiled-modules=existing \
  -e 'using Pkg; Pkg.activate("packages/VBF"); Pkg.test(;julia_args=["--compiled-modules=existing","--threads=4"])'
```

This includes 6,266 reference-conformance assertions, 259 rectangular
representation/group/API assertions, the isolated branching regression,
and direct verification of Figure 1's discrepancy and Example 2's group
order and DFS count. It also exercises the existing square APIs and group,
certificate, budget and threaded-refinement tests.

The local Documenter build also completed with doctests enabled, without
doctest failures, missing-docstring warnings or unresolved references. The
generated API includes the shared search outcomes used by bounded equivalence
and group discovery. Existing bibliography-format and HTML-size warnings remain.

## Printed pseudocode and figure discrepancies

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
Lemma 16's inductive step assumes that a branching point can be selected;
the printed `>1` condition does not guarantee that step. Lemma 17 invokes
Lemma 16, so the literal pseudocode's completeness argument has this gap.
This does not refute completeness of the corrected mathematical DFS.

The scalar example is `VBFTable{2,1}([0,0,0,1])`, representing
`F(x₁,x₂)=x₁x₂`. Its graph is an affine basis in dimension three and its
full ambient CCZ group has order 24. The square example above embeds this
scalar function into two output bits, adding a pointwise kernel of order 8.

### Algorithm 3 needs an exhaustion boundary

The final loop in Algorithm 3 stops only when `HyperplaneFloor` is reached.
If the requested floor exceeds the number of available hyperplanes, its next
cell does not exist. This also arises naturally in small dimensions: there
are only `2*(2^(n+m)-1)` affine hyperplanes in total, and initialization may
have already retained fewer than that. Algorithms 5 and 7 bound their initial
selection by the available classes; Algorithm 3 needs the same protection.

The native trim iterates over existing cells and retains all of them if the
floor cannot be reached. This boundary has been present since the original
implementation; its specification and regression tests are isolated from
algorithmic extensions. The paper profile still sorts the surviving cells by
increasing size and preserves their left/right correspondence. Tests cover
exactly sufficient, oversized and maximum-integer floors, empty partitions,
and public equivalence/group calls with only six ambient hyperplanes. The
additional focused regression passes 71 assertions.

### Verification against the authors' implementation

The optional driver `packages/VBF/perf/partition_refinement_specification_audit.cpp`
checks the official C++ revision
[`c9cec6515b3297abf5c15fedd23e55b43f2ba888`](https://github.com/zskiley/CCZ-EA-equivalence/tree/c9cec6515b3297abf5c15fedd23e55b43f2ba888).
All 54 source/header files in the executed checkout were verified byte for
byte against that revision's official archive. The source fingerprint,
using the same sorted-path/content convention as the benchmark runner, is
`d26c2ea762258e3ce3cf21a7b0cf6d4e55d6488a717c2f0b3e62bf04cbe09757`.

Both `partition_branch::NextUndeterminedBranchCell` and the equivalence
routine's `NextUndeterminedBranchCellPair` skip singleton *cells*, then accept
any remaining cell containing at least one undetermined point. After matched
singletons have been processed, this permits the necessary sole-free-point
branch. This is different from requiring more than one *undetermined point*.
The driver's direct probe accepts `[second],[third],[first,fourth]` with the
first three points mapped. End-to-end group discovery recovers graph order
24 in both the scalar and square cases, and ambient orders 24 and 192.
Positive equivalence checks also succeed. The authors' quadratic wrapper
individualizes the anchor and adjoins translations before DFS, providing an
additional difference from the printed Algorithm 5.

The C++ `KeepSmallestCells` returns immediately when the number of available
hyperplanes does not exceed the requested floor. The driver verifies that a
maximum-integer floor safely retains all six hyperplanes in ambient dimension
two. **Neither identified pseudocode defect is present in these inspected
C++ routines at the pinned revision.** These checks do not establish general
correctness of the released implementation or independently validate the
paper's large-dimension experimental results.

Re-run from the repository root against an external checkout of that revision:

```sh
CCZ_REFERENCE=/tmp/CCZ-EA-equivalence-main python3 - <<'PY'
import os, pathlib, subprocess
src = pathlib.Path(os.environ['CCZ_REFERENCE']) / 'src'
files = sorted(str(p) for p in src.rglob('*.cpp')
               if p.name not in ('main.cpp', 'python.cpp', 'group_benchmark.cpp'))
subprocess.run(['g++', '-std=c++17', '-O2', '-I' + str(src),
                'packages/VBF/perf/partition_refinement_specification_audit.cpp',
                *files, '-o', '/tmp/vbf-reference-specification-audit'], check=True)
subprocess.run(['/tmp/vbf-reference-specification-audit'], check=True)
PY
```

The driver is independent audit code; no upstream source is vendored or
required by package tests.

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

## Implementation history and algorithmic extensions

The local branches were separated on 2026-10-09 after three census commits
were interleaved with this work. `feat/native-partition-equivalence` is based
on the original `f0401a2` and preserves the 22 solver, conformance, optimization
and benchmark commits. `feat/apn-literature-audit` is a three-commit census
stack on that solver branch: its EA verifier calls the native solver, so the
dependency is explicit. The solver branch's diff contains no census files;
the audit branch's diff against the solver contains only census files.

The original mixed heads are preserved locally as
`backup/native-partition-equivalence-mixed-20261009` (`380b8a3`) and
`backup/apn-literature-audit-mixed-20261009` (`ecb0739`). Commit IDs below and
the measured revision IDs in `packages/VBFPaper/bench/data/archive/bench/README.md` identify the original history.
Some replayed commits have new IDs, but their patches and the final VBF source
tree are unchanged; the recorded benchmark source fingerprints remain valid.
This separation adds only this documentation note after replaying the solver
commits. No remote history was rewritten by the local separation.

The original implementation used deterministic weights, restored previous cell
ordering after truncation, seeded quadratic translations before group DFS, and
propagated EA constraints before leaves. Those choices are extensions, not
literal pseudocode. They are confined to `algorithm=:optimized`. Earlier optimization commits remain distinct:

- `a552de8`: direct indexing of implied graph images.
- `1dad1ed`: skipping uniform-cell sorting and SIMD Walsh butterflies.
- `34d732a`: group machinery and opt-in parallel refinement kernels.
- `b6ad7b2`: avoiding boxed counters in threaded score construction.

The paper's experimental tables are separate empirical claims. Small fixture
comparisons in `packages/VBF/perf/` do not reproduce Section 7's sampled corpora, Magma
comparisons, large-dimension averages or peak RSS measurements. Implementing
Algorithms 1–7 does not imply reproducing those hardware-dependent tables.

The conformance work is committed separately from those extensions:

- `372f9c0`: independent input/output dimensions and rectangular group oracles.
- `5ebb803`: paper keys and ordering, explicit optimized profile, direct reference.
- `c81708a`: paper DFS scheduling, leaf-only EA checks and post-DFS affine lifting.
- `49a127d`: isolated correction to the printed free-point condition.
- `e0e2ac3`: Section 6.2 two-sided discovery and certificate orientation.
- `0d7efaa`: rectangular public decisions and EA/CCZ certificates.
- `ab6997e`: example validation and the Figure 1 discrepancy.
- `d2f5e7d`: Algorithm 3's necessary exhaustion boundary and focused regression.

## Limits of the paper's experimental claims

The reported tables demonstrate substantial improvements on many cases,
but do not establish universal per-instance superiority in time and memory:

| Observation in the local paper | Qualification |
| :--- | :--- |
| Table 1, positive CCZ search: 6 s for Algorithm 7, 1 s for Magma | The search alone is faster in Magma. Both times exclude group discovery; adding the reported group averages gives approximately 42 s versus 158 s, favoring the proposed method for a fresh end-to-end query. |
| Table 5, dimension-13 inverse automorphisms: 1,256 MB for Algorithm 5, 969 MB for Magma | Magma uses less reported peak memory in this case. |
| Section 7 benchmarks CCZ and states EA behaves similarly | Corresponding EA measurements are not presented, so the tables do not independently substantiate that assertion. |
| Table 5 labels the dimension-10-through-15 inverse benchmarks non-APN | The odd cases 11, 13 and 15 are APN, as Section 7.2 itself states. |

For the last point, extend inversion by `F(0)=0`. For nonzero `a,b`, put
`x=az`. Away from `z=0,1`, the differential equation becomes
`z²+z=1/(ab)`. At `ab=1`, the two exceptional solutions are joined by two
ordinary solutions exactly when `Tr(1)=0`, which holds for even dimension.
Thus inversion is APN in odd dimension and differentially 4-uniform in even
dimension. CCZ transformations preserve this distinction; using transformed
inverse functions does not make the odd-dimensional cases non-APN.

The branching condition affects the printed completeness argument; the table
findings constrain the scope of the experimental claims.

## Reproduction claim

The supported claim is: **VBF independently implements the Kaleyski–Sunde
CCZ/EA equivalence and automorphism algorithms of ePrint 2026/940 in native
Julia**, including rectangular functions and full ambient group lifting.
The default path follows the paper's mathematical algorithms; the necessary
branching/floor safeguards and Figure 1 discrepancy are explicit above.
The independent reference is test-only and shares no native partition,
signature, partial-affine-map or group-search implementation.

The memory guard estimates allocations, not peak RSS. In particular its
conservative group bound exceeds the default 512 MiB budget at nine input
bits for square functions. Raising the explicit memory allowance permits
larger computations; this is a resource policy, not a negative result.
Large-dimension performance parity and the experimental tables remain
separate claims requiring their own measurements.

## Arbitrary binary generator matrices

`binary_code_equivalence(G,H)` covers a different input problem from Algorithms
5/7: arbitrary binary linear codes, represented by generators whose rows may be
redundant. The exact reduction is to invertible linear equivalence of the
**column multisets** of full-rank rowspace bases. Row reduction supplies source
pivot columns equal to the standard basis. Search maps their images into target
columns, propagates linear relations, and preserves zero/duplicate multiplicities.
Its permutation witness has convention `rowspace(G[:,p]) == rowspace(H)`; an
independent rank/stack replay checks that assertion.

The implementation reuses the incremental GF(2) isomorphism primitive used in
Kaleyski–Sunde recovery for ranks up to 32 and existing wide `rank_f2` beyond it.
This is separate bounded orchestration, not a claim that the paper's graph
algorithm was extended verbatim. The graph engine relies on distinct graph
points, input-based indexing, and affine anchors. The older linear-set routine
discards duplicate counts and materializes membership over the entire ambient
space, so it is unsuitable for arbitrary generators.

No `2^rank` ambient arrays or external code solver are required. Worst-case
basis-image search remains exponential. A complete negative is conclusive only
after valid invariant separation or exhaustion; time, node, and estimated-memory
stops remain `BudgetHit`. Core row reduction/rank calls are cooperatively timed.
The implementation is not a promise of practical classification of every large
code or of equivalence among all APN functions in a dimension.

Independent tests compare literal codeword sets under every small coordinate
permutation, replay planted rank-33/65 maps, include equal-weight-enumerator
inequivalent controls, and compare CCZ-code decisions with native graph recovery.
