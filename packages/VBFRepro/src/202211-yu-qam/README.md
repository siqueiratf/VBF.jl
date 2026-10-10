# Yu_202211d — Constructing More Quadratic APN Functions with the QAM Method

**Paper**: Yu, Perrin. "Constructing more quadratic APN functions with the QAM method." 2022.

**Reproduction path**: `packages/VBFRepro/src/202211-yu-qam/`

**Verdict**: Mostly complete

The strongest structure in the 2022 batch: the QAM correspondence, Theorem 2, Proposition 3,
Theorem 6 and the eq. (5)/(6) redundancy are all reproduced and independently confirmed, and
the reproduction already caught a genuine flaw in the paper's Theorem 6 exclusion set. The
one substantive gap is that the paper's four *quantitative* corpus claims are never
evaluated — even though all four reproduce exactly, as verified here. Two smaller defects: an
`exhaustive` flag that can never be true, and a tautological test.

> **Re-review 2026-08-15, Julia 1.12.6**: the suite executes green (86/86). One claim from the
> previous revision is **withdrawn as factually wrong**: `1 << 24 - 1` evaluates to
> `16777215`, not `8388608` — Julia binds `<<` *tighter* than `-`, so there is no operator-
> precedence bug in `small_searches.jl:18`. See reproduction issue 2.

---

## Paper Issues

### 1. Theorem 6 / eq. (2): the excluded set is too small

The reproduction already flagged this; here is the hard counter-evidence.

- **Location**: `.tex:341`, the quantifier line after eq. (2) — "for all
  `(λ₁,…,λ_{n-1},μ₁,μ₂) ≠ (0,0,…,0,0,1,1,0)`" — plus proof step 1) at `.tex:346`.
- **Computed counter-evidence**: on the seed `H_8` — which *is* a QAM — condition (★) fails
  for **63** distinct `(λ,μ)` beyond the single excluded vector, namely every `λ` with
  `λ₇=1` and `(λ₁…λ₆) ≠ 0` paired with `μ=(1,0)` (`63 = 2^{n-2}−1`). With the whole family
  `{μ=(1,0), λ_{n-1}=1}` excluded, violations drop to **0**. So "If `H_n` is a QAM, then (2)
  is obviously true" is false as literally written; only the family-wide exclusion is
  correct, which is what Theorem 4(i) actually gives.
- **Credit**: the repository's reading in `theorem6_model.jl:19-28` and its implementation at
  `:92` are the correct ones.

### 2. Editorial inconsistencies

- `.tex:315` "we haven't realized the new model" contradicts `.tex:378-397`, which presents
  it as an operational improvement; `.tex:397` has "Similarly property holds" and "aviod"
  typos. No mathematical impact.

### Checked and found correct (not paper issues)

- **Conjecture 3**: all **seven** product estimates are arithmetically exact
  (563976483840000 = 2^49.00, 955102533525504 = 2^49.76, 966313344761856 = 2^49.78,
  781247805456384 = 2^49.47, 739769049169920 = 2^49.39, 903337795584000 = 2^49.68,
  158369767920000 = 2^47.17).
- **Section 3.2 counting**: `3 + 2·245 + 6301 = 6794`; `1 + 245 + 6301 = 6547`;
  `6547 − 2 − 1133 = 5412`; `21113 + 5412 = 26525`; `8192 + 12921 = 21113`. All consistent.
- **Δ/Γ-rank class counts**: `7+21+45+6+31+482+2363+2831+1008 = 6794`. Consistent.

---

## Reproduction Issues

### 1. The paper's quantitative corpus claims are never checked

*Largest gap.*

- **Location**: `paper_invariants.jl:70-89` defines `PAPER_WALSH_SPECTRA` and
  `paper_walsh_class`, but they are applied only to the Gold `x³` seed
  (`paper_invariants.jl:177`). `catalog_validation.jl:47-52` checks only δ=2, deg=2 and
  `is_qam` on a 50-function sample.
- **Symptom**: `results/report.toml` records `walsh_class_seed = "W1"` and nothing about the
  5412 corpus. The paper's two headline numbers are unverified.
- **Root cause**: the scaffolding exists but is never wired to the corpus.
- **Independent verification — both PASS**:
  - Extended Walsh spectrum over all 5412 corpus members: **W₁ = 5084, W₂ = 324, W₃ = 4** —
    *exactly* the paper's Section 3.2 multiplicities. Roughly 3.5 minutes in pure Python;
    **91 s in Julia** for one pass over all 5412 members computing the extended Walsh class,
    `apn_ea_mugshot` and the ortho-derivative fingerprint (measured 2026-08-15).
  - Distinct ortho-derivative fingerprints over all 5412: **5410** distinct by the `π_F`
    **differential** spectrum alone; the 2 collisions (members `{880, 2701}` and
    `{1837, 5151}`) split as soon as the `π_F` **Walsh** spectrum is added → **5412 distinct
    (Walsh, differential) pairs**, exactly the paper's "5412 new EA-equivalence classes".
    That is precisely `apn_ea_mugshot`.
- **Resolution plan**:
  1. Add `corpus_walsh_report()` in `paper_invariants.jl` iterating
     `corpus_function(db, CORPUS_NAME, i)` and tallying `paper_walsh_class` → assert
     `(5084, 324, 4)`.
  2. Add `corpus_class_count()` tallying `apn_ea_mugshot` into a `Set` → assert `5412`.
  3. Mark both as exact reproductions in `report.jl`'s summary.
  4. Keep them behind a `full=true` flag if runtime matters.

### 2. The `exhaustive` flag is wrong at n=4

- **Location**: `small_searches.jl:18` —
  `exhaustive = n_classes < limit && max_evaluations > 1 << 24 - 1`.
- **Symptom**: `results/report.toml` records
  `[results.small_searches.n4_full] exhaustive = false`, even though the n=4 full QAM search
  *is* exhaustive.
- **Root cause**: the flag is derived from the *budget*, not from whether the search
  terminated naturally. (Verified 2026-08-15: `1 << 24 - 1 == 16777215` in Julia — `<<` binds
  *tighter* than `-`, so the guard correctly means `max_evaluations ≥ 2^24`. **An earlier
  revision of this file claimed an operator-precedence bug here; that claim was wrong and is
  withdrawn** — acting on it would have "fixed" correct code.) `small_searches_report` (`:46`)
  defaults `max_evaluations = 1 << 22` = 4194304 < 2^24, so the branch can never be true from
  the report path — and the n=4 search demonstrably terminates naturally well below 2^22
  (identical wall time at budgets 2^22, 2^23, 2^24 and 2^26), so `exhaustive = false` in
  `results/report.toml` is a false negative.
- **Resolution plan**:
  1. Have `search_qam_full` return a `terminated_naturally` flag and propagate it.
  2. Failing that, write `max_evaluations ≥ (1 << 24)` with explicit parentheses.
  3. Raise the report's default `max_evaluations` for n=4.
  4. Assert `r4.exhaustive` in `test/runtests.jl`.

### 3. The "13 classes on `F_{2^6}`" test is tautological

- **Location**: `test/test_paper_invariants.jl` —
  `cls = search_qam_full(6; limit = 13, …); @test length(cls) == 13`; the same pattern
  appears at `paper_invariants.jl:132`.
- **Symptom**: the assertion is satisfied by the `limit` argument, not by the mathematics. It
  cannot detect a search that would have found 14, and it does not establish the "13" used by
  Conjecture-1 fact (3).
- **Root cause**: `limit` used as both a cap and an expectation.
- **Resolution plan**:
  1. Run with `limit = typemax(Int)` (or `limit = 20`) and assert `== 13`.
  2. Keep `distinct_ccz_lower_bound(cls) == 13` as the separation claim.

### 4. Conjecture 3's arithmetic is not checked, and Conjecture 1's supporting facts are absent

- **Symptom**: the seven product estimates are trivially assertable (they are exact — see
  above), and Conjecture-1 supporting facts (1), (2) and (3) are not represented at all.
- **Resolution plan**: assert the seven products and their `log2` values; add the
  Conjecture-1 facts.

### 5. Library-reuse violations

See the Library-Reuse Note below — `f2_span`, `print_header` and `f2_decompose` all duplicate
core functionality.

---

## Items Reproduced Exactly

| Paper item | Status | Independent evidence |
|------------|--------|----------------------|
| Definition 1 (QAM) | fully reproduced | `is_qam` |
| Theorem 1 (Yu–Wang–Li correspondence) | fully reproduced | `qam_correspondence.jl` round-trip |
| Definition 2 (ortho-derivative) | fully reproduced | `ortho_derivative`, `apn_ea_mugshot` |
| Conjecture 2 — the literal `H_8` 6×6 `g`-power block | fully reproduced | normal basis `γ = g^11`, modulus 285, `g = 2` (order 255): the computed block **equals** the paper's matrix exactly; the full `H_8` is a QAM |
| Theorem 2 (`H′ = PᵗHP` ⇒ EA-equivalent, QAM-preserving) | fully reproduced | `congruence_transvection` + `reduce_x13_into_A` (`x₁₃`: 107 → 3 ∈ A) |
| Proposition 3 cardinalities | fully reproduced | `dim V = dim U = 5` → `|A| = 7`, `|B| = 112`, `|{c₁,c₂,c₃}| = 3`, `|G| = 96`; `A = {1,2,3,8,9,10,11}` |
| Definition 3 (proper), Theorem 4, Lemma 5, Theorem 6 | reproduced **with a correction** | see paper issue 1 |
| eq. (5) versus eq. (6) redundancy | fully reproduced | `224·192 = 43008` valid `(x₁₃, x₇)` pairs, identical under both formulations |
| The 5412-function corpus | loaded and count-checked | `yuperrin2022_qam_n8` = 5412 members, all quadratic APN |

## Test Results

Reviewed 2026-08-15 on Julia **1.12.6** with the project fully instantiated.

| | |
|---|---|
| Command | `make -C packages/VBFRepro/src/202211-yu-qam test` |
| Exit code | **0** |
| Wall time | **71 s** (`@testset` reported `1m07.7s`) |
| Totals | **86 pass / 0 fail / 0 error / 0 broken — 86 total** |

The suite reports a single top-level testset (`Yu–Perrin 2022 (QAM method) reproduction`).
An instrumented `verbose=true` re-run of the same file set gives the breakdown; the three
expensive testsets are ~96 % of the runtime — the n=6 QAM class search (53.2 s), the
`small_searches` artifact test (50.7 s) and the n=4 full search (42.1 s). `git status` is
clean after the run: the artifact test removes its temporary `results/small_searches.toml`.

Every value in the committed `results/report.toml` was independently regenerated and matches:
`conjecture2` (evaluated 256, budget 1048576, exhaustive true, candidate_space 256, qam_hits 1,
n_classes 1), `theorem6` (43008 valid pairs; 1 vs 224 span builds), `invariants` (Γ-rank 1102,
Δ-rank 94, `walsh_class_seed = "W1"`), `proposition3` (7, 112, 3, 96; 107→3), `catalog` (5412).
The 2026-06-06 artifact is trustworthy.

Corpus-level re-verification: the paper's §3.2 extended-Walsh multiplicities
(𝒲₁=5084, 𝒲₂=324, 𝒲₃=4) and the 5412 distinct ortho-derivative fingerprints reproduce
exactly, in **91 s** for one pass over all 5412 members. All 5412 members are APN (not just
the 52 the repo's own tests sample).

## Catalog Status

No individually-named new APN function is claimed; the paper's contribution is the
5412-member set, which is **present** as the bulk corpus `yuperrin2022_qam_n8`
(`packages/VBFCatalog/data/catalog.sqlite (dataset yuperrin2022_qam_n8)`, 5412 members, verified quadratic
APN, with a Walsh-spectrum distribution matching the paper).

**No catalog gaps.**

## Library-Reuse Note

| Helper | Line | Verdict |
|--------|------|---------|
| `f2_span` | `helpers.jl:75-84` | **reuse violation** — duplicates `span_from_basis` (`packages/VBF/src/linalg/subspace_search.jl:152`); the only difference is `Set{Int}` versus `Vector{UInt32}` |
| `print_header` | `helpers.jl:192-196` | **reuse violation** — hand-rolled; should call `print_banner` |
| `f2_decompose` | `proposition3_partitions.jl:71` | **reuse violation (minor)** — brute-force over `2^k`; should use `solve_f2` |
| `toml_safe` / `write_results_toml` | `helpers.jl:150-188` | **promote-to-core** — a byte-identical concept appears in `packages/VBFRepro/src/202508-beierle-millions/helpers.jl` |
| `normal_basis` | `helpers.jl:50` | **promote-to-core** — also in `packages/VBFRepro/src/202512-yu-dimension-ten/helpers.jl` and `packages/VBFRepro/src/202400-ichanska-qam-search/helpers.jl` |
| `gold3_polar` | `helpers.jl:62` | **promote-to-core candidate** — a generic "polar/bilinear form of a quadratic on an arbitrary basis"; `quadratic_apn_matrix` only handles the *standard* basis |
| `nontrivial_coset_reps`, `coset_involution_half`, `is_proper`, `new_model_is_qam`, `congruence_transvection` | — | legitimately paper-specific; correctly built on `rank_f2`, `is_qam`, `qam_to_sbox` |
