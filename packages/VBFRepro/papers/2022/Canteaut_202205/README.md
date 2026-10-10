# Canteaut_202205 — Recovering or Testing Extended-Affine Equivalence

**Paper**: Canteaut, Couvreur, Perrin. "Recovering or Testing Extended-Affine Equivalence."
2022.

**Reproduction path**: `packages/VBFRepro/papers/2022/Canteaut_202205/`

**Verdict**: Mostly complete

The strongest reproduction in the 2021-2022 batch: the file-per-claim layout mirrors the
paper's numbering exactly, and every Table 7 value recomputed independently matches. Three
gaps remain. Section 4.5 is declared out of scope on a **factually incorrect premise** — the
corpus *is* in the repository and sums to the paper's exact 21,102. One concrete Section 4.3
claim (Σ⁴-multiplicities) is mentioned in a comment but never computed. And the `m ≠ n` half
of Propositions 14/16/18/22/25 and Table 2 is structurally unreachable, blocked on a core
type limitation rather than a paper-local bug.

> Every numeric claim below was re-derived independently in Python by an earlier review and
> has since been re-confirmed against the repository's own Julia API (Julia 1.12.6,
> 2026-08-15). All agree; two corrections to this file's own inferences are noted inline.

> **Supersedes a previous revision.** An earlier version of this file carried a log of seven
> "RESOLVED" reproduction issues. Two of those resolutions are demonstrably wrong and are
> reopened below: the Section 4.5 out-of-scope declaration (issue 1) and the "15 quadratic
> n=6 catalog entries" count (issue 4, actual: 19).

---

## Paper Issues

### 1. The open-butterfly formula printed in Section 4.3 is not an involution

- **Location**: below Remark 41.
- **Computed counter-evidence**: the paper writes
  `H_{α,β}(x,y) = (T_y⁻¹(x), T_{T_y⁻¹(x)}(y))` and calls these "the involutions defined
  as…". Over all 64 inputs with `α = 2` and `β ∈ {1, α³+1/α}` in `F₈` (`x³+x+1`), the
  printed ordering is a **degree-4 APN permutation but `H∘H ≠ id`**. Swapping the two
  components — `H(x,y) = (T_{T_y⁻¹(x)}(y), T_y⁻¹(x))`, the CDP17 open-butterfly convention —
  **is** an involution, verified for both `β`.
- **Note**: `section4_3.jl:65-67` already documents this; the computation confirms it
  independently.

### 2. The proof of Proposition 25 has a typo in Eq. (9)

- **Location**: proof of Proposition 25.
- **Evidence**: the displayed equivalent system reads
  `X′·Jac_lin G(v)·U − V·Jac_lin F(**v**)·Y′ = 0`; it must be `Jac_lin F(**w**)`, per the
  hypothesis `rank Jac_lin G(v) = rank Jac_lin F(w)` and Eq. (8).

### 3. Table 8, rows 12 and 15 are internally inconsistent

- **Location**: Table 8.
- **Computed counter-evidence**: the row-12 entry `{0:15600, 16:46520, 32:5440}` is not among
  the six extended Walsh spectra listed two paragraphs earlier in Section 4.5, and its
  entries sum to 67,560 ≠ 65,280 = 255·256. Row 15 (`{0:15600, 16:43520, 32:5440}`, sum
  64,560) is likewise not one of the six and does not sum correctly. A full corpus scan finds
  **only** the six listed spectra across all 21,102 functions, so both table cells are typos.

  Both cells are typos for **𝒲₀ = `{0:16320, 16:43520, 32:5440}`**. For row 12 this is forced:
  the paper states the 22 functions with thickness spectrum `{0:1, 1:255}` include the cube
  mapping, and `ews(gold_apn(8))` computed in this repository is exactly
  `[0=>16320, 16=>43520, 32=>5440]`. For row 15 it is forced by the paper's own narrative —
  rows 15/16 are the announced "identical thickness spectra but different Walsh spectra"
  example, row 16 is 𝒲₁, so row 15 must be a different spectrum; `15600 → 16320` is the
  single-token correction that both restores the 65,280 sum and lands on one of the six.
  (An earlier revision of this file guessed 𝒲₁ for row 12; that inference was wrong.)

---

## Reproduction Issues

### 1. Section 4.5 is declared out of scope on a false premise — the corpus is in the repository and matches the paper's count exactly

- **Location**: `report.jl:44-45`
  (`"Section 4.5 (21,102 8-bit functions) — SKIPPED (corpus not in repo; ≈ hours of ortho-derivative bucketing)"`)
  and the previous revision of this README, which marked the issue `[RESOLVED — out-of-scope]`
  on the grounds that "the 21,102-function eight-bit APN corpus is not available in the repo".
- **Symptom**: `SELECT name, member_count FROM bulk_corpora` on the tracked
  `packages/VBFCatalog/BFA_catalog.sqlite` returns `yuwangli2014_qam_n8 = 8179` and
  `beierleleander2022_n8 = 12923`. **8179 + 12923 = 21102**, the paper's number to the unit.
  Both side stores are tracked (`corpora/*.sqlite`, modulus 285, `quadratic-coeffs-v1`).
- **Root cause**: the availability of the bulk corpora was not checked when the scope note
  was written.
- **Counter-evidence**: scanning both corpora end-to-end in **pure Python took 45 s total**
  and yields **exactly six** distinct extended Walsh spectra — precisely the six literals at
  `.tex` lines 1250-1256 — with combined multiplicities **𝒲₀ 17007, 𝒲₁ 3599, 𝒲₂ 320,
  𝒲₃ 146, 𝒲₄ 26, 𝒲₅ 4** (total 21,102). That is the paper's headline Section 4.5 Walsh
  claim, reproduced at negligible cost.
- **Resolution plan**:
  1. Add `section4_5.jl` loading both corpora via `VBFCatalog.list_corpora` /
     `corpus_coefficients` plus `VBF.decode_quadratic_lut`.
  2. Assert the combined member count is 21,102, and that the distinct
     extended-Walsh-spectrum set has cardinality 6 and equals the paper's six.
  3. Add the ortho-derivative bucketing (`apn_ea_mugshot`) behind `full_search` / `limit`,
     asserting 21,102 distinct buckets — the paper's "all of these functions can be put into
     distinct buckets in a few minutes".
  4. Put the 255-thickness-spectra, 486-bucket, Table 8 and Figure 2 claims behind
     `full_search` with an honest cost note; those genuinely need `extract_linear_subspaces`
     on 16-bit Walsh-zero sets.
  5. Correct `report.jl:44-45`.

### 2. The Section 4.3 Σ⁴-multiplicities claim is mentioned but never computed

- **Location**: `section4_3.jl:319` — a comment says "they share thickness spectrum and
  Σ⁴-multiplicities, as the paper notes", with no corresponding computation.
  `section4_3.jl` returns no Σ⁴ field, and `test_section4_3.jl` has no Σ⁴ assertion.
- **Symptom**: the paper's Section 4.3 sentence "These two EA-classes also share the same
  Σ⁴-multiplicities, meaning that the same observation applies to this invariant" is a
  concrete, cheap, checkable claim that is taken on faith.
- **Root cause**: treated as narrative rather than as a claim.
- **Counter-evidence (positive)**: Σ⁴-multiplicities (Definition 32, over ordered 4-tuples
  summing to 0) were computed for both butterflies: `H_{α,1}` gives
  `{3840 ↦ 56, 4992 ↦ 7, 12160 ↦ 1}`, and `H_{α,β}` gives the **identical** multiset. The
  paper is right; the reproduction simply does not check it.
- **Resolution plan**:
  1. `VBF` exports `sigma_multiplicities` — call it on `H1` and `H2` in `section4_3.jl`.
  2. Add `ok_sigma4 = sigma_multiplicities(H1, 4) == sigma_multiplicities(H2, 4)` with a
     `print_check` labelled "both permutation EA-classes share Σ⁴-multiplicities (§4.3)".
  3. Surface it in the returned `NamedTuple` and assert it in `test_section4_3.jl`.
  4. Also add Definition 32 to `section4_4.jl` as a Table 5 invariant over the 13 Banff
     functions, since Section 4.4 explicitly compares the non-ortho-derivative invariants'
     distinguishing power.

### 3. The `m ≠ n` cases of Propositions 14/16/18/22/25 and Table 2 are unreachable

- **Location**: `helpers.jl:28` `jac_lin_cols(F::SBox{N,T}, a)` and every downstream
  function are square-only; `proposition25.jl:92` sets `m = n = N`.
- **Symptom**: `test_proposition25.jl` loops `for N in (6, 8)` only. Table 2 rows 3, 4, 8, 9,
  12 and 13 are `(m,n) = (6,8)` and `(8,6)`; those six rows are not reproduced. The previous
  README's claim that `proposition25_report` is "parameterized … over `n_values` … the paper
  reports tests for `m, n ∈ {6, 8}`" overstates the coverage: only the two square cases are
  exercised.
- **Root cause**: `SBox{N,T}` at `packages/VBF/src/representations/sbox.jl:37-58` enforces
  that every LUT entry fits in `N` bits, i.e. `m = n` by construction. This is a **core**
  limitation, not a paper-local bug.
- **Resolution plan**:
  1. Reword `proposition25.jl:81` and this README to say "square case only; the rectangular
     Table 2 rows require an `(n,m)` function type that `VBF.SBox` does not model".
  2. File a promote-to-core request for an `SBox{N,M,T}` (or a `VBFunction{n,m}`) type.
  3. Once available, add the **six** rectangular Table 2 rows (3, 4, 8, 9, 12, 13).

### 4. The catalog-snapshot count in the docs is stale

- **Location**: `section4_4.jl:18` ("The catalog's quadratic 6-bit APN functions (≥ 15; the
  paper worked with 15 …)"), `test/test_section4_4.jl:24` (`@test length(quad_fns) >= 15`),
  and the previous revision of this README.
- **Symptom**:
  `SELECT count(*) FROM functions WHERE n=6 AND is_apn=1 AND is_quadratic=1` on the tracked
  database returns **19** (`n6_Gold_x3`, `n6_Kasami_x48`, `n6_Kim`, `reprs6_0..12` minus
  `reprs6_4`, `n6_Gold_i5`, `n6_BCP_k2_s1`, `n6_BCP_k2_s5`, `n6_Taniguchi_m1_a1_b2`). The
  `>= 15` test still passes; only the prose is wrong.
- **Root cause**: the documentation was written against an older catalog build.
- **Resolution plan**:
  1. Update the prose to "19 quadratic 6-bit APN entries partitioning into 13 EA mugshot
     buckets".
  2. Keep the `>= 15` inequality and the exact `== 13` class assertion, which are the
     invariants that matter.

### 5. Lemma 20 (rank-table complexity) has no counterpart

- **Location**: no file.
- **Symptom**: `report.jl`'s scope list never mentions Lemma 20, and nothing times
  `rank_table`.
- **Root cause**: treated as asymptotic-only.
- **Resolution plan**: optional — add a scaling check in `proposition22.jl` timing
  `rank_table` at n = 6, 8, 10 and asserting near-linear growth in `2ⁿ`; or explicitly list
  Lemma 20 as "asymptotic, not empirically reproduced" in the report docstring.

### 6. Proposition 38 is not directly exercised

- **Location**: `section4_3.jl:152` uses `is_ccz_equivalent_to_permutation(κ)` — Proposition
  39's criterion — but nothing tests Proposition 38 ("𝒜 admissible ⟺ 𝒜ᵀ(𝒱) ⊆ Z_F").
- **Symptom**: no assertion anywhere references admissibility.
- **Root cause**: Proposition 38 is used implicitly inside `ccz_equivalent_function`.
- **Resolution plan**: add a short check in `section4_3.jl` — for a sample of the 222 spaces,
  build `L` and assert `ccz_equivalent_function(κ, F2AffineMap(L,0)) !== nothing`, and
  conversely that a random non-Walsh-zero subspace yields `nothing`.

---

## Items Reproduced Exactly

| Paper item | File | Independent check |
|------------|------|-------------------|
| Definition 12, Propositions 13, 14, Corollary 15 | `helpers.jl:19-88`, `proposition14.jl` | the column formula `F(a⊕eⱼ)⊕F(a)⊕F(eⱼ)⊕F(0)` is exactly Eq. (3); the symmetric identity `Jac_lin F(a)·x = Jac_lin F(x)·a` is checked both ways |
| Proposition 16 (Eq. 4) | `section3_2.jl` | correct column-wise form `A₀(Jac_lin F(B₀x)·B₀eⱼ)` |
| Definition 17, Proposition 18 (QAM ↔ Jac_lin) | `proposition18.jl` | `H = MᵀC_P M` with Moore matrix `M_{i,j} = α_j^{2^{i-1}}`, cross-checked against `quadratic_apn_matrix`; QAM ⟺ APN via `is_qam` |
| Definition 19, Proposition 22, Remark 23 | `proposition22.jl` | `ℛ_dist[r]·2^r = 𝒟_dist[2^{n−r}]` checked at **every** `r`, including absent ranks; Remark 23 asserted |
| Corollary 24 | `corollary24.jl` | both directions, with a genuine multi-rank non-APN witness |
| Proposition 25 + Table 2 (s = 1, 2, 3) | `proposition25.jl` | the bounds `r(m+n−r)` and `r(m+n−r)+(n−r)` plus the sharpness observation; `n = m ∈ {6, 8}` |
| Algorithm 1 (Section 3.4.5) + Section 3.4.4 | `algorithm1.jl` | rank-distribution gate, rarest-rank reference vectors with the Remark 28 spill, Remark 27 linear independence, `T = 10`, `C₀`/`a` recovery, exhaustive negative at n = 5 and 7 |
| Definition 33, Lemma 34, Propositions 35, 36 | `proposition35_36.jl` | `π_F` as the unique nonzero left-kernel vector with the rank-`(n−1)` uniqueness argument; `π_G = (A₀ᵀ)⁻¹∘π_F∘B₀` |
| Section 4.3 Kim CCZ-class | `section4_3.jl` | 222 spaces, thickness spectrum `{0:1,1:63,2:126,3:32}`, 8 spectra, 32 thickness-3 spaces bipartitioned 16+16, 256 cross-pair permutations plus inverses → 4 affine classes → 2 EA classes, inversion structure, Dillon permutation membership |
| Section 4.3 butterflies | `section4_3.jl:70-85` | `H_{α,1}` and `H_{α,β}` (`β = α³+1/α`, `α = 2`, `Tr α = 0`) confirmed **APN involutions of degree 4** under the repository's component ordering |
| Section 4.4, Table 6 | `helpers.jl:323-352` | all 13 Banff polynomials parse to **quadratic APN**; **#5's LUT == `kim_apn()`** |
| Section 4.4, Table 7 | `section4_4.jl:41-67` | recomputed independently: the **linearity vector `[16,16,16,16,16,16,32,16,16,16,16,16,16]` matches exactly**; **all 13 `π_F` differential spectra match the paper's Table 7 literals exactly**; the 13 are pairwise distinct, so functions 9 and 10 are separated as the paper claims |

## Test Results

Command: `make -C packages/VBFRepro/papers/2022/Canteaut_202205 test`
Julia 1.12.6 · reviewed 2026-08-15 · **exit code 0** · **737 s wall (12 min 17 s)**

| Testset | Pass | Broken | Fail | Total | Time |
|---------|-----:|-------:|-----:|------:|-----:|
| `proposition14` | 7 | 0 | 0 | 7 | 0.9s |
| `section3_2 (Proposition 16)` | 4 | 0 | 0 | 4 | 0.4s |
| `proposition18` | 8 | 0 | 0 | 8 | 0.5s |
| `proposition22` | 6 | 0 | 0 | 6 | 0.4s |
| `corollary24` | 8 | 0 | 0 | 8 | 0.3s |
| `proposition25` | 31 | 0 | 0 | 31 | 1.7s |
| `algorithm1` | 9 | 0 | 0 | 9 | 2.8s |
| `proposition35_36` | 7 | 0 | 0 | 7 | 0.7s |
| `section4_3 (Kim mapping CCZ-class)` | 20 | 0 | 0 | 20 | **10m22.3s** |
| `section4_4 (Tables 6-7, catalog partition)` | 30 | 0 | 0 | 30 | 1m44.7s |
| **Total** | **130** | **0** | **0** | **130** | **737s** |

This supersedes the older 109-test figure.

**Runtime warning.** At 12 min this is by far the most expensive paper suite in the
repository, and 84 % of it is one testset. Measured breakdown of `section4_3` (Julia 1.12.6,
single core): `extract_linear_subspaces` 3.0s · `enumerate_ccz_class` 2.4s · **222 ×
`thickness_spectrum` = 261s** · **≈265 × `affine_representative` @ 0.876 s/call ≈ 232s**.
Both hot spots are inherent to the Section 4.3 claims (222 CCZ representatives; affine
partition of 512 permutations), not accidental. CI (`.github/workflows/ci.yml`,
`timeout-minutes: 20`) has only ~7 min of headroom over the local figure before
`Pkg.instantiate` and precompilation are counted, and GitHub-hosted runners are commonly
1.5–2× slower than this machine — so this is the single most likely job in the matrix to time
out. The `CANTEAUT_202205_FAST=1` escape hatch that skips the `section4_3_report` block
exists (`test/test_section4_3.jl:39`) but CI does not set it.

All values previously derived in Python were re-confirmed against the repository's own Julia
API: the full Table 6/7 recomputation, Banff #5 == Kim, both butterfly component orderings,
the Σ⁴-multiplicities, and the extended-Walsh scan of all 21,102 corpus members (66 s in
Julia, yielding exactly the paper's six spectra with multiplicities
17007/3599/320/146/26/4).

## Catalog Status

The paper **claims no new APN function** — it introduces EA-recovery and EA-partitioning
machinery and re-analyses known functions (the Kim mapping, the Banff list, the 21,102 known
8-bit quadratics). Every function it names is already represented: `n6_Kim` (data-raw
`n6_apn.toml`), `n6_Gold_x3`, the 13 Banff classes via `reprs6_*`, the Dillon permutation via
`VBF.dillon_apn_permutation`, and the 8-bit corpora.

**No catalog gaps.** One observation worth recording: the 13 Banff mugshots reproduced by
`section4_4.jl` are the same 13 buckets that the 19 catalog n=6 quadratic APN entries fall
into, so the catalog is complete for n = 6 quadratics with respect to this paper.

## Library-Reuse Note

**No duplication of an exported core symbol.** `helpers.jl` correctly routes through
`qam_to_sbox`, `polynomial_terms`, `terms_to_lut`, `conway_polynomial`, `rank_f2` and
`print_banner`; the other files use `ortho_derivative`, `apn_ea_mugshot`, `thickness`,
`thickness_spectrum`, `enumerate_ccz_class`, `walsh_zeroes`, `extract_linear_subspaces`,
`gamma_rank`, `delta_rank`, `linearity`, `differential_spectrum`, `sorted_pairs`, `is_qam`,
`quadratic_apn_matrix`, `are_affine_equivalent`, `affine_representative`,
`are_ea_equivalent`, `is_ccz_equivalent_to_permutation`, `kim_apn`,
`dillon_apn_permutation`, `compositional_inverse`, `f2_dot` and `is_invertible`.

- **Should use a core export (currently unused)**: `VBF.sigma_multiplicities` — see
  reproduction issue 2.
- **Duplicate of a VBF *internal***: `section4_3.jl:53-56` `_perm_from_pair` rebuilds
  `transpose(F2LinearMap{12,UInt32}([b1; b2]))`, identical to `VBF._ccz_mapping_from_bases`
  (`packages/VBF/src/equivalence/ccz/thickness.jl:105-112`) and to two helpers in
  `packages/VBFRepro/papers/2021/Chase_202110/helpers.jl`. One export collapses all three call sites.
- **Promote-to-core candidates** (core genuinely lacks them):
  - `helpers.jl:200-294` `nwords_for_bits` / `solve_augmented_gf2!` — a multi-word packed
    augmented GF(2) Gauss–Jordan returning `(rank, particular, kernel)`. Core's `solve_f2`
    (`linalg/linear_system.jl:177`) and `kernel_f2` (`:239`) assert
    `nbits ≤ 8*sizeof(T)`, capping at 128 bits, while Algorithm 1 at n = 9 needs
    `2n²+1 = 163`. A real core API gap.
  - `helpers.jl:304-316` `extract_f2linear` — generic "read an `N×N` F₂ matrix out of a
    packed bit vector at an offset"; belongs next to `F2LinearMap`.
  - An `(n, m)`-shaped function type — see reproduction issue 3.

- **Should use a core export** (reclassified 2026-08-15 — this is a reuse violation, not a
  core gap): `helpers.jl:362-368` `counts(values)` is *exactly* `sorted_pairs(Spectrum(values))`
  — verified equal on `thickness_spectrum(kim_apn())`. Both `Spectrum(::AbstractVector{<:Integer})`
  and `sorted_pairs` are exported (`packages/VBF/src/representations/spectrum.jl:42,83`).
- **Correctly paper-specific**: `jac_lin_*` / `rank_table` / `rank_distribution`
  (Definitions 12 and 19), `open_butterfly` (CDP17), `BANFF_TABLE6`,
  `_build_combined_system!`, `_recover_ea_triple`, and `pseudo_random_quadratic`
  (deterministic by design, and built on `qam_to_sbox`).

## Open Questions

- For Section 4.5, is bucketing all 21,102 functions by `apn_ea_mugshot` acceptable as a
  default (the paper reports about 70 s in C/Python, so Julia should be comparable), or
  should it stay `full_search`-gated?
