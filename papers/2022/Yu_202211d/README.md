# Yu_202211d — Constructing More Quadratic APN Functions with the QAM Method

**Paper**: Yu, Perrin. "Constructing more quadratic APN functions with the QAM method."
*Designs, Codes and Cryptography*, 2022.

**Reproduction path**: `papers/2022/Yu_202211d/`

**Verdict**: Mostly complete

The best-structured reproduction in the 2021–2022 set. Every theorem, definition and
proposition has an executable counterpart, the infeasible parts are honestly labelled, and
the reproduction independently found and worked around a genuine flaw in the paper
(Theorem 6's exclusion set — see P1). The remaining gap is that the paper's *quantitative*
corpus claims (5412 classes, Walsh-spectrum multiplicities 5084/324/4, cross-corpus
disjointness, and the Conjecture-3 arithmetic) are never checked, even though the corpora are
already registered in VBFCatalog and the infrastructure is all present.

> **Environment note**: Julia is not installed in the review environment, so `make test` could
> not be executed. The committed `results/report.toml` (Julia 1.12.6, 2026-06-06) records a
> full prior pass with every check `true`; independent Python re-derivation confirms the
> load-bearing values.

---

## Paper Issues

### P1. Theorem 6's excluded set is too small — the "only if" direction is false as written

- **Location**: tex line 341 — "for all `(λ_1,…,λ_{n-1},μ_1,μ_2) ≠ (0,0,⋯,0,0,1,1,0)`" — and
  proof step 1 (line 346), which excludes only that single tuple.
- **Counter-evidence**: taking `H_8` = the genuine QAM of `x^3` in the normal basis
  `γ = g^11` (a QAM, so condition (2) must hold), condition (2) is violated for **63**
  additional tuples, all with `μ = (1,0)` and `λ_{n-1} = 1` (e.g.
  `λ = 0b1000001, 0b1000010, 0b1000011, …`). Violation distribution:
  `Counter({((1,0), λ_{n-1}=1): 63})`.
- **Correct statement**: the excluded family is `{ μ = (1,0) and λ_{n-1} = 1 }` (`2^{n-2}`
  tuples), which is exactly what Theorem 4(i) forces.
- **Credit**: the reproduction already found and documented this — `theorem6_model.jl:19-33`
  and the guard at `theorem6_model.jl:92`.

Nothing else. Conjecture 3's seven product estimates all recompute exactly
(`7×100×154×87×20×2×3×64×90×29×3 = 563976483840000 ≈ 2^49.0`, …,
`158369767920000 ≈ 2^47.17`); all seven stated products and all seven `≈2^x` values are
correct. The `W_1` spectrum `{N_0=16320, N_16=43520, N_32=5440}` is exactly the extended Walsh
spectrum of `x^3` on `F_2^8` (verified under both modulus 285 and 283). And
`|A|=7, |B|=2^7−2^4, |{c_i}|=3, |G|=2^7−2^5` all follow from `dim V = dim U = 5`, which is
confirmed.

---

## Reproduction Issues

### 1. The paper's headline corpus statistics are never checked against the corpus that is already loaded

- **Location**: `catalog_validation.jl:41-77` (samples 50 of 5412 for `δ=2` / degree 2 /
  `is_qam` only); `paper_invariants.jl:70-89` defines `PAPER_WALSH_SPECTRA` and
  `paper_walsh_class` but applies them only to the Gold seed
  (`paper_invariants.jl:176-179`).
- **Symptom**: Section 3.2's central claims — 5412 distinct EA-classes; extended Walsh classes
  occurring 5084 / 324 / 4 times (which sum to exactly 5412); "no function we found was in the
  Beierle–Leander or the earlier QAM data set" — have zero executable coverage, although
  `yuperrin2022_qam_n8`, `beierleleander2022_n8` and `yuwangli2014_qam_n8` are all registered
  corpora (`packages/VBFCatalog/data-build/import_quadratic_apn_8bit.jl:107,125,152`).
- **Root cause**: catalog validation was scoped as a smoke test rather than as the
  reproduction of Section 3.2.
- **Resolution plan**:
  1. Add `section3_2_corpus.jl`: compute `apn_ea_mugshot` for all 5412 corpus members and
     assert 5412 distinct mugshots (the paper's "5412 new EA-classes").
  2. In the same file, compute `paper_walsh_class` for all 5412 and assert the multiset
     `{W1:5084, W2:324, W3:4}`.
  3. Add a cross-corpus check: the mugshot sets of `yuperrin2022_qam_n8` vs
     `beierleleander2022_n8` and vs `yuwangli2014_qam_n8` are disjoint.
  4. Expose all three behind `limit`/`max_evaluations` knobs per `AGENTS.md:63`, defaulting to
     a sample and offering `full_search=true`.
  5. Add a `conjecture3_arithmetic.jl` (or a test) asserting the seven products and their
     `log2` roundings — roughly 20 lines, exactly reproducing a paper table.

### 2. The `exhaustive` flag in `small_search_full` is a budget heuristic, not a statement about the search

- **Location**: `small_searches.jl:21` —
  `exhaustive = n_classes < limit && max_evaluations > 1 << 24 - 1`, with the comment
  "exhaustive when search terminated naturally (not by budget or limit)".
- **Symptom**: `results/report.toml` records `n4_full.exhaustive = false` even though the `n=4`
  quadratic-APN classification (a single Gold class) *is* complete; conversely the flag can
  read `true` merely because a large budget was passed. `VBF.search_qam_full` returns only a
  vector, so the caller cannot know why it stopped.
- **Root cause**: the underlying API does not report a termination reason.
- **Resolution plan**:
  1. Either extend `search_qam_full` (`packages/VBF/src/constructions/qam_search.jl:302`) to
     return `(reps, evaluated, exhausted)`, or
  2. rename the field to `budget_allows_exhaustive` and document it, and
  3. cite the `search_qam_full` docstring guarantee ("`n=5` → single Gold class, `n=6` → 13
     classes") for the completeness claims instead of the heuristic.

### 3. Proposition 3's dependent cardinalities are checked for one `x_12` only

- **Location**: `test/test_proposition3_partitions.jl` loops
  `for x13 in prop3_candidates_x13()` asserting `|{c_i}| = 3`, but `|G| = 96` is only checked
  for `prop3_cardinalities()`'s default `x12 = first(B)`.
- **Symptom**: asymmetric coverage of a symmetric claim.
- **Root cause**: oversight.
- **Resolution plan**: add the mirror loop
  `for x12 in prop3_candidates_x12(); @test length(prop3_candidates_x6(x12)) == 96; end`.

### 4. `print_header` bypasses the VBF report emitters

- **Location**: `helpers.jl:192-196` uses raw `println` where `print_banner` (a VBF export,
  used correctly by `papers/2022/Li_202207/helpers.jl:17`) is the convention.
- **Root cause**: boilerplate drift.
- **Resolution plan**: replace with `print_banner(io, title, venue)`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| **Conjecture 2's `H_8`** | `h8_base()` (`conjecture2_search.jl:83-86`) builds `B_{x³}(α_u, α_v) = α_u²α_v + α_uα_v²` on the normal basis `α_u = γ^{2^{u-1}}, γ = g^{11}`, modulus 285. The upper-left 6×6 block matches the paper's literal `g`-power matrix **entry for entry** (`g^34, g^81, g^83, g^170, g^106; g^68, g^162, g^166, g^85; g^136, g^69, g^77; g^17, g^138; g^34`). The full seed is a QAM |
| **`base_matches_paper()` / `conjecture2_recovers_seed()`** | Both confirmed true |
| **`qam_hits == 1`** (`test/test_conjecture2.jl`) | Sweeping all 256 values of `x_13` with the other 12 entries at the `x³` seed, exactly **one** value keeps `H_8` a QAM — `x_13 = 107`, matching `results/report.toml` (`x13 = 107`, `reduced_x13 = 3`) |
| **Proposition 3** | `V = Span(g^34,g^81,g^83,g^170,g^106)` and `U = Span(g^34,g^68,g^162,g^166,g^85)` both have `dim = 5`; hence `|A|=7, |B|=112, |{c_i}|=3, |G|=96` — matching the paper and the artifact |
| **Theorem 2 (transvection)** | `congruence_transvection` + `reduce_x13_into_A` implement `H' = PᵗHP` for the exact `P` printed in the paper's proof; the artifact records `reduction_same_qam = true`, `reduction_ea_equiv = true` |
| **Theorem 6** | `new_model_is_qam` matches `is_qam` on 2000/2000 (`n=5`), 2000/2000 (`n=6`), 600/600 (`n=8`) proper-block random matrices, per the artifact |
| **eq. (5) vs eq. (6)** | `redundancy_comparison` shows both select 43008 pairs (`= 224 × 192`), with 1 vs 224 span constructions — the paper's stated payoff, correctly formalised |
| **Definition QAM / Theorem 1 correspondence** | Delegated to `VBF.is_qam` / `qam_to_sbox` / `quadratic_apn_matrix` with round-trip tests — the right call |
| **Class invariants (Definition 2, Σ₄, Γ/Δ-ranks)** | All delegated to VBF; the 13 `F_2^6` classes are separated by the ortho-derivative fingerprint (artifact: `n6_classes = 13`, `n6_distinct_fingerprints = 13`); `walsh_class_seed = "W1"` — independently confirmed, `x³` on `F_2^8` has spectrum `{0:16320, 16:43520, 32:5440} = W_1` |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Yu_202211d test` | **Not run** — `julia` is not installed in the review environment |
| Committed `results/report.toml` (prior run, Julia 1.12.6) | Full pass, all checks `true` |
| Independent re-verification: `H_8` 6×6 block match, seed is a QAM, `dim V = dim U = 5`, unique QAM-preserving `x_13 = 107`, 63 Theorem-6 counterexample tuples, `W_1` spectrum, all seven Conjecture-3 products | **All confirmed** |

## Catalog Status

The paper claims 5412 **new** quadratic APN functions on `F_2^8`, delivered as a data set
rather than as closed forms. They live in the VBFCatalog corpus `yuperrin2022_qam_n8` (5412
members, per `packages/VBF/test/unit/corpus_test.jl:62`), which is the correct home — the
curated `n8_apn.toml` is for named representatives, not 5412 LUTs.

- **Status: present** (as a corpus), for all 5412.
- **No catalog-gap records emitted.** If a *representative* of the Yu–Perrin set is wanted in
  `n8_apn.toml`, pick corpus member 1 and add it with `bib_key = "Yu_202211"` — that is a
  curation decision, not a gap.
- **Caveat**: the SQLite corpus could not be queried without Julia, so "present" rests on
  `corpus_test.jl:62` and `results/report.toml` (`count = 5412, count_ok = true`).

## Library-Reuse Note

Duplicates a core export:

- `f2_span(vecs)` — `helpers.jl:75-84` — duplicates `VBF.span_from_basis`
  (`packages/VBF/src/linalg/subspace_search.jl:152`, exported at `exports.jl:32`). Used at
  `helpers.jl:95`, `helpers.jl:118`, `theorem6_model.jl:148`, `theorem6_model.jl:161`. Fix
  target: `span_from_basis(UInt32.(vecs))` (returns a `Vector{UInt32}`; wrap in `Set` if
  membership tests are hot).
- `print_header` — `helpers.jl:192-196` — should call `VBF.print_banner`.

Borderline:

- `f2_decompose` (`proposition3_partitions.jl:71-81`) brute-forces `2^k` combinations;
  `VBF.solve_f2(A::Vector{T}, b::T; nbits)` (`packages/VBF/src/linalg/linear_system.jl:177`)
  solves the same system. Worth switching, though `k=5` makes it harmless.

Legitimately paper-specific (not flagged): `h8_base`, `h8_from_vars`, `H8_VAR_POSITION`,
`gold3_polar`, `nontrivial_coset_reps`, `coset_involution_half`, `is_proper`,
`new_model_is_qam`, `congruence_transvection`, `extended_walsh_spectrum`,
`PAPER_WALSH_SPECTRA`.

Promote-to-core candidates:

1. `toml_safe` + `write_results_toml` (`helpers.jl:150-188`) — byte-for-byte duplicated in
   `papers/2025/Beierle_202508/helpers.jl`. Belongs next to `print_banner` in
   `packages/VBF/src/io/`.
2. `nontrivial_coset_reps` / `coset_involution_half` (`helpers.jl:94-130`) — generic `F_2`
   coset partitioning, useful to any search paper; belongs in
   `packages/VBF/src/linalg/subspace_search.jl`.
3. `extended_walsh_spectrum` with the `b ≠ 0` convention (`paper_invariants.jl:57-66`) — a
   standard invariant; core has `absolute_walsh_spectrum` but not this convention.

## Open Questions

1. Is the corpus-vs-paper statistical reproduction (issue 1) deliberately out of scope, or
   simply not yet written? The infrastructure is all present.
2. `report.jl:70-74` defines `using_now()` with a comment about avoiding a `Dates` dependency,
   while `paper_invariants.jl:25` already does `using Random` and
   `papers/2021/Calderini_202100/helpers.jl` uses `Dates`. Intentional?
