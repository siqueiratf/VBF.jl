# Beierle_202508 — Millions of Inequivalent Quadratic APN Functions in Eight Variables

**Paper**: Beierle et al. "Millions of inequivalent quadratic APN functions in eight
variables." 2025.

**Reproduction path**: `packages/VBFRepro/papers/2025/Beierle_202508/`

**Verdict**: Partial

Everything implemented is *correct*, but what is implemented is almost entirely arithmetic on
transcribed constants plus toy-dimension smoke tests. Every substantive computational claim of
the paper — the Section 3 working hypothesis, Table 4.1's profile distribution, Definition
4.3's `J₂`, and all six search counts — is transcribed and never computed, even though the
required data (32,916 dimension-8 quadratic APN functions) is present in
`packages/VBFCatalog/corpora/`. This review also surfaced a genuine defect in the paper that
only computation reveals, and an off-by-one in the estimator that the test tolerance hides.

---

## Paper Issues

### 1. Definition 4.1 does not specify the order on `BS(V)` pairs — and under the natural reading, Table 4.1 is wrong

- **Location**: Definition 4.1 (Eq. 4.1), Table 4.1 and Remark 4.2, PDF p. 3.
- **The gap**: Definition 4.1 says `P_k(F)` is "the lexicographically greatest tuple
  `[BS(V₀),…,BS(V_k)]`" with `BS(V) = (b, K(V))`, but never says how two pairs are compared.
- **Computed counter-evidence**: under the *standard* lexicographic order on the pairs, three
  members of `packages/VBFCatalog/corpora/beierleleander2022_n8.sqlite` (indices **9172,
  9624, 10320**; all verified du=2, deg=2, Σα=510) have
  `P₆ = [(0,0),(1,1),(3,3),(7,7),(15,15),(30,46),(58,90) / (52,108) / (56,96)]`.
  `(30,46)` does **not** occur at level 5 in Table 4.1, which lists only `(28,40)` and
  `(30,34)` — yet the table's counts sum to exactly 32,892, i.e. it claims to be exhaustive.
- **Why it is systematic**: these functions have a rank-4 component (α=16). Index 9172's
  extended Walsh spectrum is `{0:15600, 16:44544, 32:5120, **64:16**}` — a *non-classical*
  spectrum. Sampling 2000 of the 12,923 Beierle–Leander-2022 members gives component-rank
  multisets `{6:85,8:170}`×1477, `{4:1,6:80,8:174}`×450, `{4:2,…}`×47, `{4:3,…}`×21,
  `{4:4,…}`×5 — i.e. about **26 %** of that corpus has a rank-4 component, so the discrepancy
  affects 3,000+ functions, not a handful.
- **Resolution of the ambiguity**: under the alternative reading "maximize `b`, then
  **minimize** `K`", all three land back inside Table 4.1:
  `[…,(30,34),(58,78)]`, `[…,(30,34),(56,84)]`, `[…,(30,34),(58,78)]`. So the table is only
  consistent with the `b↑, K↓` order, which the paper never states.
- **Suggested repository action**: implement `P_k` under *both* orders and record which one
  reproduces Table 4.1; report the ambiguity.

### 2. Table 4.1's internal consistency is never stated, but does hold

- Every row satisfies `b ≤ 2ⁱ−1` and `K − b ∈ 4·ℤ`, with the level-5 multiset a sub-multiset
  of level 6 (all 14 rows checked). Worth asserting in code as a free transcription check.

---

## Reproduction Issues

### 1. Coupon-collector MLE is off by one; the test tolerance hides it

- **Location**: `estimators.jl:13-18` (`_coupon_delta`) and `:21-41`
  (`coupon_collector_mle`).
- **Symptom**: `test/test_estimators.jl` asserts `abs(r.coupon_mle - 6_123_206) <= 2`. The
  repository's Float64 bisection returns **6,123,207**; the paper's (and the true) integer
  argmax of `C(N,ℓ)/Nᵗ` is **6,123,206**.
- **Root cause**: catastrophic cancellation.
  `log((N+1)/(N+1-l)) - t*log((N+1)/N)` subtracts two Float64 quantities of about 0.0152 to
  obtain about `−7e−12`. At N=6,123,206 the exact value is `−7.2699e−12` (60-digit decimal)
  but Float64 gives `+6.788e−13`, flipping the sign and pushing the bisection one step past
  the maximum. The *naive* `lgamma`-based brute force is worse still: it returns 6,123,221.
- **Resolution plan**:
  1. Rewrite as `delta = -log1p(-l/(N+1)) - t*log1p(1/N)` (removing the ratio-then-log
     rounding), **or** evaluate in `BigFloat` with ≥64-bit precision.
  2. Re-run the bisection; it should return exactly 6,123,206.
  3. Tighten `test/test_estimators.jl` to `r.coupon_mle == 6_123_206` so the estimator is
     actually pinned to the paper's value.
  4. Apply the same tightening to the `print_check` at `estimators.jl:70`.

### 2. Definition 4.1's `P_k` is never implemented; Table 4.1 is only summed

- **Location**: `component_profiles.jl:67-80` (`component_bs`) and `paper_counts.jl:13-31`.
- **Symptom**: `test_paper_counts.jl` asserts only `table41_total() == 32_892` and
  `length(...) == 14`. No test computes a profile of any real dimension-8 function; the only
  function ever profiled is `gold_apn(4,1)`.
- **Root cause**: profile strings are stored as opaque `String` and the flag search was never
  written.
- **Resolution plan**:
  1. Add `profile_pk(F::SBox{8}, k)` doing the level-by-level "keep all maximizers" flag
     search (correct for lexicographic maximization; about 4 s per function in Python, far
     less in Julia).
  2. Parse `TABLE_4_1_PROFILE_COUNTS[i].profile` into `Vector{NTuple{2,Int}}` and assert the
     parsed rows are internally consistent (paper issue 2).
  3. Add an opt-in target `make table41 corpus=<name> limit=N` that computes `P₆` over
     `VBFCatalog.corpus_function` members and tallies against Table 4.1, under **both** pair
     orders (paper issue 1).
  4. Report the `(30,46)` outliers explicitly.

### 3. Section 3's working hypothesis is unimplemented despite the data being local

- **Location**: no file; `report.jl:32-33` describes scope as "full millions-scale generation
  … not run by default", which conflates the (infeasible) generation with the (cheap)
  verification.
- **Symptom**: no test or script anywhere touches `corpus_function`;
  `catalog_validation.jl:26-33` only calls `corpus_length`.
- **Root cause**: corpora were treated as count metadata rather than as function data.
- **Counter-evidence**: decoding members via the corpora side stores (37-byte
  `encode_quadratic` blobs, modulus 285) and searching for a 4-dimensional all-bent subspace
  of `Comp(F)`, **32/32 sampled members across all 7 pre-2025 corpora contain one** — under a
  minute in Python. `VBFCatalog.corpus_function` makes this directly runnable.
- **Resolution plan**:
  1. Add `working_hypothesis.jl` with `has_bent_space(F::SBox{8}, dim=4)` — a DFS over the
     bent-component set; `VBF.bent_components` gives the set directly.
  2. Iterate `corpus_function(db, name, i)` over the 7 pre-2025 corpora with a `limit=`
     budget; assert every checked member has a 4-dimensional bent space.
  3. Extend `catalog_validation.jl` to record that the local union is 32,916 versus the
     paper's 32,892 (Δ = +24, presumably cross-list duplicates) as a stated diagnostic, not a
     bare number.

### 4. Lemma 4.6 is transcribed, not verified

- **Location**: `extension_criteria.jl:14-25` (`lemma46_filter`); tests at
  `test_extension_criteria.jl:5-7`.
- **Symptom**: with `output_bits = N` the threshold is `2^{n-n+1} = 2`, so the "test"
  degenerates to "Gold is APN, zero is not". The lemma's actual content — *a function with
  DU > `2^{n−m+1}` has no APN extension* — is never exercised for any `m < n`.
- **Root cause**: the helper defaults `output_bits = N`, and no `(n,m)` example with `m < n`
  is ever constructed.
- **Resolution plan**:
  1. Build a `(4,2)` or `(4,3)` quadratic example with `generic_differential_uniformity`
     (already in `helpers.jl:81`).
  2. Exhaustively enumerate all APN extensions to `(4,4)` and assert that any base with
     DU > `2^{n−m+1}` has none, while at least one base under the threshold does — i.e.
     exercise both directions.

### 5. Theorem 4.9 is only checked at `(n,m) = (2,3)`

- **Location**: `extension_criteria.jl:119-125` (`theorem49_base_lut` hard-codes
  `[1,0,0,0]`), `:128`.
- **Symptom**: `test_extension_criteria.jl` asserts `total_linear_maps == 64` — the smallest
  possible instance.
- **Root cause**: `all_linear_luts(n,m)` materialises `2^{n·m}` LUTs, so it cannot scale past
  about (3,4).
- **Resolution plan**:
  1. Replace exhaustive enumeration with random sampling above `n·m > 16`, keeping exhaustive
     for small cases.
  2. Add at least `(n,m) = (3,4)` and `(4,4)` sampled cases so the theorem is tested where
     `F` is a genuine quadratic APN (`gold_apn(4,1)` → 5-bit extension).

### 6. Unsourced Zenodo metadata constants

- **Location**: `helpers.jl:22-24` — `ZENODO_FILE = "new_apns.txt"`,
  `ZENODO_FILE_BYTES = 3_400_000_000`,
  `ZENODO_FILE_MD5 = "dd6ae0655ba8a299a3d668cfc6cf10bf"`.
- **Symptom**: none of these appear in the `.tex` or the PDF, which give only the DOI
  `10.5281/zenodo.16752428`. No test asserts them, so a wrong MD5 would silently mislead
  anyone who downloads the artifact.
- **Root cause**: constants added from an out-of-band source without provenance.
- **Resolution plan**: (1) cite the source of the filename/size/MD5 in a comment, or
  (2) delete `ZENODO_FILE_BYTES` / `ZENODO_FILE_MD5` and keep only the DOI and record URL.

### 7. `catalog_validation.jl` omits one local n=8 corpus without saying why

- **Location**: `catalog_validation.jl:15-23` (`PRIOR_CORPUS_NAMES`, 7 entries).
- **Symptom**: `packages/VBFCatalog/corpora/` contains 8 n=8 quadratic corpora;
  `simonberg_gf4_n8` (196,863 members) is silently excluded.
- **Root cause**: the list was hand-written.
- **Resolution plan**: derive the list from `list_corpora(db)` filtered on
  `n == 8 && degree == 2`, and record explicitly which corpora are "pre-2025 known" versus
  excluded and why.

---

## Items Reproduced Exactly

| Paper item | File | Independent result |
|------------|------|--------------------|
| Table 4.1 transcription (14 rows) | `paper_counts.jl:13-28` | matches PDF p. 3 row for row |
| Table 4.1 rows sum to 32,892 | `paper_counts.jl:31` | `9+468+90+32+3128+7+13480+2+7549+49+7008+80+923+67 = 32892` ✓ |
| Theorem 5.1 arithmetic | `paper_counts.jl:34-43` | `32,892 + 3,775,599 = 3,808,491` ✓ |
| Theorem 2.3 + Remark 2.4 (Gold n=4) | `component_profiles.jl:83-99` | `Σα = 30 = 2⁵−2` ✓ |
| Lemma 4.7 (Gold n=4 / zero) | `extension_criteria.jl:62-79` | 35 rank-2 forms exist; **0** in `Comp(x³)^⊥` (du=2); **35** in `Comp(0)^⊥` (du=16) ✓ |
| Theorem 4.9 exhaustive (n=2, m=3) | `extension_criteria.jl:128-157` | 64 linear maps, **24** satisfy the condition, **24** give du=2, **0** disagreements ✓ |
| Section 5 overlap estimate | `estimators.jl:44-45` | `92955·3776451/(92955−32286) = 5,786,151.13 → 5,786,151` ✓ |

## Items Missing

All of the following have data available in-repository:

1. **Section 3 working hypothesis** — see reproduction issue 3.
2. **Table 4.1 / Definition 4.1 (`P_k`)** — see reproduction issue 2. `P₆` was re-implemented
   in Julia during the 2026-08-15 re-review on top of the reproduction's own
   `component_quadratic_rank`, and reproduces the earlier Python results exactly:
   `edelpott2009_n8` #1 → `[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(50,102)]`, #3 →
   `[…,(30,34),(50,102)]` — both genuine Table 4.1 rows. A straightforward Julia
   keep-all-maximizers flag search costs **1.62 s per function** (measured over 10
   `beierleleander2022_n8` members), i.e. roughly **15 hours** for the full 32,916-member
   distribution — not the ~30 minutes previously estimated. A `make table41` target must
   therefore be opt-in and `limit=`-budgeted, and would benefit from bitmask subspace
   representation and canonical-subspace deduplication.
3. **Definition 4.3 (`J₂` invariant)** — not implemented at all.
4. **Remark 4.4** (3,747,371,328 (8,5)-functions), **Step 2** (2,403,534), **Section 4.2**
   (866,470 (6,8)-functions; 92,955 (8,8)-APNs) — transcribed in prose only, with no code and
   no scoping note.
5. **"None of our found functions is CCZ-equivalent to a permutation"** — never checked,
   although `is_ccz_equivalent_to_permutation` is a `VBF` export and the corpora are local.
6. **Zenodo dataset (3.4 GB `new_apns.txt`)** — never validated;
   `test/test_dataset_validation.jl` only round-trips a Gold n=4 LUT through a temp file.
   Reasonable, but it should be labelled explicitly.
7. **The (8,4)-bent count 92,515** (Section 4.1) is never recorded anywhere.
8. **Internal consistency of Section 5** is unchecked: `3,808,491 − M(=3,776,451) = 32,040 ≤ t′(=32,286)`.
   Cheap and meaningful.

## Test Results

Re-reviewed **2026-08-15** on **Julia 1.12.6** (repo commit `bf15e59`), project instantiated.

| | |
|---|---|
| Command | `make -C packages/VBFRepro/papers/2025/Beierle_202508 test` |
| Exit code | **0** |
| Wall time | **6 s** (Julia-reported testset time 2.8 s; the rest is `Pkg.instantiate()`) |
| Result | **35 / 35 pass, 0 fail, 0 broken, 0 errored** |

The `make` log prints only the collapsed total. The per-testset breakdown below comes from
re-running the identical `test/*.jl` files under `@testset verbose=true`:

| Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|
| `paper count arithmetic` | 4 | 0 | 0 | 4 | 0.4 s |
| `component profile moments` | 6 | 0 | 0 | 6 | 0.3 s |
| `extension criteria` | 13 | 0 | 0 | 13 | 0.4 s |
| `section 5 estimators` | 4 | 0 | 0 | 4 | 0.0 s |
| `dataset parser and bounded sample` | 5 | 0 | 0 | 5 | 0.5 s |
| `catalog diagnostics` | 3 | 0 | 0 | 3 | 0.8 s |
| **Beierle et al. 2025 reproduction** | **35** | **0** | **0** | **35** | **2.5 s** |

A green suite here certifies only what the suite asserts: table-sum arithmetic, a Gold n=4
component-moment identity, Lemma 4.7 / Theorem 4.9 at n=4 / (n,m)=(2,3), the two Section 5
estimator formulas, a LUT-parser round-trip, and three corpus-count assertions. It does not
exercise any dimension-8 search claim of the paper.

Every load-bearing number previously derived in Python/C was additionally recomputed with the
repository's own Julia API and **reproduced exactly — zero disagreements**. The one apparent
divergence (extended Walsh spectrum `0:15600` vs `0:15855`) is a `b=0`-column convention and
resolves exactly: 15855 − 255 = 15600.

## Catalog Status

The paper's claimed-new objects are **3,775,599 CCZ classes in bulk**, not named functions.
Per-function `[[apn_functions]]` entries are inapplicable at that scale.

- **Status: unverifiable** — the 3.4 GB Zenodo artifact is not in the repository, so nothing
  can be verified or ingested.
- **Bulk-corpus gap (conditional)**: the intended home is a `bulk_corpora` row
  `beierle2025_n8`, and an importer for it **already exists** at
  `packages/VBFCatalog/data-build/import_beierle2025.jl` (bib key `Beierle_202500` is present
  at `packages/VBFCatalog/data-raw/bibliography.bib:1417`; `packages/VBFCatalog/.gitignore:7`
  already ignores `corpora/beierle2025_n8.sqlite`). That importer is currently **unrunnable
  for two independent reasons**, both established by execution on 2026-08-15: (1) its `KUZDIR`
  at line 13 resolves to `packages/VBFRepro/papers/Kuznetsov_202606`, which does not exist — the paper lives at
  `packages/VBFRepro/papers/2026/Kuznetsov_202606`; (2) its input side-file `catalogs/apn8_blp2025.anf` is not
  present anywhere in the repository. So the gap is blocked on obtaining the source data *and*
  on repairing the importer path — not merely on the Zenodo download. There is also a decision
  pending about storing roughly 3.7M × 37-byte encodings (about 140 MB packed). Flagged only;
  **no gap record emitted**.

Note for `packages/VBFRepro/papers/2026/Kuznetsov_202606`: that reproduction's `theorem6.jl` looks up a bulk
corpus named `beierle2025_n8` which does not exist, and treats its absence as a *passing*
inequivalence check. Importing this dataset would fix that vacuity.

## Library-Reuse Note

Duplicating core or other papers:

- `helpers.jl:54-79` — `toml_safe` (9 methods) plus `write_results_toml` and
  `paper_results_dir` / `paper_results_path` are a **verbatim duplicate** of
  `packages/VBFRepro/papers/2022/Yu_202211d/helpers.jl:134,158,165,182`. → **promote-to-core**
  (`packages/VBF/src/io/`), e.g. `VBF.write_results_toml(data, path)`.
- `component_profiles.jl:67-80` `component_bs` recomputes the bent count that
  `VBF.bent_components` already returns; and `α(f)` could be cross-validated against
  `VBF.walsh_power_moment(lat(F), 4)`. → use the core exports at least as a cross-check.
- `helpers.jl:101-113, 115-130` `linear_lut_from_columns` / `all_linear_luts` overlap
  `VBF.F2LinearMap` / `affine_map_from_masks`, but those are square-only. → **promote-to-core**
  as non-square F₂-linear map builders.

Promote-to-core candidates (core genuinely lacks these):

- `helpers.jl:81-99` `generic_differential_uniformity(lut, n, m)` — `VBF.differential_uniformity`
  only accepts a square `SBox{N}`. Non-square `(n,m)` DU is needed by this paper, by Taniguchi
  2025 §2, and by any Nyberg-bound work. → `packages/VBF/src/`.
- A `Comp(F)^⊥` / quadratic-form-rank API (`component_profiles.jl:47-64`) — generic ("F₂-rank
  of the alternating form of a quadratic Boolean function"), currently paper-local.

## Open Questions

- Which pair order does Definition 4.1 intend? The repository should record the answer, since
  it changes Table 4.1's meaning (paper issue 1).
- Is `simonberg_gf4_n8` intended to be part of the "known prior to this work" set
  (reproduction issue 7)?
