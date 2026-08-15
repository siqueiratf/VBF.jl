# Kaleyski_202200 — A Doubly-Infinite Family of 0-APN Monomials

**Paper**: Kaleyski et al. "A doubly-infinite family of 0-APN monomials."

**Reproduction path**: `papers/2022/Kaleyski_202200/`

**Verdict**: Mostly complete

Theorem 1 is reproduced in its corrected form and verified with zero violations over
`l ∈ 2..8`, `k ∈ 1..5`, `n ≤ 60`; both Remark 2 experiments match the paper's counts and
uncovered-dimension sets exactly; and the reproduction independently detects and documents a
genuine notational error in the paper's Theorem 1 statement. The remaining gaps are narrow:
one sub-claim of Remark 3 (which turns out to be **false** — see P4) is not checked, and
Section 3 (odd characteristic) is declared out of scope, which hides a second paper
imprecision.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Every numeric assertion in the test suite was re-derived
> independently in Python and matches.

---

## Paper Issues

### P1. Theorem 1's statement has the exponent arguments swapped

- **Location**: Section 2, Theorem 1 — the hypothesis reads
  `gcd(e(k, l-1), 2^n - 1) = 1`, but the proof (tex line 93: "If the second condition of the
  hypothesis is satisfied, i.e. `gcd(e(l-1,k), 2^n-1)=1`") uses `e(l-1, k)`.
- **Counter-evidence**: with `n=2, l=3, k=1` the printed condition holds
  (`gcd(kl,n)=gcd(3,2)=1`, `e(k,l-1)=e(1,2)=1`, `gcd(1,3)=1`), yet `x^7` is **not** 0-APN
  over `GF(4)`: for `x ∈ {ω, ω²}`, `x^7 = x`, so `x^7+(x+1)^7+1 = 0`. A systematic scan over
  `l ∈ 2..8`, `k ∈ 1..5`, `n ≤ 40` found **88** parameter triples where the printed condition
  holds but `x^{e(l,k)}` is not 0-APN. The corrected condition had **0** violations over
  `l ∈ 2..8`, `k ∈ 1..5`, `n ≤ 60`.
- **Credit**: the reproduction already detects and documents this at `theorem1.jl:17-31` and
  `helpers.jl:123-128`.

### P2. Remark 1 repeats the same swap

- **Location**: Remark 1 — "then `x^{e(k,l)}` must be 0-APN"; it should be `x^{e(l,k)}`.
  Cosmetic, but the third occurrence of the same notational slip.

### P3. Section 3's odd-characteristic identity is missing a Frobenius power

- **Location**: Section 3 — the paper writes
  `(x^{p^{lk}} − x)((x+1)^{e'} − x^{e'}) = 0`.
- **Counter-evidence** (verified symbolically in `F_3[x]`): for `l ≥ 3` the correct identity
  is `g(x)^{p^k} − g(x) = (x^{p^{lk}} − x)·((x+1)^{e'} − x^{e'})^{p^k}`, with
  `g(x) = (x+1)^e − x^e − 1`. Checked for
  `(p,l,k) ∈ {(3,2,1),(3,2,2),(3,3,1),(3,3,2),(3,4,1)}`: the un-powered form fails for
  `l ≥ 3`; the `p^k`-powered form holds in all cases.
- **Severity**: the zero-set is unchanged, so the conclusion survives. This is an imprecision
  rather than an error — note the characteristic-2 proof does carry the `2^k` explicitly.

### P4. Remark 3's second Gold-equivalence claim is false

- **Location**: Remark 3 — "in some cases, e.g. for `l=(n-1)/2` and `k=2`, … `e(l,k)` is
  equivalent to a Gold function."
- **Counter-evidence**: `e((n−1)/2, 2) = (2^{n−1}−1)/3`. For `n=7` this is `21`, and `x^21`
  over `GF(2^7)` has **differential uniformity 6** — not APN, hence not equivalent to any
  Gold function. Likewise `n=9`: `e=85`, DU = **8**; `n=11`: `e=341`, DU = **6**. A
  cyclotomic-class search finds no Gold match for `n = 7,9,11,13,15,17,19`. The claim holds
  only for the degenerate `n=5` case (`e=5`, literally Gold).
- **Note**: the companion claim (`l=(n-1)/2+1`, `k=1`, i.e. `e = 2^{(n+1)/2}−1`) **is**
  correct — cyclotomically equivalent to Gold `2^{(n+1)/2}+1` for every odd `n` tested up
  to 19.

---

## Reproduction Issues

### 1. Remark 3's Gold-equivalence sub-claim is not reproduced

- **Location**: `remark3.jl:14-68`
- **Symptom**: `remark3_report` covers only the Gold `e(2,k)` and Inverse `e(n-1,1)`
  identifications. The third sentence of Remark 3 (`l=(n-1)/2, k=2` and `l=(n-1)/2+1, k=1`
  giving Gold-equivalent exponents) has no check, so the reproduction misses paper issue P4
  entirely.
- **Root cause**: scope taken from the first two sentences of the remark only.
- **Resolution plan**:
  1. Add `remark3_gold_equivalence(io; n_range)` computing `e((n-1)÷2, 2)` and
     `e((n-1)÷2+1, 1)` for odd `n ∈ 5:19`.
  2. For each, compute the cyclotomic class `{2^j·e mod 2^n−1} ∪ {2^j·e^{-1} mod 2^n−1}` and
     test membership of `{2^i+1 : gcd(i,n)=1}`.
  3. Also compute `differential_uniformity(SBox(gf_monomial_lut(n, e)))`.
  4. Emit `print_check` "k=1 branch is Gold-equivalent" → expect PASS, and "k=2 branch is
     Gold-equivalent" → expect FAIL, with `print_kv` of the computed DU (6 / 8 / 6 for
     `n = 7 / 9 / 11`) as the counter-evidence.

### 2. Section 3 (odd characteristic) is declared out of scope with no verification

- **Location**: `report.jl:21` — `scope = "... Section 3 out-of-scope (odd char)"`
- **Symptom**: the paper's only other mathematical content is silently dropped, and the
  missing `p^k` power (P3) goes undetected.
- **Root cause**: the reproduction has no odd-characteristic polynomial arithmetic.
- **Resolution plan**:
  1. Add `section3.jl` with dense `F_p[x]` polynomial arithmetic (roughly 30 lines).
  2. Assert `g(x^{p^k}) − g(x) == (x^{p^{lk}} − x)·((x+1)^{e'} − x^{e'})^{p^k}` for
     `p ∈ {3,5}`, `l ∈ 2..4`, `k ∈ 1..2`.
  3. Add a `print_check` recording that the paper's un-powered form fails for `l ≥ 3`.

### 3. `e_exponent` throws on `l = 0` and overflows for `l·k ≥ 63`

- **Location**: `helpers.jl:25` — `e_exponent(l,k) = sum(1 << (j*k) for j in 0:l-1)`
- **Symptom** (latent): `e_exponent(0, k)` reduces over an empty generator and raises
  `ArgumentError`; it is reachable via `theorem1_holds(1, k, n)` (`helpers.jl:116`). Also
  `1 << (j*k)` is `Int64`, so for `l*k ≥ 63` it silently wraps. Neither is triggered by the
  current `test_pairs` (`theorem1.jl:34`, max `l·k = 7`), so tests pass.
- **Root cause**: no `l ≥ 1` guard, and `Int` rather than `BigInt` accumulation.
- **Resolution plan**:
  1. `e_exponent(l,k) = l ≤ 0 ? big(0) : sum(big(1) << (j*k) for j in 0:l-1)`.
  2. Propagate `BigInt` into `theorem1_holds` / `build_derivative_poly` (the latter already
     uses `BigInt` shifts).
  3. Add unit tests for `e_exponent(0, 3) == 0` and `e_exponent(8, 8)` (exceeds 63 bits).

### 4. Remark 1's own soundness is never checked, only its subsumption

- **Location**: `theorem1.jl:50-61`
- **Symptom**: the report checks `Remark1 ⊆ Theorem1` but never checks
  `remark1_holds(l,k,n) ⇒ is_zero_apn_poly(e,n)` directly. This follows from subsumption plus
  Theorem 1's soundness, so it is a completeness nit rather than a bug.
- **Root cause**: omission.
- **Resolution plan**: add one loop asserting `remark1_holds ⇒ is_zero_apn_poly` over the
  same `test_pairs`.

---

## Items Reproduced Exactly

| Paper item | Reproduction | Independently verified |
|---|---|---|
| Theorem 1 (corrected form), soundness | `theorem1.jl:33-48`, `helpers.jl:114-119` | 0 violations, `l ∈ 2..8`, `k ∈ 1..5`, `n ≤ 60` |
| Theorem 1 printed-vs-proof discrepancy | `theorem1.jl:17-31` | counter-example `n=2, l=3, k=1` confirmed |
| Remark 1 subsumption by Theorem 1 | `theorem1.jl:50-61` | no counterexample, `l ≤ 9`, `k ≤ 6`, `n ≤ 200` |
| Remark 2, `(l,k)=(7,1)`: 28 theorem dims, 33 actual, uncovered `{7,35,49,77,91}` | `remark2.jl:41-47` | exact match, range `n = 1..100` |
| Remark 2, `(l,k)=(5,1)`: 40 theorem dims, 50 actual, uncovered `5+10j, j=0..9` | `remark2.jl:50-57` | exact match, range `n = 1..100` |
| Remark 3, Gold `e(2,k) = 2^k+1` | `remark3.jl:17-43` | confirmed |
| Remark 3, Inverse `e(n-1,1) = 2^{n-1}-1` | `remark3.jl:45-67` | confirmed (cyclotomic-equivalent to `x^{2^n-2}`, APN for odd `n`) |

The reproduction's choice of `max_n = 100` for Remark 2 (the paper says only "some range") is
confirmed correct — it is the unique small bound reproducing all four counts.

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Kaleyski_202200 test` | **Not run** — `julia` is not installed in the review environment |
| Independent re-derivation of every assertion in `test/test_theorem1.jl`, `test/test_remark2.jl`, `test/test_remark3.jl` | **All match** |

## Catalog Status

No new APN function is claimed. The paper produces **0-APN** monomials only and explicitly
leaves APN-ness open ("determine what additional conditions `e(l,k)` needs to satisfy in
order to be APN"). **Not applicable — no catalog gap.** The Gold and Inverse representatives
mentioned in Remark 3 are already covered (`n5_Gold_x3`, `n6_Gold_x3`, `n8_Gold_x3`,
`n10_Gold_x3`, …).

## Library-Reuse Note

Good reuse: `gf_pow`, `primitive_polynomial`, `gf_monomial_lut`, `differential_uniformity`,
`SBox`, and correct use of `print_banner` / `print_section` / `print_check` / `print_kv`
(this paper is the batch's positive example for banners).

- **Promote-to-core candidate** — `helpers.jl:30-65` (`gf2poly_deg`, `gf2poly_square`,
  `gf2poly_mod`, `gf2poly_gcd`) and `helpers.jl:82-91` (`root_count_in_gf2n`). There is no
  `GF(2)[x]` `BigInt`-bitvector polynomial arithmetic nor a distinct-root counter anywhere in
  `packages/VBF/src/`. This is generic, reusable and testable — it belongs in core (e.g.
  `packages/VBF/src/linalg/gf2_polynomials.jl`), so this is a promotion opportunity, not a
  reuse violation.
- **Minor reuse miss** — `remark3.jl:33` and `remark3.jl:59` build Gold / Inverse LUTs via
  `gf_monomial_lut`; core already exports `gold_apn(n, k)` and `inverse_apn(n)`, which also
  validate `gcd(k,n)=1`. Prefer those.
- Paper-specific and correctly local: `e_exponent`, `build_derivative_poly`,
  `is_zero_apn_poly`, `is_zero_apn_direct`, `theorem1_holds`, `theorem1_printed`,
  `remark1_holds`.
