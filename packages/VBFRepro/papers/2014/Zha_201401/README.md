# Zha_201401 — Constructing new differentially 4-uniform permutations from the inverse function

## Audit corrections (2026-10-10)

F014 now has executable evidence separate from the printed Table 1.
Row 3 is pinned at NL=110 and differential spectrum
`{0:33111,2:31698,4:471}` for every nonzero GF(4) scalar under both field
representations, against the printed NL=108 and repeated row-4 spectrum.
`TABLE1_PUBLISHED` preserves the paper's values while the report explicitly
shows the mismatch. Equal NL=110 invalidates the paper's stated nonlinearity
separation from reference [16]; it does **not** establish CCZ equivalence.
A concrete earlier inverse-swap control, `Yuyin_201300.inverse_swap(1,32,8)`
with modulus 283, has du=4 and NL=110 but a different differential spectrum,
proving separation from that one reference. `proposition5.jl` now checks the
entire cited inverse two-point-swap family at n=8: 255 normalized LUTs, all
32,640 unordered pairs (including zero), and all 8,355,840 scaling-identity
graph points. The source trace conditions select 9,180 DU4 pairs among 32,385
nonzero pairs. Exact differential and absolute-Walsh spectra separate all 18
nonzero-scalar Zha instances from this entire finite family and its affine
equivalents. Unequal invariants prove CCZ inequivalence; equal invariants never
prove equivalence. These are DU4 permutations, so no quadratic-APN theorem is
used. The broader claim of separation from every earlier construction remains
unresolved. The cube
root helper now selects a verified primitive element rather than assuming
integer 2 generates the multiplicative group.


Run the bounded comparison with `make -C packages/VBFRepro/papers/2014/Zha_201401 proposition5 timeout_seconds=60 save_results=true`.
Evidence is optional under `results/proposition5.toml`; an interrupted run is
reported as inconclusive. The earlier source is [Yu, Wang and Li, IACR 2011/047](https://eprint.iacr.org/2011/047.pdf), Section 4,
Proposition 4, Theorem 1, Corollary 1 and Remark 2. The local earlier-paper source
is absent; these hypotheses were checked against that original public PDF.
The historical review below predates this finite-family extension.

**Citation**: Z. Zha, L. Hu, S. Sun, *Constructing new differentially 4-uniform
permutations from the inverse function*, Finite Fields and Their Applications
25:64–71 (2014).

**Reproduction path**: `packages/VBFRepro/papers/2014/Zha_201401/`

**Verdict**: **Partial** (leaning Mostly complete on what it covers) — every
claim the reproduction implements is implemented correctly: all 83 test
assertions execute and pass under Julia 1.12.6 (exit 0), and every number was
additionally re-derived independently. The three constructions
(Eq. 3, Eq. 8, Theorem 6) are transcribed faithfully, and the two places where
the reproduction deviates from the printed tables are genuine paper typos,
confirmed here. It is *Partial* because roughly half the paper's reproducible
content is absent: all six **Propositions** (including Proposition 5, the paper's
novelty claim), the three **compositional inverses** stated in closed form,
**Theorem I**, and all six **Lemmas** have no implementation file. Each theorem
is also validated at a single hard-coded parameter rather than over the family it
quantifies over, and two of Theorem 3's three branches are never exercised.

---

## Issue Catalog

### Paper Issues

1. **Table 1, row 3 (sn=8, `x²⁵⁴ + t(x⁴+x)²⁵⁵ + t`): 𝒩ℒ(f) and 𝒟(f) are
   wrong.** The paper prints NL=108 and 𝒟={0³⁴³³⁵, 2²⁹²⁵⁰, 4¹⁶⁹⁵}, which is
   character-for-character row 4's data. The true values for (s,n)=(2,4) are
   **NL=110, 𝒟={0³³¹¹¹, 2³¹⁶⁹⁸, 4⁴⁷¹}** — invariant over all t ∈ F₄\* and under
   both the primitive (x⁸+x⁴+x³+x+1) and Conway (x⁸+x⁴+x³+x²+1) moduli. Row 4
   (s=4,n=2) reproduces the paper exactly, so the paper duplicated row 4 into
   row 3. The reproduction already documents this at `table1.jl:16-19`; the
   diagnosis is correct.

2. **Table 2, row 2 (sn=6, `ωx⁶² + ω²x⁶²(x⁴+x)⁶³`): 𝒟(f) is wrong.** The paper
   prints {0²¹²⁷, 2¹⁷⁹⁴, 4¹¹¹}, which is Table 1 row 2's spectrum. The true
   value is **{0²¹⁵¹, 2¹⁷⁴⁶, 4¹³⁵}**; NL=22 is correct. Documented at
   `table2.jl:17-21` — again the correct diagnosis.

3. **Proposition 5's F_{2⁸} argument does not survive the Issue 1 correction.**
   *(New finding — not noted in the reproduction.)* Section 5 argues: "the
   differentially 4-uniform permutations of [16] have the nonlinearity 110 on
   F_{2⁸}. That is to say, our new functions in Theorem 1 are also
   CCZ-inequivalent to the [16] functions on F_{2⁸}." That inference rests on the
   Theorem 1 function having NL ≠ 110. With the corrected value, the **s=2, n=4
   instance has NL = 110 exactly**, so nonlinearity alone no longer separates it
   from Yu–Wang–Li [16]. The s=4, n=2 instance (NL=108) is unaffected, so
   Proposition 5's conclusion may still hold — but the stated *proof* is
   incomplete for the q=4 instance, and re-establishing it needs [16]'s
   differential spectrum, which the paper does not give.

   **Cross-paper corroboration**: reference [16] is reproduced in this repo as
   [`packages/VBFRepro/papers/2013/Yuyin_201300`](../../2013/Yuyin_201300/README.md). That review
   independently confirmed nl = 110 for **all 32385** functions I₍u,v₎ with
   uv≠0 on GF(2⁸) — so the collision is real on both sides, not an artifact of
   either reproduction.

4. **Abstract vs. Theorems 2 and 5.** The abstract claims families "over
   F_{2^{2m}}", but Theorems 2 and 5 construct differentially 4-uniform
   permutations over F_{2^{sn}} with sn **odd**, which is not of the form 2m.
   Internal scope inconsistency, not an error in the theorems.

5. **OCR/typesetting artifacts in the supplied `.tex`** (the file is a machine
   conversion, not publisher source): Theorem I item 1) has a stray `g` before
   `gcd`; item 4) renders `x^{2^{2t}+2^t+1}` as `x^{2^{2t}}+2^t+1`; the Section 4
   opening writes `Tr_s^{Sn}` with a capital S. Low severity — flagged so a
   reader does not transcribe them into code.

### Reproduction Issues

1. **`nl_lower_bound` returns a false bound for odd `sn`.**
   - **Location**: `helpers.jl:178-181` —
     `(1 << (N - 1)) - (1 << (N ÷ 2)) - (1 << s)`.
   - **Symptom**: for odd `N` the value is *larger* than Propositions 2/4/6
     allow, so a `NL ≥ ℬ(f)` check would report FAIL on correct functions.
     Concretely: (s,n)=(1,7) → helper returns **54**, the paper's bound is
     2⁶ − 2^{3.5} − 2 ≈ **50.69**, actual NL is **52**. (s,n)=(3,3) → helper
     returns **232**, paper bound ≈ **225.37**, actual NL **230**.
   - **Root cause**: `1 << (N ÷ 2)` silently truncates 2^{sn/2} to 2^{⌊sn/2⌋}
     when sn is odd. Propositions 2/4/6 are stated for arbitrary sn, and
     Theorems 2 and 5 live entirely in the odd-sn regime.
   - **Resolution plan**:
     1. Compute the bound in floating point when `isodd(N)`:
        `2.0^(N-1) - 2.0^(N/2) - 2.0^s`, returning a `Float64` (or
        `ceil(Int, …)` if an integer is required).
     2. Keep the exact integer path for even `N` so the Table 1/2 ℬ(f)
        comparisons stay exact.
     3. Add assertions `NL ≥ nl_lower_bound(s,n)` for the odd-sn instances
        (1,5), (1,7), (3,3) of Theorems 2 and 5.
     4. Move the check into dedicated `proposition2.jl` / `proposition4.jl` /
        `proposition6.jl` files.

   *This is the only outright incorrect computation in the reproduction —
   highest priority.*

   **Latent under `make test`** (established by execution, 2026-08-15): the only
   callers of `nl_lower_bound` are `table1_compute` (params (2,2),(2,3),(2,4),(4,2))
   and `table2_row1/2/3` (N=4,6) — all even `sn` — so no executed path reaches the
   truncating branch. The suite passes 83/83 **with the defect present**, which is
   precisely why it needs the odd-`sn` assertions in step 3; as the files stand, no
   regression run would ever catch this.

2. **All six Propositions have no implementation file.**
   - **Location**: paper directory root; only `theorem1..6.jl`, `table1.jl`,
     `table2.jl`, `example1.jl` exist.
   - **Symptom**: Propositions 1–6 are unreproduced. The mandatory naming rule
     (`.claude/skills/reproduce-paper/SKILL.md:85-92`) expects
     `proposition2.jl`-style names so the paper reads side-by-side.
   - **Root cause**: reproduction scope stopped at theorems + tables.
   - **Resolution plan**:
     1. `proposition1.jl`: for each covered (s,n), assert
        `algebraic_degree(f) == N-1` **and**
        `algebraic_degree(compositional_inverse(SBox{N}(lut))) == N-1` for
        Construction 1.
     2. `proposition3.jl`: same for Construction 2.
     3. `proposition2.jl` / `proposition4.jl` / `proposition6.jl`:
        `print_check("NL ≥ 2^{sn-1} − 2^{sn/2} − 2^s", …)` for Constructions
        1/2/3 (depends on Issue 1).
     4. `proposition5.jl`: build the Theorem I families at n=6 and n=8, print
        their (NL, `differential_spectrum`) alongside the Zha functions, and
        `print_check` that each pair differs — using the baseline below. Add an
        explicit FAIL/warning line for the [16] NL=110 collision (Paper Issue 3).

   Separating invariants computed during this review, for use as the regression
   baseline:

   | n=8 function | Δ | NL | 𝒟(f) |
   |---|---|---|---|
   | Inverse x²⁵⁴ | 4 | 112 | {0³²⁸⁹⁵, 2³²¹³⁰, 4²⁵⁵} |
   | Theorem I 6) Tan–Qu–Tan–Li | 4 | 102 | {0³⁶⁷³⁵, 2²⁴⁴⁵⁰, 4⁴⁰⁹⁵} |
   | Theorem I 7) k=2 | 4 | 98 | {0³⁶⁴⁹⁵, 2²⁴⁹³⁰, 4³⁸⁵⁵} |
   | Theorem I 7) k=3 | 4 | 100 | {0³⁶³⁵¹, 2²⁵²¹⁸, 4³⁷¹¹} |
   | **Zha Thm 1, s=2,n=4** | 4 | **110** | {0³³¹¹¹, 2³¹⁶⁹⁸, 4⁴⁷¹} |
   | **Zha Thm 1, s=4,n=2** | 4 | **108** | {0³⁴³³⁵, 2²⁹²⁵⁰, 4¹⁶⁹⁵} |

   At n=6, for the Theorem 4 instance: Gold x⁵ NL=24, Kasami x¹³ NL=24, Inverse
   NL=24 (all maximal); TQTL 6) NL=20, 𝒟={0²³⁰¹,2¹⁴⁴⁶,4²⁸⁵}; TQTL 7) k=2 NL=22,
   𝒟={0²²²³,2¹⁶⁰²,4²⁰⁷}; vs Zha Thm 4 𝒟={0²¹⁵¹,2¹⁷⁴⁶,4¹³⁵}.

3. **Theorem I not implemented.**
   - **Location**: no `theoremI.jl`.
   - **Symptom**: the reference set that Proposition 5 argues against is absent,
     so the novelty claim has no baseline in the repo.
   - **Root cause**: same scope decision as Issue 2.
   - **Resolution plan**:
     1. Add `theoremI.jl` with the seven families and their exact parameter
        guards (`gcd(i,n)=2, n=2t, t odd` for 1)–2); `n=4t, t odd` for 4);
        `n=3t, t/2 odd, gcd(n,s)=2, 3∣t+s` for 5); `n=2t, 2≤k≤t−1` for 7)).
     2. Reuse `gold_apn`, `kasami_apn`, `inverse_apn`, `gf_monomial_lut` from
        core rather than re-rolling monomial LUTs.
     3. Assert Δ=4 for each family at the smallest admissible n, and record
        NL/𝒟 for `proposition5.jl` to consume.

4. **The three compositional inverses are never built.**
   - **Location**: paper §3.1 (g after Theorem 3), §3.2 (g after Theorem 5), §4
     (g after Theorem 6); nothing in the reproduction.
   - **Symptom**: the paper gives explicit closed forms for all three g's and
     asserts each has the same Δ and degree sn−1 ("Checked by a computer…" for
     Theorem 6). None of that is reproduced.
   - **Root cause**: `compositional_inverse` (a core export) is never called.
   - **Resolution plan**:
     1. Add `construction1_inverse_lut`, `construction2_inverse_lut`,
        `construction3_inverse_lut` to `helpers.jl` transcribing the paper's
        three closed forms.
     2. Assert `lut_g == compositional_inverse(SBox{N}(lut_f)).lut` for each.
     3. Assert `differential_uniformity(g) == differential_uniformity(f)` and
        `algebraic_degree(g) == N-1` (both verified to hold in all 23 instances
        tested).

   **Transcription now de-risked** (execution, 2026-08-15): all three closed forms
   taken from the paper (§3.1 g, §3.2 g, §4 g) reproduce
   `compositional_inverse(SBox{N}(lut_f)).lut` **exactly** — Construction 1 at
   (2,2),(2,3),(2,4),(1,3),(3,2); Construction 2 at (2,3),(1,3),(1,5),(3,3);
   Construction 3 at (2,2),(2,3),(1,4) — with Δ_g = Δ_f and deg g = sn−1 in every
   case, confirming the paper's "Checked by a computer" remark after Theorem 6. Only
   the repo files are missing; the math is settled.

5. **Two of Theorem 3's three branches are dead.**
   - **Location**: `theorem3.jl:14-22` (`expected_du_theorem3`), `theorem3.jl:37`
     (default params), `test/test_theorem3.jl`.
   - **Symptom**: the `s ≥ 5 → 6` branch and the `s = 3 with n/2 even → 6`
     branch are never reached by any test; `s=3` is only tested at `n=2`
     (n/2 odd → 4).
   - **Root cause**: the parameter list stops at N=8.
   - **Resolution plan**:
     1. Add `(5, 2)` → N=10 to the default params and to `test_theorem3.jl`
        (verified: Δ=6).
     2. Add `(3, 4)` → N=12 behind a `limit` / `full_search` Makefile knob
        (verified: Δ=6).
     3. Note in the file header that `(1,2)` is a smoke test only (Issue 14).

6. **Each theorem is validated at a single hard-coded parameter.**
   - **Location**: `theorem1.jl:16`, `theorem2.jl:22`, `theorem3.jl:27`,
     `theorem4.jl:17`, `theorem5.jl:19`, `theorem6.jl:16-17`.
   - **Symptom**: the theorems quantify over all t ∈ F_q\* (Thm 1–3), all
     t₁,t₂ ∈ F_q with Tr(t₁⁻¹)=1 (Thm 4–5), and all t₁ with Tr_s^{sn}(t₁)=0 plus
     t₂ ∈ F_q\* (Thm 6). Only one representative is exercised, so the verdict is
     "single instance verified", not "parameter family validated".
   - **Root cause**: `*_verify` functions bake the parameter in rather than
     accepting it.
   - **Resolution plan**:
     1. Give each `*_verify` an optional `t` / `t1` / `t2` keyword defaulting to
        the current choice (keeps report output stable).
     2. Add `*_verify_all(s, n)` sweeping the admissible parameter set.
     3. Assert the theorem conclusion for every member at the small (s,n). These
        sweeps were run during review and all pass — Theorem 1 all t; Theorem 2
        all 7 t at (3,3); Theorems 4/5 all (t₁,t₂); Theorem 6 all (t₁,t₂) across
        11 (s,n) pairs.

7. **Theorem 1 pins `t` to a cube root of unity, stronger than the theorem.**
   - **Location**: `theorem1.jl:16` → `helpers.jl:40-45`
     `find_t_construction1`, which returns ω and asserts `3 ∣ 2^N − 1`.
   - **Symptom**: Theorem 1's hypothesis is only `t ∈ F_q^*`; the helper
     conflates that with Table 1's specific choice `t³ = 1`. A reader comparing
     Theorem 1 to the code sees a condition the theorem does not impose.
   - **Root cause**: one helper serving two different roles.
   - **Resolution plan**:
     1. Rename `find_t_construction1` → `table1_t` (its actual job) and keep it
        in `table1.jl`'s orbit.
     2. Have `theorem1_verify` default to any/all t ∈ F_q\* (ties into Issue 6).

8. **`find_omega` silently assumes α = 2 is primitive for the supplied
   modulus.**
   - **Location**: `helpers.jl:28-32` — `gf_pow(2, order ÷ 3, N; modulus)`.
   - **Symptom**: the signature accepts an arbitrary `modulus`, but the formula
     is only valid when the modulus is primitive. With a merely-irreducible
     modulus it returns a wrong ω with no error, and the downstream
     `in_subfield` assert at `helpers.jl:43` does **not** catch it. Verified in
     Julia: with modulus 31 (`x⁴+x³+x²+x+1`, irreducible but not primitive —
     α=2 has multiplicative order 5), `find_omega(4; modulus=31)` returns
     **ω = 1**, and `in_subfield(1, 2, 4; modulus=31)` is `true`, so
     `find_t_construction1` silently returns `t = 1` with no error. The
     precondition is entirely unguarded.
   - **Root cause**: unchecked precondition.
   - **Resolution plan**:
     1. Post-check `gf_pow(ω, 3, N; modulus) == 1 && ω != 1`, throwing
        otherwise.
     2. Or solve x² + x + 1 = 0 directly by scanning, which is modulus-agnostic.
     3. Better: promote a generic `gf_root_of_unity(n, d; modulus)` to
        `packages/VBF/src/representations/finite_field.jl` (see Library-reuse
        note).

9. **Table expectations silently absorb the reproduction's own output for the
   two disputed rows.**
   - **Location**: `table1.jl:24` (row sn=8, s=2), `table2.jl:25` (row sn=6,
     t₂=0); mirrored in `test/test_table1.jl:5-12` and
     `test/test_table2.jl:14-19`.
   - **Symptom**: for those two rows the "expected" constant *is* the
     reproduction's output, so the test asserts computed == computed. There is
     no PASS/FAIL signal reporting that the paper's own printed numbers were not
     reproduced, and a regression that shifted the computation would need a
     human to notice.
   - **Root cause**: the deviation is documented in comments but folded into the
     assertion data.
   - **Resolution plan**:
     1. Keep two constants per row: `TABLE1_PAPER` and `TABLE1_REPRODUCED`.
     2. `print_check` the paper value with an explicit `(paper typo — expected
        FAIL)` label, and `@test` against the reproduced value.
     3. Both deviations are recorded above as Paper Issues 1–2, with the
        evidence that they are modulus- and t-independent.

10. **Dead Makefile knobs.**
    - **Location**: `Makefile:8-9` (`limit ?=`, `save_results ?=`) and
      `Makefile:20-21` (`clean_results`).
    - **Symptom**: no `.jl` file reads either variable and no `results/`
      directory is ever written, so `clean_results` removes a path that cannot
      exist.
    - **Resolution plan**: either wire `save_results=true` to emit
      `results/table1.csv` / `results/table2.csv` from the report functions (and
      use `limit` for the Issue 5 large-N cases), or delete the two variables
      and the `clean_results` target.

11. **`report.jl` advertises a parameter range it does not run.**
    - **Location**: `report.jl:29` — `"Parameter range: sn ≤ 8 (exact), sn ≤ 10
      (bounded)"`.
    - **Symptom**: the largest instance actually run is sn = 9 ((3,3) in
      Theorems 2 and 5), and nothing is "bounded" — every run is exhaustive.
    - **Resolution plan**: correct the string to `sn ≤ 9 (exhaustive)`, or extend
      to sn=10 by adding (5,2) to Theorem 3 and (2,5) to Theorem 4 (both
      verified feasible and correct).

12. **`theorem2.jl` header comment is unresolved scratch deliberation.**
    - **Location**: `theorem2.jl:9-13`.
    - **Symptom**: the block argues with itself ("Actually when s,n odd… / The
      paper says t ∈ F_q\*, NOT t³=1 for odd s. / Re-reading: Theorem 2 just
      requires t ∈ F_q\*"), which reads as unfinished work in a file meant to be
      read against the paper.
    - **Resolution plan**: replace with the settled statement — "Theorem 2
      requires only t ∈ F_q\*; for s=1 the only choice is t=1, and for s>1 the
      conclusion is t-independent (verified by sweep)."

13. **`theorem6_verify` has no parameter guard and computes S twice.**
    - **Location**: `theorem6.jl:14-24`; `helpers.jl:118-133` and
      `helpers.jl:141-154`.
    - **Symptom**: unlike Theorems 1–5 it has no `@assert` on the paper's
      hypotheses (t₁ ∈ F_{q^n}\* with Tr_s^{sn}(t₁)=0, t₂ ∈ F_q\*), so it will
      happily accept invalid parameters. `build_affine_subspace` is called once
      inside `construction3_lut` and again at `theorem6.jl:22` for `s_size`.
    - **Resolution plan**:
      1. Add `@assert gf_relative_trace(t1, N, s; modulus) == 0` and
         `@assert t2 != 0 && in_subfield(t2, s, N; modulus)`.
      2. Return `S` from a single call and reuse it for both the LUT and
         `s_size`.

14. **The `(1,2)` Theorem 3 case is vacuous.**
    - **Location**: `theorem3.jl:37`, `test/test_theorem3.jl:5-7`.
    - **Symptom**: at N=2 every function on F₄ has Δ ≤ 4 because DDT rows sum to
      4, so "Δ_f = 4" carries no information about the theorem.
    - **Resolution plan**: keep it as a smoke test with a comment, and let
      `(1,6)` and `(3,2)` carry the real "otherwise → 4" branch.

15. **`find_t1_construction3` has a redundant emptiness test.**
    - **Location**: `helpers.jl:161-172`.
    - **Symptom**: `Tr_s^{sn}(t₁) = 0` already guarantees S ≠ ∅ (additive
      Hilbert 90 — the paper itself says "non-empty **if and only if**
      Tr_s^{sn}(t₁)=0"), so the inner `build_affine_subspace` scan is dead work
      and makes the search O(2^{2N}) worst case.
    - **Resolution plan**: drop the inner scan, or compute the image of
      x ↦ x^q + x once and index into it.

16. **Inconsistent helper signatures.**
    - **Location**: `helpers.jl:40` `find_t_construction1(s, n; …)` vs
      `helpers.jl:76` `find_t1_construction2(s, N; …)` vs `helpers.jl:161`
      `find_t1_construction3(s, n; …)`.
    - **Symptom**: the middle helper takes the extension degree `N = s·n` while
      its two siblings take `n`. Call sites currently pass the right thing
      (`theorem4.jl:16`, `theorem5.jl:16`, `table2.jl:53,66`), but this is a
      silent-wrong-answer trap.
    - **Resolution plan**: standardize all three on `(s, n)` and derive
      `N = s*n` internally.

---

## Items reproduced exactly

| Paper item | Repro file | Independent check |
|---|---|---|
| Construction 1, Eq. (3) `f = x⁻¹ + t(x^q+x)^{q^n−1} + t` | `helpers.jl:55-69` | piecewise form matches Eq. (3) exactly |
| Construction 2, Eq. (8) | `helpers.jl:95-108` | matches the paper's case form |
| Construction 3, Theorem 6 | `helpers.jl:118-133` | polynomial form evaluated directly at n=4 agrees with the piecewise LUT for all 9 (t₁,t₂) |
| Theorem 1 (s even → Δ=4) | `theorem1.jl` | (2,2),(2,3),(2,4),(4,2) → all perm, Δ=4; full t-sweep under both moduli → Δ=4 always |
| Theorem 2 (s,n odd → Δ=4) | `theorem2.jl` | (1,3),(1,5),(1,7),(3,3) → Δ=4; full t-sweep at (3,3) → Δ=4 for all 7 t |
| Theorem 3 (s odd, n even → Δ=6 or 4) | `theorem3.jl` | (1,2)→4, (1,4)→6, (1,6)→4, (1,8)→6, (3,2)→4 all correct (branch coverage gap: Issue 5) |
| Theorem 4 (n odd, s even → Δ=4) | `theorem4.jl` | (2,3), t₁=58, t₂=0 → Δ=4; full (t₁,t₂) sweep over F₄ also Δ=4 |
| Theorem 5 (sn odd → Δ=4) | `theorem5.jl` | (1,3),(1,5),(1,7),(3,3) → Δ=4; full sweep at (3,3) → Δ=4 for all 4×7 pairs |
| Theorem 6 (Δ_f ≤ 6, permutation) | `theorem6.jl` | all valid (t₁,t₂) swept for 11 (s,n) pairs: zero violations of Δ≤6, all permutations |
| Example 1 (F_{2⁴}, t₁,t₂ ∈ F₄\*, Δ=4) | `example1.jl` | all 9 pairs: permutation, Δ=4, NL=4, deg=3 — via the piecewise LUT and via direct polynomial evaluation |
| Table 1, rows 1, 2, 4 | `table1.jl:22,23,25` | exact match with the paper's NL, 𝒟(f), ℬ(f) |
| Table 2, rows 1, 3 | `table2.jl:24,26` | exact match with the paper |
| ℬ(f) column at sn=4,6,8 | `helpers.jl:178-181` | 0, 20, 108, 96 all match (even sn only — Issue 1) |

## Missing items

Propositions 1–6 (Issue 2), Theorem I (Issue 3), the three compositional
inverses (Issue 4), Theorem 3's `s ≥ 5` and `s=3, n/2 even` branches (Issue 5 —
both verified to hold: (5,2)/N=10 → Δ=6 and (3,4)/N=12 → Δ=6), and Lemmas 1–6 +
Remark 1. Lemma 3 (Kloosterman range), Lemma 4 (existence of u with
Tr(1/(1+u+u⁻¹))=0), Remark 1 (s=1,3 ⇒ Tr=1 for all u) and Lemma 6 are all
directly checkable at small s and would document *why* Theorem 3 splits the way
it does.

Propositions 1 and 3 are partially covered: `deg f` is checked inside
`table1.jl:71` / `table2.jl:101`, but the compositional inverse is never built.
The full claim was verified during review: deg f = deg f⁻¹ = sn−1 in all 23
instances tested across the three constructions.

## Test results

**Executed.** Julia 1.12.6, review date 2026-08-15.

```
$ make -C packages/VBFRepro/papers/2014/Zha_201401 test
```

Exit code **0**. Wall time **4 s** (including `Pkg.instantiate()`; the nine
testsets themselves total 2.8 s). No failures, no errors, no broken tests — and
no `const`-redefinition warnings from the nine separate `include`s of
`helpers.jl`, confirming the static prediction the previous revision could only
guess at.

| Test file | Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|---|
| `test/test_theorem1.jl` | `theorem1_test` | 4 | 0 | 0 | 4 | 0.4 s |
| `test/test_theorem2.jl` | `theorem2_test` | 8 | 0 | 0 | 8 | 0.5 s |
| `test/test_theorem3.jl` | `theorem3_test` | 10 | 0 | 0 | 10 | 0.2 s |
| `test/test_theorem4.jl` | `theorem4_test` | 2 | 0 | 0 | 2 | 0.1 s |
| `test/test_theorem5.jl` | `theorem5_test` | 8 | 0 | 0 | 8 | 0.1 s |
| `test/test_theorem6.jl` | `theorem6_test` | 4 | 0 | 0 | 4 | 0.1 s |
| `test/test_example1.jl` | `example1_test` | 19 | 0 | 0 | 19 | 0.2 s |
| `test/test_table1.jl` | `table1_test` | 16 | 0 | 0 | 16 | 0.9 s |
| `test/test_table2.jl` | `table2_test` | 12 | 0 | 0 | 12 | 0.3 s |
| **Total** | | **83** | **0** | **0** | **83** | **2.8 s** |

What the passing assertions cover: Theorem 1 at (2,2),(2,3); Theorem 2 at
(1,3),(1,5),(1,7),(3,3); Theorem 3 at (1,2),(1,4),(1,6),(3,2),(1,8) against
`expected_du_theorem3`; Theorem 4 at (2,3); Theorem 5 at (1,3),(1,5),(1,7),(3,3);
Theorem 6 at (2,2),(2,3); Example 1 at all 9 pairs (t₁,t₂) ∈ F₄\* × F₄\*; Table 1
all 4 rows × (NL, Δ, deg, 𝒟); Table 2 all 3 rows × (NL, Δ, deg, 𝒟).

Note that `test_example1.jl` asserts only `!isempty`, `r.perm` and `r.du == 4`
for each pair (19 assertions = 1 + 9×2). It does **not** check the piecewise LUT
against the direct polynomial form; that equivalence was established by reviewer
computation and is credited in "Items reproduced exactly", not to the suite.

The report targets were also exercised out-of-band during review
(`table1_report`, `table2_report`, `theorem6_report`): every `print_check` line
emitted `[PASS]`, including the `NL ≥ ℬ(f)` checks at sn = 4, 6, 8.

## Catalog status

**Not applicable — no APN claims, no catalog gap.**

This paper constructs differentially **4**-uniform and **6**-uniform
permutations, explicitly positioned as an alternative to APN functions ("there
was only one sporadic example of APN permutation over fields with even degree").
No theorem, example or table claims Δ_f = 2.

This was confirmed computationally rather than assumed: across every instance of
Constructions 1, 2 and 3 built during review (all t / (t₁,t₂) sweeps at
(s,n) ∈ {(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),(2,2),(2,3),(2,4),(2,5),(3,2),(3,3),(3,4),(4,2),(5,2)}),
the differential uniformity was **4 or 6** at every parameter admitted by the
theorems. The only Δ=2 instances reachable from the code are degenerate ones
*outside* the paper's hypotheses: `construction2_lut(s, n, 1, 0)` with `sn` odd
collapses to the plain inverse function `x⁻¹` (verified
`lut == [gf_inv_zero_safe(x, N) for x in 0:2^N-1]` at (1,3), (1,5), (3,3)),
which is the classical APN inverse monomial and is already in the catalog.
Theorem 5 explicitly requires `t₂ ∈ F_q^*`, so these are not instances of the
paper's family. Nothing here qualifies for
`packages/VBFCatalog/data-raw/apn_catalog/n<N>_apn.toml`.

- Per claimed-new APN function: **none exist** → no present / missing / not-new /
  unverifiable determinations to make.
- **Catalog-gap records emitted: none.**
- `literature_sboxes.toml` is a cipher-S-box list (AES, PRESENT, SERPENT, …),
  not a construction-family catalog, so no entry is warranted there either.
- The bibliography already carries the key:
  `packages/VBFCatalog/data-raw/bibliography.bib:654` → `@article{Zha_201401}`.
  Nothing in the reproduction references it; it should.

## Library-reuse note

**Clean — no helper duplicates a `VBF` core export.** Everything routes through
core: `gf_pow`, `gf_mul`, `gf_inv_zero_safe`, `gf_trace`, `gf_relative_trace`,
`in_subfield`, `subfield_elements`, `primitive_polynomial`, `SBox`,
`is_permutation`, `differential_uniformity`, `differential_spectrum`,
`algebraic_degree`, `nonlinearity`, `sorted_pairs`, `print_banner`,
`print_section`, `print_check`, `print_kv`. No re-rolled field arithmetic, no
re-rolled DDT/LAT/ANF, no locally defined report emitters.

Minor smells (not violations): `helpers.jl:20`
`const safe_inv = gf_inv_zero_safe` and `helpers.jl:175`
`const compute_nonlinearity = nonlinearity` are pure aliases that hide the core
call from a side-by-side read. `helpers.jl:6-8`'s "VBF API used" header lists
`gf_inv` (never called) and omits `gf_inv_zero_safe`, `nonlinearity`,
`differential_spectrum`, `algebraic_degree`, `sorted_pairs`, `print_section`,
`print_check`, `print_kv`.

**Already available but unused**: `compositional_inverse` — a core export that
would directly serve the paper's three g's (Issue 4).

**Promote-to-core candidates** (core genuinely lacks these; general + testable,
belong in `packages/VBF/src/`):
1. `find_omega` → **`gf_root_of_unity(n, d; modulus)`** (`helpers.jl:28-32`). A
   primitive d-th root of unity in GF(2ⁿ) is a generic primitive with no core
   export. Would fix Issue 8 at the same time.
2. `build_affine_subspace` → **additive-polynomial root set**
   (`helpers.jl:141-154`). The solution set of x^{2^k} + x = c is an F₂-affine
   subspace; core has `solve_f2` / `kernel_f2` / `span_from_basis` but no direct
   entry point for the Frobenius-shift equation. Natural fit next to
   `in_subfield` / `subfield_elements`.

Legitimately paper-specific, do not flag: `construction1_lut`,
`construction2_lut`, `construction3_lut`, `find_t_construction1`,
`find_t1_construction2`, `find_t1_construction3`, `nl_lower_bound`,
`expected_du_theorem3`, `print_header`.

## Open questions

1. **Is Proposition 5 in scope?** It is the paper's headline novelty claim and
   its invariant-based argument is cheap to reproduce (baseline table above).
   But an actual CCZ-equivalence *decision* at n=8 via `are_ccz_equivalent` is
   expensive. Should `proposition5.jl` reproduce only the paper's own invariant
   argument, or attempt a stronger equivalence test at n=6 where it is
   tractable?
2. **How should Paper Issue 3 be recorded?** The corrected NL=110 collides with
   the value the paper attributes to [16] (= `Yuyin_201300`, independently
   confirmed at 110 in that paper's review), breaking the stated separation
   argument for that instance. This is a substantive mathematical gap, not a
   typo. Recorded here as a Paper Issue; the suggestion is an
   explicitly-labelled FAIL check in `proposition5.jl` too — but if the project
   prefers reproductions to stay silent on gaps in the source paper's
   *reasoning* (as opposed to its numbers), scope that down.
3. **Compute budget for Issue 5.** Adding (3,4) → N=12 to Theorem 3 means a
   4096-entry LUT and a 2²⁴ DDT pass. Acceptable inside `make test`, or should
   it sit behind the (currently dead) `limit` knob?
4. **Should Lemmas 1–6 get files?** The mandatory naming rule implies
   `lemma1.jl`…`lemma6.jl`. Lemmas 1, 3, 4 and Remark 1 are directly checkable
   at small s and would explain Theorem 3's branch structure; Lemmas 2, 5, 6 are
   existence statements checkable by exhaustive search at small (s,n). Their
   absence was not treated as a hard defect because they are supporting results.
5. **`table2_row1` parameter choice.** It picks `t1 = 1` and
   `t2 = fq_star[1] = 1`, whereas the paper's Table 2 row 1 writes t, h with
   `t³ = h³ = 1`, i.e. any elements of F₄\*. All 9 combinations give identical
   invariants (verified), so the result is unaffected — but should the row
   iterate to make the "for all t, h ∈ F₄\*" quantifier explicit?
