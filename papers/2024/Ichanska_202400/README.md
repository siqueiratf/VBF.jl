# Ichanska_202400 — Pushing the QAM Method for Finding APN Functions Further

**Paper**: Ichanska, Berg, Kaleyski, Yu. "Pushing the QAM method for finding APN functions
further."

**Reproduction path**: `papers/2024/Ichanska_202400/`

**Verdict**: Partial

Everything present is numerically correct — every assertion the reproduction makes was
independently confirmed. But coverage is thin: roughly 5 of ~25 reproducible paper items are
touched. One item (Lemma 1) uses a category definition that contradicts §3.2; one (Theorem 2)
verifies a strictly weaker statement than the one printed — and the printed one is **false**;
and two items declared "out of scope" (Appendix B Tables 10/11, and the Δ-rank) turn out to be
fully reproducible, and were reproduced during this review. The entire computational core of
the paper — matrix structures (11) and (20)–(23), Theorem 1, Algorithms 3 and 4, the submatrix
test, §4.5.1's Tables 2/3, and §5.4's matrices (25)/(26) — is absent, even though `VBF` already
ships a QAM API written *for this paper* that the reproduction never calls.

> **Environment note**: Julia is not installed in the review environment, so `make test` could
> not be executed (`make: julia: No such file or directory`, exit 127). Every load-bearing
> claim below was instead re-derived from the paper's definitions in pure Python (GF(2^n)
> arithmetic, DDT, ortho-derivative, Walsh/FWHT, F₂ ranks, orbit enumeration, design 2-ranks).

---

## Paper Issues

### P1. Theorem 2 (§3.4) is false as printed, for α ≠ 1

- **Location**: §3.4, Theorem 2 — "the matrix `M_{F′} = (M_{σ(i),σ(j)})` will be the derivative
  matrix of the equivalent function `F′ = F ∘ L`, where `L = αx^{2^s}`, for any `α ∈ F_{2^m}`".
- **Counter-evidence**: `n = 4`, modulus `x⁴+x+1`, normal element `b = a³ = 8`, `m = 2` so
  `F₄ = {0, 1, a⁵, a¹⁰}`. Take `F(x) = x⁵ = x^{2⁰+2²}` (coefficient `1 ∈ F₄`, so a legal member
  of the class (4)). For `α = a⁵` and `α = a¹⁰`, and for **every** `s ∈ {0,1,2,3}`,
  `M_{F∘αx^{2^s}} ≠ σ_s(M_F)`; in fact `M_{F′} = α⁵·σ_s(M_F) = α²·σ_s(M_F)`. For `F(x) = x³`
  the identity holds for all `α ∈ F₄` only because `α³ = 1` in `F₄`.
- **Root cause**: the proof's step "Since α is a constant in `F_{2^n}`, it can be factored out"
  is invalid — `ΔF(αa, αx) = Σ_{k<l} a_{k,l}·α^{2^k+2^l}(…)`, and the α-power varies from term
  to term, so it does not factor.
- **Correct statement**: the theorem holds verbatim for `α = 1` (verified for `x³` and `x⁵`
  over `F₁₆`, all `s`). Downstream uses (submatrix pruning, Tables 2 and 3) need only
  `s`-shifts, so the paper's *conclusions* survive.

### P2. Matrix (22), Appendix A.3, `(n,m) = (10,1)`: five wrong entries

The matrix must be symmetric and satisfy (6). Diffing against the canonical structure
(`M[i][j] = var_{(j−i) mod 10}` raised to `2^{i−1}`):

| position | printed | correct |
|---|---|---|
| (7,2) | `E^{2²}` | `E²` |
| (8,3) | `E^{2³}` | `E^{2²}` |
| (8,4) | `D^{2⁴}` | `D^{2³}` |
| (9,4) | `E^{2⁴}` | `E^{2³}` |
| (10,5) | `E^{2⁵}` | `E^{2⁴}` |

Each also breaks symmetry against its transpose partner ((2,7), (3,8), (4,8), (4,9), (5,10)).
Note (4,9) prints `E^{2⁸}`, which reduces correctly to `E^{2³}` since `E ∈ F_{2⁵}` — merely
non-reduced, not wrong.

### P3. Matrix (21), Appendix A.2, `(n,m) = (9,3)`: the K-entries are mutually inconsistent

- Positions {2,9}, {3,5}, {6,8} form a single 3-cycle under `(i,j) ↦ (i+3, j+3) mod 9`, so
  their exponents must be `e`, `e+3`, `e+6` (mod 9) — three *distinct* values. The paper prints
  `K^{2⁶}` at {2,9}, `K^{2³}` at {3,5}, `K^{2⁶}` at {6,8} — exponent 6 twice.
- **Counter-evidence**: building the derivative matrix of a random purely-quadratic `F` over
  `F_{2⁹}` with `F₈` coefficients in a normal basis (modulus `x⁹+x⁴+1`), and setting
  `K := M[3][5]^{2⁻³}`, the three entries are `K^{2⁰}`, `K^{2³}`, `K^{2⁶}` at {2,9}, {3,5},
  {6,8}. So positions (2,9)/(9,2) should read **K**, not `K^{2⁶}`.

### P4. Matrix (24), Appendix A.4: entry (6,2)

Printed `D^{2}`; must be `D^{2²}` (symmetry with (2,6) = `D^{2²}`, and (24) is the shift-by-1
of (23)). Verified: all other 99 entries of (24) agree exactly with the shift of (23).

### P5. §4.1's running-time arithmetic is 10× off

"255⁶ × 15² ≈ 6.19 × 10¹⁶" is correct (exactly 61 861 949 300 390 625). But
`6.19 × 10¹⁶ × 0.010 s` = **6.19 × 10¹⁴ s ≈ 19 602 869 years**, not "6.19 × 10¹⁵ seconds, or
196283612 years". The two quoted figures are consistent with each other but both a factor 10
too large.

### P6. Table 1, "Average number of orbits of C"

Exhaustive recomputation (`|L| = 24576`, full orbit tree to level 3):

| A | #orbits of B (paper) | computed | avg #C (paper) | computed |
|---|---|---|---|---|
| 1 | 8 | **8** | 22.1 | **23.125** |
| a | 30 | **30** | 56.7 | **57.700** |
| a⁷ | 22 | **22** | 43.5 | **44.500** |
| a¹⁷ | 14 | **14** | 41.5 | **32.500** |

Three of the four paper values equal exactly `(Σ_B #C − #C at B = A) / #B` — one term dropped
from the numerator but not the denominator. The `a¹⁷` row does not even match that formula
(which gives 31.5), so 41.5 looks like a digit typo for 31.5. All *per-branch* values stated in
the §4.1 text reproduce exactly: `B₁ = {1, a, a⁵, a⁷, a¹³, a¹⁷, a⁵¹, a⁸⁵}`, `#C_{1,a} = 30`,
`#C_{1,a^85} = 12`.

### P7. §4.4 vs §5.3/Table 7 disagree on the (10,1) level-1 representatives

§4.4 prints `𝒜 = {1, a, a⁷, a¹⁵, a³³, a⁵⁷, a⁹⁹, a³⁴¹}`; §5.3 and Table 7 print `a⁵`.
Exhaustive computation (modulus `x¹⁰+x⁶+x⁵+x³+x²+1 = 1135`, `|L| = 480` confirmed) gives
min-discrete-log representatives **{1, a, a⁵, a¹⁵, a³³, a⁵⁷, a⁹⁹, a³⁴¹}** with orbit sizes
1, 240, 480, 240, 15, 30, 15, 2. So §4.4's `a⁷` is the typo. (§5.3's prose also lists only 7 of
the 8, omitting `a³⁴¹`, while Table 7's header has 8 columns.)

### P8. §4.2, (8,4): "𝒜 = Cat₁ ∪ {a}" is a missed reduction — sound but not tight

`Cat₁ = {α : α + α^{2⁴} = 0} = F₁₆^*` has 15 elements, and **all 15 lie in one orbit**:
`l(x) = αx` is a linear polynomial with coefficient `α ∈ F_{2⁴}` and a permutation of `F_{2⁸}`,
mapping `1 ↦ α`. By Lemma 1, `Orb(1) ⊆ Cat₁`, hence `Orb(1) = Cat₁` exactly. Combined with
`Cat_Ind` being a single orbit (Theorem 1), the (8,4) first level has **2** candidates
`{1, a}`, not 16. Treating each `Cat₁` element as its own class keeps the search exhaustive, so
this is a performance loss rather than an error — but the paper does not say so.

### P9. Table 10 typesetting (presentation)

Rows 14/15, 23/24 and 26/27 are `\multirow` cells each holding two polynomials, leaving rows
"15", "24", "27" blank; the index → polynomial map is ambiguous on first read. Under the
natural reading (first line = lower index) all 27 are APN and match Table 11 index-for-index —
verified.

### P10. Table 5 and Table 10 #10 are different (but equivalent) polynomials

Table 5's `f(x) = a¹⁷⁰x¹⁹² + a¹⁷⁰x¹⁴⁴ + a⁸⁵x⁴⁸ + x³⁶ + a¹⁷⁰x²⁴ + a¹⁷⁰x¹⁸ + x¹² + x⁶` is exactly
the **square** of Table 10 entry #10 (verified pointwise over all 256 inputs), hence linearly
equivalent. The paper presents them as the same object without remark.

### P11. The (8,2) category decomposition (informational)

For `(n,m) = (8,2)` the disjoint decomposition (10) has exactly 4 parts, of sizes 192
(`Cat_Ind`), 48 (`a + a⁴ + a¹⁶ + a⁶⁴ = 0`), 12, and 3 (`= F₄^* = Cat₁`); 192 + 48 + 12 + 3 =
255. Recorded because the reproduction contradicts it — see issue 1.

---

## Reproduction Issues

### 1. Lemma 1 uses a category definition that contradicts §3.2

- **Location**: `lemma1.jl:16-25` (`compute_categories`), docstring at `:19`; test
  `tests/test_lemma1.jl:11`
- **Symptom**: test `lemma1_test` asserts `length(cat_ind) == 252` and the docstring claims
  "For (n=8, m=2): … Cat_Ind has 252 elements". The paper's `Cat_Ind^m` (§3.2) is the set of α
  whose `n/m` conjugates under `x ↦ x^{2^m}` are F₂-linearly independent. **Actual:
  `|Cat_Ind²| = 192`, not 252.** The 60-element remainder splits into a 48-element category
  (`ν = 15`: `a + a⁴ + a¹⁶ + a⁶⁴ = 0`) and a 12-element one (`ν ∈ {5,10,15}`).
- **Root cause**: only the single relation `Cat₁^m` (`α + α^{2^m} = 0`) is implemented; the
  paper defines one category per nonzero `ν ∈ F₂^{n/m}` and `Cat_Ind` as the complement of
  *all* of them. `VBF` already exports `independent_conjugate_elements(n, m)`
  (`packages/VBF/src/constructions/qam_search.jl:107`), which computes exactly `Cat_Ind^m` —
  unused.
- **Resolution plan**:
  1. Implement `categories(n, m)` enumerating all `ν ∈ F₂^{n/m}\{0}` and returning the disjoint
     decomposition (10).
  2. Define `Cat_Ind` via `VBF.independent_conjugate_elements(n, m)`.
  3. Fix the tests: `|Cat₁| = 3`, `|Cat_Ind| = 192`, `|Cat_{ν=15}| = 48`,
     `|Cat_{ν∈{5,10,15}}| = 12`, total 255.
  4. Strengthen `verify_lemma1_preservation` (`lemma1.jl:35-56`) to the actual Lemma-1 claim —
     every `l ∈ 𝓛` maps *each* category into itself — over all 24576 permutations, not 20/30
     samples.

### 2. Tables 10 and 11 declared unavailable, though printed in the paper and fully reproducible

- **Location**: `section5_1.jl:74-81`, `report.jl:26-27`
- **Symptom**: `print_kv(io, "Note on full 27-class classification", "Requires Simon-Berg
  thesis data (not available locally). …")` and `report.jl`'s scope line "out of scope : … all
  27 Simon-Berg reps (repo not available)". Only 1 of 27 classes is reproduced. **Actual: all
  27 Table 10 representatives are APN (differential uniformity 2), their ODDS match Table 11
  index-for-index for all 27 indices, and the 27 ODDS are pairwise distinct** — matching the
  paper's "27 unique ODDS". Every Table 11 row also satisfies
  `Σcounts = Σ δ·count = 255·256 = 65280`.
- **Root cause**: reference [1] (Berg's list of all 196863 functions) was conflated with
  Appendix B, which prints the 27 representatives *and* their ODDS in full.
- **Resolution plan**:
  1. Add `table10_representatives()` returning the 27 polynomial strings (usable directly with
     `polynomial_to_lut(..., 8, 285)`; the tokenizer maps `a` → generator 2 and `^` → `**`).
  2. Add `table11_odds()` with the 27 expected spectra.
  3. Assert `differential_uniformity == 2` and ODDS match for all 27.
  4. Assert the 27 ODDS are pairwise distinct.
  5. Restrict the "Simon-Berg" note to the 196863-function list and Table 6 only.

### 3. Δ-rank = 438 declared out of scope; it is computable

- **Location**: `section5_1.jl:78-80`; underlying guard
  `packages/VBF/src/invariants/design_ranks.jl:64-81`
- **Symptom**: `print_kv(io, "Δ-rank = 438", "out of scope (n=8 needs ~512 MB — not supported
  in VBF.jl)")`. **Actual: Δ-rank = 438**, exactly Table 5. `Δ-rank ≤ 2^{n+1} = 512`, so at
  most 512 pivot rows of `2^{2n} = 65536` bits ≈ 4 MB are ever live; generating the translate
  module of `χ_{D_F}` under the `2n = 16` generators terminates after 438 pivots.
  `|D_F| = 32640`.
- **Root cause**: `_design_2rank` (`design_ranks.jl:64`) materialises all `2^{2n}` rows up
  front, and `_design_rank_guard` (`:75`) refuses `n ≥ 8` for *both* ranks; the paper file
  inherited the blanket message.
- **Resolution plan**:
  1. Add a rank-bounded Δ-rank path in core (module-closure elimination over the `2n` translate
     generators, keeping ≤ `2^{n+1}` pivots) and relax the guard for `delta_rank` to `n ≤ 8`.
  2. Assert `delta_rank(new_function_n8_m2()) == 438`.
  3. Keep Γ-rank (14034) and `|𝓜(G_F)|` (3072) out of scope, but state the real reason: Γ-rank
     needs ≈14034 pivots × 8 KB ≈ 115 MB plus 65536 eliminations, and the automorphism-group
     order needs a design-automorphism solver the repo lacks.

### 4. Theorem 2 verified only for α = 1, only for Gold `x³` at n = 4

- **Location**: `theorem2.jl:24-41` (`verify_theorem2`) and `:55-62`; pseudocode comment at
  `theorem2.jl:8`
- **Symptom**: the file's own pseudocode says "For `s ∈ {1,…,n−1}` and `α ∈ F₂ᵐ`, define
  `F′(x) = F(α x^{2^s})`", but the code builds `Fprime = x^(3*(1<<s))`, i.e. `α = 1` only.
  `verify_theorem2()` therefore returns `true` for a statement strictly weaker than the paper's
  — and the paper's statement is **false** (P1: `n = 4, m = 2, F = x⁵, α = a⁵` ⇒
  `M_{F′} = α²·σ_s(M_F) ≠ σ_s(M_F)`, for every `s`). `m` is never even a parameter of the test.
- **Root cause**: α was silently dropped in translation.
- **Resolution plan**:
  1. Parameterise the check by `(n, m, F, α, s)`.
  2. Add the `α ≠ 1` case and record it as a counterexample to Theorem 2 as literally stated.
  3. Assert the corrected statement (`α = 1`; or "`M_{F′} = λ·σ_s(M_F)` when all nonzero
     `a_{k,l}` share the same `α^{2^k+2^l}`").
  4. Test at `(n,m) = (8,2)` and `(10,2)` with a genuine subfield-coefficient quadratic, not
     only Gold `x³` at `n = 4`.

### 5. `_row_combo_rank` hardcodes 8-bit field elements

- **Location**: `theorem3.jl:41-47`
- **Symptom**: `bits = zeros(UInt8, 8 * sizeof(Int), n)` followed by `for bit in 0:7` — only
  the low 8 bits of each `GF(2ⁿ)` entry are read. Correct for the exercised case (`n = 4`),
  **silently wrong for `n ≥ 9`**, i.e. for the paper's (9,3), (10,1) and (10,2) cases. Rows
  9…64 are permanently zero, so `_f2_rank` also does ~8× redundant work.
- **Root cause**: literal `8` where `n` was meant.
- **Resolution plan**:
  1. Replace `0:7` with `0:n-1` and size the matrix `n × n`; **or**
  2. delete `_f2_rank`/`_row_combo_rank` and call `VBF.rank_f2`
     (`packages/VBF/src/linalg/f2_arith.jl:90`).
  3. Extend `verify_theorem3` to `(n,m) = (10,2)` on the paper's matrix (26). Independently
     confirmed: all 1023 nonzero row-subsets satisfy `rank(Σαᵢrᵢ) = rank(Σαᵢr_{i+2})`, min rank
     = 9 = `n−1`, and the shift-orbit reduction leaves 207 of 1023 subsets (79.8 % fewer).

### 6. Theorem 1 (§3.2) is not implemented at all

- **Location**: absent; `report.jl:23-27` lists only Theorem 2, Theorem 3, Lemma 1,
  Algorithm 1, §5.1, §5.3
- **Symptom**: Theorem 1 is the paper's central enabling result (abstract: "an innovative
  approach for computing orbit partitions for cases where it is infeasible … resulting in the
  applications for `(n,m) = (8,4)` and `(9,3)`"). Nothing references it.
  `VBF.independent_conjugate_elements` exists and is documented as this theorem.
- **Root cause**: scope choice.
- **Resolution plan**:
  1. Add `theorem1.jl` computing `Cat_Ind^m` via `independent_conjugate_elements`.
  2. Verify Theorem 1 exhaustively at (8,2) and (10,2), where all of `𝓛` is enumerable: for
     every `α, β ∈ Cat_Ind^m` check "∃ linear `l` with `F_{2^m}` coefficients, `l(α) = β`" ⟺
     "∃ linear *permutation* `l′` with `F_{2^m}` coefficients, `l′(α) = β`".
  3. Derive and assert the (8,4) consequence `𝒜 = {1, a}` (P8).

### 7. §4.1's quantitative results are not asserted, and the report text misstates `|𝓛|`

- **Location**: `algorithm1.jl:80-90`, `:112`, `:118-121`; `tests/test_algorithm1.jl:14-16`
- **Symptom**: the test only checks "4 orbits" and "reps = {1, a, a⁷, a¹⁷}". `|𝓛| = 24576`
  (§4.1) is printed but never asserted. Worse, `algorithm1.jl:112` says "4^8 = 65536 maps" and
  `:121` says "exhaustive enumeration of all 65536 F₂²-coefficient linear maps" — conflating
  the 65536 candidate linear **maps** with the 24576 linear **permutations** that constitute
  `𝓛`. §4.1's `B₁`, `#C_{1,a} = 30`, `#C_{1,a^85} = 12` and Table 1 are absent.
- **Actual** (all confirmed): `|𝓛| = 24576`; level-1 reps `{1, a, a⁷, a¹⁷}` with orbit sizes
  3/192/48/12; `|𝓛_A| = 8192/128/512/2048`; `B₁ = {1, a, a⁵, a⁷, a¹³, a¹⁷, a⁵¹, a⁸⁵}`;
  `#C_{1,a} = 30`; `#C_{1,a^85} = 12`; `#B = 8/30/22/14`.
- **Root cause**: the reproduction stops at the level-1 partition; Algorithm 3 (`classORB`) is
  never implemented.
- **Resolution plan**:
  1. Implement Algorithm 3 as `class_orb(Ω, 𝓛) -> (reps, 𝓛_Ω)`.
  2. Assert `length(perms) == 24576`.
  3. Assert `B₁ == {1, a, a⁵, a⁷, a¹³, a¹⁷, a⁵¹, a⁸⁵}`.
  4. Assert `#C_{1,a} == 30` and `#C_{1,a^85} == 12`.
  5. Reproduce Table 1's `#B` column (8, 30, 22, 14) and print the exact averages
     23.1/57.7/44.5/32.5 alongside the paper's 22.1/56.7/43.5/41.5 (P6).
  6. Fix the "65536 maps" wording at `:112` and `:121`.

### 8. §4.4, §4.5 and §5.4 not reproduced although cheap

- **Location**: absent (no `section4_4.jl`, `section4_5.jl`, `section5_4.jl`)
- **Symptom**: nothing computes `|𝓛| = 480` for (10,1) (only `2¹⁰ = 1024` candidate maps), the
  (10,1) representatives, `|𝓛| = 367200` for (10,2), `𝒜 = {1, a, a⁵}`, or any of F (18), `l`,
  F′ (19), (25), (26).
- **Actual** (all confirmed in seconds-to-minutes): `|𝓛|₍₁₀,₁₎ = 480`; reps
  `{1, a, a⁵, a¹⁵, a³³, a⁵⁷, a⁹⁹, a³⁴¹}` (P7); `|𝓛|₍₁₀,₂₎ = 367200`; `𝒜 = {1, a, a⁵}` with
  orbit sizes 3/255/765; `F(18) = x²⁸⁸ + a⁶⁸²x⁹⁶ + a³⁴¹x⁹ + x³` has differential uniformity 2;
  `a⁴⁸⁶` is a normal element; matrix (25) matches the computed derivative matrix in **all 90
  off-diagonal entries**; `l` is a permutation and maps `a⁷¹⁹↦a⁵`, `a⁸⁵¹↦a³⁵⁸`, `a¹⁴⁶↦a¹⁰`;
  `l∘F(18)` equals `F′(19)` pointwise; matrix (26) matches in **all 90 entries**.
- **Root cause**: scope choice.
- **Resolution plan**: add the three files asserting the above; use
  `conway_polynomial(10) == 1135` (already the paper's primitive polynomial) and the paper's
  normal elements `a⁸⁰⁵` / `a⁴⁸⁶` rather than `find_normal_element`.

### 9. Derivative-matrix structures (11), (20)–(23) missing; `VBF`'s QAM API unused

- **Location**: `helpers.jl:53-63` has only `normal_basis_deriv_matrix`; nothing builds `M`
  from the free variables
- **Symptom**: the paper's central objects — (11) with A…H (`D, H ∈ F₁₆`), (20) with A…P
  (`D, J, N, P ∈ F₁₆`), (21) with A…L, (22) with A…E (`E ∈ F₃₂`), (23) with A…I — are never
  constructed. `VBF` exports `qam_cyclic_orbits(n,m)` and `qam_from_cyclic(n,m,values)`
  (`packages/VBF/src/constructions/qam_search.jl:47,77`) which generate exactly these, plus
  `is_qam`, `qam_to_sbox`, `cyclic_qam_subset_representatives`; none is called from the paper
  directory.
- **Actual**: the orbit counts confirm the paper's variable counts — (8,2) → 8 vars, two of
  orbit-length 2 forcing `D, H ∈ F₁₆`; (8,4) → 16 vars, four fixed forcing `D, J, N, P ∈ F₁₆`;
  (9,3) → 12; (10,1) → 5 with `E ∈ F₃₂`; (10,2) → 9. Symbolic consistency check: **(11), (20)
  and (23) consistent; (21) has 4 defects (P3); (22) has 5 defects (P2); (24) has 1 defect
  (P4).**
- **Root cause**: scope choice, compounded by unawareness of the core QAM API.
- **Resolution plan**:
  1. Build (11)/(20)/(21)/(22)/(23) with `qam_cyclic_orbits` + `qam_from_cyclic` and assert the
     variable counts and subfield constraints.
  2. Diff the generated structures against the paper's printed matrices and record P2/P3/P4.

### 10. §4.5.1 (Table 2, Proposition 4, Table 3) missing

- **Location**: absent
- **Symptom**: no file mentions "equivalence on the right", `DerMatr`, Proposition 4, or
  Tables 2/3.
- **Actual** (all confirmed): Table 2's nine rows follow symbolically from (23) by cyclic shift
  — **all 9 match exactly**. Instantiating (26)'s values (`A = a⁵, B = a³⁵⁸, C = a¹⁰,
  D = a²⁷⁵, E = a²¹⁵, F = a⁶⁵⁹, G = a⁶⁵¹, H = a²²⁵, I = a¹¹`) into each of (14), (15), (16),
  (17) and into every Table 3 entry yields a function with differential uniformity 2 and the
  **same ODDS as F′** — 9/9 pass.
- **Root cause**: scope choice.
- **Resolution plan**: add `section4_5_1.jl` implementing `DerMatr(A,…,I)` over structure (23),
  asserting Table 2 symbolically and Proposition 4 / Table 3 numerically on the (26) instance.

### 11. Algorithm 4 (Estimate Tree Size, §3.3) missing

- **Location**: absent
- **Symptom**: the tree-size estimator that decides when the orbit tree is affordable has no
  counterpart.
- **Root cause**: scope choice.
- **Resolution plan**: implement `estimate_ts(𝓛, level, nvars, max_classes)` per the paper's
  pseudocode with the stated threshold `max_classes = 2^{n-1} + 2^{n-2}`, and demonstrate it on
  the (8,2) orbit tree, which is fully enumerable.

### 12. Submatrix test (§3.4, Definition 3.1 "proper") missing

- **Location**: absent from the paper directory; `VBF` has an unexported closure `proper`
  inside `search_qam_full` (`packages/VBF/src/constructions/qam_search.jl:317-332`)
- **Symptom**: the paper's claim "`M_F` is QAM if and only if for every `1 ≤ p,q ≤ n` every
  submatrix `S ∈ F_{2^n}^{p×q}` is proper" and its use for branch pruning are untouched.
- **Root cause**: the primitive exists in core but is private.
- **Resolution plan**:
  1. Promote `proper` to a `VBF` export (every nonzero F₂-combination of the `p` rows of a
     `p×q` submatrix has rank ≥ `q−1`).
  2. Reproduce the iff-claim exhaustively at small `(n, m)`.
  3. Reproduce Table 7's "number of orbits B that passed the submatrix test" row
     (0, 746, 1012, 753, 71, 112, 78, 8) for (10,1) if affordable.

### 13. `section5_3.jl` asserts less than its completeness string claims

- **Location**: `section5_3.jl:11`, `:52`, `:85-87`; `tests/test_section5_3.jl`
- **Symptom**: the completeness string reads "exact (3 representatives APN + pairwise
  CCZ-distinct via ODDS …)". The ODDS argument is sound (CCZ = EA for quadratic APN by
  Yoshiara; the ortho-derivative is EA-covariant), but nothing checks that the three functions
  are quadratic, nor that they belong to the (10,1) family (F₂ coefficients in a normal basis /
  derivative matrix of form (22)). `:52` prints "577 quadratic APN functions" with no
  supporting check.
- **Actual** (confirms the three representatives): modulus 1135, `a = 2` — `x³`: du 2, ODDS
  `[0^595386, 2^416361, 6^35805]`; `x⁹`: du 2, ODDS
  `[0^713031, 2^211761, 4^92070, 6^15345, 8^5115, 12^10230]`; `x³ + a⁻¹Tr(a³x⁹)`: du 2, ODDS
  `[0^630216, 2^327081, 4^76215, 6^12150, 8^1665, 10^195, 12^30]`. Pairwise distinct.
- **Root cause**: the completeness string was written for a broader check than the code
  performs.
- **Resolution plan**:
  1. Assert `algebraic_degree == 2` for all three.
  2. Either assert each has a derivative matrix of form (22) in a suitable normal basis, or
     state plainly that membership in the (10,1) family is not checked.
  3. Label the 577-function count and Table 7 explicitly "not reproduced (months of compute)".

### 14. `section5_1.jl` inverts a paper claim

- **Location**: `section5_1.jl:76-77`
- **Symptom**: "All 196863 found APN functions verified pairwise CCZ-inequivalent via ODDS."
  §5.1 says the opposite: functions with **equal** ODDS were tested with the Edel–Pott test [9]
  and found CCZ-**equivalent**; the 196863 functions collapse into 27 classes. (Table 6 is
  internally consistent: 3360 + 144379 + 40720 + 8404 = 196863.)
- **Root cause**: misreading of §5.1.
- **Resolution plan**: reword to "the 196863 functions fall into 27 ODDS buckets; within each
  bucket CCZ-equivalence was confirmed by the Edel–Pott test [9]".

### 15. Minor robustness and hygiene

- **Location / symptom**:
  - `section5_1.jl:52` and `tests/test_section5_1.jl:12` index `ds.counts[k]` directly;
    `Spectrum.counts` is a `Dict{Int,Int}`
    (`packages/VBF/src/representations/spectrum.jl:37-39`), so a missing key raises `KeyError`
    instead of failing the assertion. Use `get(ds.counts, k, 0)`.
  - `helpers.jl:93` and `lemma1.jl:45` call `collect(coeffs)` **inside** the inner `x` loop —
    255 allocations per coefficient tuple × 65536 tuples ≈ 1.7 × 10⁷ needless allocations.
    Hoist the `collect` out.
  - `lemma1.jl:41-54` re-inlines the body of `linear_perms_subfield` (`helpers.jl:85-98`)
    instead of calling it.
  - `helpers.jl:100-114` (`orbit_partition`) and `algorithm1.jl:23-33` (`findlinear`) are the
    same routine written twice.
  - The reproduction uses `tests/` where every other paper uses `test/`.
- **Resolution plan**: apply each fix above; rename `tests/` → `test/`.

---

## Items Reproduced Exactly

1. **Table 5 — the new (8,2) APN function** (`section5_1.jl:27-30`).
   `F(x) = a¹⁷⁰x¹⁹² + a¹⁷⁰x¹⁴⁴ + a⁸⁵x⁴⁸ + x³⁶ + a¹⁷⁰x²⁴ + a¹⁷⁰x¹⁸ + x¹² + x⁶` over `GF(2⁸)`
   mod 285 (the paper's `x⁸+x⁴+x³+x²+1`), `a = 2`:
   - differential uniformity = **2**
   - ODDS = **[0³⁸¹⁹⁶, 2²²⁰⁰⁸, 4⁴⁶⁰⁸, 6⁴⁵⁶, 8¹²]** = Table 11 index 10
   - Walsh spectrum = **[−32²³⁸⁰, −16²⁰⁴⁰⁰, 0¹⁶³²⁰, 16²³¹²⁰, 32³⁰⁶⁰]** = Table 5
   - `𝒩𝓛 = 112`; not a permutation; algebraic degree 2
2. **Algorithm 1 / Algorithm 2 at (8,2) level 1** (`algorithm1.jl:23-56, 80-90`). 4 orbits,
   representatives `{1, a, a⁷, a¹⁷}` (`|𝓛| = 24576`, printed but not asserted — issue 7).
3. **Theorem 3 (§3.5)** (`theorem3.jl:57-69`), at `n = 4`. Independently confirmed at the
   paper's own scale too: on matrix (26), `(n,m) = (10,2)`, all 1023 nonzero row-subsets
   satisfy `rank(Σαᵢrᵢ) = rank(Σαᵢr_{i+2})`, min rank = 9 = `n−1`.
4. **Theorem 2 restricted to α = 1** (`theorem2.jl:24-41`). Correct as tested; the general-α
   claim is a *paper* defect (P1).
5. **§5.3's three CCZ classes** (`section5_3.jl:37-47`). `x³`, `x⁹` and
   `x³ + a⁻¹Tr₁₀(a³x⁹)` are all APN over `F_{2¹⁰}` with pairwise distinct ODDS.
6. **Field conventions.** `conway_polynomial(8) = 285` equals §4.1's `x⁸+x⁴+x³+x²+1` and
   `conway_polynomial(10) = 1135` equals §4.4's `x¹⁰+x⁶+x⁵+x³+x²+x+1`; 2 is primitive in both.
   The reproduction's basis choice is faithful.

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2024/Ichanska_202400 test` | **Cannot run** — `make: julia: No such file or directory`, `make: *** [Makefile:11: test] Error 127` |

Because the repo's own entry point cannot run, every load-bearing claim was re-derived
independently in pure Python. Results:

| Claim (paper location) | Result |
|---|---|
| Table 5 function: du = 2, ODDS, Walsh spectrum, NL = 112 | **all match** |
| Table 5: Δ-rank = 438 | **438 — match** |
| Table 5: Γ-rank = 14034, `\|𝓜(G_F)\|` = 3072 | **not verified** (infeasible in Python) |
| Tables 10 (27 reps) × 11 (27 ODDS), Appendix B | **27/27 APN, 27/27 ODDS match, all 27 pairwise distinct** |
| Table 6: 3360+144379+40720+8404 = 196863 | **match** |
| §4.1 `\|𝓛\|` = 24576 | **match** |
| §4.1 `𝒜 = {1, a, a⁷, a¹⁷}` | **match** |
| §4.1 `ℬ₁ = {1,a,a⁵,a⁷,a¹³,a¹⁷,a⁵¹,a⁸⁵}` | **match** |
| §4.1 `#𝒞_{1,a} = 30`, `#𝒞_{1,a^85} = 12` | **match** |
| Table 1 #orbits of B = 8/30/22/14 | **match** |
| Table 1 avg #C = 22.1/56.7/43.5/41.5 | **mismatch → 23.1/57.7/44.5/32.5** (P6) |
| §4.1 timing 6.19×10¹⁵ s / 196283612 yr | **mismatch → 6.19×10¹⁴ s / 1.96×10⁷ yr** (P5) |
| §4.4 `\|𝓛\|` = 480 | **match** |
| §4.4/§5.3/Table 7 first-level reps | **{1,a,a⁵,a¹⁵,a³³,a⁵⁷,a⁹⁹,a³⁴¹}** — §5.3/Table 7 correct, §4.4 wrong (P7) |
| §4.5 `\|𝓛\|` = 367200, `𝒜 = {1,a,a⁵}` | **match** |
| (18) `F(x) = x²⁸⁸+a⁶⁸²x⁹⁶+a³⁴¹x⁹+x³` APN | **du = 2** |
| Matrix (25), normal element `a⁴⁸⁶` | **all 90 off-diagonal entries match** |
| `l` maps `a⁷¹⁹↦a⁵, a⁸⁵¹↦a³⁵⁸, a¹⁴⁶↦a¹⁰`; `l∘F(18) = F′(19)` | **match** |
| Matrix (26) | **all 90 off-diagonal entries match** |
| Table 2 (9 rows, equivalence on the right) | **9/9 match symbolically** |
| Proposition 4 (14)–(17) + Table 3 + `M^s` | **9/9 give APN with ODDS = ODDS(F′)** |
| Matrix (11), (8,2) structure | **consistent** |
| Matrix (20), (8,4) structure | **consistent** |
| Matrix (21), (9,3) structure | **4 defects** (P3) |
| Matrix (22), (10,1) structure | **5 defects** (P2) |
| Matrix (23), (10,2) structure | **consistent** |
| Matrix (24) vs shift of (23) | **1 defect** (P4) |
| §5.3 three classes APN + distinct ODDS | **match** |
| Theorem 2 for α ≠ 1 | **false** — counterexample found (P1) |
| Theorem 3 on (26), (10,2) | **holds for all 1023 subsets**; shift-orbit reduction 1023 → 207 |

## Catalog Status

### The (8,2) function of Table 5 / Table 10 index 10 → **missing**

Verification level: **full claim reproduced** for the function itself, except the Γ-rank and
automorphism-group invariants. Formula reproduced; APN property verified (differential
uniformity 2 from the full DDT); no parameter family to validate (a single explicit function);
novelty checked against the shipped `n = 8` catalog, though not against the whole literature.

ODDS is a CCZ-invariant for quadratic APN functions (CCZ = EA by Yoshiara; the ortho-derivative
is EA-covariant), so distinct ODDS ⇒ CCZ-inequivalent:

| catalog entry | alg. degree | ODDS | vs. new function |
|---|---|---|---|
| `n8_Gold_x3` | 2 | `[0³⁹⁷⁸⁰, 2²¹⁹³⁰, 6³⁵⁷⁰]` (= Table 11 #26) | **distinct** |
| `n8_Gold_x9` | 2 | `[0³⁵⁷⁰⁰, 2²⁶⁵²⁰, 4³⁰⁶⁰]` (= Table 11 #1) | **distinct** |
| `n8_Kasami_x57` | 4 | n/a (not quadratic) | **EA-inequivalent** (degree 2 vs 4); CCZ-inequivalent by Yoshiara 2016 (a power APN CCZ-equivalent to a quadratic APN must be EA-equivalent to a Gold function, which `x⁵⁷` is not) |
| `n8_Calderini2021_thm62` | 2 | `[0³⁹¹⁵⁰, 2²⁰⁴⁶³, 4⁴⁹²⁰, 6⁶⁷⁵, 8⁵⁴, 10¹², 12⁶]` | **distinct** |
| `n8_Taniguchi2025_ex4_2` | 2 | `[0³⁸⁵⁹², 2²¹⁴²⁶, 4⁴⁵⁹⁰, 6⁶⁵⁴, 8¹⁸]` (= Table 11 #12) | **distinct** |
| **new function** | 2 | `[0³⁸¹⁹⁶, 2²²⁰⁰⁸, 4⁴⁶⁰⁸, 6⁴⁵⁶, 8¹²]` (= Table 11 #10) | — |

Additional supporting invariants: Walsh spectrum
`[−32²³⁸⁰, −16²⁰⁴⁰⁰, 0¹⁶³²⁰, 16²³¹²⁰, 32³⁰⁶⁰]`, nonlinearity 112, Δ-rank 438, not a
permutation.

### Catalog-gap record

```
target file : packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml
name              = "n8_Ichanska2024_new"
n                 = 8
m                 = 8
is_permutation    = false
algebraic_form    = "a^170*x^192 + a^170*x^144 + a^85*x^48 + x^36 + a^170*x^24 + a^170*x^18 + x^12 + x^6 in GF(2^8), modulus x^8 + x^4 + x^3 + x^2 + 1 (=285), a = generator (x)"
bib_key           = "Ichanska_202400"
source            = "Ichanska, Berg, Kaleyski, Yu, 'Pushing the QAM method for finding APN functions further', Section 5.1 Table 5 (invariants) and Appendix B Table 10 index 10 (bold, given there in the linearly-equivalent form a^85*x^96 + a^85*x^72 + a^170*x^24 + x^18 + a^85*x^12 + a^85*x^9 + x^6 + x^3, whose square is the form stored here). Found by an exhaustive QAM search over quadratic functions on GF(2^8) with coefficients in GF(4)."
lut               = [0, 215, 232, 33, 96, 120, 14, 8, 144, 82, 78, 146, 205, 192, 149, 134, 238, 181, 115, 54, 97, 245, 122, 240, 8, 70, 163, 243, 186, 59, 151, 8, 249, 82, 227, 86, 41, 77, 181, 207, 82, 236, 126, 222, 191, 206, 21, 122, 149, 178, 250, 195, 170, 66, 67, 181, 72, 122, 17, 61, 74, 183, 149, 118, 111, 170, 115, 168, 68, 78, 222, 202, 245, 37, 223, 17, 227, 252, 79, 78, 115, 58, 26, 77, 183, 49, 88, 192, 159, 195, 192, 130, 102, 245, 191, 50, 186, 3, 84, 243, 33, 87, 73, 33, 27, 183, 195, 113, 189, 222, 227, 158, 36, 17, 191, 148, 80, 170, 77, 169, 243, 211, 94, 96, 186, 85, 145, 96, 130, 205, 27, 74, 41, 169, 54, 168, 206, 148, 97, 37, 88, 205, 113, 250, 126, 189, 146, 79, 58, 54, 80, 66, 68, 146, 158, 86, 61, 36, 97, 102, 41, 26, 66, 111, 50, 206, 223, 61, 94, 120, 3, 59, 120, 145, 163, 84, 87, 232, 73, 232, 163, 211, 59, 85, 86, 252, 126, 202, 159, 250, 49, 74, 72, 21, 37, 102, 168, 58, 67, 207, 14, 70, 85, 3, 211, 84, 14, 151, 70, 151, 94, 145, 73, 87, 215, 215, 118, 178, 88, 130, 68, 79, 236, 249, 207, 238, 80, 111, 159, 113, 134, 118, 178, 134, 27, 49, 223, 36, 240, 21, 67, 238, 169, 26, 252, 158, 144, 236, 72, 240, 148, 50, 202, 189, 144, 249]
```

Equivalence evidence to record in `description`: differential uniformity 2 and algebraic
degree 2 (re-verified); ortho-derivative differential spectrum
`[0^38196, 2^22008, 4^4608, 6^456, 8^12]`, which differs from every quadratic `n = 8` catalog
entry; ODDS is a CCZ-invariant for quadratic APN (CCZ = EA, Yoshiara 2012), so all four are
CCZ-inequivalent. `n8_Kasami_x57` has algebraic degree 4, hence EA-inequivalent, and
CCZ-inequivalent by Yoshiara 2016. Δ-rank = 438 and the Walsh spectrum match Table 5 of the
source. Γ-rank 14034 and `|𝓜(G_F)| = 3072` from the paper are **not** verified in-repo (the
`n ≤ 7` design-rank guard, `packages/VBF/src/invariants/design_ranks.jl:75`).

If the equivalent `x³`-containing form of Table 10 #10 is preferred instead, its LUT is:

```
[0, 214, 109, 47, 38, 53, 144, 23, 88, 137, 152, 221, 64, 84, 91, 219, 234, 117, 166, 173, 39, 125, 176, 126, 23, 143, 246, 250, 228, 185, 222, 23, 104, 137, 254, 139, 56, 28, 117, 197, 137, 111, 178, 192, 231, 196, 7, 176, 91, 243, 236, 208, 224, 141, 140, 117, 31, 176, 5, 62, 154, 240, 91, 165, 183, 224, 166, 101, 10, 152, 192, 198, 125, 45, 193, 5, 254, 107, 153, 152, 166, 184, 150, 28, 240, 43, 27, 84, 201, 208, 84, 217, 161, 125, 231, 175, 228, 132, 14, 250, 47, 138, 30, 47, 151, 240, 208, 35, 98, 192, 254, 200, 44, 5, 231, 90, 12, 224, 28, 100, 250, 212, 156, 38, 228, 15, 89, 38, 217, 64, 151, 154, 56, 100, 173, 101, 196, 90, 39, 45, 27, 64, 35, 236, 178, 98, 221, 153, 184, 173, 12, 141, 10, 221, 200, 139, 62, 44, 39, 161, 56, 150, 141, 183, 175, 196, 193, 62, 156, 53, 132, 185, 53, 89, 246, 14, 138, 109, 30, 109, 246, 212, 185, 15, 139, 107, 178, 198, 201, 236, 43, 154, 31, 7, 45, 161, 101, 184, 140, 197, 144, 143, 15, 132, 212, 14, 144, 222, 143, 222, 156, 89, 30, 138, 214, 214, 165, 243, 27, 217, 10, 153, 111, 104, 197, 234, 12, 183, 201, 35, 219, 165, 243, 219, 151, 43, 193, 44, 126, 7, 140, 234, 100, 150, 107, 200, 88, 111, 31, 126, 90, 175, 198, 98, 88, 104]
```

### Cross-reference findings (not gaps, but worth recording in existing entries)

- `n8_Taniguchi2025_ex4_2`'s ODDS equals **Table 11 index 12** exactly — Taniguchi–Polujan–
  Pott–Arshad Example 4.2 falls in Ichanska et al.'s (8,2) class #12 (representative
  `a¹⁷⁰x¹⁴⁴ + a⁸⁵x¹³² + x⁷² + a¹⁷⁰x⁴⁸ + a¹⁷⁰x²⁴ + x¹⁸ + a¹⁷⁰x¹² + x³`). Consistent — that
  function's coefficients lie in `F₄` — and it gives an independent literature anchor for the
  entry.
- `n8_Gold_x3` = Table 11 index **26**; `n8_Gold_x9` = Table 11 index **1**.
- The other 26 Table 10 representatives are all **absent** from `n8_apn.toml`. The paper does
  not claim them as new (they come from Berg's thesis / prior work), so they are **not** catalog
  gaps under a strict reading — but adding them would give the repo the complete (8,2)
  classification with verifiable ODDS. Recommended as an optional bulk addition with a "novelty
  not asserted" caveat.

## Library-Reuse Note

Helpers duplicating `VBF` core exports:

| helper (`file:line`) | duplicates | notes |
|---|---|---|
| `theorem3.jl:16-31` `_f2_rank` | `rank_f2` (`packages/VBF/src/linalg/f2_arith.jl:90`) | straight reimplementation; also carries the 8-bit bug (issue 5) |
| `theorem3.jl:33-48` `_row_combo_rank` bit-extraction | `rank_f2` | see issue 5 |
| `helpers.jl:29-47` `find_normal_element._is_normal` | `rank_f2` | inline F₂ Gauss–Jordan |
| `helpers.jl:53-63` `normal_basis_deriv_matrix` | `quadratic_apn_matrix` (`packages/VBF/src/constructions/qam.jl:30`) | identical up to the choice of basis |
| `section5_3.jl:20-28` `_gf_trace10` | `gf_trace` | hardcoded `n = 10` |
| `section5_1.jl:56-58` manual nonlinearity | `nonlinearity` / `linearity` | `128 - max_w ÷ 2` reimplements the export |
| `algorithm1.jl:23-33` `findlinear` vs `helpers.jl:100-114` `orbit_partition` | each other | internal duplication; keep one |
| `lemma1.jl:41-54` | `helpers.jl:85-98` `linear_perms_subfield` | body re-inlined instead of called |

**Core available but not reused at all.** None of the following is called from
`papers/2024/Ichanska_202400/`, despite all of them being written for this exact paper
(`packages/VBF/src/constructions/qam.jl:3` and `qam_search.jl:3` both `@cite Ichanska_202400`):
`is_qam`, `quadratic_apn_matrix`, `qam_to_sbox`, `qam_cyclic_orbits`, `qam_from_cyclic`,
`independent_conjugate_elements` (= Theorem 1's `Cat_Ind`), `cyclic_qam_subset_representatives`
(= Theorem 3's reduction), `search_qam`, `search_qam_full`; plus `delta_rank`, `gamma_rank`,
`nonlinearity`, `gf_trace`, `rank_f2`, `algebraic_degree`, `are_ccz_equivalent`,
`apn_ea_mugshot`.

Legitimately paper-specific (not flagged): `cyclic_shift_matrix`, `new_function_n8_m2`,
`third_ccz_class_n10`, `equivset`'s min-discrete-log rule, `is_in_cat1` (though it needs
generalising — issue 1).

Promote-to-core candidates:

1. `find_normal_element(n; modulus)` / normal-basis construction — fully generic, currently
   paper-local (`helpers.jl:28-51`).
2. `quadratic_apn_matrix(F; basis)` — add a basis keyword so the normal-basis derivative matrix
   (the paper's (5)) needs no paper-local copy.
3. `linear_perms_subfield(n, m; modulus)` — enumerate the linear permutations of `GF(2ⁿ)` with
   `GF(2ᵐ)` coefficients (`helpers.jl:85-98`); generic, and needed by any subfield-QAM work.
4. `orbit_partition(elements, group)` + min-discrete-log representative selection (the paper's
   Algorithms 1 and 2) — generic group-action utility.
5. Rank-bounded `delta_rank` for `n = 8` (issue 3), lifting `_design_rank_guard` for Δ-rank only.
6. `proper(S)` — the §3.4 submatrix test, currently an unexported closure inside
   `search_qam_full` (`packages/VBF/src/constructions/qam_search.jl:317`).

### Core documentation bugs found while auditing (outside this paper directory)

- `packages/VBF/src/constructions/qam_search.jl:103` — "Theorem 1 of Ivković–Nikova (the set
  `Cat^m_I`)" and `:127` — "Theorem 3 of Ivković–Nikova". These are Theorem 1 and Theorem 3 of
  **Ichanska–Berg–Kaleyski–Yu** (the module header at `:3` cites `Ichanska_202400` correctly).
  The repo's only Ivković reference is `Ivkovic_202200` (Ivković–**Kaleyski**, 3-to-1
  functions) — "Ivković–Nikova" does not exist in `bibliography.bib`. Also `:103` writes
  `Cat^m_I` where the paper writes `Cat^m_Ind`.
- `packages/VBF/src/constructions/qam_search.jl:25-26` — "the reference accelerates the search
  with a linear-permutation-group orbit reduction over each variable and Theorem-3 submatrix
  pruning". Theorem 3 is the **row-combination** reduction (§3.5); the **submatrix** test is
  §3.4 / Definition 3.1, and the shift invariance is Theorem 2.

## Open Questions

1. **Table 10 multirow ambiguity (P9).** The reading assumed here is that the first polynomial
   in each two-line `\multirow` cell belongs to the lower index (14, 23, 26) and the second to
   the next (15, 24, 27). Under that reading all 27 ODDS match Table 11 index-for-index, which
   is strong evidence the reading is right — but the PDF should be checked before hard-coding
   the mapping.
2. **Which polynomial form should enter the catalog** — Table 5's (all-even exponents) or
   Table 10 #10's (with `x³`)? They are linearly equivalent; the record above defaults to
   Table 5's, since that is the form the paper attaches all invariants to.
3. **Should the other 26 Table 10 representatives be catalogued?** They are verified APN with
   verified ODDS but are not claimed new by this paper. Needs a policy decision.
4. **Table 1's "average number of orbits of C" definition (P6).** The exhaustive count
   reproduces every per-branch number the paper states in prose, but not the averages. Whether
   the paper intends a different denominator, or the `a¹⁷` row is a digit typo, cannot be
   settled from the text alone.
5. **§4.2's "𝒜 = Cat₁ ∪ {a}" (P8).** Read as "16 candidates" it is a sound but loose
   reduction; read as "{1} ∪ {a}" it is tight. The text does not disambiguate, and the (8,4)
   figure is an image that could not be read.
6. **Figures 1–7** are supplied only as JPEGs (`input/images/*.jpg`), so the branch counts they
   encode (notably Figure 3 for (8,2), Figure 5 for (10,1), Figure 6 for (10,2), Figure 7 for
   the backward search) could not be diffed against the computed orbit trees. If those figures
   matter for the reproduction, they need transcription first.
7. **Which of §5.2's (8,4) numbers (`#ℋ_S = 143`, `#ℋ_S^Sub = 122`) are worth targeting?** They
   need the Proposition-1/2 partition criterion, which is not implemented anywhere; reproducing
   them is a real project, not a test.
