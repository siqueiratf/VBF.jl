# Kaleyski_202200 — A Doubly-Infinite Family of 0-APN Monomials

**Paper**: Kaleyski et al. "A doubly-infinite family of 0-APN monomials."

**Reproduction path**: `papers/2022/Kaleyski_202200/`

**Verdict**: Mostly complete

The best-behaved reproduction in the 2022 batch. Theorem 1 is implemented in its *corrected*
form and the reproduction already detects and documents the paper's swapped-argument bug;
both Remark 2 experiments match exactly; the GF(2)[x] machinery is mathematically correct.
The gaps are one unchecked (and false) Remark 3 sub-claim, an undocumented search-range
inference, a missing integer-overflow guard, and Section 3 declared out of scope without
stating why.

---

## Paper Issues

### 1. Theorem 1's hypothesis has swapped exponent arguments

- **Location**: statement at `.tex` line 45 versus proof at `.tex` line 93.
- **Evidence**: the statement reads `gcd(e(k, l-1), 2ⁿ-1) = 1`; the proof uses `e(l-1, k)`.
  Counter-evidence: `n=2, l=3, k=1` satisfies the printed condition (`e(1,2)=1`,
  `gcd(1,3)=1`), yet `x⁷` is not 0-APN over `GF(4)` — all four field elements are roots. A
  wider scan gives **101** printed-condition false positives over the feasible sub-range
  `l ∈ 2..8`, `k ∈ 1..5`, `(l−1)k ≤ 12`, `n ≤ 40` (22 of the 35 `(l,k)` pairs), versus **0**
  for the corrected condition. Biggest contributors: `(l=7,k=1)`→24, `(l=5,k=1)`→16,
  `(l=3,k=1)`→14. The full `l ≤ 8, k ≤ 5` range is **not computable** with the repo's
  `build_derivative_poly`, whose output polynomial has degree `e` (up to `2^40/31 ≈ 3.5·10^10`
  bits) — see reproduction issue 8. (An earlier revision of this file reported "61"; that
  figure is not reproducible and is superseded.)
- **Credit**: the reproduction already detects and documents this (`helpers.jl:123-128`,
  `theorem1.jl:17-31`).

### 2. Remark 1 repeats the same swap

- **Location**: Remark 1 — "then `x^{e(k,l)}` must be 0-APN"; it should be `e(l,k)`.
- **Severity**: cosmetic.

### 3. Remark 3's first Gold-equivalence claim is false

- **Location**: Remark 3 — "in some cases, e.g. for `l=(n-1)/2` and `k=2` … `e(l,k)` is
  equivalent to a Gold function."
- **Computed counter-evidence**: `e((n−1)/2, 2) = (2^{n−1}−1)/3`. For n=7, `e=21` and `x^21`
  over `GF(2⁷)` has **DU = 6**; n=9 → `e=85`, **DU = 8**; n=11 → `e=341`, **DU = 6**. Not
  APN, hence not equivalent to any Gold function under any notion. A cyclotomic-class search
  finds no Gold match for n=7,9,11,13,15. The claim holds only at the degenerate n=5
  (`e=5`, literally Gold).
- **Note**: the companion claim (`l=(n−1)/2+1`, `k=1`, `e = 2^{(n+1)/2}−1`) **is** correct:
  `(2^m−1)(2^m+1) = 2^{2m}−1 ≡ 1 mod 2ⁿ−1` with `m = (n+1)/2`, so it is cyclotomically Gold
  with `gcd((n+1)/2, n) = 1`.

### 4. "The inverse function can be written as `e(n−1,1)`" is true only up to cyclotomic equivalence

- **Location**: Remark 3.
- **Evidence**: `e(n−1,1) = 2^{n−1}−1 ≠ 2ⁿ−2`; the two are related by one Frobenius step
  (`2·(2^{n−1}−1) = 2ⁿ−2`). Harmless, but the paper states it as an equality.

### 5. Section 3's odd-characteristic identity may be missing a Frobenius power

- **Location**: Section 3, the identity `(x^{p^{lk}}−x)((x+1)^{e′}−x^{e′}) = 0`.
- **Status**: it appears to be missing a Frobenius power relative to the characteristic-2
  derivation, which does carry `2^k` explicitly. **Flagged for confirmation — not
  independently re-verified in this pass.**

---

## Reproduction Issues

### 1. The Remark-2 search range is an undocumented inference

- **Location**: `remark2.jl:14,38` and `theorem1.jl:14` (`max_n = 100`); assertions at
  `remark2.jl:42-57` and `test/test_remark2.jl:5-15`.
- **Symptom**: the paper says only "all dimensions `n` in some range". The counts 28/33 and
  40/50 and the uncovered sets are consistent with `1:100`, which the reproduction hard-codes
  without saying it is an inference. The range is **not** unique: a Julia sweep of
  `max_n = 90..105` (2026-08-15) shows `1:99` reproduces 28/33 and 40/50 exactly as well, and
  so does `2:101` — the next dimension satisfying either condition is `n = 101`. Only the
  *window*, not the endpoint, is pinned.
- **Root cause**: undocumented reverse-engineering of an unspecified parameter.
- **Resolution plan**:
  1. Add a `print_kv` stating "paper's range unspecified; n ∈ 1:100 is the unique range
     reproducing 28/33 and 40/50".
  2. Add a `@test` that `n ∈ 1:101` does *not* reproduce the counts (it gives 29/34 and
     41/51). Do **not** assert this for `1:99` — `1:99` *does* reproduce 28/33 and 40/50, so
     such a test would fail.

### 2. `e_exponent` silently overflows

- **Location**: `helpers.jl:25` — `e_exponent(l,k) = sum(1 << (j*k) for j in 0:l-1)`.
- **Symptom**: for `(l−1)·k ≥ 63` the `Int64` shift wraps or zeroes, so `theorem1_holds`,
  `remark1_holds` and `remark2_experiment` return garbage for large `(l,k)` with no error.
  Both are user-settable through the public functions.
- **Root cause**: no domain guard, and `Int` instead of `BigInt`.
- **Resolution plan**:
  1. Either `e_exponent(l,k) = sum(big(1) << (j*k) …)`, or
  2. `((l-1)*k < 62) || throw(ArgumentError(...))`.
  3. Add a `@test_throws` for an out-of-range pair.

### 3. Remark 3's Gold-equivalence sub-claim is not checked (and is false)

- **Location**: `remark3.jl` — only the two exponent identities are covered; the
  "`l=(n−1)/2, k=2` / `l=(n−1)/2+1, k=1` ⇒ Gold" sentence is absent.
- **Symptom**: the paper's only equivalence claim in Remark 3 goes untested, hiding paper
  issue 3.
- **Root cause**: omission.
- **Resolution plan**:
  1. Add `cyclotomic_class(e,n)` (or use `known_apn_monomials`) and check both candidate
     families for odd `n = 5..19`.
  2. `print_check` the `(n+1)/2` case as PASS and the `(n−1)/2, k=2` case as FAIL, with
     DU = 6/8/6 for n = 7/9/11.
  3. Record paper issue 3 here.

### 4. The Inverse identification is not shown to be cyclotomic

- **Location**: `remark3.jl:45-67`.
- **Symptom**: it checks `e(n−1,1) = 2^{n−1}−1` and APN-ness, but never shows the link to
  `x^{-1} = x^{2ⁿ−2}` that makes the paper's sentence true.
- **Root cause**: omission.
- **Resolution plan**: add `@test (2*(e_exponent(n-1,1))) % (2^n-1) == 2^n-2` plus a
  `print_kv` noting the Frobenius step; optionally compare against core `inverse_apn(n)`.

### 5. Section 3 (odd characteristic) is declared out of scope without stating why

- **Location**: `report.jl:21` — "Section 3 out-of-scope (odd char)".
- **Symptom**: the paper's generalisation, including the identity in paper issue 5, is
  untested. Core has no `GF(p)` support, so this is a legitimate scope call — but as written
  it hides paper issue 5.
- **Root cause**: `VBF` is characteristic-2 only.
- **Resolution plan**:
  1. Keep it out of scope, but state *why* (no odd-characteristic layer in core).
  2. Optionally add a small self-contained `section3.jl` doing symbolic checks in `F_p[x]`
     for `(p,l,k) ∈ {(3,2,1),(3,3,1),(3,3,2),(3,4,1)}`.
  3. Record paper issue 5.

### 6. No test covers `report.jl` / `theorem1_report`

- **Location**: `test/runtests.jl` includes the theorem1, remark2 and remark3 tests, but
  nothing exercises the aggregate driver.
- **Resolution plan**: a `paper_report()` smoke test writing to `devnull` would be one line.

### 7. Opportunity, not a defect: the paper's own stated future work is a cheap experiment

- **Context**: the paper's stated motivation is that "`e(l,k)` are good candidates for APN
  monomials that might disprove Dobbertin's conjecture", and it lists "determine what
  additional conditions `e(l,k)` needs to satisfy in order to be APN" as future work.
- **Result of running it here** (`n = 4..11`, `l = 2..8`, `k = 1..4`): **every** APN `e(l,k)`
  found is cyclotomic-equivalent to a known APN monomial (Gold/Kasami/Welch/Inverse) — no
  Dobbertin counterexample in range.
- **Resolution plan**: add it as a cheap, high-value experiment using
  `differential_uniformity(SBox(gf_monomial_lut(n,e)))` plus `known_apn_monomials`.

---

## Items Reproduced Exactly

- **Theorem 1 (corrected form)** — `helpers.jl:114-119`. Scanning
  `(l,k) ∈ {(2,1),(2,2),(2,3),(3,1),(3,2),(4,1),(5,1),(7,1)} × n ≤ 100`: **zero** violations.
- **Paper-bug demonstration** — `theorem1.jl:17-31`. At `n=2, l=3, k=1` the printed condition
  holds while `x⁷` is not 0-APN over `GF(4)` ✔.
- **Remark 1 ⊆ Theorem 1** — verified for all tested pairs, `n ≤ 100`, zero exceptions.
- **Remark 2, both experiments — exact match**:
  - `(l=7,k=1)`, `e=127`: 28 theorem dimensions, 33 actual 0-APN dimensions, uncovered
    `{7,35,49,77,91}` ✔
  - `(l=5,k=1)`, `e=31`: 40 theorem dimensions, 50 actual, uncovered
    `{5,15,…,95} = 5+10k, k=0..9` ✔
- **Remark 3 identities** — `e(2,k) = 2^k+1` (`k=1..10`) and `e(n-1,1) = 2^{n-1}-1`
  (`n=2..20`) ✔; Gold `x^{e(2,k)}` APN for `gcd(k,n)=1`, and Inverse-family `x^{e(n-1,1)}`
  APN for odd `n ≤ 13` ✔.
- **The GF(2)[x] machinery is mathematically correct**: `build_derivative_poly` yields
  `Σ_{0≠i⊊e} x^i`, exactly the paper's eq. (1); `root_count_in_gf2n` counts distinct roots
  via `gcd(f, x^{2ⁿ}+x)`; 0-APN ⟺ 2 roots ✔.

## Test Results

Executed 2026-08-15 on Julia 1.12.6 (`--project=/home/tiago/VBF.jl`, project instantiated).

| Command | Exit code | Wall time |
|---------|-----------|-----------|
| `make -C papers/2022/Kaleyski_202200 test` | **0** | **3 s** |

| Test set | Pass | Broken | Fail | Total | Time |
|----------|------|--------|------|-------|------|
| `theorem1_test` | 129 | 0 | 0 | 129 | 0.3 s |
| `remark2_test`  | 6   | 0 | 0 | 6   | 0.5 s |
| `remark3_test`  | 45  | 0 | 0 | 45  | 0.7 s |
| **Total**       | **180** | **0** | **0** | **180** | — |

No assertion is vacuous: the 129 `theorem1_test` assertions decompose as 8 (basic
`e_exponent` + paper-bug) + 39 (Theorem 1 soundness, `n ≤ 20`) + 39 (poly-vs-direct
cross-validation) + 43 (Remark 1 ⊆ Theorem 1, `n ≤ 50`), independently recomputed in Julia.

Report targets also run clean:

| Command | Result |
|---------|--------|
| `make -C papers/2022/Kaleyski_202200 theorem1` (`max_n=100`) | 3/3 `[PASS]`, 0 violations |
| `make -C papers/2022/Kaleyski_202200 remark2`  (`max_n=100`) | 6/6 `[PASS]`, 28/33 + 40/50 + both uncovered sets exact |
| `make -C papers/2022/Kaleyski_202200 remark3`                | 4/4 `[PASS]` |

(`make report` / `make full` were deliberately not run.)

## Catalog Status

The paper claims **0-APN** monomials, not APN, so there is no new-APN claim to catalog. The
two families it *does* identify (Gold `e(2,k)`, Inverse `e(n−1,1)`) are already present:
`n4_Gold_x3`, `n5_Gold_x3`, `n5_Gold_x5`, `n6_Gold_x3`, `n7_Gold_x3`, `n8_Gold_x3`,
`n10_Gold_x3` for Gold, and `n7_Inverse_x126`, `n9_Inverse_x510` for Inverse. There is **no**
`n5_Inverse` entry and none is needed: `e(4,1) = 15` and `n5_Kasami_x15` is that exact
exponent (`x^30` = inverse is cyclotomic-equivalent to `x^15` mod 31). An exhaustive scan
(reproduction issue 7)
found no `e(l,k)` that is APN and inequivalent to a known family for `n ≤ 11`.

**No catalog gaps.**

## Library-Reuse Note

- `helpers.jl:30-91` `gf2poly_deg` / `gf2poly_square` / `gf2poly_mod` / `gf2poly_gcd` /
  `root_count_in_gf2n` — **no core equivalent exists**. Core has `GF(2ⁿ)` field arithmetic
  but no univariate `GF(2)[x]` polynomial layer. **Promote-to-core candidate**: a generic
  `GF(2)[x]` mod/gcd/square plus distinct-root counting in `GF(2ⁿ)` belongs in
  `packages/VBF/src/representations/` — general and testable. Not a reuse violation.
- `helpers.jl:17-21` `print_header` correctly wraps core `print_banner` ✔. This paper is the
  good example the other 2022 reproductions should follow.
- `helpers.jl:100-110` `is_zero_apn_direct` correctly uses `gf_pow` plus
  `primitive_polynomial` ✔.
- `remark3.jl:33,59` uses `gf_monomial_lut` plus `differential_uniformity` ✔. Minor:
  `gold_apn(n,k)` and `known_apn_monomials` / `inverse_apn` could replace the ad-hoc
  constructions and would tie the checks to the core family definitions.
- `e_exponent`, `build_derivative_poly`, `theorem1_holds`, `theorem1_printed` and
  `remark1_holds` are genuinely paper-specific and correctly local.

## Open Questions

- Was the Remark-2 range really `1..100` in the authors' experiment, or e.g. `2..101`? The
  independent scan says `1..100` reproduces both experiments exactly.
- Paper issue 5 (the Section 3 identity) has not been re-verified in this pass.
