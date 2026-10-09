# Exploring the Set of APN Functions

Jules Baudrin, Pierre Galissant and Léo Perrin, BFA 2025,
[HAL hal-05376704v2](https://hal.science/hal-05376704v2), submitted 21 November 2025.
The supplied PDF is the ground truth; no public TeX source was identified.

This reproduction implements the Section 3.1 Walsh-zero subspace orbit workflow
using VBF's native automorphism generators, checks the Section 3.2 six-bit
known-class census, provides a resumable seven-bit census, and checks six-bit
switching closure relevant to
Conjecture 1. It requires Julia ≥1.12 and runs in the repository's root project.
No Python, sboxU or Magma runtime is required.

## Algorithm and attribution

The EA-class/automorphism-orbit correspondence and practical classification
workflow are due to Baudrin, Galissant and Perrin (Proposition 2 and Section
3.1). The Walsh-zero admissibility framework comes from Anne Canteaut and Léo
Perrin, *On CCZ-equivalence, extended-affine equivalence, and function twisting*
(2019). The switching construction is Edel–Pott's, implemented by VBF's existing
complete-system switching routines.

The paper's first stage enumerates automorphisms through ortho-derivatives. We
retain that backend for comparison. The alternative first stage uses Nikolay
Kaleyski and Joakim Sunde's *Efficiently deciding and recovering CCZ and EA
equivalence for arbitrary vectorial Boolean functions using the partition
refinement framework*, [ePrint 2026/940](https://eprint.iacr.org/2026/940), using
the native Julia implementation in VBF. Group generators suffice to compute
the same full-group orbits; this substitution is explicitly an integration
and method extension, not a literal reimplementation of the paper's
ortho-derivative search. The default algorithm profile is `:paper`.

The authors state that their code is available in sboxU. Its current source
already supplies quadratic APN automorphism generators and Walsh-zero orbit
classification; using generators is not a new algorithm claimed here. The
inspected current reference is
[sboxU revision bedb6d1a796c3c582572393a91270b6fd15dc9e1](https://github.com/lpp-crypto/sboxU/tree/bedb6d1a796c3c582572393a91270b6fd15dc9e1).
That revision is not asserted to be the paper's original 2025 implementation.
The old `ccz.py` URL in the paper has been superseded by a refactored source tree.
No author code is vendored or used as a package dependency.

## Files and claims

| File | Paper claim | Execution scope |
|---|---|---|
| `section31.jl` | Proposition 2 / Section 3.1 exact CCZ-class representation | Exact when group, subspaces and representative construction complete |
| `section32.jl` | Section 3.2 known six-bit census | Full fourteen-root run is explicit; defaults are small demonstrations |
| `conjecture1.jl` | Section 3.2 switching exploration preceding Conjecture 1 | Bounded evidence, with undecided comparisons retained |
| `section32_switching.jl` | Section 3.2 / Gillot–Langevin Section 6, Fact 3 | Resumable complete switching over all 716 certified six-bit representatives |
| `section32_sevenbit.jl` | Section 3.2 seven-bit census | Resumable 488-root closures, using explicitly selected optimized algorithms |
| `catalog_validation.jl` | Known input collections | Thirteen six-bit APN-rep records plus Kim; pinned 488 seven-bit quadratic roots |
| `report.jl` | Aggregate demonstration | Four-bit smoke examples; does not launch the six-bit census |

`EXPERIMENTS.md` records the broader mathematical inventory. Finite checks do
not prove its universal theorems. Conjecture 1 is not proved by a switching
closure computation: a further APN class might lie outside this closed set.

## Running

```sh
make -C papers/2025/Baudrin_202509 test
make -C papers/2025/Baudrin_202509 report
make -C papers/2025/Baudrin_202509 section31
make -C papers/2025/Baudrin_202509 switching max_neighbors=2
```

The full known-class six-bit census is expensive and is an explicit opt-in:

```sh
make -C papers/2025/Baudrin_202509 census6 save_results=true
make -C papers/2025/Baudrin_202509 closure6 save_results=true
make -C papers/2025/Baudrin_202509 census7 save_results=true
```

Both checkpointed drivers support independent parent/root tasks. For example,
`make -C papers/2025/Baudrin_202509 census7 threads=16 workers=16 save_results=true`
uses 16 default-pool Julia threads. Each task has its own search state and RNG;
checkpoints are disjoint and summary reduction follows dataset order. Limits
apply per search/root, so aggregate memory can grow with the worker count.
The overall time limit remains shared. Serial execution remains the default.

The expected complete results are 691 EA classes in thirteen quadratic CCZ
classes, plus 25 in the remaining nonquadratic class: 716 in total, with degree
counts `{2:13, 3:521, 4:182}`. The cube's CCZ class has three EA classes.
Each completed quadratic native orbit partition is compared against the
ortho-derivative backend. Distinct input CCZ classes are independently checked:
quadratic ortho-derivative invariant mismatch is valid because CCZ=EA for
quadratic APN functions in dimension ≥4; other pairs use a CCZ invariant or
an exhausted native equivalence decision. An undecided root pair prevents
an exact global census claim. Completed APN closures in dimension ≥2 also check
Theorem 2's orbit-count bounds using the exact group order; the full Burnside
fixed-subspace sum is not computed.

`closure6` loads the complete saved six-bit census, validates all 716 positive
graph certificates, exhausts each representative's 63 output quotient
directions and checks every nonzero quotient combination against the fourteen
roots. This is the one-coordinate closure assertion of Gillot and Langevin,
*Observation of known APNs*, [arXiv:2601.11247v1](https://arxiv.org/abs/2601.11247v1).
Their Section 6 table counts quotient basis vectors; we record both that count
and the larger number of all nonzero combinations. Classification uses positive
CCZ graph certificates, which suffice because the input census contains the
complete EA closures of those fourteen roots. Per-candidate EA searches are
unnecessary for this closure assertion.

`census7` selects all 488 quadratic roots with the pinned `sboxu@7066b82`
source tag, including three Gold records merged into the catalog's APN family.
The expected degree counts are `{2:488, 3:60302, 4:21619}`, totaling 82,409.
Each root's independently computed closure has a strict completion flag; root
distinctness is inherited from the pinned collection and labelled as such.
The driver explicitly uses the existing native `algorithm=:optimized` group
profile and `subspace_algorithm=:optimized`. These choices preserve the orbit
correspondence; the core's paper/reference defaults remain available. The
subspace optimization is recorded in a separate commit, with exhaustive parity
and Gaussian-count tests. Arbitrary admissible complements avoid spending time
searching for permutation representatives; degree and EA counts are unchanged.

A bounded six-bit switching example starts from the cube and Kim roots and
compares against the fourteen known CCZ representatives:

```sh
make -C papers/2025/Baudrin_202509 switching dimension=6 sample_size=2 \
  max_nodes='typemax(Int)' timeout_seconds=120 limit=2 \
  max_neighbors=5 max_comparisons=100 save_results=true
```

The controls have distinct meanings:

- `limit`: processed census inputs or switching-parent expansions.
- `sample_size`: selected census inputs or initial switching roots.
- `max_nodes`: native discovery, subspace and search budget; the census uses a
  per-root budget, while switching shares this counter across its closure and
  equivalence calls. Six-bit subspace extraction can examine nearly a billion
  rejected candidates, so `census6` explicitly uses `typemax(Int)`.
- `max_evaluations`: total switching candidate evaluations; it does not limit
  the constructor's necessary-constraint assembly, which has time checks.
- `timeout_seconds`: overall wall-clock budget for one experiment call.
- `max_subspaces`: cap on each closure's subspace enumeration.
- `max_comparisons`: total switching EA/CCZ decisions.
- `max_frontier`: total distinct scheduled parent lookup tables.
- `max_neighbors`: returned-neighbour cap per switching-parent call.
- `max_memory_bytes`: core estimated-allocation bound, not measured peak RSS.
- `seed`: reproducible search keys; default 940.

The legacy ortho-derivative enumeration cannot be interrupted inside its own
call. Its elapsed time is charged to the experiment, and subsequent work uses
the remaining budget. Native discovery, native subspace/orbit work and legacy
subspace/orbit checks share the per-root node budget; the legacy automorphism
enumeration itself has no node counter. One APN test or linear algebra primitive also cannot be
interrupted midway.

## Evidence and limits

Every emitted graph map is independently checked point by point against its
recorded source and target lookup tables. Switching neighbours are explicitly
checked APN. An equivalence budget hit remains undecided; it never becomes
inequivalence or a novelty claim. A candidate reported inequivalent to current
reference seeds has exhausted all those comparisons and is described relative
to the recorded collection, not as a global classification theorem.

The frontier expands EA representatives from a cached CCZ closure only once
per seed. Matching candidates receive a CCZ certificate and an EA comparison
against that closure's representatives. Partial closures may require additional
parents; unresolved EA comparisons are retained. Finite frontier exhaustion
and complete exploration of that finite starting region do not prove that
all APN functions are reachable by switching.

With `save_results=true`, portable TOML snapshots are written under `results/`.
They contain parameters, dataset lookup tables and hashes, frontier/parent
indices, outcomes, verified switching supports, and graph-map columns/constants.
Snapshots also record elapsed compute time and each group/subspace/action
completion stage, including individual cached switching closures. SHA-256
hashes of all VBF Julia source files and the paper's runtime Julia scripts are
captured once when the helpers load, using repository-relative paths. The
source PDF's hash is captured at the same time; an absent PDF is explicitly
marked unavailable. This provenance capture does not require Git at runtime.
The older `conjecture1` snapshots are diagnostic snapshots. The `closure6` and
`census7` drivers additionally save a separate checkpoint for each completed
parent or root and resume those completed rows; interrupted rows are recomputed.
Changing recorded source code or algorithm profiles requires a new result name.
Generated output
and source PDFs are ignored; this README is tracked.

The bounded test suite passed **132 assertions** across four test sets under
Julia 1.13.1. The fast report completed with two four-bit Gold EA classes,
complete native/legacy orbit agreement, and a bounded switching run that
evaluated fifteen candidates, made 34 equivalence decisions and retained 32
independently verified graph witnesses. Its parent-expansion limit left the
frontier incomplete, as reported.

The full six-bit census completed on 9 October 2026 with seed 940 and all
fourteen recorded roots. All thirteen quadratic native orbit partitions agree
with the ortho-derivative backend. The resulting **716 EA classes** have exactly
the paper's degree distribution: **13 quadratic, 521 cubic and 182 quartic**.

| CCZ root | Walsh subspaces | EA classes | Degree 2 | Degree 3 | Degree 4 |
|---|---:|---:|---:|---:|---:|
| reprs6_0 | 190 | 3 | 1 | 1 | 1 |
| reprs6_1 | 190 | 3 | 1 | 1 | 1 |
| reprs6_2 | 94 | 19 | 1 | 15 | 3 |
| reprs6_3 | 106 | 13 | 1 | 9 | 3 |
| reprs6_5 | 118 | 91 | 1 | 66 | 24 |
| reprs6_6 | 94 | 19 | 1 | 15 | 3 |
| reprs6_7 | 106 | 85 | 1 | 66 | 18 |
| reprs6_8 | 118 | 91 | 1 | 63 | 27 |
| reprs6_9 | 118 | 91 | 1 | 66 | 24 |
| reprs6_10 | 114 | 86 | 1 | 69 | 16 |
| reprs6_11 | 126 | 92 | 1 | 69 | 22 |
| reprs6_12 | 106 | 85 | 1 | 66 | 18 |
| reprs6_13 | 25 | 25 | 0 | 10 | 15 |
| Kim | 222 | 13 | 1 | 5 | 7 |
| **Total** | | **716** | **13** | **521** | **182** |

Every saved affine matrix is independently checked using integer XOR and
binary elimination; direct DDT and Möbius computations verify APN and degree
for all 716 outputs. All 91 pairs of census roots are distinguished: 78 by
quadratic ortho-derivative invariants, one by its absolute Walsh spectrum, and
twelve by exhausted native CCZ searches. The first 79 invariant mismatches are
also checked by independent integer computations. The twelve negative searches
rely on the tested native solver; their outcome records are not independently
checkable negative certificates.

The full census snapshot is `results/section32.toml`. That run started before
the v2 metadata additions, so its v1 evidence is accompanied by the explicitly
supplemental `results/section32_run_provenance.toml`, containing the original
source/PDF hashes and the saved artifact hash. Subsequent runs capture this
provenance and stage completeness directly in v2 snapshots.

Two bounded six-bit switching runs also completed. The cube/Kim initialization
with two cube-parent expansions produced four APN neighbours, fourteen
equivalence decisions and 27 graph witnesses. A separate Kim-parent expansion
produced two neighbours in the known CCZ classes `reprs6_8` and `reprs6_11`,
79 decisions and 200 witnesses, including the newly traversed classes' EA
closures. Both runs retain an incomplete frontier and found no new CCZ class
or undecided comparison in their samples. Their snapshots are
`results/conjecture1_sixbit.toml` and `results/conjecture1_kim.toml`.

The VBF regression suite passed **138,326 assertions in 97 test items**,
excluding the two previously known failing items `linear_backtracking` and
`extensions`. The documentation build and doctests passed. The independent
review and evidence checks are recorded in `REVIEW.md` and `TEST_REPORT.md`.
No timing advantage over sboxU is claimed here.
