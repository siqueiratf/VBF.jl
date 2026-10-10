# Experiment inventory

## Paper metadata

- **Title:** *Exploring the Set of APN Functions*.
- **Authors:** Jules Baudrin, Pierre Galissant and Léo Perrin.
- **Year and venue:** BFA 2025, 10th International Workshop on Boolean Functions
  and their Applications, September 2025, Larnaca, Cyprus.
- **Version:** [HAL hal-05376704v2](https://hal.science/hal-05376704v2), submitted
  21 November 2025. The supplied PDF has a HAL cover followed by six paper pages.
- **Ground truth:** the supplied `/tmp/main.pdf`; this private input is not a
  repository artifact. Paper page numbers below exclude the HAL cover.
- **Author implementation:** the paper links
  [sboxU's `graph_automorphisms_of_apn_quadratic`](https://github.com/lpp-crypto/sboxU/blob/master/sboxU/ccz.py).
  The mutable `master` link does not identify a revision. No author code is
  vendored, and this inventory does not assert agreement with an inspected
  reference-code revision.

The experiment integrates VBF's native automorphism generators into the
Walsh-zero orbit computation. The full known-class six-bit census, complete
one-coordinate switching closure, and all 488 seven-bit per-root closures have
now completed, with independently checked mathematical evidence. Seven-bit
input-root distinctness is inherited from the pinned source collection.
Conjecture 1 remains unproved. This inventory maps claims and methods; actual
coverage and timings are recorded in README.md and TEST_REPORT.md.

The core integration alongside this experiment adds
`ea_class_orbits(F; backend=:partition_refinement, automorphisms=H,
max_nodes, timeout_seconds, max_subspaces, max_memory_bytes)` with explicit
`complete`, `subspaces_complete`, `automorphisms_complete`, `stop_reason` and
`group_order` fields, retaining `bases`, `nspaces`, `nauts` and `orbits`.
`backend=:ortho_derivative` preserves the quadratic-only cross-check.
`ea_class_representatives` returns selected representatives, their graph
maps and chosen orbits directly. These are reusable core API extensions rather
than APIs present before this work. Use this new routine instead of indexing
the older `enumerate_ccz_class` output by subspace/orbit index.

## Mathematical setting

- Functions are `F : F₂ⁿ → F₂ⁿ`, APN when every nonzero derivative is
  two-to-one; quadratic means algebraic degree two. The main experiments use
  `n=6`; the paper also reports `n=7` totals. Proposition 3 and Corollary 1 have
  the explicit precondition `n ≥ 4`.
- Graph points are `(x,F(x))`. An ambient affine permutation is admissible when
  its graph image is again a function graph. Its block form determines whether
  it is an EA mapping.
- Let `𝒱 = {(a,0) : a ∈ F₂ⁿ}` and
  `𝒵_F = {(a,b) : W_F(a,b)=0} ∪ {(0,0)}`. `Σ_F` is the set of all
  `n`-dimensional linear subspaces contained in `𝒵_F`.
- The acting group is `Aut₀(F)`, the linear parts of the full affine graph
  automorphism group. Translation offsets do not act on Walsh masks. The
  paper writes the action as `V ↦ Lᵀ(V)`; acting with `L⁻ᵀ` gives the same
  orbit partition for a complete group because inversion permutes its elements.
  The distinction must be documented when comparing individual actions.
- VBF packs graph points as `(x << n) | F(x)` and Walsh masks as
  `(a << n) | b`, with storage `lut[x+1]`. Its `walsh_zeroes` does not include
  the origin, which subspace routines account for implicitly. Do not count an
  absent stored zero as an absent mathematical subspace origin.
- For the Kim mapping the paper specifies
  `x³+x¹⁰+u*x²⁴`, with `u` a root of `x⁶+x⁴+x³+x+1`.
  VBF's `kim_apn` provides the existing implementation. Polynomial inputs from
  other classifications may use another field basis; record its modulus and
  coefficient convention rather than comparing lookup tables literally.

## Claims inventory

### 1. Admissible mappings and EA similarity

- **ID:** `theorem1-ea-similarity`.
- **Type:** Theorem.
- **Section + number:** Section 2, Theorem 1, paper pages 1–2.
- **Statement:** Two admissible images are EA-equivalent exactly when an EA
  map between their graphs conjugates the admissible mappings to an
  automorphism of the original graph.
- **Reproducibility:** Exact for constructed examples; the general theorem is
  a mathematical proof, not established by finite tests.
- **VBF APIs likely needed:** `F2LinearMap`, `F2AffineMap`, `ea_mapping`,
  `FunctionGraph`, `ccz_equivalent_function`, `ea_equivalence_certificate`,
  `graph_image_by`.
- **Estimated cost:** Fast for bounded small examples.
- **Proposed Julia file:** `section31.jl` (certificate consistency checks).
- **Proposed Makefile target:** `section31`.

### 2. Walsh characterization of admissibility

- **ID:** `proposition1-walsh-admissibility`.
- **Type:** Proposition.
- **Section + number:** Section 2.1, Proposition 1, paper page 2; attributed by
  the authors to Canteaut–Perrin 2019.
- **Statement:** An affine map with linear part `L` is admissible exactly when
  `Lᵀ(𝒱) ⊆ 𝒵_F`, and is an EA mapping exactly when `Lᵀ(𝒱)=𝒱`.
- **Reproducibility:** Exact for every emitted representative and its mapping.
- **VBF APIs likely needed:** `walsh_zeroes`, `extract_linear_subspaces`,
  `ccz_equivalent_function`, `F2LinearMap`, `F2AffineMap`,
  `ccz_block_decomposition`.
- **Estimated cost:** Fast after subspace extraction; extraction is separately
  charged to the Section 3.1 experiment.
- **Proposed Julia file:** `section31.jl`.
- **Proposed Makefile target:** `section31`.

### 3. EA classes as automorphism orbits

- **ID:** `proposition2-subspace-orbits`.
- **Type:** Proposition.
- **Section + number:** Section 2.1, Proposition 2 and Equation (1), paper page 2.
- **Statement:** Two admissible images belong to the same EA class exactly
  when their Walsh-zero subspaces lie in the same linear automorphism orbit.
- **Reproducibility:** Exact when both the subspace enumeration and group
  discovery are complete; Bounded otherwise, giving a subgroup-orbit upper
  bound on the number of EA classes when subspace enumeration is complete.
- **VBF APIs likely needed:** `ea_class_orbits`,
  `partition_refinement_automorphisms`, `AutomorphismGroupResult`,
  `automorphisms_from_ortho_derivative`, `enumerate_ccz_class`.
- **Estimated cost:** Medium to Slow for full six-bit examples, depending on
  group discovery and Walsh-zero extraction.
- **Proposed Julia file:** `section31.jl`.
- **Proposed Makefile target:** `section31`.

### 4. Burnside's orbit formula

- **ID:** `theorem2-burnside-count`.
- **Type:** Theorem.
- **Section + number:** Section 2.1, Theorem 2, paper page 3.
- **Statement:** The number of EA classes is the average fixed-subspace count
  over `Aut₀(F)`, between `|Σ_F|/|Aut₀(F)|` and `|Σ_F|`.
- **Reproducibility:** Exact as a mathematical description and an orbit-count
  bound; Out-of-scope for explicit Burnside summation over a large fully
  enumerated group in this integration.
- **VBF APIs likely needed:** `ea_class_orbits`,
  `partition_refinement_automorphisms`.
- **Estimated cost:** Fast for checking the bounds after the orbit computation;
  full group enumeration is not required and not proposed.
- **Proposed Julia file:** `section31.jl` (bounds only).
- **Proposed Makefile target:** `section31`.

### 5. Quadratic APN automorphisms are EA

- **ID:** `proposition3-quadratic-automorphisms`.
- **Type:** Proposition.
- **Section + number:** Section 2.2.1, Proposition 3, paper page 3.
- **Statement:** For `n ≥ 4`, quadratic APN functions have only EA graph
  automorphisms, and every CCZ map between two quadratic APN functions is EA.
- **Reproducibility:** Exact finite checks on the computed generators; the
  universal statement remains the cited mathematical result.
- **VBF APIs likely needed:** `partition_refinement_automorphisms`,
  `ccz_block_decomposition`, `is_quadratic_apn`, `algebraic_degree`.
- **Estimated cost:** Fast after group discovery.
- **Proposed Julia file:** `section31.jl`.
- **Proposed Makefile target:** `section31`.

### 6. Degrees inside a quadratic CCZ class

- **ID:** `corollary1-degree-structure`.
- **Type:** Corollary.
- **Section + number:** Section 2.2.1, Corollary 1, paper pages 3–4.
- **Statement:** A quadratic APN CCZ class has one quadratic EA class,
  nontrivial twists have degree at least three, one-twists have degree three,
  a cubic member exists, and the quadratic function is not twist-self-equivalent.
- **Reproducibility:** Exact for the degree-two uniqueness and existence of a
  cubic member in each fully enumerated six-bit CCZ class; explicit twist
  identities are Out-of-scope unless constructed and checked separately.
- **VBF APIs likely needed:** `ea_class_orbits`, `enumerate_ccz_class`,
  `algebraic_degree`, `tu_decomposition_from_space_basis`, `apply_tu`, `twist`.
- **Estimated cost:** Fast after representatives are constructed.
- **Proposed Julia file:** `section32.jl` (degree distributions).
- **Proposed Makefile target:** `section32`.

### 7. Exact representation pipeline

- **ID:** `section31-exact-representation`.
- **Type:** Algorithm.
- **Section + number:** Section 3.1, paper pages 4–5; supported by Section 2.2.2,
  Definition 2 and Lemma 1 on ortho-derivatives.
- **Statement:** Compute all graph automorphisms, enumerate all `n`-dimensional
  Walsh-zero subspaces, keep one per group orbit, and turn them into exactly
  one representative of each EA class in the CCZ class.
- **Reproducibility:** Exact on completed runs; Bounded when group discovery
  is stopped. Supplying a complete native generator set substitutes for the
  paper's full ortho-derivative automorphism list and gives identical orbits;
  it does not reproduce that list-generation algorithm instruction by instruction.
- **VBF APIs likely needed:** `ortho_derivative`,
  `automorphisms_from_ortho_derivative`, `partition_refinement_automorphisms`,
  `ea_class_orbits`, `walsh_zeroes`, `extract_linear_subspaces`,
  `enumerate_ccz_class`, `ccz_equivalent_function`, `FunctionGraph`.
- **Estimated cost:** Medium to Slow for complete six-bit cases.
- **Proposed Julia file:** `section31.jl`.
- **Proposed Makefile target:** `section31`.

The native-generator integration must expose group completeness, validate
supplied generators, and preserve the existing ortho-derivative route as a
cross-check. Avoid materializing every group element merely to obtain orbits.
Representative maps must be saved alongside their lookup tables when requested,
and graph images must verify against the originals.

### 8. Six-bit census

- **ID:** `section32-six-bit-census`.
- **Type:** Experiment.
- **Section + number:** Section 3.2, six-bit case, paper page 5.
- **Statement:** Thirteen quadratic CCZ classes contribute 691 EA classes;
  the remaining known nonquadratic CCZ class contributes 25, yielding 716
  classes with degree counts `{2:13, 3:521, 4:182}`, and the cube's CCZ class
  contributes exactly three.
- **Reproducibility:** Exact when all fourteen complete group/subspace runs
  finish; Bounded when fewer representatives are processed or groups stop.
  This is a census of the known classes, not a proof that no other APN function
  exists. The paper's aggregate is compatible with Calderini 2020's thirteen
  quadratic row counts `3,3,19,13,13,91,19,85,91,91,86,92,85`.
- **VBF APIs likely needed:** `ea_class_orbits`,
  `partition_refinement_automorphisms`, `enumerate_ccz_class`,
  `algebraic_degree`, `differential_uniformity`, `gold_apn`, `kim_apn`.
  Dataset loading uses existing VBFCatalog `load_catalog`, `list_functions`,
  `find_function` and `load_sbox` only in `catalog_validation.jl`.
- **Estimated cost:** Slow for the complete census; a bounded smoke test is Fast.
- **Proposed Julia file:** `section32.jl`, with dataset access isolated in
  `catalog_validation.jl`.
- **Proposed Makefile target:** `section32`.

For each row report subspace count, generator count, graph/group order,
completeness, stop reason, orbit count, representative degrees and validated
certificate count. A full census succeeds only if every row is complete and
the independently accumulated totals match. Do not import or include another
paper's scripts merely to borrow its constants.

The current catalog's `list_functions(db; n=6, is_apn=true, family="APN-rep")`
returns thirteen representatives including the nonquadratic `reprs6_13`.
Add `kim_apn()` (whose catalog record was merged into another family) to obtain
the fourteen inputs; the degree-two filter must then return thirteen. There is
no existing `load_apn_representative` API to call.

### 9. Switching exploration

- **ID:** `section32-switching-exploration`.
- **Type:** Experiment.
- **Section + number:** Section 3.2, six-bit switching discussion and footnote 2,
  paper page 5.
- **Statement:** Explore switching neighbours and CCZ closures starting from
  the cube and Kim mapping; the authors recovered the known six-bit classes
  and found no new function in their explicitly partial exploration.
- **Reproducibility:** Bounded. Run with explicit frontier, candidate and
  equivalence-search limits and report which stages completed. A candidate
  whose comparison hits a budget is undecided, never a new class.
- **VBF APIs likely needed:** `switching_neighbors`, `gold_apn`, `kim_apn`,
  `differential_uniformity`, `partition_refinement_equivalence`,
  `ccz_equivalence_certificate`, `ccz_equivalent_function`, `Found`,
  `Exhausted`, `BudgetHit`, `search_solutions`, `proves_emptiness`.
- **Estimated cost:** Medium to Slow; unconstrained closure may be much larger.
- **Proposed Julia file:** `conjecture1.jl`, including the switching discussion
  immediately preceding the named conjecture.
- **Proposed Makefile target:** `switching`.

Use the existing deterministic switching constructor rather than duplicate
Edel–Pott mathematics. Its observer currently permits counting candidate,
final-test and verified-APN events; the public constructor has no bound kwargs
in the pre-integration API. Enforcing a true constructor work limit may require
a reusable core extension, rather than truncating a completed output vector.
Record root seed, source/target lookup tables, APN check and independently
verified mapping for every saved equivalence witness. `save_results=false`
must leave no generated artifacts. A complete switching batch from one seed
does not establish complete reachability of all APN functions.

### 10. Exhaustiveness conjecture

- **ID:** `conjecture1-six-bit-exhaustiveness`.
- **Type:** Conjecture.
- **Section + number:** Section 3.2, Conjecture 1, paper page 5.
- **Statement:** Every six-bit APN function lies in one of the 716 known EA
  classes, grouped into fourteen CCZ classes, and has degree below five.
- **Reproducibility:** Out-of-scope. Matching the known census and finding no
  new bounded switching neighbours supplies evidence, not a proof.
- **VBF APIs likely needed:** None sufficient to prove this universal claim.
- **Estimated cost:** No feasible exhaustive computation established.
- **Proposed Julia file:** None; state the limitation in `README.md` and the
  switching report.
- **Proposed Makefile target:** None; the `switching` output must retain this
  limitation.

### 11. Seven-bit census

- **ID:** `section32-seven-bit-census`.
- **Type:** Experiment.
- **Section + number:** Section 3.2, seven-bit case, paper page 5.
- **Statement:** The CCZ closure of 488 quadratic EA representatives contains
  82,409 EA classes with degree counts `{2:488, 3:60302, 4:21619}`; the cube
  has three EA classes, including its degree-four inverse and a cubic one-twist.
- **Reproducibility:** Completed for all 488 pinned roots, with exact per-root
  native group/subspace closures and stored witnesses. The global aggregate
  inherits the source collection's pairwise CCZ distinctness.
- **VBF APIs likely needed:** `gold_apn`, `ea_class_orbits`,
  `partition_refinement_automorphisms`, `enumerate_ccz_class`,
  `algebraic_degree`, `is_permutation`; corpus APIs, if used, remain isolated
  in `catalog_validation.jl`.
- **Estimated cost:** Full 488-root run completed in 384.13 seconds on 16 workers.
- **Julia file:** `section32_sevenbit.jl`, plus its standalone evidence audit.
- **Makefile target:** Explicit `census7`; the default does not launch the full run.

## Routines checklist

No author routines checklist was supplied. The synthesized checklist is:

1. Extend `ea_class_orbits` to consume verified native affine generators,
   preserving subgroup/completeness semantics and the ortho-derivative route
   (`proposition2-subspace-orbits`, `section31-exact-representation`).
2. Check all generator graph images and, for quadratic APN `n ≥ 4`, EA block
   form (`theorem1-ea-similarity`, `proposition3-quadratic-automorphisms`).
3. Compute Walsh-zero subspaces and exactly one valid function/certificate per
   selected orbit (`proposition1-walsh-admissibility`,
   `section31-exact-representation`).
4. Use the `ea_class_representatives` core routine to construct
   representatives and corresponding graph certificates directly from the
   chosen orbit bases. The older `enumerate_ccz_class` can skip inadmissible
   maps and returns functions without certificates, so its output must not be
   blindly indexed by orbit-basis index.
5. Cross-check small/full six-bit native orbit partitions against the existing
   ortho-derivative route; compare partitions independently of union-find root
   and orbit ordering (`proposition2-subspace-orbits`).
6. Isolate catalog loading; enumerate all fourteen known six-bit CCZ classes,
   accumulate class counts and degree histograms, check 691+25=716
   (`section32-six-bit-census`, `corollary1-degree-structure`).
7. Bound switching work and exact comparisons; distinguish witnessed matches,
   proved inequivalence within completed comparisons and undecided candidates
   (`section32-switching-exploration`).
8. Optionally save reproducible, independently verified witnesses under
   `results/`; report limits/completeness and preserve conjecture status
   (`section32-switching-exploration`, `conjecture1-six-bit-exhaustiveness`).
9. Keep report/test defaults small; make the full six-bit census explicit and
   the full seven-bit run an explicit, resumable target
   (`section32-six-bit-census`, `section32-seven-bit-census`).

## Open questions

None of these prevents the authorized bounded integration:

- The paper's promised tinySQL database has no download/revision identifier in
  the supplied text. Reconstruct and verify the six-bit known-class census
  from existing catalog/classification inputs instead of asserting identical
  author lookup-table choices.
- No exact switching frontier, candidate order, stopping threshold or number
  of explored candidates is supplied. Record our deterministic order and
  limits; do not claim identical coverage to the authors' partial exploration.
- Full-group orbit equality requires complete native discovery. An interrupted
  valid subgroup is useful but can split genuine EA orbits. Mark its count as
  an upper bound only when all Walsh-zero subspaces were enumerated; truncated
  subspace lists do not provide the same bound.
- `nauts` in the existing API means the number of listed linear automorphisms;
  a generator count is different from a group order. Preserve compatibility
  and report both concepts explicitly after native integration.
- The paper's introductory block-rank sentence names `A` and `B` even though
  invertibility of the displayed block-triangular EA map requires `A` and `C`.
  Apply the mathematical invertibility condition, not that apparent typo.
- Proposition 2's printed action is a transpose; the existing VBF code uses
  inverse transpose. Their full-group orbits coincide, but validate the exact
  convention for certificate provenance rather than rename one as the other.
- The generic pipeline also applies to the nonquadratic six-bit class using
  the native complete CCZ automorphism group. The ortho-derivative completeness
  argument applies only to the thirteen quadratic rows.
- Credit the Section 3.1 orbit-classification approach to Baudrin, Galissant
  and Perrin, the Walsh/admissibility framework to Canteaut and Perrin, and
  native graph automorphism discovery separately to Kaleyski and Sunde
  (ePrint 2026/940). Native discovery is an alternative first stage, not a
  line-by-line reproduction of sboxU's ortho-derivative first stage.


## Executed coverage, 9 October 2026

The fourteen-root six-bit census, all 716-parent one-coordinate switching
closure, and all 488-root seven-bit EA census completed. See README.md and
TEST_REPORT.md for measured times, independent artifact audits and exact
counts. Seven-bit root distinctness remains inherited from the pinned input
collection, and exhaustive known-set switching closure does not prove the
universal exhaustiveness conjecture. The optimized subspace/group profiles
and parallel drivers are documented implementation extensions with separate
commits; the reference paths remain available.
