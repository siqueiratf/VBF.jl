# Bracken, Tan & Tan (2012) — Binomial differentially 4 uniform permutations with high nonlinearity

- **Citation:** C. Bracken, C.H. Tan, Y. Tan, "Binomial differentially 4 uniform permutations with
  high nonlinearity", *Finite Fields Appl.* 18:537–546, 2012.
- **Reproduction path:** `papers/2012/Bracken_201205/`
- **Paper source:** `input/Bracken et al. - 2012 - Binomial differentially 4 uniform permutations with high nonlinearity.tex`
- **Verdict:** **Partial** — everything implemented is numerically correct and the degeneracy
  caveat is documented honestly, but the reproduction covers only 3 of 12 computationally
  feasible parameter instances, verifies *weaker* statements than Lemma 3.1 and Theorem 1.1
  actually make, and omits four cheaply reproducible paper items (Table 1, the Section 5 CCZ
  remarks, the Section 1 general family `G`, Problem 5.1). The title claim — a genuine
  (non-degenerate) binomial differentially-4-uniform permutation — is never exhibited, although
  the n=30 case turns out to be reachable (~5 min for the permutation half, seconds for a
  rank-based differential check).

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

Defects introduced in our implementation.

#### BTT-1 — Headline claim declared out of scope when it is partly reachable

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

#### BTT-2 — Lemma 3.1's differential *spectrum* claim is not checked

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

#### BTT-3 — Theorem 1.1's Walsh *spectrum-set* claim is not checked

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

#### BTT-4 — Table 1 and the Section 5 remarks are absent

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

#### BTT-5 — Problem 5.1 is dismissed instead of tested

- **Location:** `report.jl:34` — "[out-of-scope] Problem 5.1 — open problem, no proof available".
- **Symptom:** a conjecture with an explicit finite instance is exactly what a reproduction can
  test; the negative result of Paper Issue 1 is currently being thrown away. The required
  quadrinomial is already coded in the sibling folder
  (`papers/2011/Bracken_201103/helpers.jl:36`), so no new mathematics is needed.
- **Root cause:** "open problem" was read as "not reproducible".
- **Resolution plan:**
  1. Add `problem5_1.jl` building `G` for `(k,s) = (5,1)`.
  2. Scan all 993 `(v,w) ∈ F_32²` with `vw ≠ 1` for the permutation property (~seconds); report
     that only `v = w = 0` is a permutation.
  3. Sample a `limit`-bounded subset for `differential_spectrum == {0,2}` (holds in every case
     tested).
  4. Record the outcome as "conjecture's differential half supported; permutation half refuted
     at t=1".

#### BTT-6 — The family constructor accepts invalid parameters

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

#### BTT-7 — Inaccurate "smallest non-degenerate case" claim

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

#### BTT-8 — No cross-check against core's identical construction

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

#### BTT-9 — Mutually inconsistent runtime documentation

- **Location:** `section3.jl:10` ("~30 s exhaustive"), `test/test_section3.jl` ("~0.5 s here"),
  `Makefile` help ("n=15 ~1 s"), `test/test_section4.jl` ("~2 s here").
- **Symptom:** three different runtimes quoted for the same n=15 differential scan. Optimized C
  on this machine: n=15 differential scan 0.99 s, streaming Walsh 5.01 s — so "~30 s" and
  "~0.5 s / ~2 s" bracket the truth from both sides.
- **Root cause:** figures were estimated at different times and never reconciled.
- **Resolution plan:** measure once with `@elapsed` and use one consistent figure across
  `section3.jl`, `section4.jl`, `Makefile`, and the tests.

#### BTT-10 — Parameter-space coverage is 3 of 12 feasible instances

- **Location:** `section2.jl:18-22`, `section3.jl:19-22`, `section4.jl:20-23`.
- **Symptom:** only `(2,4)`, `(4,2)`, `(5,1)` are exercised. The full feasible set with n=3k ≤ 15
  satisfying Theorem 1.2, with independently verified outcomes:

  | k | s | n | t | k/t | shape | perm | diff. spectrum | Walsh values | in repro |
  |---|---|---|---|---|---|---|---|---|---|
  | 1 | 2 | 3 | 1 | odd | degenerate | yes | `{0,2}` | `{0,±4}` | no |
  | 2 | 1 | 6 | 1 | even | binomial | no | `{0,2}` | `{0,±8,±16}` | no |
  | 2 | 4 | 6 | 2 | odd | degenerate | yes | `{0,4}` | `{0,±16}` | **yes** |
  | 4 | 2 | 12 | 2 | even | binomial | no | `{0,4}` | `{0,±64,±256}` | **yes** |
  | 4 | 5 | 12 | 1 | even | binomial | no | `{0,2}` | `{0,±64,±128}` | no |
  | 4 | 8 | 12 | **4** | odd | degenerate | yes | **`{0,16}`** | `{0,±256}` | no |
  | 4 | 11 | 12 | 1 | even | binomial | no | `{0,2}` | `{0,±64,±128}` | no |
  | 5 | 1 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | **yes** |
  | 5 | 4 | 15 | 1 | odd | binomial | yes | `{0,2}` | `{0,±256}` | no |
  | 5 | 7 | 15 | 1 | odd | binomial | yes | — | — | no |
  | 5 | 10 | 15 | **5** | odd | degenerate | yes | **`{0,32}`** | `{0,±1024}` | no |
  | 5 | 13 | 15 | 1 | odd | binomial | yes | — | — | no |

  The `t = 4` and `t = 5` rows are the only feasible evidence that Lemma 3.1's exponent is really
  `2^t` and not "4 or 2"; both are absent.
- **Resolution plan:** extend `SECTION2/3/4_CASES` to the full grid, at minimum adding `(2,1)`,
  `(4,8)` (t=4, du=16) and `(5,10)` (t=5, du=32).

#### BTT-11 — Smaller omissions

- **Section 1 general family `G(x) = αx^{2^s+1} + α^{2^k}x^{2^{ik}+2^{tk+s}}`** (`i ≡ ks`,
  `t ≡ −i mod 3`) is not implemented and not mentioned in `report.jl`'s scope block. Genuinely
  infeasible at t=2, but it should at least be listed as transcribed-only.
- **Lemma 4.1** (≤ 2^d roots of `∑ r_i x^{2^{si}}` when `gcd(n,s)=1`) is never exercised; a
  randomized check would be cheap.
- **Quadraticity** — the paper's whole proof strategy rests on F being quadratic, but
  `algebraic_degree(F) == 2` is never asserted.
- **α primitive** — a stated hypothesis, never asserted. It does hold: the order of 2 is 7, 63,
  4095, 32767 for n = 3, 6, 12, 15 under `PRIMITIVE_POLYNOMIALS`.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Lemma 2.1** (permutation iff `k/t` odd) — odd branch, n=6 (k=2, s=4) | `section2.jl:19` | perm = true |
| **Lemma 2.1** — even branch, n=12 (k=4, s=2) | `section2.jl:20` | perm = false |
| **Lemma 2.1** — odd branch, n=15 (k=5, s=1), genuine binomial | `section2.jl:21` | perm = true |
| **Lemma 3.1** (`Δ_F = 2^t`), n=6 t=2 and n=15 t=1 | `section3.jl:20-21` | du = 4 and 2 (max only — see BTT-2) |
| **Lemma 4.2** (Walsh bound `2^{(n+t)/2}`), n=6 and n=15 | `section4.jl:21-22` | linearity = 16 and 256 (bound only — see BTT-3) |
| Degeneracy caveat for the t=2 headline | `helpers.jl:30-31`, `report.jl:24-33` | correctly identified: `e₁ ≡ e₂ ≡ 17 (mod 63)` |

None of the implemented computations is wrong; the issues above are all scope, claim-strength,
and documentation.

---

## Test results

`make -C papers/2012/Bracken_201205 test` → **could not run**: `make: julia: No such file or
directory`. No Julia toolchain exists in the review environment.

All three test files' assertions were independently re-derived and **hold**: `(2,4)` perm=true,
du=4, Walsh `{0,±16}`; `(4,2)` perm=false; `(5,1)` perm=true, du=2, Walsh `{0,±256}`.

Verification used a C/Python re-implementation of VBF's exact field conventions (`gf_mul`/
`gf_pow` bit-convention, `PRIMITIVE_POLYNOMIALS`, `lat` = ±1 Walsh sum). Re-confirm under Julia
before relying on the numbers. Bibliography and CI wiring are correct: `Bracken_201205` is at
`packages/VBFCatalog/data-raw/bibliography.bib:596` and in `.github/workflows/ci.yml:38`.

---

## Catalog status

**No APN function is claimed as new by this paper.** Its contribution is a differentially
*4*-uniform permutation (Table 1, row 5); the APN specialization (`t = 1`) is explicitly
attributed to ref [8] (Budaghyan–Carlet–Leander 2008, `Budaghyan_200809`).

| Claimed object | Status |
|---|---|
| Theorem 1.1/1.2 family, `t = 2` (diff-4 permutation, n = 30) | not APN → **out of catalog scope** |
| Theorem 1.2 family, `t = 1` at n = 15 (k=5; s=1,4,7,13) — APN | **not-new / present in core**: verified identical to `α · bcp_apn(k,s)` (elementwise LUT equality for (5,1)). No `n15_apn.toml` exists (catalog covers n ∈ {4,…,12}), so no gap record is warranted |
| Theorem 1.2 family, `t = 1` at n = 12 (k=4; s=5,11) — APN | **unverifiable here**: these are BCL/BCP binomials (core `bcp_apn(4,5)`, `bcp_apn(4,11)`; both pass the g₁≠g₂ guard, g₁=7, g₂=1) and are absent from `packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml` (which holds only the two `Calderini_202306` entries). The CCZ/EA comparison needs `apn_ea_mugshot`/ortho-derivative tooling, unrunnable without Julia. Any addition belongs to `Budaghyan_200809`, not to this paper |
| Problem 5.1 family (BBMM quadrinomial) | already reproduced under `papers/2011/Bracken_201103`; verified APN at n=15 in sampling. Not claimed new here |

**Catalog-gap records emitted: none.** No `.toml` should be edited on the basis of this paper.

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `bracken_binomial_lut` | `helpers.jl:33-43` | **Partial duplication.** Its `t = 1` output is exactly `α ·` core `_apn_binomial_lut` / `bcp_apn` (`packages/VBF/src/constructions/apn_quadratic_families.jl:38,73`). Legitimately paper-specific only for `t > 1`, which `bcp_apn` rejects. Keep, but add the equality cross-check (BTT-8) and the parameter validation `bcp_apn` already has (BTT-6) |
| `bracken_binomial_sbox` | `helpers.jl:48-51` | Fine — thin `SBox` wrapper |
| `linearity_rowwise` | `helpers.jl:63-80` | **Not a violation** — a genuine streaming variant of core `linearity` (`packages/VBF/src/spectra/linear.jl:90`), needed because the full n=15 LAT is ~8 GB. Correctly reuses core `walsh_hadamard!`, and its LAT convention matches core `lat` exactly. Already self-flagged at `helpers.jl:60-62` |

Cross-paper duplication (informational): `bracken_binomial_lut(k,s)` is the `v = w = 0` special
case of `papers/2011/Bracken_201103/helpers.jl:36` `bracken_lut(k,s,u,v,w)`. Paper folders are
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

1. Is the n = 30 boundary a hard project policy, or may a paper ship an opt-in long-running
   target (`full_search=true`, several minutes) as AGENTS.md's "expensive searches must accept
   explicit limits" seems to allow? BTT-1's resolution depends on this.
2. Should Problem 5.1's negative result (Paper Issue 1) be recorded inside this paper's folder,
   or does the project prefer refutations of open problems to live elsewhere?
3. Should Table 1's prior rows reuse core `gold_apn` / `kasami_apn` / `inverse_apn` (documented
   for the APN, odd-n regime) or be built as plain monomial LUTs via `gf_monomial_lut` for the
   even-n differentially-4 regime the table actually concerns?
4. The n = 12 BCL binomials (`bcp_apn(4,5)`, `bcp_apn(4,11)`) are absent from `n12_apn.toml`.
   Pursue that under `Budaghyan_200809` (a separate review), since it is out of this paper's
   novelty scope?
