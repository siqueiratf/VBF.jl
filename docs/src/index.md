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
the whole target graph. The search handles arbitrary square SBoxes, including
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
root. General automorphism discovery and stabilizer-group pruning from the
paper are not implemented. The older `:heggebakk`, `:ortho_derivative` and CCZ
`:canteaut_perrin` strategies remain available explicitly. Native refinement
decides and recovers one map; it does not replace the APIs enumerating all EA
maps or entire CCZ classes. See [the reproducible comparison](https://github.com/zambonin/VBF.jl/blob/main/bench/README.md#native-partition-refinement-comparison)
for the C++ benchmark and its scope.
