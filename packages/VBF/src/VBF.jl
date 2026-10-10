"""
    VBF

Algorithms for analysing **vectorial Boolean functions** (S-boxes) in Julia:
differential/linear/boomerang spectra, the linear/affine/EA/CCZ equivalence
hierarchy, and APN-specific invariants and constructions. Paper-reproduction
scripts live under `packages/VBFRepro/papers/`.

Source is grouped by concept (each directory is a chapter of the algorithm
catalog); files load in dependency order:

1. `representations/` — the ways to present a VBF and convert between them:
   `SBox` (truth table), `F2LinearMap`/`F2AffineMap`, `Spectrum`, the ANF
   (Möbius) transform, and GF(2ⁿ) finite-field arithmetic.
2. `linalg/`          — F₂ (GF(2)) bit-packed linear algebra: Gauss–Jordan,
   rank/basis/kernel, linear & affine systems, the dyadic-bitset substrate,
   and F₂-subspace search.
3. `spectra/`         — distribution tables and transforms: the Walsh–Hadamard
   transform, DDT / LAT / BCT / FBCT, algebraic degree, linear structures, and
   the Bonnetain–Perrin–Tian anomaly models.
4. `invariants/`      — EA/CCZ invariants: ortho-derivative & ortho-integral,
   σ-multiplicities, the APN/EA mugshot.
5. `equivalence/`     — the equivalence hierarchy: `linear/`, `affine/`, `ea/`,
   `ccz/` (incl. TU-decomposition and the Edel–Pott linear-code matrices).
6. `constructions/`   — building/searching for functions: switching neighbours,
   CCZ-quadratic representatives, the quadratic-APN graph machinery.
7. `random/`          — seeded random S-box / linear / affine generators.
8. `io/`              — Markdown/LaTeX rendering.

The data/catalog layer lives in the companion `VBFCatalog` package (it depends
on `VBF`, never the reverse). See the top-level README for the catalog index.
"""
module VBF
using Random: AbstractRNG, Xoshiro, rand

# 1. representations — types first (used in later signatures), then transforms
include("representations/truth_table.jl")
include("representations/sbox.jl")
include("representations/f2_linear_map.jl")
include("representations/f2_affine_map.jl")
include("representations/spectrum.jl")
include("representations/anf.jl")
include("representations/finite_field.jl")
include("representations/univariate.jl")

# 1b. search — the three-case result type bounded searches return. No
#     dependencies; included before anything that runs a bounded search.
include("search/outcome.jl")

# 2. linalg — F₂ bit-linear-algebra substrate
include("linalg/f2_arith.jl")
include("linalg/partial_isomorphism.jl")
include("linalg/linear_system.jl")
include("linalg/affine_system.jl")
include("linalg/dyadic_bitset.jl")
include("linalg/subspace_search.jl")
include("linalg/subspace_in_set.jl")

# 3. spectra — transforms + distribution tables + anomaly models
include("spectra/walsh.jl")
include("spectra/differential.jl")
include("spectra/linear.jl")
include("spectra/boomerang.jl")
include("spectra/algebraic.jl")
include("spectra/linear_structures.jl")
include("spectra/anomaly.jl")

# 4. invariants — EA/CCZ invariants
include("invariants/ortho_derivative.jl")
include("invariants/quadratic_apn_rank.jl")
include("invariants/ortho_integral.jl")
include("invariants/sigma_multiplicities.jl")
include("invariants/mugshot.jl")
include("invariants/bent.jl")
include("invariants/image.jl")
include("invariants/pi_multiset.jl")
include("invariants/design_ranks.jl")
include("invariants/classification_keys.jl")

# 5. equivalence — the relation hierarchy
include("equivalence/linear/backtracking.jl")
include("equivalence/linear/canonical_representative.jl")
include("equivalence/linear/general_equivalence.jl")
include("equivalence/linear/api.jl")
include("equivalence/linear/self_equivalences.jl")
include("equivalence/linear/set_equivalence.jl")
include("equivalence/linear/three_to_one.jl")
include("equivalence/linear/three_to_one_equivalence.jl")
include("equivalence/affine/shift.jl")
include("equivalence/affine/api.jl")
include("equivalence/ea/partition.jl")
include("equivalence/ea/outer_permutation.jl")
include("equivalence/ea/inner_permutation.jl")
include("equivalence/ea/api.jl")
include("equivalence/ea/ea_full.jl")
include("equivalence/ea/partition_automorphisms.jl")
include("equivalence/ccz/function_graph.jl")
include("equivalence/ccz/block_decomposition.jl")
include("equivalence/ccz/linear_code.jl")
include("equivalence/partition_refinement/partition.jl")
include("equivalence/partition_refinement/refine.jl")
include("equivalence/partition_refinement/groups.jl")
include("equivalence/partition_refinement/search.jl")
include("equivalence/partition_refinement/affine_kernel.jl")
include("equivalence/partition_refinement/automorphisms.jl")
include("equivalence/ccz/walsh_zeroes.jl")
include("equivalence/ccz/thickness.jl")
include("equivalence/ccz/tu_decomposition.jl")
include("equivalence/ccz/api.jl")
include("equivalence/partition_refinement/api.jl")

# 6. constructions — building / searching for functions
include("constructions/switching_neighbors.jl")
include("constructions/apn_extensions.jl")
include("constructions/ccz_quadratic.jl")
include("constructions/quadratic_apn_graph.jl")
include("constructions/ea_class_orbits.jl")
include("constructions/quadratic_apn_search.jl")
include("constructions/quadratic_extensions.jl")
include("constructions/quadratic_apn_tree.jl")
include("constructions/quadratic_restrictions.jl")
include("invariants/quadratic_profiles.jl")
include("constructions/trims.jl")
include("constructions/extensions.jl")
include("constructions/qam.jl")
include("constructions/qam_search.jl")
include("constructions/taniguchi.jl")
include("constructions/le_automorphism_search.jl")
include("constructions/apn_families.jl")
include("constructions/apn_quadratic_families.jl")
include("constructions/sporadic_apn.jl")

# 7. random object generators
include("random/random_objects.jl")

# 8. presentation
include("io/display.jl")
include("io/report.jl")

include("exports.jl")

end # module VBF
