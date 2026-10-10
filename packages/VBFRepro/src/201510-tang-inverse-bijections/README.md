# Tang_201510 — Differentially 4-Uniform Bijections by Permuting the Inverse Function

Current audit application (2026-10-10, Julia 1.13.1): `make test` and `make report` ran successfully. The suite now passes 77 assertions (including newly added regressions where applicable). VBFRepro retained source/input hashes and logs under `data/repro/runs/Tang_201510/` for the recorded runs. The older “no Julia” review below is historical and is superseded by these executions.


**Citation**: D. Tang, C. Carlet, X. Tang, *Differentially 4-uniform bijections
by permuting the inverse function*, Designs, Codes and Cryptography 77:117–141
(2015).

**Reproduction path**: `packages/VBFRepro/src/201510-tang-inverse-bijections/`

**Verdict**: **Partial** — Section 3 (Construction 1 + Theorem 1) and Section 4.1
(Theorem 2) are correctly and exhaustively reproduced, but the paper's headline
contribution — Section 4.3, the CCZ-inequivalence results (Theorems 7, 8, 9,
Corollary 4) — is not verified at all, only gestured at in a comment. Table 2 is
absent, Table 4 is covered for one of four rows and none of its comparison
columns, Table 3 is only counted (not compared row-by-row), and Example 1 is not
implemented — the file named `example1.jl` actually implements the n=8 row of
Table 4. Two "cannot be reproduced" notes in the repo are **factually wrong**:
Table 3 reproduces exactly (all 22 rows including the α-index sets) and Example
1's nonlinearity values reproduce exactly, under `conway_polynomial(6) = 91` and
`conway_polynomial(8) = 285`, both already exported by VBF.

---

## Issue Catalog

### Paper Issues

1. **Example 1's two U sets do not satisfy Construction 1 condition a)**
   (`.tex` l.685-688). Under Magma's default `GF(2^8)` (Conway polynomial
   x⁸+x⁴+x³+x²+1 = 285, α = root), both printed index sets are subsets of
   `U_max` but are **not closed under x ↦ x+1**. First set: α^42, α^138, α^162,
   α^168 have no partners (partners are α^5, α^20, α^65, α^80). Second set: 8
   elements unpaired (logs 122, 158, 167, 174, 186, 211, 233, 244; partners 61,
   79, 87, 93, 117, 171, 213, 234). The resulting F is not a permutation and has
   differential uniformity 8 (resp. 16), not 4.

   This was ruled out as a representation artifact exhaustively: all 128
   primitive elements of GF(2⁸) were tested (all multipliers k with
   gcd(k,255)=1, which covers every primitive element in every isomorphic
   representation, since `U_max` is Frobenius/isomorphism-invariant). **No**
   choice makes either printed set a valid U.

   The numbers themselves are nevertheless correct and reproducible: dropping
   exactly the trailing out-of-order index groups (`138,42,162,168` and
   `186,174,167,158,122,211,233,244` — precisely the group appended out of
   sorted order in each list) yields **valid** U sets of size 16 and 40, which
   are permutations with δ = 4 and **NL = 106 and NL = 104 exactly as claimed**.
   So the index lists carry 4 (resp. 8) spurious entries, and the stated sizes
   "20" and "48" are correspondingly wrong (should be 16 and 40).

2. **Theorem 7's proof restates its hypothesis inconsistently.** The statement
   uses `0 < |U| < (2^{n-1}−2^{n/2})/3 − 2` but the first line of the proof
   writes `0 < |U| ≤ ⌈(2^{n-1}−2^{n/2})/3⌉ − 3` (`.tex` l.540). Both give
   |U| ∈ {2,4} at n=6, so nothing downstream breaks; a presentational slip.

3. **Appendix, proof of Lemma 12** writes `∑_{i=0}^{4}|A_i| = 2^{n-1}` twice
   (`.tex` l.765, l.773) although only `A_0..A_3` are defined; should be
   `∑_{i=0}^{3}`. Harmless typo.

### Reproduction Issues

1. **`table3.jl` claims Table 3's α-index column is not reproducible; it is.**
   - **Location**: `table3.jl:11-13` and `:64-65`; echoed in `report.jl:38-39`.
   - **Symptom**: the file asserts only `num_classes == 22` and prints a note
     saying "α-indices differ from paper … CCZ-class COUNT is
     polynomial-independent". None of Table 3's 22 rows — neither the `U` sets
     nor the `(nl, D₀, D₂, D₄)` values — is compared against the paper.
   - **Root cause**: `build_u_max` / `construction1_sbox` are called with the
     default `modulus = primitive_polynomial(6) = 67`, while the comment on
     line 11 *correctly identifies* the paper's modulus as Magma's Conway
     polynomial 91 — and then never uses it. The `modulus` keyword already
     exists on every helper (`helpers.jl:23,30,35,57,70`) and
     `conway_polynomial` is already called on line 64 for the printed message
     only. With `modulus = 91` and α = 2, **all 22 Table 3 rows match exactly**
     — each listed `{α^i}` set is a subset of `U_max`, is closed under +1, and
     yields precisely the paper's `nl` and `(D₀, D₂, D₄)`. With the current
     default 67, 21 of 22 listed sets are not even subsets of `U_max`.
   - **Resolution plan**:
     1. Add a `modulus` keyword to `table3_classes` / `table3_report`,
        defaulting to `conway_polynomial(n)` for the Table 3 comparison path.
     2. Transcribe the 22 `(U-index-set, nl, D₀, D₂, D₄)` rows into a
        `const TABLE3_ROWS` literal.
     3. For each row build `U = [gf_pow(2, i, 6; modulus=91) for i in idxs]`,
        assert `validate_u(U, 6; modulus=91)`, and assert the computed
        `(nonlinearity, D₀, D₂, D₄)` equals the row.
     4. Keep the modulus-independent `num_classes == 22` enumeration as a
        separate complementary check, and replace the "cannot reproduce" note
        with a statement that Table 3 reproduces under `conway_polynomial(6)`.
     5. Propagate the corrected note to `report.jl:38-39`.

2. **`example1.jl` does not implement Example 1, and its stated reason is
   wrong.**
   - **Location**: `example1.jl:12-17` (the NOTE), `:36-71` (`example1_report`
     actually verifies Table 4's n=8 row), `test/test_example1.jl`.
   - **Symptom**: a file named after Example 1 verifies a different paper item.
     Example 1's two explicit U sets and their NL values (106, 104) are never
     touched. The stated justification — "Magma's primitive element
     representation for GF(2^8) in that version differs from VBF's polynomial
     basis" — is incorrect.
   - **Root cause**: same as Issue 1 — the default `primitive_polynomial(8) = 283`
     was used instead of `conway_polynomial(8) = 285`. Under 285 both printed
     sets are subsets of `U_max` and reproduce NL = 106 and 104 exactly. The
     real obstruction is Paper Issue 1 (the printed index lists are not closed
     under +1), which is a paper defect, not a representation mismatch.
   - **Resolution plan**:
     1. Rename the current content to `table4.jl` (or fold it into a Table 4
        file covering rows n = 6, 8, 10 and the Q₁/Q₂ columns).
     2. Create a real `example1.jl` that builds both sets from the paper's
        α-indices with `modulus = conway_polynomial(8)`.
     3. Assert the printed sets are `⊆ U_max` (this holds) and record that
        `validate_u` **fails** condition a) on both — surfacing Paper Issue 1
        explicitly as a documented erratum rather than silently skipping it.
     4. Verify the corrected sets: dropping the trailing groups
        `{138,42,162,168}` and `{186,174,167,158,122,211,233,244}` gives valid U
        of sizes 16 and 40 with `is_permutation`,
        `differential_uniformity == 4`, and `nonlinearity == 106` / `== 104`.
     5. Also record the closure alternative (24 and 56 elements → NL 104 and
        102) so a reader can see both readings of the erratum.

3. **Section 4.3 (the paper's main contribution) is not reproduced; the report
   overstates what was checked.**
   - **Location**: `report.jl:36-37`: *"Theorems 7-9 (CCZ-inequivalence proofs)
     are mathematical; verified structurally via distinct (nl,D0,D2,D4)
     fingerprints."*
   - **Symptom**: no `theorem7.jl` / `theorem8.jl` / `theorem9.jl`. Counting 22
     distinct fingerprints among the paper's *own* functions says nothing about
     inequivalence to the inverse, Gold, Kasami, Bracken–Leander or quadratic
     functions — which is exactly what Theorems 7 and 8 claim. The note reads as
     if the claim were validated.
   - **Root cause**: the paper's inequivalence criteria are concrete CCZ
     invariants (`#{(a,b) : δ_F(a,b)=4}` and the extended Walsh spectrum), but
     the reproduction never computes a reference baseline for the functions
     being separated from.
   - **Resolution plan**:
     1. `theorem7.jl`: build the inverse function LUT at n=6
        (`gf_inv_zero_safe`), confirm `D₄ = 2ⁿ − 1 = 63`; then for every valid U
        with `0 < |U| < (2^{n-1}−2^{n/2})/3 − 2` (i.e. |U| ∈ {2,4}) assert
        `D₄ > 63` and `D₄ ≥ (2ⁿ−1−3|U|) + (2^{n-1}−2^{n/2}−3|U|−3)|U|`.
        (Confirmed: 111/123/165/171 vs bound 87.)
     2. `theorem8.jl`: compute the extended Walsh spectrum via
        `absolute_walsh_spectrum`, assert it contains a value not in
        `{0, 2^{n/2}, 2^{n/2+1}}` and not divisible by `2^{n/2}`; cross-check
        against `gold_apn` / `kasami_apn` spectra for the same n. (Confirmed:
        `{0,4,8,12,16,20,24}` for U_max at n=6.)
     3. `theorem9.jl`: assert `2^{n-3} + 7·2^{n/2−2} < (2^{n-1}−2^{n/2})/3 − 2`
        for even n in 12…40, and that it fails for n ∈ {6,8,10} — reproducing
        the "n ≥ 12" threshold — plus `|U_m0|`, `|U_m1|` inside Lemma 12's
        bounds at n = 6,8,10.
     4. Rewrite the `report.jl` note to state precisely which invariants were
        checked.

4. **`helpers.jl` redefines the VBF export `nonlinearity`.**
   - **Location**: `helpers.jl:81-83`.
   - **Symptom**: `function nonlinearity(F::SBox{N}) where N; (1 << (N - 1)) - linearity(F) ÷ 2; end`
     — byte-for-byte the same formula as `VBF.nonlinearity`
     (`packages/VBF/src/spectra/linear.jl:119`), in a file that already does
     `using VBF`.
   - **Root cause**: missed reuse. It is the only such shadowing across all 42
     paper directories (`grep -rn '^function nonlinearity' packages/VBFRepro/src/` returns this
     line alone).
   - **Resolution plan**:
     1. Delete `helpers.jl:80-83`.
     2. Remove `linearity` from the "VBF API used" header (`helpers.jl:7`) and
        let call sites in `theorem3.jl`, `table3.jl`, `example1.jl` resolve
        `nonlinearity` from `VBF`.
     3. No call-site edits needed — signature and semantics are identical.

5. **`construction1_sbox` silently accepts an invalid `U`.**
   - **Location**: `helpers.jl:69-78`; `validate_u` (`:56-66`) exists but is
     called only once, in `test/test_construction1.jl:28`.
   - **Symptom**: passing a set that violates condition a) produces a
     non-bijective, non-4-uniform LUT with no error — precisely the failure mode
     of Paper Issue 1, i.e. the situation the reproduction most needs to detect.
   - **Root cause**: validation is optional and unwired.
   - **Resolution plan**:
     1. Add a `validate::Bool = true` keyword to `construction1_sbox` that runs
        `validate_u` before building the LUT.
     2. Add an `n` domain guard (even, `n ≥ 6`) matching Construction 1's
        hypothesis, with a clear error for odd n or n < 6. (The current code
        happily returns results for n = 4, 5, 7, outside the paper's range.)
     3. Have the Example 1 reproduction pass `validate = false` explicitly where
        it demonstrates the paper's defective sets.

6. **`theorem3.jl` never checks the Table 4 *actual* NL values it computes.**
   - **Location**: `theorem3.jl:47-76`; `report.jl:26` restricts it to `ns = [6]`.
   - **Symptom**: `nl_small`, `nl_max`, `nl_m0`, `nl_m1` are computed and
     compared only against the (very loose) theorem bounds. At n=6 the Thm 5/6
     bound is −2, so `ok5` / `ok6` are vacuously true. Table 4's actual n=6
     entries (20, 22, 22) are never asserted.
   - **Root cause**: only the inequality half of Sections 4.2/5 was implemented.
   - **Resolution plan**:
     1. Add `const TABLE4_NL = Dict(6 => (umax=20, um0=22, um1=22), 8 => (100,102,102), 10 => (442,450,444), 12 => (1902,1924,1892))`.
     2. Assert equality for n = 6 and 8 by default, gating n = 10 (and 12)
        behind the existing `full` flag in `report.jl`.
     3. Also assert the printed lower bounds match Table 4's `𝒩ℒ` column
        (6/−2/−2 at n=6; 78/62/62 at n=8; 414/382/382 at n=10;
        1854/1790/1790 at n=12).

7. **Documentation drift in file headers.**
   - **Location**: `helpers.jl:7-8` lists `gf_pow` (never used) and omits
     `gf_inv_zero_safe` (used at line 19); `construction1.jl:19` omits
     `algebraic_degree`, called at line 46; `Makefile:32-33` defines
     `clean_results` but nothing in the paper writes a `results/` directory.
   - **Symptom**: headers misdescribe the code; a dead make target.
   - **Root cause**: drift after refactoring.
   - **Resolution plan**: correct the three header comment lines; either drop
     `clean_results` or have `report.jl` optionally emit its tables under
     `results/`.

---

## Items reproduced exactly

| Paper item | Repo file | Evidence |
|---|---|---|
| Construction 1 (Sec. 3), conditions a), b), `F(x) = (x+δ_U(x))^{-1}` | `helpers.jl:23-78` | `build_u_max/m0/m1` match Eqs. (7),(8),(9); `construction1_sbox` matches Eq. (1) |
| Theorem 1 (F is δ=4) | `construction1.jl:28-53` | recomputed n=6 `du=4`, n=8 `du=4`; implied for all 127 valid U at n=6 by `test_table3.jl:18` |
| F is a bijection | `construction1.jl:38` | recomputed `is_permutation = true`, n=6,8,10 |
| Theorem 2 (deg = n−1) | `theorem2.jl` | recomputed deg = 5 (n=6), 7 (n=8, all three special sets) |
| Table 3 — class *count* (22) | `table3.jl:73`, `test_table3.jl:14` | all 127 non-empty valid U → exactly 22 distinct `(nl, D₀, D₂, D₄)`; multiplicities sum to 127 |
| Table 4, n=8 row (our functions) NL = 100/102/102 | `example1.jl:31-33` | recomputed under both moduli 283 and 285: `U_max`→100, `U_m0`→102, `U_m1`→102, all `du=4` |
| `\|U_max\| = 14` for n=6 (Sec. 4.3 text) | `test_construction1.jl:10` | recomputed 14 |

Theorems 3–6 (NL lower bounds) are **partially** reproduced: the bound formulas
at `theorem3.jl:20-23` are transcribed correctly, but are checked as inequalities
at n=6 only, where the Thm 5/6 bound is −2 and the assertion is vacuous
(Reproduction Issue 6).

## Missing items

All of the following are in the LaTeX source and all are computationally
checkable at n=6 and/or n=8; each was verified independently during the review.

1. **Table 2** (exact numbers of the sets U, n = 6…20). No `table2.jl`.
   Verified: `|U_max|` = 14, 72, 242, 1036, 4118, 16272 for n = 6…16, i.e.
   exactly 2⁷, 2³⁶, 2¹²¹, 2⁵¹⁸, 2²⁰⁵⁹, 2⁸¹³⁶ sets — matching all six computable
   Table 2 entries.
2. **Lemma 3** (Appendix; the computational core of Theorem 1). Verified
   exhaustively: all 127 valid U at n=6 × all (a,b) ∈ (F∖{0,1})×F* — zero
   violations.
3. **Theorem 7** (CCZ-inequivalence to the inverse function). Verified: inverse
   at n=6 has `D₄ = 63 = 2ⁿ − 1`; every valid U with |U| ∈ {2,4} gives
   `D₄` ∈ {111,123,165,171} > 63, all exceeding the paper's own bound 87.
4. **Theorem 8** (CCZ-inequivalence to Gold / Kasami / Bracken–Leander /
   quadratic via extended Walsh spectrum). Verified: for U = U_max at n=6 the
   extended Walsh spectrum is `{0,4,8,12,16,20,24}`, not contained in
   `{0,8,16}` and not divisible by 8 — exactly the paper's argument.
5. **Theorem 9 / Corollary 4** — the arithmetic gate
   `2^{n-3} + 7·2^{n/2−2} < (2^{n-1}−2^{n/2})/3 − 2 for n ≥ 12` is a two-line
   check; absent.
6. **Corollary 2** (`2^{n−2} − 2^{n/2−1} ≤ |U_max| ≤ 2^{n−2} + 2^{n/2−1}`) and
   **Lemma 12** (bounds on `|U_m0|`, `|U_m1|`). Both hold on the recomputed data
   (n=8 attains the Corollary 2 upper bound exactly: 72 = 64+8).
7. **Example 1** (Sec. 5, n=8, two explicit U with NL = 106 and 104) — see
   Reproduction Issue 2.
8. **Table 4 rows n = 6, 10, 12** for our functions. `theorem3.jl` computes the
   n=6 NL values but never compares them to Table 4. Verified: n=6 → 20/22/22 ✓,
   n=10 → 442/450/444 ✓.
9. **Table 4 columns Q₁ and Q₂** (the Qu et al. [14] comparison — the point of
   Section 5). Verified reproducible: Q₁ = `x^{-1} + tr(x²(x+1)^{-1})` gives
   NL 20 (n=6), 102 (n=8); Q₂ with `d = 3(2^t+1)` gives NL 22 (n=6), 98 and 100
   (n=8) — matching Table 4 exactly.
10. **Table 1** (summary of known δ=4 bijections). Not represented anywhere.
11. **Sec. 4.3 n=6 computer claim** (all obtained bijections CCZ-inequivalent to
    known δ=4 bijections and to Q₁, Q₂). Not checked.

## Test results

**Not executed.** No Julia toolchain exists in this environment:

```
julia --project=/home/tiago/VBF.jl -e 'using Pkg; Pkg.instantiate()'
make: julia: No such file or directory
make: *** [Makefile:11: test] Error 127
```

The paper *is* in the CI matrix (`.github/workflows/ci.yml`, entry
`2015/Tang_201510`, Julia 1.12), so it is exercised upstream.

In place of running the suite, every value asserted by the five test files was
**independently recomputed in Python** (GF(2ⁿ) from scratch, mirroring the repo's
`gf_trace` / `gf_inv_zero_safe` / `differential_spectrum` / `linearity` / `anf`
semantics), and all check out:

- `test_construction1.jl`: `|U_max| = 14` ✓, closure ✓, `tr(x^{-1}) = 1` ✓,
  `is_permutation` ✓, `du = 4` for `U_max` and for a 2-element U ✓.
- `test_theorem2.jl`: `algebraic_degree = 5` at n=6 for both `U_max` and a
  2-element U ✓.
- `test_theorem3.jl`: all four bounds satisfied ✓; `U_max = U_{m0} ∪ U_{m1}` ✓
  (12 + 2 = 14).
- `test_table3.jl`: `|U_max| = 14` ✓, 7 pairs ✓, exactly 22 classes ✓, every
  class has `D₀+D₂+D₄ = 4032` ✓, multiplicities sum to 127 ✓.
- `test_example1.jl`: n=8 → `U_max` NL 100, `U_{m0}` NL 102, `U_{m1}` NL 102,
  all `du = 4`, all permutations ✓.

The suite should therefore pass as written; the findings above are about
*coverage and two incorrect notes*, not about failing assertions.

## Catalog status

**Not applicable — no new APN claims.** This paper constructs *differentially
4-uniform* bijections, explicitly as a substitute for the (conjecturally
nonexistent) APN bijections in even dimension. Every function produced by
Construction 1 has δ = 4, confirmed exhaustively for all 127 valid U at n = 6 and
for `U_max`, `U_{m0}`, `U_{m1}` at n = 8 and n = 10.
`packages/VBFCatalog/data/apn/` requires δ = 2 and its loader rejects
non-APN entries, so none of these functions is eligible.

**Catalog-gap records: none.** The only APN function *mentioned* in the paper is
Dillon's n=6 APN permutation (ref. [3], `.tex` l.64), already covered by
`dillon_apn_permutation` in `packages/VBF/src/constructions/sporadic_apn.jl`.

Non-blocking maintainer note: `packages/VBFCatalog/data/literature_sboxes.toml`
is the natural home for a representative δ=4 bijection from this family (e.g.
n=8, `U = U_{m0}`, NL = 102, deg = 7), and `Tang_201510` already exists as a
`bib_key` in `packages/VBFCatalog/data/bibliography.bib:704`. A suggestion,
not a gap — and any such change is subject to the catalog rebuild gate.

## Library-reuse note

One genuine duplication: `nonlinearity(F::SBox{N})` at `helpers.jl:81-83`
duplicates the core export (Reproduction Issue 4). `const safe_inv = gf_inv_zero_safe`
(`helpers.jl:19`) is an alias only, no reimplementation — low severity, but
calling `gf_inv_zero_safe` directly would make the reuse visible at call sites.

Legitimately paper-specific, do not flag: `print_header` (thin `print_banner`
wrapper), `build_u_max` / `build_u_m0` / `build_u_m1` (Eqs. 7–9, correctly built
on `gf_trace` + `gf_inv_zero_safe`), `u_max_pairs`, `validate_u`,
`construction1_sbox` (Eq. 1), `diff_spec_d024` (thin projection of
`differential_spectrum` onto Table 3's `(D₀,D₂,D₄)`; correctly excludes row a=0,
matching the paper's `δ_F(a,b), a ∈ F*`), and `nl_bound_thm3/4/5/6`
(`theorem3.jl:20-23`, correctly transcribed theorem statements).

**Promote-to-core candidates**: none. Everything this paper needs beyond
`nonlinearity` is genuinely paper-specific.

**Adjacent core issue (pre-existing, not caused by this paper)**:
`PRIMITIVE_POLYNOMIALS[8] = 0b100011011` (the AES/Rijndael polynomial) is
irreducible but **not** primitive — measured ord(x) = 51, not 255 — while the
`finite_field.jl` module docstring and the `PRIMITIVE_POLYNOMIALS` docstring both
state the entries generate the multiplicative group of GF(2ⁿ). All other entries
(n = 2…7, 9…16) are genuinely primitive; n=8 is the sole exception. This matters
for any reproduction indexing field elements as α^i with α = 2 under
`primitive_polynomial(8)`. Worth raising separately (rename the constant, or add
a `PRIMITIVE_POLYNOMIALS` entry distinct from the AES modulus); it also surfaced
in the `Yuyin_201300` review.

## Open questions

1. **Is the Table 3 / Example 1 modulus choice deliberate?** `table3.jl:11`
   correctly names Magma's Conway polynomial 91 and then does not use it. Should
   paper reproductions default to `primitive_polynomial(n)` and switch to
   `conway_polynomial(n)` only where the paper's data demands it (the
   recommendation above), or is there a repo-wide convention to defer to?
2. **How should a genuine paper erratum be surfaced?** Paper Issue 1 is a real
   defect. Preferred pattern: (a) reproduce the corrected sets and document the
   erratum in-file, (b) reproduce the printed sets and assert the observed
   failure, or (c) both? Reproduction Issue 2 steps 3–4 sketch (c).
3. **Should `example1.jl` be renamed?** Doing so changes the `Makefile` target
   `example1` and the `test/test_example1.jl` filename.
