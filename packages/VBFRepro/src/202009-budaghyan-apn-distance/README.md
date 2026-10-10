# Budaghyan_202009 — On the Distance Between APN Functions

**Paper:** L. Budaghyan, C. Carlet, T. Helleseth, N. Kaleyski, *On the Distance
Between APN Functions*, IEEE Trans. Inf. Theory 66(8), 2020.

**Reproduction:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/` — `helpers.jl`, `proposition2.jl`,
`algorithm1.jl`, `corollary2.jl`, `proposition6.jl`, `table2.jl`, `table3.jl`,
`section5.jl`, `report.jl`.

**Verdict:** **Good** — every theorem-level item is implemented and correct, and
(as of the R1–R12 pass below) the paper's computational content is now covered:
the three Section IV-A worked examples, the Section IV-E tightness witnesses,
Table II at n=4/5/6.1 and the whole n=7 block, Table III's computed columns, and
both halves of Section V (APN and non-APN `F`), with an exhaustive minimum
single-shift search. What remains blocked is external data, not code: the
Edel–Pott representatives for Table II's n=6/n=8 rows and the BCP-1/BCP-2
functions for Table III.

**Tests:** 2619 assertions across 7 test sets, all passing. Every new assertion
was mutation-tested (12 mutations, all caught — see "Non-vacuity evidence").

---

## Issue Catalog

### Paper Issues

**P1. The n=3 tightness witness in Section IV-E is wrong.**

The paper gives `u₁=0, u₂=1, v₁=1, v₂=α` as the n=3 witness showing the
Corollary 2 bound is tight. Tested for **every** primitive α ∈ GF(8):
`DU(G) ∈ {4,6}` — never 2. So the printed witness never yields an APN function.

The bound *is* tight at n=3 (distance 2), but the witnesses are the single-shift
ones: at `U={0,1}`, the only `(v₁,v₂)` giving an APN `G` are `(2,2), (4,4),
(6,6)` — i.e. `v₁ = v₂ ∈ {α, α², α⁴}`. The paper's n=2 and n=4 witnesses check
out (`d=1=bound` and `d=2=bound`, both APN).

This went undetected because the Section IV-E witnesses were not implemented
(see R5). **Now recorded as a test:** `tightness_witnesses` (`proposition6.jl`) and
`test/test_proposition6.jl` assert that the published witness is *not* APN for any
primitive α, and that `(2,2), (4,4), (6,6)` — i.e. `v₁ = v₂ ∈ {α, α², α⁴}` — are
the only APN shifts of `U = {0,1}`, each at distance 2 = the bound. The bound is
tight at n=3; the paper's witness for it is wrong.

**P2. Equation (9) has one typo (not three — see R1).**

For `b = β³`, the paper's eq. (9) gives `2ⁿ − 1`; the correct value is `2ⁿ`.
Brute-forced over all (β,b) pairs for n=3,4,5,6,8: the `b=β³` case mismatches in
**every** instance (8/8, 16/16, 32/32, 64/64, 256/256), while every other branch
matches perfectly (0/56, 0/240, 0/992, 0/4032, 0/65280).

**Now recorded as a test:** `pi_formula_gold_as_published` implements eq. (9)
verbatim and `proposition6_check_formula` compares both versions against
`|Π_F^β(b)|`; `test/test_proposition6.jl` asserts `mismatches == 0` for the
corrected formula and exactly `2ⁿ` for the published one. The implementation
matches the *corrected* formula — the paper's version is not silently adopted.

**P3. Example (c) is not reproducible as stated — the paper never pins its β.**

Section IV-A's third example depends on the choice of primitive element. Of the
36 primitive elements of GF(2⁶), only **18** reproduce it. The paper says only
"β primitive in F₂ⁿ". See R2 for the consequence.

**Now recorded:** `example_c` pins `β = 7` and documents P3; `test_algorithm1.jl`
asserts that `β = 2` (also primitive, and the repo default) empties every domain,
so the sensitivity is under test rather than merely noted.

### Reproduction Issues

**R1. [RESOLVED] `proposition6.jl` accuses the paper of two typos that do not
exist.**

*Fixed:* the two spurious claims are gone; the file's "Pseudocode" header now
transcribes eq. (9) verbatim from the `.tex`, and the one real typo (P2) is
quoted accurately as `2ⁿ − 1`. `proposition6.jl:51,53` untouched. Added
`pi_formula_gold_as_published` + `proposition6_check_formula`, which compare both
the corrected and the as-published formula against `|Π_F^β(b)|` on **every**
`(β,b)` pair for n=3..6: 0 mismatches for the corrected one, exactly `2ⁿ` for the
published one (all on the `b=β³` branch), asserted in `test_proposition6.jl`.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/proposition6.jl:9-13, 23-27`
- **Symptom:** The docstring claims the published eq. (9) has three typos. Two of
  them are not in the paper. The paper's `(n even, n/2 odd, cube)` branch reads
  `2^{n-1}+2^{n/2}-1` and its `(n even, n/2 even, not cube)` branch reads
  `2^{n-1}+2^{n/2-1}-1` — which is **exactly what the file implements**
  (`proposition6.jl:51,53`). The file's own "Pseudocode" header mis-transcribes
  the paper and then "corrects" a non-existent error. The third claim
  (`proposition6.jl:24`, "paper writes `2^{N-1}`") misquotes the real typo, which
  is `2ⁿ − 1` (see P2).
- **Root cause:** The docstring was written against a mis-transcription of the
  `.tex`, not the `.tex`. The *implementation* is correct throughout; only the
  documentation defames the paper.
- **Resolution plan:**
  1. Delete the two spurious typo claims.
  2. Keep the real one (P2) but quote the paper accurately: `2ⁿ − 1`, not
     `2^{N-1}`.
  3. Leave `proposition6.jl:51,53` alone — they are right.

**R2. [RESOLVED] Example (c) fails under the repo's default primitive element.**

*Fixed:* `example_c` (`algorithm1.jl`) pins `β = 7` — the smallest of the 18
primitive elements that reproduce the paper — as a keyword default, with P3
recorded in the docstring. `test_algorithm1.jl` asserts the default *is* 7, that
it reproduces the paper, and that the same construction with `β = 2` collapses
(all domains empty), so the β-sensitivity is itself under test.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/algorithm1.jl`
- **Symptom:** With `primitive_polynomial(6) = 0x43` and the implicit generator
  β = 2, the subspace `U = span{1, β, β⁴, β²¹}` gives `algorithm1_filter` →
  **all `D_i = {0}`**, i.e. no APN `G` at all. The paper's shift set
  `{β⁷,β¹⁴,β²⁸,β³⁵,β⁴⁹,β⁵⁶} = {6,11,20,26,28,31}` yields `DU(G) = 4`, not 2.
- **Root cause:** P3 — the example is β-sensitive and the paper never pins β.
  Sweeping all 36 primitive elements: **18 reproduce the paper exactly** (e.g.
  β=7), giving `D_i \ {0} = {β⁷,β¹⁴,β²⁸,β³⁵,β⁴⁹,β⁵⁶}` for all 16 points, all six
  shifts giving an APN `G` at distance 16, `G` CCZ-equivalent to
  `x⁶+x⁹+β⁷x⁴⁸` (verified with `are_ccz_equivalent`), and 0/30 mixed-shift
  combinations APN. β=2 is one of the 18 that fail.
  Subtlety worth recording: it is the **subspace `U`** that is β-sensitive, not
  the coefficient — `x⁶+x⁹+c·x⁴⁸` is APN exactly for `c ∈ {6,11,20,26,28,31}`,
  and `β⁷ = 6` at β=2 is itself a valid coefficient.
- **Resolution plan:** Pin a working primitive element explicitly (e.g. β=7) with
  a comment recording P3, or restate the example as "for a suitable primitive β"
  and search for one. **Needs a decision — see Open Questions.**

**R3. [RESOLVED] Section IV-A Examples (a), (b), (c) are all absent.**

*Fixed:* `example_a`, `example_b`, `example_c` in `algorithm1.jl`, driven by
`algorithm1_examples_report` and covered in `test_algorithm1.jl`. All three
reproduce, including the CCZ-equivalences (`G ≅ x⁵` for (b), `G ≅ x⁶+x⁹+β⁷x⁴⁸`
for (c)) and (c)'s "no mixed shift is APN" (0 of 30). New helper
`algorithm1_domains(F, U; drop_zero=true)` returns the domains themselves; with
`drop_zero` the paper's singleton domain reads as a singleton (point 4 of the
plan).

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/algorithm1.jl`
- **Symptom:** These are the paper's *only* concrete demonstrations of
  Algorithm 1. The file substitutes an LCG-random point set instead.
- **Root cause:** Not written.
- **Resolution plan:** Add all three (verified during review):
  1. **(a)** `U = {α⁰..α⁵}`, n=5: `D_i = {0}` for all `i` ⇒ no APN `G`, matching
     the paper. Robust — holds for all 30 primitive α.
  2. **(b)** `U = span{1,α,α²} = {0..7}`, n=5: `D_i \ {0} = {α²⁵} = {25}`; `G` is
     APN, `d(x³,G)=8`, and `G` is **CCZ-equivalent to `x⁵`** — the paper's claim,
     matching the `n5_Gold_x5` catalog entry. Fragile: only 5 of 30 primitive α
     reproduce it; the repo's default α=2 happens to be one.
  3. **(c)** per R2.
  4. Note: `algorithm1_filter` keeps `v=0` in `D_i`, so the paper's "singleton
     domain" reads as `|D_i| = 2` here. Cosmetic, but it blocks verbatim
     comparison of the paper's numbers.

**R4. [RESOLVED] Prop 2 / Algorithm 1 tests never exercise a positive instance.**

*Fixed:* `test_proposition2.jl` now asserts the positive instance (n=5,
`U={0..7}`, `v=25` → `cond == true` **and** `direct == true`), plus negative
controls (`v ∈ {1, 24, 26}` → both `false`), agreement on all 32 uniform shifts,
and two non-uniform shift vectors. `proposition2_positive_check` puts the same
instance in the report. `algorithm1.jl:92-96`'s always-skipped membership check
is replaced by a sweep over every uniform `v`, so the guarantee "APN ⇒ v ∈ D_i"
is actually exercised (via Example (b), where APN shifts exist).
Mutation-checked: stubbing `check_apn_conditions` to a constant `false` fails 5
assertions; to a constant `true`, 50.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/test/test_proposition2.jl`,
  `packages/VBFRepro/src/202009-budaghyan-apn-distance/algorithm1.jl:92-96`
- **Symptom:** For n=5, `m_F=15` ⇒ bound 6, so **no** K=1 or K=2 modification can
  ever be APN. Every assertion in `test_proposition2.jl` and every
  `proposition2_random_check` trial therefore reduces to `false == false`.
  Likewise the `v ∈ D_i` check at `algorithm1.jl:92-96` is *always skipped*
  because `G` is never APN. `check_apn_conditions` is never validated on a
  true-APN case in-repo.
- **Root cause:** All test instances sit below the distance bound.
- **Resolution plan:**
  1. Add the positive instance found during review: n=5, `U={0..7}`, `v=25` →
     `cond=true`, `direct=true` (APN).
  2. Assert both directions, so a hardcoded implementation would fail.
  3. (Independent confirmation from the review: `check_apn_conditions` agrees
     with a direct APN test on 400 random `(U,V)` with K ∈ {3,4,6,8}, plus
     `U = {0..7}` over all 32 uniform shifts — **0 mismatches**. The code is
     correct; the tests just don't show it.)

**R5. [RESOLVED] Section IV-E tightness witnesses are absent.**

*Fixed:* `tightness_witnesses` in `proposition6.jl` (called from
`proposition6_report`), tested in `test_proposition6.jl`. The n=2 and n=4
witnesses check out (APN, `d = bound`). P1 is recorded as a test: the paper's n=3
witness is asserted **not** APN for every primitive α of GF(8), and the corrected
witnesses `v₁ = v₂ ∈ {α, α², α⁴} = {2,4,6}` are asserted to be the *only* APN
shifts of `U={0,1}` (exhaustive over all 64 pairs), each at `d = 2 = bound`.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/` (no file)
- **Symptom:** The n=1..4 bullet list of witnesses is not tested — which is why
  P1 went unnoticed.
- **Resolution plan:** Add the n=2 and n=4 witnesses (both check out), and record
  P1 for n=3 with the corrected witnesses `v₁ = v₂ ∈ {α, α², α⁴}`.

**R6. [RESOLVED] Table II is reproduced at 5 of ~41 rows, and the n=7 block is
wrongly called expensive.**

*Fixed:* `table2.jl` now loads the whole n=7 block from the catalog
(`n7_Inverse_x126 → m_F=54, bound=19`; the other 7 → `m_F=63, bound=22`), matching
the paper's rows "7 | 7.1" and "7 | all others". The `[SKIPPED] ... (expensive
search)` line in `report.jl` is gone — the block runs in ~0.01 s per function, and
the report now states plainly what is blocked and why. Tested in
`test_table2.jl`, which also asserts the inverse function is the odd one out.
n=6 (except row 1.1) and n=8 remain blocked by the catalog gap + the Edel–Pott
label mapping (open question 2) — unchanged, and now labelled `[BLOCKED]` rather
than `[SKIPPED]`.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/table2.jl:16-22`,
  `packages/VBFRepro/src/202009-budaghyan-apn-distance/report.jl:52`
- **Symptom:** Only 5 monomial rows are hard-coded. Missing: n=6 rows 1.2 and
  2.1–2.12, all of n=7, all of n=8. `report.jl:52` labels the n=7 block
  `[SKIPPED] ... (expensive search)`.
- **Root cause:** The "expensive" label is simply wrong — the n=7 block runs in
  **under a second** (~0.05 s/function) with the existing catalog and the
  existing `compute_m_F`.
- **Resolution plan:**
  1. Add the n=7 block. Verified during review: `n7_Inverse_x126 → m_F=54,
     bound=19`; the other 7 n=7 entries → `m_F=63, bound=22`. That is exactly the
     paper's rows "7 | 7.1 | 54 | 19" and "7 | all others | 63 | 22", and matches
     its text ("the same bound for all functions listed in [16] except the inverse
     function").
  2. Correct `report.jl:52`.
  3. n=6 and n=8 remain blocked by catalog gaps (see Catalog status) and by the
     Edel–Pott label mapping (see Open Questions).

**R7. [RESOLVED] Table II's "minimum single-shift distance" column is absent for
every row**, though `section5.jl` has the machinery.

*Fixed:* `table2.jl` includes `section5.jl` and calls the new
`min_single_shift_distance` (exhaustive in `v` and in the kernel). Reproduces the
paper's column: n=4 x³ → 2; n=5 x³ → 8, x⁵ → 8, x¹⁵ → 10; n=6 row 1.1 → 16. For
n=7 the paper itself prints "?" and Section V's bitmask solver is n ≤ 6, so the
cell stays "?".

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/table2.jl`
- **Resolution plan:** Wire `section5.jl`'s single-shift search into the table.

**R8. [RESOLVED] Table III is absent entirely.**

*Fixed:* new `packages/VBFRepro/src/202009-budaghyan-apn-distance/table3.jl` + `test/test_table3.jl`. m_F /
lower bound (x³=15/6, x⁵=15/6, x⁷=15/6, x¹¹=15/6, x¹⁵=9/4) and minimum
single-shift distance (8, 8, 12, 12, 10) reproduce exactly. The CCZ-class column
also reproduces once the paper's label is resolved: it names the class by an
*EA*-representative, and `x⁷ ≅_CCZ x⁵`, `x¹¹ ≅_CCZ x³` (asserted, not assumed).
The "actual distance" and "number of shifts" columns come from the paper's
filtered search over *non-uniform* shifts, which is not reproduced — they are
printed as `[QUOTED]`. BCP-1/BCP-2 rows remain blocked (open question 3).

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/` (no file)
- **Symptom:** Not implemented — yet its two hardest columns compute in seconds.
- **Resolution plan:** Add it. Verified during review, all matching the paper:
  - m_F / lower bound: x³=15/6, x⁵=15/6, x⁷=15/6, x¹¹=15/6, x¹⁵=9/4
  - minimum single-shift distance: x³=8, x⁵=8, x⁷=12, x¹¹=12, x¹⁵=10
  - Only the BCP-1/BCP-2 rows are blocked (VBF's `bcp_apn` is the `n=3k` family;
    the n=5 BCP EA-representatives from [8] exist nowhere in VBF or the catalog).
    **Needs a decision — see Open Questions.**

**R9. [RESOLVED] Section V implements only the APN half, and does not guard its
precondition.**

*Fixed:* both. `build_single_shift_system(F, v)` implements the paper's steps 1–5
for an **arbitrary** `F`, returning `(rows, rhs)`; `single_shift_solutions` solves
the affine system by appending `rhs` as an extra column and calling the exported
`kernel_f2` (a kernel vector with that coordinate set is a particular solution,
and one exists iff the system is consistent). `build_single_shift_constraints` —
the APN-only entry point — now **errors** unless `differential_uniformity(F) == 2`.
Tested on `H = x³` with `H(0)` flipped (DU = 4): the step 4–5 rows fire, `U = ∅` is
correctly **not** a solution (a homogeneous-only system always admits it — that is
the discriminator), `U = {0}` is, every solution gives an APN `G`, and the shift
`v = 2` is correctly reported inconsistent (no APN `G` at all).

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/section5.jl:26-49`
  (`build_single_shift_constraints`)
- **Symptom:** Only the homogeneous rows (`D_aF(x)+D_aF(y)=v ⇒ …=0`) are
  emitted. The paper explicitly advertises applicability *"to an arbitrary
  function F (not only APN)"*; steps 4–5 (non-APN `F`, inhomogeneous system) are
  missing. Worse, the function does not check that its input is APN — it would
  silently return a wrong system.
- **Root cause:** Half the method implemented, with no guard on the assumption.
- **Resolution plan:**
  1. Implement steps 4–5 via the already-exported `solve_f2`, **or**
  2. At minimum, assert the APN precondition so misuse fails loudly.

**R10. [RESOLVED] `section5_report`'s minimum-weight result is right by luck, not
by construction.**

*Fixed:* new `min_single_shift_distance(F; verify=true)` sweeps **every** `v ∈ F₂ⁿ*`
and enumerates the **full** kernel for each (`limit` now defaults to `2²⁰`, and
`exhaustive` is asserted rather than printed), then re-verifies the minimiser with
`differential_uniformity`. `section5_report` reports that value, and also verifies
all 2047 non-trivial solutions instead of a 10-element sample. `test_section5.jl`
asserts `n_solutions == 2^kernel_dim` for every `v` — a truncated enumeration
(`limit = 64`, the old behaviour) fails it.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/section5.jl` (`section5_report`)
- **Symptom:** It enumerates only `limit=64` of `2¹¹ = 2048` kernel vectors,
  never sweeps `v`, prints `exhaustive: false` — and then prints "min |U| among
  non-trivial solutions (single-shift distance bound): 8" as if established. The
  value 8 *is* correct (verified over all `v` and all kernel vectors during
  review), but nothing in the code establishes it.
- **Resolution plan:** Make the search exhaustive over the kernel and over `v`,
  or stop reporting the number as a computed result.

**R11. [RESOLVED] `corollary2.jl` tests EA where the paper claims CCZ.**

*Fixed:* `proposition3_ccz_invariance` now uses a genuinely CCZ-but-not-EA pair —
`F = x³` over `F₂⁵` is a permutation, so `F⁻¹ = x²¹` is CCZ-equivalent (graph swap)
but has algebraic degree 3 vs F's 2, hence provably not EA-equivalent
(`are_ccz_equivalent` true, `are_ea_equivalent` false, both asserted). The
comparison is on the **full multiset** `Π_F` (new `pi_full_multiset` in
`helpers.jl`, `2^{2n}` counts), not the key set, and is additionally checked
across every representative of `enumerate_ccz_class(F)` (64 reps, both EA-classes).
Discriminating control: `x¹⁵` is CCZ-inequivalent to `x³` and has a different Π.
`proposition4_ea_invariance` now uses non-trivial `A₁(x) = x²`, `A₂(x) = x²⊕7`,
`A(x) = 3·x`, and checks `|Π_{F'}^β(t)| = |Π_F^{A₂(β)}(A₁⁻¹(t + A(β)))|` on all
1024 `(β,t)` pairs; the test also asserts that dropping `A(β)` **or** `A₁⁻¹`
breaks the identity, so both are load-bearing.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/corollary2.jl:43-66`
  (`proposition3_ccz_invariance`), `:74-95` (`proposition4_ea_invariance`)
- **Symptom:** `proposition3_ccz_invariance` builds `F'(x) = F(x⊕3)⊕5` — an **EA**
  map — and compares only **key sets** (`Set{Int}`), not the multiset Π_F. Prop 3
  is the paper's headline claim (*"the first new CCZ-invariant in ten years"*)
  and is never tested against a genuinely-CCZ-but-not-EA pair.
  `proposition4_ea_invariance` uses only `A₂(x)=x⊕c` with `A₁ = id, A = 0`, so the
  `A₁⁻¹(t + A(β))` part of Prop 4 is never exercised.
- **Root cause:** The test was written with the weaker equivalence.
- **Resolution plan:**
  1. Use the exported `ccz_equivalent_function` / `enumerate_ccz_class` to build a
     genuine CCZ-but-not-EA pair.
  2. Compare the full multiset Π_F, not the key set.
  3. Exercise a non-trivial `A₁` and `A` in the Prop 4 test.

**R12. [RESOLVED] Two helpers duplicate core.**

*Fixed:* `print_header` is now a three-line wrapper around core `print_banner`
(the convention `packages/VBFRepro/src/202100-calderini-construction-relations/helpers.jl` already follows), and
`gold_x3` is deleted — all 15 call sites (7 source, 8 test) now use
`gold_apn(N, 1)`.

- **Location:** `packages/VBFRepro/src/202009-budaghyan-apn-distance/helpers.jl:14-20` (`print_header`),
  `packages/VBFRepro/src/202009-budaghyan-apn-distance/helpers.jl:27-29` (`gold_x3`)
- **Symptom:** `print_header` hand-rolls a `"="^72` banner (10 other papers already
  call `print_banner`, `packages/VBF/src/io/report.jl:33`). `gold_x3(N)` is
  literally `gold_apn(N, 1)` (`packages/VBF/src/constructions/apn_families.jl:40`).
- **Resolution plan:** Call `print_banner` and `gold_apn(N, 1)`.

---

## Items reproduced exactly (context)

| Paper item | Where |
|---|---|
| Proposition 2 (conditions i–vi) | `proposition2.jl` — correct; cross-checked against a direct APN test on both a positive (APN) and negative instance |
| Observation 1 | folded into Algorithm 1's set `A` (`algorithm1.jl`) |
| Algorithm 1 (domain filtering) | `algorithm1.jl` — mechanism correct |
| Section IV-A Examples (a), (b), (c) | `algorithm1.jl` — `example_a/b/c` (β pinned to 7 in (c); see P3) |
| Corollary 2 (`d(F,G) ≥ ⌈m_F/3⌉+1`) | `helpers.jl`, `corollary2.jl` |
| Proposition 3 (Π_F is CCZ-invariant) | `corollary2.jl` — CCZ-but-not-EA witness (`F` vs `F⁻¹`), full multiset |
| Proposition 4 (EA refinement) | `corollary2.jl` — non-trivial `A₁`, `A₂`, `A`; all `(β,t)` pairs |
| Proposition 5 (quadratic ⇒ Π_F^β β-independent) | `corollary2.jl` |
| Proposition 6 (Gold x³ formula) | `proposition6.jl` — matches `|Π_F^β(b)|` on every `(β,b)`, n=3..6 |
| Table I (m_F, bounds) + tightness witnesses | `proposition6.jl` — formula verified for all n=1..20; witnesses for n ≤ 4 (P1 recorded) |
| Table II (n=4, n=5, n=6 row 1.1, all of n=7) | `table2.jl` — incl. the minimum single-shift distance column |
| Table III (m_F / bound / single-shift columns) | `table3.jl` |
| Section V (both halves, APN and non-APN `F`) | `section5.jl` — exhaustive minimum single-shift distance |

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper, one process at a time;
`make` bypassed (its `JULIA ?= julia` would escape the cap). **No OOM; nothing
skipped for memory.**

| Command | Result |
|---|---|
| `test/runtests.jl` | **PASS 2619/2619** — proposition2 55, algorithm1 40, corollary2 33, proposition6 77, table2 52, table3 65, section5 2297 (was 206 before the R1–R12 pass) |
| `report.jl` | **PASS** — all 14 summary checks, ~11 s |

### Non-vacuity evidence (mutation testing)

Every new assertion was checked against a deliberately broken implementation. All
12 mutations are caught:

| Mutation | Caught by | Failing assertions |
|---|---|---|
| `check_apn_conditions` → constant `false` | `test_proposition2.jl` | 5 |
| `check_apn_conditions` → constant `true` | `test_proposition2.jl` | 50 |
| Section V: drop the paper's steps 4–5 | `test_section5.jl` | 2052 |
| Section V: truncate the kernel (`limit = 64`) | `test_section5.jl` | 2 |
| Π_F compared by support instead of multiset | `test_corollary2.jl` | 1 |
| Prop 4 with `A = 0` (the old setup) | `test_corollary2.jl` | 1 |
| Prop 3 with an EA-only witness (the old setup) | `test_corollary2.jl` | 1 |
| Corollary 2 bound `⌊m/3⌋+1` instead of `⌈m/3⌉+1` | `test_proposition6.jl` | 3 |
| eq. (9) `b=β³` branch "fixed" back to `2ⁿ−1` | `test_proposition6.jl` | 10 |
| `compute_m_F` stubbed to a constant 63 | `test_table2.jl` | 15 |
| Example (c) default β reverted to 2 | `test_algorithm1.jl` | 2 |
| `min_single_shift_distance` → first solution found | `test_table3.jl` | 21 |

Note on the `⌈·⌉` mutation: **every** m_F the paper prints (3, 9, 15, 27, 54, 63,
111, 255, 495) is divisible by 3, so no table row can distinguish `⌈m/3⌉` from
`⌊m/3⌋`. `test_proposition6.jl` therefore pins the rounding directly
(`lower_bound_distance(16) == 7`, and `== cld(m,3)+1` for m = 0..200).

## Catalog status

**The paper claims no new APN functions** — its contribution is a new
CCZ-invariant (Π_F, m_F). Of the two APN functions it *exhibits*:

- n=5: `x³` shifted on `span{1,α,α²}` by `α²⁵` → CCZ-equivalent to `x⁵`,
  **already present** as `n5_Gold_x5`.
- n=6: `x⁶+x⁹+β⁷x⁴⁸` (Example (c)) → **missing from the catalog**.

### Catalog-gap record

```
target file: packages/VBFCatalog/data/apn/n6_apn.toml

name             = "n6_EdelPott_x6_x9_b7x48"
n                = 6
m                = 6
is_permutation   = false
lut = [0, 6, 53, 54, 37, 18, 39, 21, 35, 59, 61, 32, 31, 54, 54, 26,
       55, 35, 18, 3, 32, 5, 50, 18, 41, 35, 39, 40, 39, 28, 30, 32,
       21, 28, 55, 59, 61, 5, 40, 21, 50, 37, 59, 41, 3, 37, 61, 30,
       5, 30, 55, 41, 31, 53, 26, 53, 31, 26, 6, 6, 28, 40, 50, 3]
algebraic_form   = "x^6 + x^9 + b^7*x^48 in GF(2^6), modulus x^6 + x + 1, b = 2 (b^7 = 6)"
bib_key          = "Edel_200900"
source           = "Budaghyan-Carlet-Helleseth-Kaleyski (2020), Sec. IV-A, third example (CCZ class of the shifted Gold function)"
```

**Equivalence evidence** (via the repo's own `are_ccz_equivalent`, n=6
exhaustive): `DU=2`, `algebraic_degree=2`, `is_quadratic_apn=true`,
`gamma_rank=1146`, `delta_rank=94`. Not CCZ-equivalent to `n6_Gold_x3` (γ=1102),
`n6_Kasami_x48` (γ=1102), or `n6_Kim` (γ=1166) — γ-rank alone separates it from
all three.

This gap is **not cosmetic**: it is one of the 11 missing n=6 CCZ classes that
block Table II (R6).

## Library-reuse note

- **Done (R12):** `print_header` now wraps core `print_banner`; `gold_x3(N)` is
  deleted in favour of `gold_apn(N, 1)`.
- **Still open — promote to core:** `compute_m_F` (`helpers.jl`). `m_F = min Π_F`
  is a general CCZ-invariant scalar and `pi_multiset` is already core; it belongs
  next to it in `packages/VBF/src/invariants/`. *Not done here — core is owned by
  another task.*
- **Still open — promote to core:** a per-`b` accessor for Π. `pi_multiset`
  returns only a *histogram over counts*, so `|Π_F^β(b)|` had to be recomputed
  paper-locally. This pass added `pi_counts(F, β) -> Vector{Int}` to
  `helpers.jl` (it is precisely the internal `hits` array of
  `pi_multiset.jl:31`, already computed there and then discarded) and routed
  `proposition6.jl`, `corollary2.jl` and the tests through it, so the paper now
  has **one** implementation instead of three. Promoting it to core would remove
  the last one. `pi_full_multiset(F)` (the multiset Π_F of Prop 3) sits on top of
  it and is a natural companion.
- Correctly paper-local: `apply_modifications`, `lower_bound_distance`,
  `hamming_distance`, `is_primitive_element`, `check_apn_conditions`,
  `algorithm1_filter`, `algorithm1_domains`, `build_single_shift_system`,
  `min_single_shift_distance`.

## Open questions (need a decision)

1. **Which β for Example (c)?** *Provisionally answered by R2:* `example_c` pins
   `β = 7` (the smallest of the 18 working primitive elements) as a keyword
   default, and the test asserts both that the default reproduces the paper and
   that `β = 2` does not. If the repo would rather *search* for a working β than
   hard-code one, the change is one line — the search itself already exists in
   the P3 sweep. Example (b) needs no decision: the paper's α is the class of `x`,
   which is the repo default (α = 2) and works.
2. **Edel–Pott Table 5 labels.** Table II indexes n=6 and n=8 functions as
   "1.1, 2.4, …" from ref [16]. The catalog names carry no such labels, so
   reproducing Table II beyond n=7 needs an explicit label↔function mapping.
   Where should it live — `packages/VBFRepro/src/200900-edel-switching/`, or new `edel_pott_label`
   metadata in the TOML? **Still open** — blocks 13 of Table II's n=6 rows and all
   23 of its n=8 rows.
3. **BCP-1 / BCP-2 (n=5).** Needed for Table III, absent from VBF and the
   catalog, and CCZ-equivalent to Gold (so arguably out of scope for a
   CCZ-indexed catalog). Add as paper-local definitions, or as a new `bcp5_apn`
   core constructor? **Still open** — blocks 2 of Table III's 7 rows. `table3.jl`
   records the gap in a comment and the report prints it as `[MISSING]`.
