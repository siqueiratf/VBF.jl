# Bracken, Tan & Tan (2012) — Binomial differentially 4 uniform permutations with high nonlinearity

Current audit application (2026-10-10): F070: the existing n=30 streaming/rank checks were revalidated as bounded evidence. Descriptions now say sampled computational evidence, not sampled proof of global differential uniformity. The full injectivity scan, all nonzero derivative rows and n=30 Walsh spectrum remain unverified locally.


- **Citation:** C. Bracken, C.H. Tan, Y. Tan, "Binomial differentially 4 uniform permutations with
  high nonlinearity", *Finite Fields Appl.* 18:537–546, 2012.
- **Reproduction path:** `packages/VBFRepro/papers/2012/Bracken_201205/`
- **Paper source:** `input/Bracken et al. - 2012 - Binomial differentially 4 uniform permutations with high nonlinearity.tex`
- **Verdict:** **Good** (was *Partial*; all 11 reproduction issues resolved on 2026-08-17).
  The grid now covers 9 of 12 feasible parameter instances on the default test path and all 12
  under `full_search = true`; Lemma 3.1 is checked as a *spectrum* and Theorem 1.1 as a Walsh
  *value set*, not as a maximum and a bound; Table 1, the Section 5 CCZ remarks and Problem 5.1
  are implemented; and the title claim is exhibited at its smallest genuine instance
  (`k=10, s=2`, n=30) as a **sampled computational evidence** of the differential half plus a budgeted prefix
  scan of the permutation half. What remains transcribed is named as such: the Walsh spectrum
  at n=30, the Section 1 general family `G`, and the t=2 CCZ-inequivalence the paper itself
  only "expects".

---

## Issue Catalog

### Paper Issues

Flaws in the original publication. Not ours to fix.

1. **Problem 5.1's permutation claim appears false at t = 1** (`.tex` l.486-492). For
   `(k,s) = (5,1)`, n = 15 — which satisfies every stated hypothesis (`3 | k+s`,
   `gcd(s,k) = t = 1`, `gcd(3,s) = gcd(3,k) = 1`, `k/t = 5` odd) — building
   `G(x) = ux^{2^s+1} + u^{2^k}x^{2^{-k}+2^{k+s}} + vx^{2^{-k}+1} + wu^{2^k+1}x^{2^{k+s}+2^s}`
   over all 993 admissible `(v,w) ∈ F_32²` with `vw ≠ 1` yields **exactly one permutation:
   `v = w = 0`**, which degenerates to Theorem 1.2's F. Repeated for six distinct primitive `u`
   with the same result. The differential half of the conjecture does hold: sampled `(v,w)`
   (including `v,w ≠ 0`) all give `Δ_G = 2 = 2^t`, spectrum `{0,2}`, consistent with the APN
   theorem of ref [6]. *Caveat:* the paper's motivating case is `t = 2`, whose smallest instance
   is n = 30; the conjecture may have been intended only there.
2. **Undisclosed degeneracy of the smallest Theorem 1.1 instance.** For `k = 2` the admissible
   `s` are exactly `s ≡ 4 (mod 6)`, and then `2^s+1 ≡ 2^{-k}+2^{k+s} ≡ 17 (mod 63)`, so `F`
   collapses to the monomial `(α+α⁴)x¹⁷`. Since `17 = 5·2⁴ mod 63`, this is linear-equivalent to
   Gold `x⁵` — Table 1's *first* row. The paper's "first class of binomial …" therefore has no
   genuine binomial representative below n = 30, a scope caveat the paper never states.
3. **Symbol collision on `t`** (`.tex` l.126-129 vs l.135): `t ≡ −i (mod 3)` as an exponent index
   for `G`, versus `t = gcd(3k,s)` in Theorem 1.2. Two incompatible meanings.
4. **Cross-reference slips.** l.129 "the function `F` in Theorem 1.2 is the particular case
   `i ≡ 2 mod 3`" should read Theorem 1.1; l.234 "we apply this trace map to Eq. (2)" should be
   Eq. (4); l.289 (Lemma 4.2) drops the absolute value that Theorem 1.2 (l.143) has —
   `F^W(a,b) ≤ …` vs `|F^W(a,b)| ≤ …`.

### Reproduction Issues

Defects introduced in our implementation. **All 11 are `[RESOLVED]`** as of 2026-08-17
(Julia 1.12.6, repo commit `bf15e59` + this working tree).

> **Measurement note.** Every runtime and count below that is labelled "measured here" was
> produced on this machine with `@elapsed` (AMD Ryzen 5 5600G, 12 threads, Julia 1.12.6,
> single-threaded; see `bench/calibration.toml`). The previous revision of this README quoted
> figures from a C program on a *different* machine — the n=30 permutation scan "4 m 55 s in
> C" and the "200 000 random non-zero `a`" derivative sample. Neither was ever run here; both
> have been replaced by this machine's own numbers, and the C figure is now labelled as
> foreign wherever it is still mentioned.

#### BTT-1 — Headline claim declared out of scope when it is partly reachable — **[RESOLVED]**

- **Location:** `report.jl:30-33`.
- **Symptom:** "Theorem 1.1's genuine non-degenerate t=2 diff-4 binomial permutation first
  appears at n=30-scale … so the diff-4 headline is TRANSCRIBED from the paper, not
  computationally exhibited."
- **Root cause:** the cost was estimated from exhaustive LUT/DDT methods. But F is quadratic, so
  its DDT rows are kernels of an F₂-linear derivative and never need a materialized DDT, and a
  permutation test needs only a 128 MB bitmap. Evidence for the smallest genuine instance
  (`k=10, s=2`, n=30, modulus `x³⁰+x⁶+x⁴+x+1` = 1073741907, α=2 verified primitive):
  permutation = **true**, exhaustive over all 2³⁰ inputs, 4 m 55 s in C; and for 200 000 random
  non-zero `a`, `dim ker D_aF = 2` in **every** case → DDT rows in `{0,4}` → `Δ_F = 4` and
  differential spectrum `{0,4}`, exactly Theorem 1.1/Lemma 3.1, in seconds.
- **Resolution plan:**
  1. Add a paper-local degree-30 primitive polynomial constant (core's `PRIMITIVE_POLYNOMIALS`
     stops at 16) with an explicit primitivity assertion on α = 2.
  2. Add an opt-in `section2` case `(k=10, s=2)` behind a `full_search`/`limit` knob per the
     AGENTS.md rule on expensive searches, running the streaming permutation check.
  3. Add a rank-based derivative check `dim ker D_aF == t` with a `samples::Int` limit,
     defaulting to a few thousand `a` so the fast suite stays quick.
  4. Reword `report.jl:30-33` from "TRANSCRIBED" to the evidence level actually achieved.
- **Resolution (done):** new `theorem1_1.jl`, plus the large-n machinery in `helpers.jl`.
  1. `PAPER_PRIMITIVE_POLYNOMIALS[30] = 1073741907` (`x³⁰+x⁶+x⁴+x+1`) and `paper_modulus(n)`,
     which falls back to core `primitive_polynomial` for `n ≤ 16`. `alpha_is_primitive(n;
     modulus)` factors `2ⁿ−1` by trial division and checks `2^{(2ⁿ−1)/p} ≠ 1` for every prime
     `p`; **verified here**: `2³⁰−1 = 3²·7·11·31·151·331` and α = 2 is primitive.
  2. `streaming_permutation_check(F; limit, full_search)` — 2ⁿ-bit bitmap (128 MB at n=30), no
     LUT, explicit budget per AGENTS.md. Default `limit = 2¹⁸`.
  3. `derivative_kernel_dims(F; samples, seed, full_search)` — `B_a(x) = F(x⊕a)⊕F(x)⊕F(a)⊕F(0)`
     is linear because F is quadratic, so each DDT row is `{0, 2^{dim ker B_a}}`; rank via core
     `gauss_jordan!`. Cross-validated in `test/test_theorem1_1.jl` against exhaustive
     `differential_uniformity` at n=6/12/15.
  4. `report.jl`'s scope block now reads `[sampled]` for the n=30 differential half and
     `[transcribed]` only for the n=30 Walsh spectrum and the Section 1 family `G`.
- **Measured here, replacing the foreign C figures:**
  | quantity | this machine | previous README |
  |---|---|---|
  | α = 2 primitive in GF(2³⁰) | verified, instant | asserted |
  | `dim ker B_a = 2`, 2000 random `a` | **0.46 s**, dims `[2]` | 200 000 `a` (never run here) |
  | `dim ker B_a = 2`, `a = 1..500` | **0.08 s**, dims `[2]` | — |
  | injectivity prefix `2¹⁶ / 2¹⁸ / 2²⁰` | **0.27 / 0.81 / 3.26 s** | — |
  | exhaustive `2³⁰` injectivity scan | **~55 min extrapolated, NOT RUN** | "4 m 55 s in C" (foreign machine) |

  The exhaustive n=30 permutation scan stays behind `full_search = true` and is **not** on the
  default test path; the test asserts only the `2¹⁶` prefix and explicitly asserts
  `!p.conclusive`, so the partial result cannot be mistaken for a proof.

#### BTT-2 — Lemma 3.1's differential *spectrum* claim is not checked — **[RESOLVED]**

- **Location:** `section3.jl:31-37`, `test/test_section3.jl`.
- **Symptom:** only `differential_uniformity(F) == 2^t` is asserted. Theorem 1.2 / Lemma 3.1 say
  "the differential spectrum of F is `{0, 2^t}`" — a strictly stronger two-valuedness claim.
- **Root cause:** `differential_uniformity` was chosen for its O(2ⁿ) memory, but core
  `differential_spectrum` (`packages/VBF/src/spectra/differential.jl:62`) has the *same* memory
  profile.
- **Resolution plan:**
  1. Replace or augment with `sort(collect(keys(differential_spectrum(F)))) == [0, 2^t]`.
  2. Expected values, independently confirmed: n=6 → `{0,4}`; n=15 → `{0,2}`; n=12 (k=4,s=2) →
     `{0,4}`.
- **Resolution (done):** `helpers.jl` gained `differential_value_set(F; streaming)`, and
  `section3.jl` / `test/test_section3.jl` now assert the whole set:
  `differential_value_set(F) == [0, 2^t]` on every instance of the grid.
  `streaming = false` is the core path — `first.(sorted_pairs(differential_spectrum(F)))` —
  and is used for `n ≤ 12`; `streaming = true` runs the identical
  one-input-difference-at-a-time scan without the `Dict`, and is used at n=15.
  **Measured here, which is why the split exists:** at n=15 core `differential_spectrum`
  costs **10.6 s** per instance (2³⁰ `Dict` updates dominate), the streaming form **1.7 s**,
  and core `differential_uniformity` — which throws the value set away — **1.0 s**. At n=12
  core `differential_spectrum` is **0.29 s**, so no local path is needed there. The two paths
  are asserted equal at n=12 in the test.
  All the expected values were re-measured here; the grid adds t=4 (`{0,16}`) and t=5
  (`{0,32}`), which are the only feasible witnesses that the exponent is really `2^t`.

#### BTT-3 — Theorem 1.1's Walsh *spectrum-set* claim is not checked — **[RESOLVED]**

- **Location:** `section4.jl:32-38`.
- **Symptom:** only `L ≤ 2^{(n+t)/2}` is asserted. Theorem 1.1 claims membership in
  `{0, ±2^{n/2}, ±2^{(n+2)/2}}`, and that set claim is precisely what Section 5 uses to separate
  F from the inverse function. A bound would not catch a stray ±4.
- **Root cause:** the bound is what `linearity_rowwise` returns; the value set is discarded.
- **Resolution plan:**
  1. At n=6 use core `absolute_walsh_spectrum(F)` and assert the value set is `{0,16}` ⊂
     `{0,8,16}`.
  2. At n=15 collect distinct values inside `linearity_rowwise` (a `Set{Int}`) instead of only
     the max; verified result is `{0,±256}` (F is AB there).
- **Resolution (done):** `helpers.jl` gained `walsh_value_set(F; streaming)` returning the
  sorted **signed** value set (core `lat` for small n, column-at-a-time `walsh_hadamard!` for
  n ≥ 13); `linearity_rowwise` is now `maximum(abs, walsh_value_set(F; streaming = true))`, so
  the two can no longer drift apart. `section4.jl` asserts the set, and additionally asserts
  Theorem 1.1's membership claim at n=6: `{0,±16} ⊆ {0,±2³,±2⁴}`. The test cross-checks against
  core `absolute_walsh_spectrum` (`first.(sorted_pairs(...)) == [0,16]`) exactly as the plan
  asked, and asserts `walsh_value_set(streaming=true) == walsh_value_set(streaming=false)` and
  `linearity_rowwise == linearity` at n=12. n=15 result confirmed here: `{0,±256}`, F is AB.
  **Scope correction found while doing this:** Lemma 4.2 is stated for `F` *of Theorem 1.2*,
  i.e. only for `k/t` **odd**. On Lemma 2.1's `k/t` even branch the bound is genuinely
  exceeded — measured here: `(2,1)` gives max 16 against the bound 8, `(4,2)` gives 256
  against 128, `(4,5)`/`(4,11)` give 128 against 64. `section4.jl` therefore records those
  rows' value sets but never asserts the bound on them; the test pins the inequality the other
  way round so the scope boundary cannot silently move. This is a scope fact, not a paper
  defect — the paper never claims the bound there.
  **Measured here:** n=15 streaming Walsh value set **4.9 s** per instance; n=12 via core
  `lat` **0.57 s**.

#### BTT-4 — Table 1 and the Section 5 remarks are absent — **[RESOLVED]**

- **Location:** no `section5.jl` exists; the `report.jl:20-34` scope block does not mention them.
- **Symptom:** the paper's summary table and its inequivalence discussion — the part that
  justifies the contribution — have no counterpart. All four prior Table-1 rows are checkable in
  seconds; independently verified:

  | Function | n | perm | du | Walsh values |
  |---|---|---|---|---|
  | Gold `x⁵` (i=2) | 6 | yes | 4 | `{0,±16}` |
  | Kasami `x¹³` (i=2) | 6 | yes | 4 | `{0,±16}` |
  | inverse `x⁶²` | 6 | yes | 4 | `{0,±4,±8,±12,±16}` |
  | Bracken–Leander `x⁷³` (k=3) | 12 | yes | 4 | `{0,±64,±128}` |

- **Root cause:** the table and Section 5 were left out of scope without a stated reason.
- **Resolution plan:**
  1. Add `section5.jl` emitting Table 1 with one computed row per function.
  2. Emit `perm / du / linearity / nonlinearity / Walsh value-set` per row, using core
     `table_to_markdown` / `to_markdown`.
  3. Add the Section 5 inverse-function separation as an explicit check:
     `Walsh-set(inverse@n=6) ⊄ {0,±8,±16}` while `Walsh-set(F@n=6) ⊆ {0,±8,±16}`.
  4. State explicitly that at n=6 F is linear-equivalent to Gold `x⁵` (`17 = 5·2⁴ mod 63`), so
     the n=6 instance cannot support the novelty claim (Paper Issue 2).
- **Resolution (done):** new `section5.jl` + `test/test_section5.jl`, wired into `report.jl`,
  the `Makefile` (`make section5`) and the scope block. Each row is recomputed here:

  | Function | n | perm | du | deg | linearity | nonlinearity | Walsh values |
  |---|---|---|---|---|---|---|---|
  | Gold `x⁵` (i=2) | 6 | yes | 4 | 2 | 16 | 24 | `{0,±16}` |
  | Kasami `x¹³` (i=2) | 6 | yes | 4 | 3 | 16 | 24 | `{0,±16}` |
  | inverse `x⁶²` | 6 | yes | 4 | 5 | 16 | 24 | `{−12,−8,−4,0,4,8,12,16}` |
  | Bracken–Leander `x⁷³` (k=3) | 12 | yes | 4 | 3 | 128 | 1984 | `{0,±64,±128}` |
  | this article, `(k,s)=(2,4)` | 6 | yes | 4 | 2 | 16 | 24 | `{0,±16}` |

  **Correction to the review's own table above:** the inverse function's Walsh set at n=6 is
  *not* `{0,±4,±8,±12,±16}` — `+16` occurs but `−16` does not. The measured, asymmetric set is
  the one recorded, and `walsh_set_string` falls back to a raw listing when a set is not
  symmetric under negation rather than prettify a wrong claim.
  Section 5's separation is asserted verbatim: `Walsh-set(inverse@6) ⊄ {0,±8,±16}` while
  `Walsh-set(F@6) ⊆ {0,±8,±16}`. Paper Issue 2 is asserted three ways: `17 = 5·2⁴ mod 63`, the
  elementwise identity `F = 18·(x^{2⁴})⁵`, and core `are_linear_equivalent(F(2,4), x⁵) = true`.
  **Open question 3 answered:** core `gold_apn` / `kasami_apn` / `inverse_apn` guard the APN
  (odd-n) regime and *throw* here (`gcd(k,n)=1`, `isodd(n)`), so the rows are built with core
  `gf_monomial_lut` — which is the API those constructors call anyway. Core
  `table_to_markdown` renders an integer matrix and cannot carry a mixed string/int table, so
  `table1_markdown` assembles the markdown; the reason is stated in-file.

#### BTT-5 — Problem 5.1 is dismissed instead of tested — **[RESOLVED]**

- **Location:** `report.jl:34` — "[out-of-scope] Problem 5.1 — open problem, no proof available".
- **Symptom:** a conjecture with an explicit finite instance is exactly what a reproduction can
  test; the negative result of Paper Issue 1 is currently being thrown away. The required
  quadrinomial is already coded in the sibling folder
  (`packages/VBFRepro/papers/2011/Bracken_201103/helpers.jl:36`), so no new mathematics is needed.
- **Root cause:** "open problem" was read as "not reproducible".
- **Resolution plan:**
  1. Add `problem5_1.jl` building `G` for `(k,s) = (5,1)`.
  2. Scan all 993 `(v,w) ∈ F_32²` with `vw ≠ 1` for the permutation property (~seconds); report
     that only `v = w = 0` is a permutation.
  3. Sample a `limit`-bounded subset for `differential_spectrum == {0,2}` (holds in every case
     tested).
  4. Record the outcome as "conjecture's differential half supported; permutation half refuted
     at t=1".
- **Resolution (done):** new `problem5_1.jl` + `test/test_problem5_1.jl`, wired into
  `report.jl` and the `Makefile` (`make problem5_1`). `G` is built locally (paper folders are
  standalone), and `problem5_1_lut(5,1,2,0,0) == bracken_binomial_lut(5,1)` is asserted, which
  pins the degeneracy at `v=w=0`.
  **Measured here, not quoted:** `problem5_1_pairs(5)` has exactly `993 = 32² − 31` admissible
  `(v,w)`. A **full** scan (`full_search = true`) costs **52.5 s** and returns the single
  permutation `(0,0)`. Repeated here for six distinct primitive `u = α^j`, `j = 1..6` (all
  coprime to `2¹⁵−1 = 7·31·151`): **52.8 / 53.4 / 54.4 / 53.7 / 54.8 / 55.0 s, 324.2 s total,
  `[(0,0)]` every time.** The differential half holds on every sample, including `v,w ≠ 0`.
  The default test path uses `limit = 32` (seeded sample, always including `(0,0)`, 1.7 s) and
  `samples = 2` for the spectrum (1.7 s each), and asserts `!scan.exhaustive` so the sampled
  result is not mistaken for the full one.
  **Open question 2 answered:** the refutation lives in this paper's folder, since it is a
  computation about *this* paper's Problem 5.1; it is filed under **Paper Issues 1**, not as a
  reproduction defect.

#### BTT-6 — The family constructor accepts invalid parameters — **[RESOLVED]**

- **Location:** `helpers.jl:33-43`.
- **Symptom:** `bracken_binomial_lut(k, s)` performs no hypothesis check.
  `bracken_binomial_lut(3, 3)` (3 | k, violating Theorem 1.2) silently returns a LUT; nothing
  enforces that `t = gcd(3k,s)` divides `k`, that `3 ∤ k`, or that `3 | k+s`.
- **Root cause:** hypotheses live only in the docstring (`helpers.jl:26`), which itself omits
  `3 ∤ k`. Compare core `bcp_apn`
  (`packages/VBF/src/constructions/apn_quadratic_families.jl:73-104`), which throws
  `ArgumentError` in the analogous situations.
- **Resolution plan:**
  1. Add checks mirroring `bcp_apn`: `3 ∤ k`, `t = gcd(3k,s)`, `t | k`, `3 | (k+s)`, plus an
     `allow_nonpermutation` path since Lemma 2.1's even branch is intentionally exercised.
  2. Assert α primitive (`ord(2) = 2ⁿ−1`), which the paper requires.
  3. Fix the docstring at `helpers.jl:26` to list `3 ∤ k`.
- **Resolution (done):** `bracken_binomial(k, s; modulus, allow_nonpermutation)` is the new
  validated constructor; `bracken_binomial_lut` and `bracken_binomial_sbox` go through it, so
  no caller can bypass the guard. Checks, mirroring `bcp_apn`: `k ≥ 1`, `s ≥ 1`, `3 ∤ k`,
  `3 ∣ (k+s)`, `t = gcd(3k,s)` divides `k`, α primitive, and — only under
  `allow_nonpermutation = false` — `k/t` odd. The default is `true` because `section2.jl`
  deliberately exercises Lemma 2.1's even branch.
  *Note on the `t ∣ k` check:* under `3 ∤ k` and `3 ∣ (k+s)` it is automatic
  (`gcd(3k,s) = gcd(3,s)·gcd(k,s)`, and `3 ∣ s` would force `3 ∣ k`), so it is a redundant
  guard kept for parity with the plan — it is documented as implied rather than presented as
  independent.
  Negative tests in `test/test_section2.jl`: `bracken_binomial_lut(3,3)` and `(6,3)` throw on
  `3 ∣ k`; `(2,2)` and `(5,2)` throw on `3 ∤ (k+s)`; `(0,3)` and `(2,0)` throw on the range
  checks; `bracken_binomial(4,2; allow_nonpermutation=false)` and `(2,1; …)` throw on `k/t`
  even while `(5,1; …)` succeeds; and `bracken_binomial(2,4; modulus = 0b1110101)` throws
  because α = 2 has order **21**, not 63, under that (irreducible but non-primitive) modulus —
  measured here.
  The docstring now lists `3 ∤ k` and points at the enforcing function.

#### BTT-7 — Inaccurate "smallest non-degenerate case" claim — **[RESOLVED]**

- **Location:** `helpers.jl:31`, `report.jl:28`.
- **Symptom:** "Smallest non-degenerate case: k=5, n=15, s=1 (t=1)" is false as written.
  `(k,s) = (2,1)` at n=6 satisfies all Theorem 1.2 hypotheses and is non-degenerate (`e₁ = 3`,
  `e₂ = 24`); it is merely in the `k/t` even (non-permutation) branch. `(4,5)` and `(4,11)` at
  n=12 are likewise non-degenerate.
- **Root cause:** "non-degenerate" conflated with "non-degenerate permutation".
- **Resolution plan:**
  1. Reword to "smallest non-degenerate **permutation** instance".
  2. Add `(2,1)` to `SECTION2_CASES` — the cheapest non-degenerate witness of Lemma 2.1's even
     branch, which also exercises Lemma 3.1 at n=6 with t=1 (verified: non-permutation, spectrum
     `{0,2}`).
- **Resolution (done):** the `bracken_binomial_lut` docstring now reads "smallest
  non-degenerate **permutation** instance is `k=5, n=15, s=1`", names `(2,1)` at n=6
  (`e₁ = 3`, `e₂ = 24`) as the smallest non-degenerate instance of any kind, and points at
  `theorem1_1.jl` for `(10,2)`, the smallest non-degenerate instance of the paper's own t=2
  headline. `report.jl`'s scope block was reworded to match. `(2,1)` is in `SECTION2_CASES`,
  `SECTION3_CASES` and `SECTION4_CASES`; degeneracy is no longer prose but a computed
  predicate `is_degenerate(F)` asserted per instance in `section2.jl`. Confirmed here: `(2,1)`
  is a non-permutation with spectrum `{0,2}` and Walsh set `{0,±8,±16}`.

#### BTT-8 — No cross-check against core's identical construction — **[RESOLVED]**

- **Location:** `helpers.jl:33`.
- **Symptom:** for `t = 1` the paper's F is exactly `α ·` core's `bcp_apn(k,s)` (ref [8] =
  `Budaghyan_200809`). Under the paper's conditions `3|k+s`, `3∤k` one always has
  `i = sk ≡ 2 (mod 3)`, matching `bcp_apn`'s `i = mod(s*k, 3)`; and `α^{2^k}/α = α^{2^k−1}` is
  exactly `bcp_apn`'s `w`. Verified elementwise:
  `bracken_binomial_lut(5,1) == gf_mul.(2, bcp_apn(5,1).lut)`.
- **Root cause:** the reproduction was written standalone without noticing that the t=1 member is
  already in core.
- **Resolution plan:**
  1. Add a test asserting
     `bracken_binomial_lut(5,1) == [gf_mul(2, y, 15) for y in bcp_apn(5,1).lut]`, which anchors
     the paper's family to the known one it generalizes and makes the "obtained by changing
     certain conditions from [8]" sentence (`.tex` l.111) explicit.
  2. Keep `bracken_binomial_lut` for the `t > 1` cases that `bcp_apn` rejects.
- **Resolution (done):** `test/test_section2.jl` asserts
  `bracken_binomial_lut(k,s) == [gf_mul(2, y, 3k) for y in bcp_apn(k,s).lut]` for
  `(5,1), (5,4), (4,5), (2,1)` — all four hold here. The complementary half is asserted too:
  `bcp_apn(4,8)` and `bcp_apn(5,10)` throw (`gcd(s,3k) = 4` resp. `5`, not 1) while
  `bracken_binomial_lut` builds them, which is exactly why the paper-local helper is kept.

#### BTT-9 — Mutually inconsistent runtime documentation — **[RESOLVED]**

- **Location:** `section3.jl:10` ("~30 s exhaustive"), `test/test_section3.jl` ("~0.5 s here"),
  `Makefile` help ("n=15 ~1 s"), `test/test_section4.jl` ("~2 s here").
- **Symptom:** three different runtimes quoted for the same n=15 differential scan. Optimized C
  on this machine: n=15 differential scan 0.99 s, streaming Walsh 5.01 s — so "~30 s" and
  "~0.5 s / ~2 s" bracket the truth from both sides.
- **Root cause:** figures were estimated at different times and never reconciled.
- **Resolution plan:** measure once with `@elapsed` and use one consistent figure across
  `section3.jl`, `section4.jl`, `Makefile`, and the tests.
- **Resolution (done):** measured once here with `@elapsed`, and the *same* figures now appear
  in `helpers.jl`, `section3.jl`, `section4.jl`, `theorem1_1.jl`, `problem5_1.jl`, the
  `Makefile` help text and the tests. The single n=15 differential-scan figure is **1.7 s**:

  | operation | n | measured here | previously quoted |
  |---|---|---|---|
  | streaming differential value set | 15 | **1.7 s** | "~30 s" / "~0.5 s" |
  | core `differential_spectrum` | 15 | **10.6 s** | — |
  | core `differential_uniformity` | 15 | **1.0 s** | "~0.5 s" |
  | core `differential_spectrum` | 12 | **0.29 s** | — |
  | streaming Walsh value set / `linearity_rowwise` | 15 | **4.9 s** | "~2 s" |
  | core `lat` + value set | 12 | **0.57 s** | — |

  The old "~30 s" in `section3.jl:10`, "~0.5 s here" in `test/test_section3.jl`, "n=15 ~1 s"
  in the `Makefile` and "~2 s here" in `test/test_section4.jl` are all gone. Every file that
  quotes a runtime now names the machine and says the figure was taken with `@elapsed` here.

#### BTT-10 — Parameter-space coverage is 3 of 12 feasible instances — **[RESOLVED]**

- **Location:** `section2.jl:18-22`, `section3.jl:19-22`, `section4.jl:20-23`.
- **Symptom:** only `(2,4)`, `(4,2)`, `(5,1)` are exercised. The full feasible set with n=3k ≤ 15
  satisfying Theorem 1.2, with independently verified outcomes:

  Every row below was **re-measured on this machine**; the last column reports the state after
  the fix. `section2` runs all 12; `section3` / `section4` run 9 by default and all 12 under
  `full_search = true` (the three deferred rows only repeat `(5,1)`'s t=1 shape and cost
  1.7 s + 4.9 s each).

  | k | s | n | t | k/t | shape | perm | diff. spectrum | Walsh values | in repro |
  |---|---|---|---|---|---|---|---|---|---|
  | 1 | 2 | 3 | 1 | odd | degenerate | yes | `{0,2}` | `{0,±4}` | **yes** |
  | 2 | 1 | 6 | 1 | even | binomial | no | `{0,2}` | `{0,±8,±16}` | **yes** |
  | 2 | 4 | 6 | 2 | odd | degenerate | yes | `{0,4}` | `{0,±16}` | **yes** |
  | 4 | 2 | 12 | 2 | even | binomial | no | `{0,4}` | `{0,±64,±256}` | **yes** |
  | 4 | 5 | 12 | 1 | even | binomial | no | `{0,2}` | `{0,±64,±128}` | **yes** |
  | 4 | 8 | 12 | **4** | odd | degenerate | yes | **`{0,16}`** | `{0,±256}` | **yes** |
  | 4 | 11 | 12 | 1 | even | binomial | no | `{0,2}` | `{0,±64,±128}` | **yes** |
  | 5 | 1 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | **yes** |
  | 5 | 4 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | `full_search` |
  | 5 | 7 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | `full_search` |
  | 5 | 10 | 15 | **5** | odd | degenerate | yes | **`{0,32}`** | `{0,±1024}` | **yes** |
  | 5 | 13 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | `full_search` |

  The `t = 4` and `t = 5` rows are the only feasible evidence that Lemma 3.1's exponent is really
  `2^t` and not "4 or 2"; both are absent.
- **Resolution plan:** extend `SECTION2/3/4_CASES` to the full grid, at minimum adding `(2,1)`,
  `(4,8)` (t=4, du=16) and `(5,10)` (t=5, du=32).
- **Resolution (done):** all three `SECTION*_CASES` lists now hold the complete 12-instance
  grid, well past the stated minimum. The two previously missing `(5,7)` / `(5,13)` spectra and
  Walsh sets were measured here and are filled in above. `t ∈ {1,2,4,5}` is covered on the
  default path, so Lemma 3.1's `2^t` and Lemma 4.2's `2^{(n+t)/2}` are both pinned at four
  distinct values of `t` instead of two. Coverage is asserted, not just implemented:
  `test_section3.jl` checks `length(SECTION3_CASES) == 12` and that exactly 9 are non-heavy.

#### BTT-11 — Smaller omissions — **[RESOLVED]**

- **Section 1 general family `G(x) = αx^{2^s+1} + α^{2^k}x^{2^{ik}+2^{tk+s}}`** (`i ≡ ks`,
  `t ≡ −i mod 3`) is not implemented and not mentioned in `report.jl`'s scope block. Genuinely
  infeasible at t=2, but it should at least be listed as transcribed-only.
- **Lemma 4.1** (≤ 2^d roots of `∑ r_i x^{2^{si}}` when `gcd(n,s)=1`) is never exercised; a
  randomized check would be cheap.
- **Quadraticity** — the paper's whole proof strategy rests on F being quadratic, but
  `algebraic_degree(F) == 2` is never asserted.
- **α primitive** — a stated hypothesis, never asserted. It does hold: the order of 2 is 7, 63,
  4095, 32767 for n = 3, 6, 12, 15 under `PRIMITIVE_POLYNOMIALS`.
- **Resolution (done), item by item:**
  1. *Section 1 general family `G`.* Listed in `report.jl`'s scope block as
     **`[transcribed]`**, with the reason: its hypotheses coincide with Theorem 1.1's
     (`gcd(3k,s) = 2`, `k/2` odd, `3 ∤ k`), so its smallest instance is also n = 30 and it is
     infeasible to scan here. Not silently omitted any more.
  2. *Lemma 4.1.* `lemma4_1_check(; trials, seed)` in `section4.jl` — a seeded randomised
     check over `n ∈ {6,8,9}`, `d ≤ 3`, roots counted exhaustively over `GF(2ⁿ)`, with
     `trials` as the explicit budget. Measured here: 8 trials in **0.4 s**; every trial found
     1 or 2 roots, well inside `2^d`. Asserted in `test/test_section4.jl`.
  3. *Quadraticity.* `algebraic_degree(F) == 2` is now asserted for **all 12** grid instances
     in `test/test_section2.jl`. This is the hinge of the whole paper's proof strategy and of
     the rank criterion used at n = 30.
  4. *α primitive.* `alpha_is_primitive(n)` is asserted for `n ∈ {3,6,12,15}` in the tests and
     for `n = 30` in `test/test_theorem1_1.jl`, and is enforced inside the constructor. A
     negative control is included: `alpha_is_primitive(6; modulus = 0b1110101) == false`
     (order 21).

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Lemma 2.1** (permutation iff `k/t` odd) | `section2.jl` `SECTION2_CASES` | all 12 feasible `(k,s)` with n = 3k ≤ 15; `is_permutation` matches the `k/t` parity prediction in every case, and `is_degenerate` is asserted alongside |
| **Lemma 3.1** (differential *spectrum* `{0, 2^t}`) | `section3.jl` `SECTION3_CASES` | 9 instances by default, 12 under `full_search`; `t ∈ {1,2,4,5}` → `{0,2}`, `{0,4}`, `{0,16}`, `{0,32}` |
| **Lemma 4.1** (≤ `2^d` roots) | `section4.jl` `lemma4_1_check` | 8 seeded random trials over `n ∈ {6,8,9}`, `d ≤ 3`; all inside the bound |
| **Lemma 4.2** (Walsh bound) | `section4.jl` `SECTION4_CASES` | asserted on the `k/t` odd rows it covers; bounds 4, 16, 256, 256, 1024 all **attained** |
| **Theorem 1.1** Walsh *set* `⊆ {0,±2^{n/2},±2^{(n+2)/2}}` | `section4.jl`, `section5.jl` | n=6: `{0,±16} ⊆ {0,±8,±16}` |
| **Theorem 1.1** at its smallest genuine instance, n=30 | `theorem1_1.jl` | α primitive verified; `dim ker B_a = t = 2` on 2000 random `a` (**sampled computational evidence** of `Δ_F = 4`, spectrum `{0,4}`); injective on a budgeted prefix |
| **Table 1** (all 4 prior rows + this paper's) | `section5.jl` | every row recomputed: perm, du = 4, degree, linearity, nonlinearity, Walsh set |
| **Section 5** CCZ separation from the inverse | `section5.jl` | `Walsh-set(inverse@6) ⊄ {0,±8,±16}` while `Walsh-set(F@6) ⊆ {0,±8,±16}` |
| **Problem 5.1** (open problem) | `problem5_1.jl` | permutation half **refuted** at t=1 over all 993 `(v,w)` and six primitive `u`; differential half supported on every sample |
| Degeneracy caveat for the t=2 headline | `helpers.jl` `is_degenerate`, `section5.jl` | `e₁ ≡ e₂ ≡ 17 (mod 63)`, and core `are_linear_equivalent(F(2,4), x⁵) = true` |
| **F ≡ α · `bcp_apn`** for t = 1 | `test/test_section2.jl` | elementwise LUT equality for `(5,1), (5,4), (4,5), (2,1)`; `bcp_apn` throws on `(4,8)`, `(5,10)` |

Still **not** reproduced, and labelled as such in `report.jl`: the Walsh spectrum at n = 30
(a `2^60`-operation LAT scan), the Section 1 general family `G` (smallest instance also
n = 30), and the t = 2 CCZ-inequivalence to Gold/Kasami — which the paper itself states only
as "we expect the case of t=2 to be no different".

---

## Test results

`make -C packages/VBFRepro/papers/2012/Bracken_201205 test` → **exit code 0**, all tests pass. Wall time
**31.7 s** (includes `Pkg.instantiate()`); Julia **1.12.6**, machine AMD Ryzen 5 5600G
(12 threads, 30.7 GB), run **2026-08-17** on the post-fix working tree. Figures below are
from that single run, not an average.

| Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|
| `section2_test` | 73 | 0 | 0 | 73 | 2.0 s |
| `section3_test` | 25 | 0 | 0 | 25 | 4.6 s |
| `section4_test` | 29 | 0 | 0 | 29 | 12.7 s |
| `section5_test` | 21 | 0 | 0 | 21 | 3.0 s |
| `theorem1_1_test` | 28 | 0 | 0 | 28 | 2.2 s |
| `problem5_1_test` | 13 | 0 | 0 | 13 | 5.7 s |
| **Total** | **189** | **0** | **0** | **189** | **31.7 s** |

The `Test Summary` lines print only `Pass / Total / Time` columns, i.e. Julia reported no
failed and no broken tests. (Before the fixes: 7 tests in 8 s.)

`make -C packages/VBFRepro/papers/2012/Bracken_201205 report` → **28.3 s**, exit 0, **62 `[PASS]` and 0
`[FAIL]`**. All six sub-targets (`section2`…`section5`, `theorem1_1`, `problem5_1`) and all
six scripts run standalone (`julia --project=<root> <file>.jl`) exit 0.

Nothing on the default test path exceeds its budget: the two long-running experiments are
opt-in and were run **once, here**, outside the suite —

| Opt-in experiment | Knob | Measured here | On the default path? |
|---|---|---|---|
| exhaustive n=30 injectivity scan | `full_search = true` | **~55 min extrapolated, never run** | no (prefix `2¹⁶` only, 0.27 s) |
| full 993-pair Problem 5.1 scan | `full_search = true` | **52.5 s** (×6 primitive `u`: **324.2 s**) | no (32-pair sample, 1.7 s) |
| three deferred n=15 grid rows | `full_search = true` | 1.7 s + 4.9 s each | no |

**Figures NOT measured on this machine, and labelled as such wherever they appear:** the
n=30 permutation check "4 m 55 s in C" and the "200 000 random non-zero `a`" derivative
sample, both from the previous review's C program on a different machine. They have been
replaced by this machine's `@elapsed` numbers (≈55 min extrapolated, and 2000 samples in
0.46 s) and are retained only as an explicitly-attributed comparison.

Bibliography and CI wiring are correct: `Bracken_201205` is at
`packages/VBFCatalog/data-raw/bibliography.bib:596` and in `.github/workflows/ci.yml:38`.

---

## Catalog status

**No APN function is claimed as new by this paper.** Its contribution is a differentially
*4*-uniform permutation (Table 1, row 5); the APN specialization (`t = 1`) is explicitly
attributed to ref [8] (Budaghyan–Carlet–Leander 2008, `Budaghyan_200809`).

| Claimed object | Status |
|---|---|
| Theorem 1.1/1.2 family, `t = 2` (diff-4 permutation, n = 30) | not APN → **out of catalog scope** |
| Theorem 1.2 family, `t = 1` at n = 15 (k=5; s=1,4,7,13) — APN | **not-new / present in core**: verified identical to `α · bcp_apn(k,s)` — elementwise LUT equality asserted here for `(5,1)`, `(5,4)`, `(4,5)`, `(2,1)`. No `n15_apn.toml` exists (catalog covers n ∈ {4,…,12}), so no gap record is warranted |
| Theorem 1.2 family, `t = 1` at n = 12 (k=4; s=5,11) — APN | **out of this paper's scope**: these are BCL/BCP binomials (core `bcp_apn(4,5)`, `bcp_apn(4,11)`; both pass the g₁≠g₂ guard, g₁=7, g₂=1) and are absent from `packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml` (which holds only the two `Calderini_202306` entries). The CCZ/EA comparison via `apn_ea_mugshot`/ortho-derivative tooling *is* runnable here — Julia 1.12.6 is installed; it was deliberately not run, because any resulting addition belongs to `Budaghyan_200809`, not to this paper, and would require the gated catalog rebuild |
| Problem 5.1 family (BBMM quadrinomial) | already reproduced under `packages/VBFRepro/papers/2011/Bracken_201103`; verified APN at n=15 in sampling. Not claimed new here |

**Catalog-gap records emitted: none.** No `.toml` should be edited on the basis of this paper.

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `bracken_binomial` / `_lut` / `_sbox` | `helpers.jl` | **Partial duplication, now anchored.** The `t = 1` output is exactly `α ·` core `_apn_binomial_lut` / `bcp_apn` (`packages/VBF/src/constructions/apn_quadratic_families.jl:38,73`), and the test asserts that elementwise for four `(k,s)`. Legitimately paper-specific only for `t > 1`, which `bcp_apn` rejects — also asserted. Parameter validation now mirrors `bcp_apn` (BTT-6) |
| `walsh_value_set` / `linearity_rowwise` | `helpers.jl` | **Not a violation** — a streaming variant of core `linearity` / `absolute_walsh_spectrum` (`packages/VBF/src/spectra/linear.jl:61,90`), needed because the full n=15 LAT is ~8 GB. Reuses core `walsh_hadamard!` and core `lat`; the non-streaming branch *is* core. Asserted equal to core at n=12. Self-flagged `TODO(promote-to-core)` |
| `differential_value_set` | `helpers.jl` | **Not a violation, but time-motivated rather than memory-motivated** — the `streaming = false` branch is literally `first.(sorted_pairs(differential_spectrum(F)))` and is the default up to n = 12. The local branch exists only because core's `Dict` costs 10.6 s at n = 15 against 1.7 s, measured here. Asserted equal to core at n=12. Self-flagged `TODO(promote-to-core)` |
| `alpha_is_primitive`, `PAPER_PRIMITIVE_POLYNOMIALS` | `helpers.jl` | **No core equivalent** — core has no primitivity predicate and `PRIMITIVE_POLYNOMIALS` stops at n = 16. Both self-flagged `TODO(promote-to-core)` |
| `streaming_permutation_check`, `derivative_kernel_dims` | `helpers.jl` | **Justified** — core `is_permutation` and `is_quadratic_apn_rank` both require a materialised LUT (2³⁰ entries) and the latter hard-codes the APN rank `N−1`. Rank itself comes from core `gauss_jordan!`; the n≤15 behaviour is cross-checked against core `differential_uniformity` in the tests |
| `problem5_1_lut` | `problem5_1.jl` | Paper-specific quadrinomial; asserted to reduce to `bracken_binomial_lut` at `v=w=0` |

Cross-paper duplication (informational): `bracken_binomial_lut(k,s)` is the `v = w = 0` special
case of `packages/VBFRepro/papers/2011/Bracken_201103/helpers.jl:36` `bracken_lut(k,s,u,v,w)`. Paper folders are
meant to be standalone, so this is acceptable — but it means the Problem 5.1 experiment (BTT-5)
needs no new mathematics.

**Promote-to-core candidates:**
1. **Streaming `linearity` / Walsh value-set** (one LAT column at a time, O(2ⁿ) memory). Generic,
   no paper-specific logic; belongs in `packages/VBF/src/spectra/linear.jl`. Already noted
   in-file.
2. **Rank-based differential uniformity for quadratic functions.** Core has
   `is_quadratic_apn_rank` (`packages/VBF/src/invariants/quadratic_apn_rank.jl:46`), but it
   hard-codes rank `N−1` (APN only, no `2^t` generalization) and requires a materialized LUT. A
   version parameterized by the target kernel dimension and driven by a derivative callback is
   exactly what makes the n=30 headline checkable (BTT-1).
3. **Primitive polynomials beyond n = 16** (`PRIMITIVE_POLYNOMIALS` stops at 16), needed for any
   n = 30 work; e.g. `x³⁰+x⁶+x⁴+x+1` (= 1073741907), for which α = 2 has verified order 2³⁰−1.

---

## Open questions

1. **Answered by construction.** The n = 30 work ships as an opt-in `full_search = true` path
   with an explicit `limit` default, exactly as AGENTS.md's "expensive searches must accept
   explicit limits" allows. The default test path never runs it: it scans a `2¹⁶` prefix
   (0.27 s) and asserts `!conclusive`, so a partial scan cannot pass for a proof. Whether the
   project *also* wants a long-running CI target is still a policy call for a human.
2. **Answered.** Problem 5.1's refutation lives in `problem5_1.jl` inside this folder, and is
   filed under **Paper Issue 1** rather than as a reproduction defect.
3. **Answered.** Core `gold_apn(6,2)` / `kasami_apn(6,2)` throw on `gcd(k,n) = 1` and
   `inverse_apn(6)` throws on even `n` — all three guard the APN, odd-n regime, which is not
   the regime Table 1 concerns. `section5.jl` therefore builds the monomials with core
   `gf_monomial_lut`, the API those constructors themselves call.
4. **Still open, and out of scope here.** The n = 12 BCL binomials (`bcp_apn(4,5)`,
   `bcp_apn(4,11)`) are absent from `n12_apn.toml`. That belongs to `Budaghyan_200809`, not to
   this paper, and touching `packages/VBFCatalog/data-raw/` requires the gated rebuild — no
   catalog change was made in this pass.
