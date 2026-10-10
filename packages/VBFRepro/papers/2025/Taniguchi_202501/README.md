# Taniguchi_202501 — Changing Almost Perfect Nonlinear Functions on Affine Subspaces of Small Codimensions

**Paper**: Taniguchi et al. "Changing almost perfect nonlinear functions on affine subspaces
of small codimensions." 2025.

**Reproduction path**: `packages/VBFRepro/papers/2025/Taniguchi_202501/`

**Verdict**: Mostly complete

Current audit (2026-10-10): the implemented formula/property checks pass.
`prior_art.jl` now independently replays an explicit EA witness between
Example4.2 and Budaghyan–Carlet–Leander2009 eq.(6), a=alpha, modulus285, at all256
points. The example is separated from Gold yet belongs to a class published in
2009. This attribution already exists in the catalog; no catalog writes were
needed. `prior_art_witness(recover=true)` performs bounded witness recovery.

The cross-paper Edel–Pott attribution is now also verified explicitly:
Table 9 entry 1.3 is `x^3 + u Tr(u^63 x^3 + u^252 x^9)` over the paper's
Table 2 field (modulus 285, primitive `u=2`). An independent EA witness maps
Example 4.2 to this primary-source formula. Its displayed alternate polynomial
`x^3 + u^245 x^33 + u^183 x^66 + u^21 x^144` is byte-identical to corpus
`edelpott2009_n8` member 5, located by a full LUT scan rather than assumed
numbering; a second replayed EA witness binds the primary formula to that
alternate representative. `edel_pott_prior_art_witness(recover=true)` provides
bounded recovery. Both maps and exact LUT bindings reside in the existing
prior-art fixture. These are positive proofs, beyond matching spectra.

The table-driven `count_valid_L_bounded` precomputes field and bilinear tables,
records modulus, trace-one e0, normalizationL(e0)=0, explored interval, next
index, and exhaustion status. n4=448 and n5=4608 were recomputed. n6 has2^30
candidates; a partial count does not validate the historical external value35648
or the publication's approximate40000. Run `make theorem3_2 n=6` for a bounded
check, or opt in with `full_search=true` and an explicit time budget. Intervals
can continue using the returned next_index. n6 enumeration and Gamma-rank
verification have **not** been rerun in this audit.

The dated review below is retained as historical context; older external-run
claims, line numbers, and proposed fixes are not current validation evidence.

---

## Paper Issues

### 1. Example 3.3's n=6 figure is imprecise

- **Location**: PDF p. 11, Example 3.3 — *"for `F(x) = x³` on `F₂⁶`, we found about 40 000
  such mappings `L`."*
- **Computed counter-evidence**: an exhaustive count over all `2³⁰` linearized `L` with
  `L(e₀)=0` gives **35,648**, reproduced identically under two different moduli (`91` and
  `97`), so the count is intrinsic. That is **11 % below** the paper's figure.
- **Caveat**: this assumes the paper counted with the same `L(e₀)=0` normalisation. A
  different normalisation would give a multiple, which could explain the gap — see Open
  Questions.

### Not paper flaws — source artifacts

The shipped `.tex` is an OCR conversion with two classes of corruption, both resolved against
the PDF: (i) Table 3.1 exponents (`x^{2^2}`→`x^2`, `x^{2^3}`→`x^{23}`, etc.) — the
reproduction's `TABLE_3_1_RAW` matches the PDF exactly; (ii) Theorem 3.2's "`L` an
`F_{2^2}`-linear mapping" — the PDF (p. 10) reads "`F₂`-linear", which is what the
reproduction implements.

**No mathematical error was found in any paper item the reproduction implements.**

---

## Reproduction Issues

The previous revision listed 10 issues, all re-checked and confirmed: Section 2 entirely
unreproduced; Remark 3.6.2 unchecked; Theorem 4.1 not generalized; missing cross-validation
sweeps; undocumented OCR repair; dead `linearized_poly_lut`; stale `VBF API used` headers;
misleading `n ≥ 6` return shape; the `D_k` column unverified; Theorem 3.5 completeness
unasserted. Three are added here.

### 11. Example 3.3 at n=6 is wrongly declared infeasible

- **Location**: `theorem3_2.jl:53` (`if n <= 5`), `:87-90`, `:108-110`; the scope line at
  `helpers.jl:20`.
- **Symptom**: `theorem3_2_report(n=6)` prints "exhaustive count infeasible" and returns
  `(count=-1, expected=40000, match=false)`. Actual cost: `2³⁰ = 1,073,741,824` candidates,
  about **4 minutes** in C on 8 cores; a table-driven Julia version is comparable.
- **Root cause**: the inner check was written without hoisting `B_F(x, a+e₀)` — which depends
  only on `x ∈ T₀` and `a⊕e₀` — out of the candidate loop, making the naive cost look about
  1000× worse than it is.
- **Resolution plan**:
  1. Precompute `Btab[i][c] = x_i²·c + x_i·c²` for `x_i ∈ T₀`, `c ∈ GF(2ⁿ)` once
     (`2ⁿ⁻¹ × 2ⁿ` ints).
  2. Precompute the Frobenius table `fr[j][x] = x^{2^j}` and evaluate `L` on `T₀` once per
     candidate.
  3. Add `make theorem3_2 n=6 full_search=true`; assert the result is **35,648**, and record
     the discrepancy with the paper's "about 40 000" (paper issue 1).

### 12. Γ-rank is declared out of scope but is computable — and the claim is correct

- **Location**: `example4_2.jl:108`
  (`[loaded] Γ-rank(G) = 13842 ≠ Γ-rank(F) = 11818 (paper claim)`), `report.jl`'s note
  "`Γ-ranks out-of-scope (Magma)`", `helpers.jl:24`; and the core guard at
  `packages/VBF/src/invariants/design_ranks.jl:75-81` with its docstring at `:26-28`.
- **Symptom**: the paper's only stated inequivalence evidence for Example 4.2 is transcribed,
  never computed; the `n8_Taniguchi2025_ex4_2` catalog description asserts it is unverifiable.
- **Counter-evidence**: both were computed with a plain bit-packed F₂ Gaussian elimination on
  the `2¹⁶ × 2¹⁶` development matrix: **Γ-rank(x³) = 11818 in 81 s** and
  **Γ-rank(G) = 13842 in 85 s**, 512 MB peak. Both match the paper exactly. The tool was
  validated first against the repository's own documented value
  `gamma_rank(gold_apn(5,1)) = 330`.
- **Root cause**: `_design_rank_guard` refuses `N > 7` based on an over-pessimistic cost
  estimate ("hours"; the docstring at `:26-28` calls n=8 "impractical (≈512 MB) — the
  literature computes the latter with Magma").
- **Resolution plan**:
  1. Raise the guard to `N ≤ 8` with a documented ~90 s / 512 MB cost and a `Base.@warn`
     above n=7.
  2. Add `gamma_rank` assertions in `test/test_example4_2.jl`: `gamma_rank(G) == 13842`,
     `gamma_rank(SBox(F_lut)) == 11818`.
  3. Change `example4_2.jl:108` from `[loaded] … (paper claim)` to a computed `print_check`,
     and correct the `n8_Taniguchi2025_ex4_2` description in `n8_apn.toml`.

### 13. Remark 3.6.2 is confirmed but still unchecked in code

- **Location**: `table3_1.jl` — no Walsh check.
- **Symptom**: all 13 extended Walsh spectra were measured: `G₇` →
  `{0:828, 8:2944, 16:256, 32:4}`, i.e. values `{0, ±8, ±16, ±32}`; the other twelve →
  `{0:1008, 8:2688, 16:336}`, the classical spectrum. So `G₇` is indeed the unique
  non-classical one, exactly as Remark 3.6.2 states — a real gap with a real expected value.
- **Resolution plan**: add the assertion with those two literal spectra.

---

## Items Reproduced Exactly

| Paper item | File | Independent result |
|------------|------|--------------------|
| Field pinning | `helpers.jl:28-29` | `91 = x⁶+x⁴+x³+x+1` and `285 = x⁸+x⁴+x³+x²+1` — exactly the paper's moduli; α=2 primitive for both; both equal `conway_polynomial(6/8)` ✓ |
| **Table 3.1** (13 `L_i`) | `helpers.jl:121-135` | matches **PDF p. 12 exactly**, row by row, including the two rows with a genuinely absent `x^{2²}` term (`L₆`, `L₁₃`). All 13 `G_i = x³ + Tr(x)L_i(x)` are **du = 2, deg = 2**, with **13 distinct** ortho-derivative fingerprints ⇒ 13 EA classes ✓ |
| **Theorem 3.7 / Eq. (3.1)** | `theorem3_7.jl:20-48` | `2·LHS = 2·RHS = 62` for all 13 entries ✓ (the paper's Remark 3.8 confirmed). Also 0/400 disagreements between Eq. (3.1) and du=2 over random `L` |
| **Example 3.3**, n=4 / n=5 | `theorem3_2.jl:41-93` | **448** and **4608**, exactly; independently recomputed in C and shown invariant under both the modulus (19/25, 37/41) and the choice of `e₀` (8,9,10,11) ✓ |
| **Example 4.2** (n=8) | `example4_2.jl` | `β = α⁸⁵ = 214`, `β² = α¹⁷⁰ = 215`, `β²+β+1 = 0`; four cosets of size 64; **`A = {0, 1, 214, 215}`** exactly as the paper states; `a₁+a₂+a₃+a₄ = α⁸⁵ ∈ A`; `G` is **du = 2, deg = 2**; the closed form `G(x) = x³ + α⁸⁵·Tr₁⁸(x)·Tr₂⁸(x)` matches the coset construction **pointwise**; `G` and `x³` have **different** ortho-derivative fingerprints ⇒ EA-inequivalent, hence CCZ-inequivalent since both are quadratic ✓ |
| Catalog entry `n8_Taniguchi2025_ex4_2` | `n8_apn.toml:56-64` | its 256-entry `lut` is **byte-identical** to the independently computed `G` ✓ |

## Test Results

Executed with Julia 1.12.6 on 2026-08-15 (project instantiated and precompiled).

| | |
|---|---|
| Command | `make -C packages/VBFRepro/papers/2025/Taniguchi_202501 test` |
| Exit code | `0` |
| Wall time | 5 s |

| Testset | Pass | Broken | Fail | Total | Time |
|---------|-----:|-------:|-----:|------:|-----:|
| `theorem3_2_test` | 3 | 0 | 0 | 3 | 0.5s |
| `table3_1_test` | 28 | 0 | 0 | 28 | 2.1s |
| `theorem3_7_test` | 14 | 0 | 0 | 14 | 0.1s |
| `example4_2_test` | 5 | 0 | 0 | 5 | 0.5s |
| **Total** | **50** | **0** | **0** | **50** | — |

Additional targets run out-of-band (not part of `make test`):

| Command | Result |
|---------|--------|
| `make -C packages/VBFRepro/papers/2025/Taniguchi_202501 theorem3_7` | all 13 entries `HOLDS  2·LHS=62  2·RHS=62`, `[PASS] Eq.(3.1) holds for all 13 Table 3.1 entries` |
| `count_valid_L(4)` / `count_valid_L(5)` | `448` (0.3 s) / `4608` (10.4 s) — both exactly Example 3.3 |
| `theorem3_2_report(; n=6)` | prints `n=6: exhaustive count infeasible (N^(n-1) = 1073741824)`, returns `(n = 6, count = -1, expected = 40000, match = false)` |

Numbers marked *(C)* elsewhere in this file were originally derived out-of-repo in Python 3.13
/ C and have since been re-derived with the repository's own Julia API **except where noted** —
see reproduction issue 12, where the repo's own `gamma_rank` does **not** reproduce the C
result within budget.

## Catalog Status

| Claimed item | Status |
|--------------|--------|
| **Example 4.2, `G` on `F₂⁸`** | **present** — `n8_Taniguchi2025_ex4_2` in `packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml`. Its LUT was independently recomputed and is byte-identical. Formula reproduced ✓ / APN property verified ✓ / parameter family n/a (a single example) / novelty claim: the paper only asserts EA-inequivalence to `x³`, verified here two independent ways — the ortho-derivative fingerprint **and** Γ-rank 13842 ≠ 11818. **Full claim reproduced.** The entry's description should be corrected per reproduction issue 12 |
| **Table 3.1, `G₁…G₁₃` on `F₂⁶`** | **not-new / partially present.** These are the 13 known Dillon quadratic-APN EA classes in dimension 6, so no novelty is claimed. `n6_apn.toml` holds only 3 entries (`n6_Gold_x3`, `n6_Kasami_x48`, `n6_Kim`). The remaining ~10 classes are a **catalog completeness gap**, but the `G_i ↦ D_k` labelling cannot be verified until Dillon's representatives (paper ref [21, Table 4]) are in the repository. **No gap record emitted** — the mapping is an open question, and emitting `n6_Taniguchi2025_G*` names would wrongly imply novelty. Recommend adding Dillon's 13 representatives under their own `bib_key` first, then checking the correspondence with `apn_ea_mugshot`. All 13 `G_i` were confirmed pairwise EA-inequivalent, so they *are* a complete set of representatives |

Note: a related n=6 gap is recorded in `packages/VBFRepro/papers/2021/Calderini_202100/README.md`
(`n6_EdelPott_switch`); both point at the same underlying under-population of `n6_apn.toml`.

## Library-Reuse Note

- **Duplicating core**: `helpers.jl:57-64` `linearized_poly_lut` duplicates `VBF.terms_to_lut`
  (`packages/VBF/src/representations/univariate.jl:331`) — terms
  `[(coeffs[i+1], 1<<i) …]`. It is also **dead code** (never called). `helpers.jl:40-52`
  `linearized_poly_eval` is the pointwise version and *is* hot-path-justified (called about
  `10⁹` times in the n=5 search), so keep it but note the relationship.
- **Borderline, not violations**: `bilinear_form_gold` (`:69-73`), `trace_zero_elements` /
  `trace_one_element` (`:78-92`), `alpha_power` (`:115`), `build_g_lut` (`:97-110`),
  `paper_modulus` (`:31-35`) — all paper-specific or thin `gf_*` wrappers.
- **Promote-to-core candidates**:
  1. A generic polar form `B_F(x,a) = F(x+a)+F(x)+F(a)+F(0)` — core has none;
     `bilinear_form_gold` is the Gold-specialised version.
  2. `evaluate_terms(terms, x, n; modulus)` — a fast `(coeff, exponent)`-list *point*
     evaluator, since core offers only the string-parsing `evaluate_polynomial` and the
     whole-LUT `terms_to_lut`, neither usable inside a `10⁹`-call loop.
  3. Raising `gamma_rank` to n=8 (reproduction issue 12).

## Open Questions

- Did the authors count `L` *without* the `L(e₀)=0` normalisation at n=6? The gap between
  35,648 and "about 40 000" is 11 %, which a different normalisation might explain.
- Should Dillon's 13 dimension-6 quadratic-APN representatives be added to `n6_apn.toml`,
  unblocking the `D_k` column check?
