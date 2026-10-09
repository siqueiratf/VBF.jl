# VBF: vectorial Boolean function analysis

VBF is a Julia workspace for analysing vectorial Boolean functions, with a focus
on APN (almost perfect nonlinear) functions and the linear / affine / EA / CCZ
equivalence hierarchy. It reimplements, in native Julia, the algorithmic content
of the sboxU cryptanalysis stack and several satellite projects, with no runtime
or build dependency on any of them.

The source lives at [github.com/zambonin/VBF.jl](https://github.com/zambonin/VBF.jl).

## Packages

- **VBF** — the algorithms (pure; its only dependency is `Random`):
  representations, F2 linear algebra, spectra, EA/CCZ invariants, the equivalence
  predicates, and the construction/search routines.
- **VBFCatalog** — the data layer (uses VBF): the curated SQLite catalog,
  multi-source reconciliation, the bibliography, data importers, and bulk corpora.

## Quick start

Requires Julia ≥ 1.12. From the repository root:

```julia
using Pkg
Pkg.activate("packages/VBF")
Pkg.instantiate()

using VBF          # the algorithms
using VBFCatalog   # the algorithms plus the catalog
```

## API reference

The pages under **API reference** in the sidebar are generated from the source
docstrings, one page per concept directory of `packages/VBF/src`:
representations, linear algebra, spectra, invariants, the equivalence hierarchy,
constructions, random objects, and rendering — plus the VBFCatalog data layer.
Each entry carries its underlying mathematics and references.

## Native CCZ and EA equivalence

`are_ccz_equivalent` and `are_ea_equivalent` use native Julia partition refinement
by default (`strategy=:auto`). The algorithm is due to **Nikolay Kaleyski and
Joakim Sunde**, [ePrint 2026/940](https://eprint.iacr.org/2026/940), *Efficiently
deciding and recovering CCZ and EA equivalence for arbitrary vectorial Boolean
functions using the partition refinement framework*. The authors also provide a
[C++ reference implementation](https://github.com/zskiley/CCZ-EA-equivalence).
VBF uses its existing Walsh transform, GF(2) linear maps and function graphs;
there is no sboxU, Sage, Python or C++ dependency in the Julia package.

The default `algorithm=:paper` follows the paper's fresh shared random weights
and ordered partitions. Supply `rng=Xoshiro(seed)` (from `Random`) for replay.
The earlier deterministic heuristic choices are available explicitly as
`algorithm=:optimized`. See [algorithm conformance](partition_refinement_conformance.md)
for the step mapping, independent validation and documented extensions.

Recover and check an affine map from F's graph to G's graph:

```julia
F, G = kim_apn(), dillon_apn_permutation()
A = ccz_equivalence_certificate(F, G)
@assert is_invertible(A)
@assert ccz_equivalent_function(F, A) == G
```

An EA certificate retains the existing outer/input/drift convention, including
affine input translations:

```julia
F = gold_apn(5, 1)
G = SBox{5}([F(x ⊻ 1) ⊻ x for x in 0:31])
c = ea_equivalence_certificate(F, G)
@assert all(c.L1(F(c.A2(x))) ⊻ c.A_drift(x) == G(x) for x in 0:31)
```

The graph convention is `(x << n) | F(x)`, so EA maps preserve the **low-bit**
output subspace. Every recovered map is checked for invertibility and against
the whole target graph. The search handles arbitrary square SBoxes and
rectangular `VBFTable{N,M}` functions F₂ⁿ → F₂ᵐ, including
nonpermutations and affine graphs that do not span the ambient space.

Use `on_inconclusive=:throw` or `:missing` for classification. Predicate defaults
retain the compatibility policy `:best_effort`, which warns and returns `false`
on a budget hit; that result is not an inequivalence proof. Certificate APIs
default to `:throw`. For explicit outcomes:

```julia
result = partition_refinement_equivalence(F, G; relation=:ea,
    max_nodes=10^6, timeout_seconds=60, max_memory_bytes=512*1024^2)
# Found: verified witness; Exhausted: proved negative; BudgetHit: undecided.
```

The memory budget checks a conservative allocation estimate, not process RSS.
The transform uses O(2^(2n)) storage and the worst-case search is exponential.
Quadratic target graphs get automatic translation symmetry reduction at the
root. The older `:heggebakk`, `:ortho_derivative` and CCZ
`:canteaut_perrin` strategies remain available explicitly. Native refinement
decides and recovers one map; it does not replace the APIs enumerating all EA
maps or entire CCZ classes. See [the reproducible comparison](https://github.com/zambonin/VBF.jl/blob/main/bench/README.md#native-partition-refinement-comparison)
for the C++ benchmark and its scope.

### Automorphism groups and stabilizer pruning

Group discovery is part of the paper's Algorithms 4–5; Algorithms 6–7 use
stabilizer orbits to prune equivalence searches. VBF implements these with
native deterministic Schreier–Sims chains on graph points. The affine lift
includes the pointwise kernel from Lemma 13, so it also returns the whole
ambient group for rank-deficient graphs. Orders use exact `BigInt` arithmetic.

```julia
F, G = gold_apn(7, 1), gold_apn(7, 2)
H = partition_refinement_automorphisms(G; relation=:ccz)
@assert H.complete && H.order == 113792
result = partition_refinement_equivalence(F, G; automorphisms=H)
@assert result isa Exhausted
@assert nodes_visited(result) == 21  # the paper's Example 2
```

`H.generators` are verified affine maps, not every group element. A stopped
discovery returns `H.complete == false` and a valid subgroup which is still
safe to use for pruning. `H.stop_reason` explains the limit; `H.order` can be
`nothing` if group construction was interrupted. Supplied maps are checked
against the target graph before use. For EA, discover with `relation=:ea`;
CCZ generators may violate the required output-subspace condition.

All decision and certificate APIs accept `automorphisms=H`. For a one-off
query, `automorphism_timeout_seconds=1.0` runs bounded discovery on both functions
and uses the larger known graph-action group in the paper profile, sharing the
query's overall time, node and memory budgets. Discovery is
opt-in: easy queries often finish faster without it. Reuse a discovered group
when testing many functions against the same target. Group memory estimates
include stabilizer chains across the DFS depth and can reject a computation
before allocating its buffers.

### Optional parallel refinement

Start Julia with `julia --threads=4 --project=.` and pass `threaded=true` to a
search or certificate API. Large fixed-width Walsh transforms and large direct
incidence sums then run on independent output slices. Small workloads stay
serial to avoid task overhead. The Walsh API also accepts
`walsh_hadamard!(v; threaded=true)`.

DFS and group mutations remain serial; integer signatures, search order, node
budgets and completeness are unchanged. Independent group searches can also
run concurrently because their mutable state is search-local. The paper's
Section 9 proposes implementation optimization and parallelization as future
work; it does not give a parallel algorithm.
