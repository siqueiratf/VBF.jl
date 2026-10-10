# Calderini_202306 — Extending Two Families of Bivariate APN Functions

**Paper**: Calderini, Li, Villa. "Extending two families of bivariate APN functions."
*Finite Fields and Their Applications* **88** (2023) 102190.

**Reproduction path**: `packages/VBFRepro/src/202306-calderini-bivariate-families/`

**Verdict**: Mostly complete

The mathematics is right and every headline number reproduces exactly under an independent
implementation — including all 11 known-family rows of Table 3, the two new rows for F1 and
F2, and the novelty argument that rests on them. A previous revision of this file recorded
"Complete — no paper errors, no reproduction issues, no catalog gaps"; that was not
supportable. There are two genuine typos in the published Table 2, several coverage gaps in
the reproduction (notably an unenforced `gcd(k,m)=1` hypothesis that silently returns
non-APN functions), the paper's *central* claim (Table 3 / `N_F` at n=12) is not exercised by
`make test` at all, and there is a real catalog gap at n=6.

> **Environment note**: reviewed 2026-08-15 with Julia 1.12.6; `make test` runs clean
> (78/78, exit 0). The figures below were first derived independently in a standalone C
> implementation and have since been re-checked against the repository's own Julia API — see
> "Test Results" and the reconciliation there. No disagreement was found. (A previous
> revision doubted the "78 tests passing" figure for want of a toolchain; it is **confirmed**,
> with the per-file counts 16 / 20 / 21 / 21 exactly as recorded.)

---

## Paper Issues

### P1. Table 2, family N. 9 (Zhou–Pott [31]) is printed with the wrong variable; the function is not APN

- **Location**: PDF p. 17 (Table 2, row 9); `.tex` line 736. Printed:
  `(xy, x^{2^k+1} + α x^{(2^k+1)2^i})` — both monomials of the second coordinate are in `x`.
- **Counter-evidence**: as literally printed, the second coordinate is a function of `x` only,
  so `D_{(0,w)}F(x,y) = (xw, 0)`, which hits each value `2^m` times. For
  `m = 6, k = 1, i = 1, α = 3` over `GF(2^6)` (modulus 67) the computed differential
  uniformity is `du = 64 = 2^m` — maximally far from APN. With the intended `y`
  (`(xy, x^{2^k+1} + α y^{(2^k+1)2^i})`, `k=1, i=0, α=2`) the result is `du = 2` and
  `N_F = [1365, 100100, 142932]`, exactly the paper's Table 3 row "families n. 5, 9, 10 and
  11". So the `x` is a typo for `y`.
- **Effect on the reproduction**: none — `table3.jl:233` uses `taniguchi_apn(6, 1, 0, b)`,
  which is `(xy, x^{12} + b·y^3)`; applying the F₂-linear map `(u,v) ↦ (u, v^{16})` turns it
  into `(xy, x^3 + b^{16} y^{3·2^4})`, i.e. the *corrected* Zhou–Pott shape. The repo silently
  used the correct family; this should be documented rather than left implicit.

### P2. Table 2, family N. 12 (Göloğlu–Kölsch [23]) mixes exponents `i` and `k`; only `i = k` is APN

- **Location**: PDF p. 17 (Table 2, row 12); `.tex` line 745. Printed:
  `(x^{2^i+1} + B y^{2^i+1}, x^{2^{k+m/2}} y + (a/B) x y^{2^{k+m/2}})` with conditions that
  constrain only `k` (`gcd(k,m)=1`, `B^{2^k+2^{k+m/2}} ≠ a^{2^k+1}`) and never `i`.
- **Counter-evidence**: at `m = 6`, `k = 1`, scanning all admissible `(B, a)` (`B` non-cube,
  `a ∈ F_8^*`, `B^{2+2^4} ≠ a^3`), the minimum differential uniformity over the whole
  parameter set is:

  | `i` | min `δ_F` |
  |---|---|
  | 1 (`= k`) | **2** |
  | 2 | 16 |
  | 3 | 8 |
  | 4 | 16 |
  | 5 | 4 |

  Only `i = k` produces APN functions, and with `i = k = 1, B = 2, a = 1` the result is
  `N_F = [1365, 100100, 144759, 126]` — exactly Table 3's "family n. 12" row. So `i` must be
  read as `k`.
- **Effect on the reproduction**: none — `table3.jl:276-297` already hard-codes `i = k = 1`
  (`pow6(x,3)`), silently applying the correction. Should be documented.

### P3. Theorem 5's Walsh-set statement is imprecise about `(a,b) = (0,0)`

- **Location**: `.tex` line 816 (Theorem 5, quoted from [27]):
  `{|W_F(a,b)| : a,b ∈ F_{2^n}} = {0, 2^{n/2}, 2^{n/2+1}}`. Taken literally the set also
  contains `W_F(0,0) = 2^n`.
- **Counter-evidence**: computed absolute-Walsh value sets excluding only `(a,b)=(0,0)` are
  `{0, 8, 16}` / `{0,16,32}` / `{0,32,64}` / `{0,64,128}` for F1 and F2 at `n = 6/8/10/12`
  respectively — the identity is exactly right once `(0,0)` is excluded.
- **Effect on the reproduction**: none — `theorem5.jl:26-30` uses `absolute_walsh_spectrum`,
  which skips exactly `(a,b)=(0,0)` (`packages/VBF/src/spectra/linear.jl:66`). Worth a
  one-line note.

### Not a paper issue (recorded to prevent re-flagging)

In `input/*.tex`, the "Conditions" lines `n = 3m, gcd(s,m)=1, v ∈ F_{2^m}^*` and
`q = 2^m, n = 2m, gcd(i,m)=1` appear attached to Table 1 rows 3 and 4 rather than 4 and 5, and
Table 3's `\multirow` labels are flattened. The PDF (`pdftotext -layout`) shows the correct
layout — these are OCR artifacts of the extracted `.tex`, not errors in the publication.

---

## Reproduction Issues

### 1. `family_f1_lut` / `find_alpha` / `has_no_root_projective` do not enforce Theorem 3's `gcd(k,m) = 1`, and silently return non-APN functions

- **Location**: `helpers.jl:16` (`has_no_root_projective`), `:27` (`find_alpha`), `:34`
  (`family_f1_lut`)
- **Symptom**: no test name — this is an unguarded API. Calling `family_f1_lut(4, 2, α)` for
  any `α` accepted by `find_alpha(4, 2)` returns an `SBox{8}` with
  `differential_uniformity == 4`, not 2. Actual vs expected, computed exhaustively over every
  admissible `α`:

  | `(m,k)` | `gcd(k,m)` | #admissible α | `differential_uniformity` |
  |---|---|---|---|
  | (4,2) | 2 | 6 | **4** (all α) |
  | (6,2) | 2 | 26 | **4** (all α) |
  | (6,3) | 3 | 28 | **8** (all α) |

  Contrast with the valid regime: **142 instances** across `m ∈ {3,4,5,6}` × every coprime `k`
  × every admissible `α` all give `du = 2`.
- **Root cause**: Theorem 3 (`.tex` line 236) and Lemma 1 (`.tex` line 194) both assume
  `gcd(k,m) = 1`; `helpers.jl` takes `k` as a free `Int` with no validation, and
  `THEOREM3_CASES` (`theorem3.jl:18`) only ever passes coprime `k`, so the hole is invisible to
  the suite. Core constructors such as `taniguchi_apn`
  (`packages/VBF/src/constructions/taniguchi.jl:48-49`) *do* throw `ArgumentError` on
  `gcd ≠ 1`; this paper's helpers do not.
- **Resolution plan**:
  1. Add `gcd(k, m) == 1 || throw(ArgumentError(...))` to `has_no_root_projective`,
     `find_alpha` and `family_f1_lut`, mirroring `taniguchi_apn`'s wording.
  2. Add a negative test in `test/test_theorem3.jl`:
     `@test_throws ArgumentError family_f1_lut(4, 2, 6)`.
  3. Optionally record the counter-example table above in `theorem3.jl` as the justification
     for the guard.

### 2. The paper's headline result (Table 3 / `N_F` at n=12) is not covered by the test suite

- **Location**: `test/runtests.jl:4-7`; `test/test_table3.jl:28`
  (`@test table3_build().skipped`)
- **Symptom**: `make test` never computes `N_F` for F1/F2, never compares against
  `TABLE3_F1`/`TABLE3_F2` (`section4_1.jl:21-22`), and never checks novelty.
  `test_table3.jl` deliberately asserts the *skip gate* instead. `section4_1.jl` and
  `remark1.jl` have no test file at all. The only APN check at `n=12` sits behind
  `full_search=true`.
- **Root cause**: runtime budget (`Makefile:46` — "table3 ~10 min"). But the choice pushes the
  paper's only novelty claim out of CI.
- **Resolution plan**:
  1. Add `test/test_section4_1.jl` running `section4_1_build(full_search = true)` and
     asserting `apn1`, `apn2`, `match_f1`, `match_f2`. The independently measured cost of the
     `n=12` `N_F` computation (non-bent scan + 4 levels of subspace counting) is **~0.55 s per
     function** in optimized C; the Julia path is slower, but this is a seconds-to-minutes
     test, not 10 minutes.
  2. Keep the full 12-family `table3` recomputation opt-in, but add a fast test that F1/F2's
     signatures are not in `TABLE3_KNOWN_ROWS` — those constants are already in the file.
  3. Add `test/test_remark1.jl` gated on `ms = [4]`.

### 3. Remark 1 is only half-reproduced, and the n=10 half is left paper-trusted although a cheap invariant settles it

- **Location**: `remark1.jl:31` (`ms = [4]`), `:38`
  (`alpha = first(a for a in alphas if a != 1)`)
- **Symptom**: only `n = 8` runs by default, only one `α ≠ 1` is tested (`α = 9` of the
  admissible set `{1,9,11,13,14}`), and `n = 10` is documented as aborted after 25 CPU-minutes.
- **Root cause**: `are_ccz_equivalent` routes through a full `are_linear_equivalent` search.
  But CCZ-equivalence of quadratic APN functions is *refuted* by any ortho-derivative
  invariant, so the cheap direction can at least be run exhaustively.
- **Supporting data** (ortho-derivative differential spectra, all admissible `α`):
  - `n = 8`, F1, `k ∈ {1,3}`, `α ∈ {1,9,11,13,14}`: identical, `{0:36420, 2:25080, 4:3780}`.
  - `n = 8`, F2, same `α`: identical, `{0:38160, 2:22104, 4:4536, 6:456, 8:24}`.
  - `n = 10`, F1, `α ∈ {1,6,7,20,21,22,23,24,25,28,29}`: identical,
    `{0:637701, 2:313131, 4:80910, 6:14415, 8:1395}`.
  - `n = 10`, F2, same 11 `α`: identical,
    `{0:634041, 2:320166, 4:78420, 6:13020, 8:1830, 10:60, 12:15}`.
- **Resolution plan**:
  1. Add a fast pre-check to `remark1_build`: compare `apn_ea_mugshot` (or
     `sorted_pairs(differential_spectrum(ortho_derivative(F)))`) for **every** admissible `α`
     against the `α = 1` member — seconds at `n = 8` and `n = 10`, covering the whole of
     Remark 1's parameter range.
  2. Keep the expensive `are_ccz_equivalent` as a confirmatory check on one representative.
  3. Enable `ms = [4, 5]` for the invariant-level check; keep the full CCZ search opt-in.

### 4. Lemma 1 is only partially tested

- **Location**: `theorem3.jl:31-39`
- **Symptom**: `lem_i` (line 33) checks only `φ_{q,α}` rootless ⇒ `φ_{q,α²}` rootless; the
  paper's Lemma 1(i) also asserts the same for `α^q x^{q+1} + x + α` (`.tex` line 195).
  `lem_ii` (line 39) checks only `is_permutation(L)` for `a=b=1, c=α` — one direction of one
  instance — but Theorem 3's proof applies Lemma 1(ii) to `α^{q²}x^{q²}+x^q+α^q x` and to
  `α^q y^{q²}+y^q+α y` (`.tex` lines 300, 323), neither of which is tested. Lemma 1(iii) is
  untested.
- **Root cause**: the tests were written against the lemma *statement's* simplest instance
  rather than against its *uses* in the proof.
- **Resolution plan**:
  1. Extend `lemma1_build` to also assert rootlessness of `α^q x^{q+1}+x+α` and
     permutation-ness of the two linearized maps actually used in the Theorem 3 proof.
  2. Add the converse direction of (ii): pick an `α` *with* a root and assert
     `!is_permutation(L)`.
  3. Add a numeric check of Lemma 1(iii) with random `(a,b,c,d)`, `ad − bc ≠ 0`.

### 5. Theorem 4's proof machinery (Eq. (7), Eq. (9)/`Res_y`) and Theorem 3's Eq. (2)–(4) / φ″ identity are not reproduced

- **Location**: `theorem4.jl` (only Lemma 3 / Eq. (5) is checked, lines 90-105); `theorem3.jl`
  (no proof-step checks)
- **Symptom**: the paper's derivations — Eq. (7) (`.tex` lines 527-533), Eq. (4) (`.tex`
  line 392), the `φ''(y) = (y+(u+1)^q)^{q+1} φ_{q,α}((uy+α)/(y+(u+1)^q))` identity (`.tex`
  line 423), and the MAGMA resultant Eq. (9) (`.tex` line 550) — are transcribed nowhere.
- **Root cause**: scope choice — only the final APN statements are checked.
- **Supporting data** (all pass, so these are reproducible *additions*, not bugs):
  - **Eq. (7)** — `F(x+a,y+b)+F(x,y)+F(a,b) == (G(x,y), H(x,y))`: exhaustive over
    `(a,b,x,y) ∈ F_{2^m}^4`, 4096 checks for `m=3` (α=2) and 65536 for `m=4` (α=1) → **0
    mismatches**.
  - **Eq. (4)** — `L(y) = α^q f_u² y^{q²} + g_u² y^q + α f_u^{2q} y` is a permutation: for
    every admissible `α` and every `u ≠ 0`,
    `(m,k) ∈ {(3,1),(3,2),(4,1),(4,3),(5,1),(5,2),(6,1),(6,5),(7,1)}` → **0
    non-permutations**.
  - **φ″ identity** — exact for all `(α, u, y)` in the same range → **0 mismatches**, and
    `φ''` has no root anywhere.
- **Resolution plan**:
  1. Add `theorem4_eq7_build(m, α)` verifying Eq. (7) exhaustively for `m = 3, 4`, asserting
     0 mismatches.
  2. Add `theorem3_eq4_build(m, k, α)` verifying Eq. (4)'s permutation-ness and the φ″
     linear-fractional identity for the reproduced `(m,k)` cases.
  3. Eq. (9) (`Res_y(G,H)`) needs a symbolic resultant over `F_2[x,y,α,a,b]`; if that is out of
     scope, say so explicitly instead of silently omitting it.

### 6. The concluding-remarks equivalence count `φ(m)/2` for family F1 is not reproduced

- **Location**: not implemented anywhere; `.tex` line 806 ("from family F1 we can get `φ(m)/2`
  inequivalent functions, one for each `k ≤ m/2` coprime with m")
- **Symptom**: missing item.
- **Root cause**: `THEOREM3_CASES` (`theorem3.jl:18-22`) includes `k = 3` at `m = 4` but never
  compares classes across `k`.
- **Supporting data**: at `m = 5` (`φ(5)/2 = 2`), ortho-derivative differential spectra are
  `{0:637701, 2:313131, 4:80910, 6:14415, 8:1395}` for `k = 1` and `k = 4`, and
  `{0:626541, 2:330336, 4:79515, 6:10230, 8:930}` for `k = 2` and `k = 3` — exactly 2 classes,
  matching `φ(5)/2 = 2`. At `m = 4` (`φ(4)/2 = 1`), `k = 1` and `k = 3` share one spectrum → 1
  class. Both confirm the claim.
- **Resolution plan**: add a `section5.jl` (or extend `theorem3.jl`) computing
  `apn_ea_mugshot` / OD-spectrum for `F1(m,k,α)` over all coprime `k` and asserting the number
  of distinct classes equals `φ(m)/2` for `m = 4, 5, 6, 7`.

### 7. `algebraic_degree == 2` is never asserted for F1/F2

- **Location**: `theorem3.jl:53-60`, `theorem4.jl:118-127`, `section4_1.jl:39-40` — all only
  check `differential_uniformity`. `test/test_table3.jl:22` does check
  `algebraic_degree(F) == 2`, but only for the *known* families.
- **Symptom**: the paper's whole novelty argument routes through Yoshiara's "CCZ = EA for
  **quadratic** APN" (`.tex` lines 132, 758). Quadraticity of the reproduced F1/F2 is assumed,
  not checked.
- **Root cause**: oversight.
- **Resolution plan**: add `@test algebraic_degree(F) == 2` alongside every `du == 2`
  assertion in `test_theorem3.jl`, `test_theorem4.jl` and the proposed `test_section4_1.jl`.
  (Quadraticity was verified independently for F1 and F2 at every admissible `α` for
  `m = 3…9`, i.e. up to `n = 18`; all quadratic.)

### 8. `table3_family6/7/8` use a heuristic "stall = 256" scan where an exact 2-value argument exists

- **Location**: `table3.jl:162` (`stall = 256`), `:197` (same for N.7/N.8), and the comment at
  `:187-196` describing a one-off 34-minute full scan
- **Symptom**: correct output, but the completeness claim ("bounded reconfirmation margin") is
  heuristic and expensive.
- **Root cause**: the `a`-dependence of families 6/7/8 was not analysed.
- **Exact argument** (verified numerically): for `F_a(x) = x^3 + a^{-1} tr(a^3 x^9)` one has
  `F_a(cx)/c^3 = F_{ac^3}(x)` and `(F_a(x^{2^{n-1}}))^2 = F_{a^2}(x)`; both hold verbatim for
  N.7 and N.8 with `tr^n_3`. So the EA class depends only on `a` modulo cubes, up to Frobenius
  — leaving **exactly two** classes per family (`a` a cube vs. `a` a non-cube). Computed at
  `n = 12` (modulus 4179), coset reps `a ∈ {1, 2, 4}`:

  | family | `a=1` | `a=2` | `a=4` |
  |---|---|---|---|
  | N.6 | `[1365,100100,139980,152]` | `[1365,100100,138918,103]` | same as `a=2` |
  | N.7 | `[1365,100100,144728,184]` | `[1365,100100,143502,198]` | same as `a=2` |
  | N.8 | `[1365,100100,144584,229]` | `[1365,100100,143286,155]` | same as `a=2` |

  The OD-DDT dedup keys separate `a=1` from `a=2` in all three families (e.g. N.6:
  `{0:10137531,2:5156403,4:1240776,6:208725,8:26694,10:2466,12:360,14:156,16:9}` vs
  `{0:10146186,2:5159556,4:1213488,6:219798,8:30204,10:3537,12:324,14:27}`), so `_od_key` will
  not over-merge.
- **Resolution plan**:
  1. Replace the `stall` scan with `a ∈ {1, g, g²}` (cube-coset representatives) and document
     the scaling/Frobenius argument in the file header.
  2. This turns a ~34-minute heuristic into 3 exact evaluations and makes the "exhaustive"
     claim real.

### 9. `table3.jl:34-37` calls the Table 3 multirow spans "ambiguous"; they are now settled

- **Location**: `table3.jl:34-43`
- **Symptom**: a comment says the vertical span of the "family n. 6" / "families n. 7 and 8"
  labels is ambiguous. The repo's guess (N.6 → 2 rows, N.7/N.8 → 4 rows) is **correct**, and
  issue 8's exact 2-classes-per-family argument proves it rather than merely observing it.
- **Root cause**: the ambiguity was resolved empirically and the comment never updated.
- **Resolution plan**: replace the "ambiguous / recomputation settles it" comment with the
  exact statement — each of N.6, N.7, N.8 has exactly two EA classes (cube vs non-cube `a`),
  so N.6 owns rows 5–6 and N.7+N.8 own rows 7–10.

### 10. Docstring "VBF API used" lists are inaccurate

- **Location**: `helpers.jl:11` lists `differential_uniformity` (never called in that file);
  `theorem3.jl:13` lists `gf_trace` (never called in that file)
- **Symptom**: cosmetic drift.
- **Root cause**: the lists were not regenerated as the files evolved.
- **Resolution plan**: regenerate the API lists from the actual call sites.

---

## Items Reproduced Exactly

| Paper item | `.tex` | Reproduction | Independent verification |
|---|---|---|---|
| **Theorem 3 (Family F1)** `f = x^{q+1}+xy^q+αy^{q+1}`, `g = x^{q²+1}+αx^{q²}y+(1+α)^q xy^{q²}+αy^{q²+1}` | 236-245 | `helpers.jl:34-63` | term-by-term identical |
| Theorem 3 APN | 245 | `theorem3.jl:44-63`, cases (3,1),(4,1),(4,3) | `du = 2` for **all** admissible α and **all** coprime `k`, `m = 3,4,5,6` (142 instances); plus quadratic+APN for every admissible α at `m = 7` (43), `m = 8` (85), `m = 9` (171, `k=1,2`) — including the `3∣m` regime the paper newly opens |
| **Theorem 4 (Family F2)** `f = x³+xy+xy²+αy³`, `g = x⁵+xy+αx²y²+αx⁴y+(1+α)²xy⁴+αy⁵` | 506-515 | `helpers.jl:65-93` | term-by-term identical |
| Theorem 4 APN | 515 | `theorem4.jl:110-130`, `m = 3,4` | `du = 2` for every admissible α, `m = 3…9` |
| Theorem 1 (Göloğlu F1) = Theorem 3 with α = 1 | 166-171 | `remark1.jl:41` | substituting α = 1 gives `(1+1)^q = 0`, collapsing to Göloğlu's quadrinomial exactly |
| Theorem 2 (Li et al.) = Theorem 4 with α = 1 | 181-187 | `remark1.jl:45` | substituting α = 1 gives `(1+1)² = 0` |
| "`x^{2^k+1}+x+1` has no root over `F_{2^m}` iff `gcd(3,m)=1`" | 444 | implicit via `find_alpha` | verified for **all** `(m,k)`, `2 ≤ m ≤ 12`, `gcd(k,m)=1` — 44 cases, 0 mismatches |
| **Lemma 2** (Williams [30]) root-count trichotomy | 449-458 | `theorem4.jl:38-76` | exhaustive over `F_{2^m} × F_{2^m}^*`: m=3 (56 pairs), m=4 (240), m=5 (992) — 0 mismatches; root counts only ever 0/1/3 |
| **Lemma 3(i)** `tr_m(1/α²) = tr_m(1)` | 463 | `theorem4.jl:83-88` | holds for every admissible α, `m = 3,4,5,6` (40 α values) |
| **Lemma 3(ii)** Eq. (5) has the unique solution `(α, 1)` | 467-472 | `theorem4.jl:90-105` | exhaustive over `F_{2^m}²`, every admissible α, `m = 3,4,5,6` — always exactly one solution, always `(α,1)` |
| **Eq. (7)** difference system for Theorem 4 | 527-533 | *(not in repo — issue 5)* | verified exhaustively, 0 mismatches |
| **Eq. (4)** + **φ″ linear-fractional identity** for Theorem 3 | 392, 423 | *(not in repo — issue 5)* | verified for all `(m,k,α,u,y)` listed above, 0 mismatches, φ″ rootless |
| **Table 3, family F1 row** `[1365, 100100, 140664]` | 791 | `section4_1.jl:21` | **exact match**: `m=6, k=1, α=6`, modulus 67 → `du=2` |
| **Table 3, family F2 row** `[1365, 100100, 144198, 192]` | 793 | `section4_1.jl:22` | **exact match**: same α → `du=2`; identical for all 21 admissible α at `n = 12` |
| **Table 3, all 11 known-family rows** | 769-789 | `table3.jl:30-48` + builders | **all 11 reproduced exactly** — see below |
| Novelty of F1 and F2 at n = 12 | 758 | `table3.jl:341-343` | F1's and F2's rows are absent from the 11 known rows → CCZ-inequivalent (Yoshiara: CCZ = EA for quadratic APN) |
| **Theorem 5** consequences: F1 is 3-to-1 ⇒ Gold-like; F2 Gold-like but **not** 3-to-1 | 816-820 | `theorem5.jl` | preimage histograms: F1 `{1↦1, 3↦(2^n−1)/3}` at n=6,8,10,12; F2 at n=12 `{0↦1541,1↦1476,2↦723,3↦271,4↦67,5↦15,6↦3}` — not 3-to-1; both Gold-like |
| Remark 1 (α-independence at n = 8, 10) | 799 | `remark1.jl` (partial) | OD spectra identical across **all** admissible α at n = 8 and n = 10 — necessary condition satisfied; see issue 3 |
| `N_F` = Göloğlu non-bent-subspace invariant | 136-155 | `nonbent_signature` + `trim_signature` (`helpers.jl:97-100`) | `packages/VBF/src/invariants/bent.jl:64` + `linalg/subspace_in_set.jl:104` compute `[|NB_F∖{0}|, #2-dim, …]`, exactly the paper's `n_i(NB_F)`; an independent canonical-greedy-basis enumeration agrees on every function tested |

### Independent recomputation of all 11 known-family Table 3 rows (n = 12, modulus 4179 / 67)

| Table 3 row | Paper attributes to | Computed representative | Match |
|---|---|---|---|
| `[1365,100100,99840,91]` | n. 1 (Gold) | `x^{2^i+1}`, `i = 1,5,7,11` (all four) | yes |
| `[1365,100100,141700]` | n. 2, 3 and 4 | BCL binomial `k=4, s=5` and `s=7`; BBMM `k=4,s=5,u=2,v=w=0` | yes |
| `[1365,100100,144010,140]` | n. 2, 3 and 4 | BCL binomial `k=4, s=1` and `s=11`; Li–Zhou–Li–Qu `m=4,s=1,μ=2,v=1` | yes |
| `[1365,100100,142932]` | n. 5, 9, 10 and 11 | BC hexanomial `i=1,c=3,s=2`; Zhou–Pott `k=1,i=0,α=2`; Taniguchi `k=1,a=1,b=6`; CBC `i=1,b=0,c=6` | yes |
| `[1365,100100,139980,152]` | n. 6 | BCL `a = 1` | yes |
| `[1365,100100,138918,103]` | n. 6 | BCL `a = 2` (≡ `a = 4`) | yes |
| `[1365,100100,144728,184]` | n. 7 and 8 | N.7 `a = 1` | yes |
| `[1365,100100,143502,198]` | n. 7 and 8 | N.7 `a = 2` (≡ `a = 4`) | yes |
| `[1365,100100,144584,229]` | n. 7 and 8 | N.8 `a = 1` | yes |
| `[1365,100100,143286,155]` | n. 7 and 8 | N.8 `a = 2` (≡ `a = 4`) | yes |
| `[1365,100100,144759,126]` | n. 12 | Göloğlu–Kölsch `k=1, B=2, a=1` | yes |

All 11 rows attained; `N_{F1}` and `N_{F2}` are in none of them. **The paper's Table 3 and its
novelty argument are fully confirmed.**

## Test Results

Reviewed on 2026-08-15 with **Julia 1.12.6** (project `/home/tiago/VBF.jl`, fully instantiated
and precompiled).

**Command**: `make -C packages/VBFRepro/src/202306-calderini-bivariate-families test`
**Exit code**: `0`
**Wall time**: 8 s (`Pkg.instantiate()` + `test/runtests.jl`)

| Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|
| `theorem3_test` | 16 | 0 | 0 | 16 | 0.6 s |
| `theorem4_test` | 20 | 0 | 0 | 20 | 0.5 s |
| `theorem5_test` | 21 | 0 | 0 | 21 | 0.8 s |
| `table3_test`   | 21 | 0 | 0 | 21 | 3.8 s |
| **Total**       | **78** | **0** | **0** | **78** | — |

The earlier "78 tests passing" figure is **confirmed**: 16 + 20 + 21 + 21 = 78, all passing,
no broken or failed assertions, and the per-file counts match the previously recorded
16 / 20 / 21 / 21 exactly. Julia emits no aggregate line, so the total is the sum of the four
`Test Summary:` blocks in the log.

Additional targeted runs (not part of `make test`):

| Command | Result |
|---|---|
| `section4_1_build(full_search = true)` | **28.0 s** — `du1 = du2 = 2`, `N_F1 = [1365, 100100, 140664]`, `N_F2 = [1365, 100100, 144198, 192]`, both `match = true` against `TABLE3_F1`/`TABLE3_F2` |
| `remark1_build(ms = [4])` (n = 8, α = 9 vs α = 1) | **passes** — `eq1 = true`, `eq2 = true`; `are_ccz_equivalent` took 84.2 s (F1) and 306.7 s (F2) |
| Catalog LUT byte-comparison | `n12_CalderiniLiVilla2023_F1` / `_F2` LUTs (4096 entries each) **identical** to `family_f1_lut(6,1,6; modulus=67)` / `family_f2_lut(6,6; modulus=67)` |

The independent C reimplementation that preceded this run agreed on every load-bearing number.

## Catalog Status

| Claimed / notable function | Status |
|---|---|
| **F1 at n = 12** (`m=6, k=1, α=6`, mod 67) — claimed new | **present** — `n12_CalderiniLiVilla2023_F1`. LUT byte-identical; `du = 2`; `N_F = [1365,100100,140664]` |
| **F2 at n = 12** (`m=6, α=6`, mod 67) — claimed new | **present** — `n12_CalderiniLiVilla2023_F2`. LUT byte-identical; `du = 2`; `N_F = [1365,100100,144198,192]` |
| **F1 at n = 6** (`m=3, k=1, α ∈ {2,4,6}`) | **not-new** — ortho-derivative mugshot `OD-DDT {0:2205, 2:1764, 8:63}`, `OD-\|W\| {0:1827, 8:1680, 16:588, 64:1}` is **identical** to `n6_Gold_x3` (and to `n6_Kasami_x48`, its known linear-equivalent). Consistent with the paper's Section 5 remark that biprojective APN at `n ≤ 10` collapses to Göloğlu's families / Gold / sporadics |
| **F2 at n = 6** (`m=3, α ∈ {2,4,6}`) | **MISSING — catalog gap** (record below) |
| F1/F2 at n = 8, n = 10 | **missing but not claimed new** — Remark 1 states these are CCZ-equivalent to Göloğlu's `F_1` [21] and Li et al.'s Theorem 2 family [28]. Neither of those families has an n=8 or n=10 catalog entry either, so these are *known-family* gaps rather than novelty gaps. Evidence: no n8/n10 catalog entry matches — n=8 F1 `{0:36420,2:25080,4:3780}` and F2 `{0:38160,2:22104,4:4536,6:456,8:24}` vs `n8_Gold_x3 {0:39780,2:21930,6:3570}`, `n8_Gold_x9 {0:35700,2:26520,4:3060}`, `n8_Calderini2021_thm62 {0:39150,…}`, `n8_Taniguchi2025_ex4_2 {0:38592,…}`; n=10 F1 `{0:637701,2:313131,4:80910,6:14415,8:1395}`, F1 with `k=2` `{0:626541,2:330336,4:79515,6:10230,8:930}`, F2 `{0:634041,2:320166,4:78420,6:13020,8:1830,10:60,12:15}` vs `n10_Gold_x3 {0:595386,2:416361,6:35805}`, `n10_Gold_x9 {0:713031,…}` (`n10_Kasami_x57`, `n10_Dobbertin_x339` are not quadratic). Low-priority optional additions |

### Catalog-gap record

```
target file : packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml

name              = "n6_CalderiniLiVilla2023_F2"
n                 = 6
m                 = 6
is_permutation    = false
lut               = [0, 9, 59, 20, 29, 38, 47, 50, 18, 59, 17, 30, 39, 60, 45, 16,
                     46, 17, 18, 11, 6, 11, 51, 24, 35, 60, 39, 30, 35, 14, 46, 37,
                     49, 50, 6, 35, 47, 30, 17, 6, 31, 60, 16, 21, 41, 56, 47, 24,
                     13, 56, 61, 46, 38, 33, 31, 62, 60, 41, 52, 7, 63, 24, 62, 63]
algebraic_form    = "Bivariate F(x,y)=(f,g), f = x^3 + x*y + x*y^2 + alpha*y^3, g = x^5 + x*y + alpha*x^2*y^2 + alpha*x^4*y + (1+alpha)^2*x*y^4 + alpha*y^5 over GF(2^3), modulus x^3+x+1 (=11), alpha=2; packed z = x|(y<<3) -> f|(g<<3)"
bib_key           = "Calderini_202306"
source            = "Calderini, Li, Villa, 'Extending two families of bivariate APN functions', Finite Fields Appl. 88 (2023) 102190, Theorem 4 (Family F2), smallest instance in the 3 | m regime (m = 3, n = 6). This is exactly family_f2_lut(3, 2; modulus = 11) as already built by packages/VBFRepro/src/202306-calderini-bivariate-families/theorem4.jl (THEOREM4_CASES m = 3) and theorem5.jl. Outside the range of Li et al. (2022) [28] Theorem 2, which requires gcd(3, m) = 1."
```

**Equivalence evidence**

- `differential_uniformity = 2`, `algebraic_degree = 2`, not a permutation (image histogram
  `{0↦29, 1↦15, 2↦12, 3↦7, 4↦1}`), `F(0) = 0`.
- Ortho-derivative mugshot: `OD-DDT {0:2583, 2:1008, 4:378, 8:63}`,
  `OD-|Walsh| {0:1953, 8:1617, 16:462, 24:63, 64:1}`.
- Compared against **every** existing `n6_apn.toml` entry:
  - `n6_Gold_x3` → `OD-DDT {0:2205, 2:1764, 8:63}`, `OD-|W| {0:1827, 8:1680, 16:588, 64:1}` —
    **differs**;
  - `n6_Kasami_x48` → identical to Gold (already flagged in the TOML as the same CCZ class) —
    **differs**;
  - `n6_Kim` → `OD-DDT {0:2373, 2:1428, 4:168, 8:63}`,
    `OD-|W| {0:1603, 8:2072, 16:364, 24:56, 64:1}` — **differs**.
- The ortho-derivative DDT/Walsh mugshot is a CCZ-invariant of quadratic APN functions, and
  CCZ = EA for quadratics (Yoshiara, `.tex` line 132), so this function is
  **CCZ-inequivalent to every current n=6 catalog entry**.
- The class is α-independent: `α ∈ {2, 4, 6}` (the complete admissible set at `m = 3`) all
  give the identical mugshot, so one entry suffices.
- **Caveat to record in the TOML description**: dimension 6 has a fully classified APN
  landscape (13 known CCZ classes); absence from this catalog is a *catalog* gap, not a claim
  of novelty in the literature. The paper itself claims novelty only at `n = 12`.

## Library-Reuse Note

**No helper duplicates a VBF core export.** Every symbol in `helpers.jl` is either
paper-specific or a thin wrapper:

| Helper | Verdict |
|---|---|
| `has_no_root_projective` (`helpers.jl:16`) | Not a duplicate — no core export tests rootlessness of `x^{2^k+1}+x+α`. (See promote-to-core below.) Correctly rejects `α = 0` via the `x = 1` iteration (`1 ⊻ 1 ⊻ α = α`), so the loop starting at `x = 1` is not a bug |
| `find_alpha` (`helpers.jl:27`) | Paper-specific |
| `family_f1_lut` / `family_f2_lut` (`helpers.jl:34, 65`) | Paper-specific (Theorems 3 and 4); correctly build on `gf_mul`, `gf_pow`, `primitive_polynomial`, `SBox` |
| `trim_signature` (`helpers.jl:97`) | Presentational only — strips the terminating `0` that `subspace_count_signature` always appends (`packages/VBF/src/linalg/subspace_in_set.jl:104-114`) |
| `paper_banner` (`helpers.jl:102`) | Thin wrapper over the core `print_banner` — correct |
| `trm` (`theorem4.jl:44`) | **Not** a duplicate of `gf_trace`/`gf_relative_trace`: it computes the *absolute* trace of `F_{2^m}` for an element embedded in the `F_{2^{2m}}` representation (`Σ_{i<m} x^{2^i}` in the big field). `gf_trace(x, 2m)` would give `2·tr_m = 0`. Legitimately paper-specific |
| `cube` (`theorem4.jl:53`) | Odd-`m` branch correctly reuses `gf_is_dth_power`; the even-`m` branch computes `t^{(2^m−1)/3}` by hand because core has no subfield-relative `d`-th-power test. Legitimate |
| `_od_key` (`table3.jl:52`) | Composes core `ortho_derivative` + `differential_spectrum` + `sorted_pairs`. Not a duplicate, though `apn_ea_mugshot` (`packages/VBF/src/invariants/mugshot.jl:122`) is the repo-canonical, strictly finer EA key — consider switching for consistency |
| `walsh_value_set` (`theorem5.jl:26`) | Thin composition of `absolute_walsh_spectrum` + `sorted_pairs` — correct |
| `table3_family*` builders | Correctly reuse `gold_apn`, `bcp_apn`, `taniguchi_apn`, `terms_to_lut`, `subfield_elements`, `gf_*`, `is_permutation`, `is_quadratic_apn`, `nonbent_signature`. Families 3, 4, 5, 6, 7, 8, 11, 12 are hand-built (core has no constructors for them) — legitimate |

Promote-to-core candidates:

1. **Projective-polynomial rootlessness (Bluher test)** — `has_no_root_projective(m, k, α)`
   ("does `a·x^{2^k+1} + b·x + c` have a root in `GF(2^m)`?") is a general finite-field
   primitive, and it is **already reimplemented in core as a private function**:
   `_taniguchi_admissible` (`packages/VBF/src/constructions/taniguchi.jl:72`) does exactly the
   `z^{2^m+1} + a·z + b` rootlessness test but is not exported. Table 2 families N.10 and N.11
   of *this* paper need it too, and `table3.jl:246` open-codes it a third time. Proposal:
   export `projective_polynomial_rootless(a, b, c, k, m; modulus)` with the `gcd(k,m) = 1`
   guard built in (which would also fix issue 1), and have `_taniguchi_admissible`,
   `table3.jl:246` and this paper's helper all call it.
2. **Subfield-relative `d`-th-power test** — `gf_is_dth_power(t, d, n)` exists; a variant
   testing cube-ness *within a subfield* `GF(2^m) ⊆ GF(2^n)` would remove the hand-rolled
   even-`m` branch at `theorem4.jl:53-54` and the `gpow(B,21,6,·)==1` idiom at
   `table3.jl:234, 281`.
3. **Cube-coset / Frobenius class reduction** for `x³ + a⁻¹·tr(...)` families — the exact
   2-classes argument in issue 8 is reusable for any BCL-style `a`-parameterized family; a core
   helper returning cube-coset representatives of `GF(2^n)^*` would let several papers replace
   `stall`-based scans with exact enumeration.

## Open Questions

1. **Catalog policy for non-novel-but-absent instances**: should `n8`/`n10` representatives of
   Göloğlu's `F_1` [21] and Li et al.'s Theorem 2 family [28] (i.e. F1/F2 at `α = 1`) be
   added? They are absent from the catalog but explicitly *not* new per Remark 1. No gap
   record was written for them pending a policy decision.
2. **n = 6 F2 gap acceptance**: dimension 6 is fully classified in the literature; the proposed
   `n6_CalderiniLiVilla2023_F2` entry is CCZ-inequivalent to all three current `n6` entries but
   is presumably one of the 13 known n=6 classes under another name (likely an Edel–Pott /
   switching-class representative). Add it under the Calderini–Li–Villa name, or match it
   against an Edel–Pott naming convention first?
3. **Eq. (9) resultant**: verifying
   `Res_y(G,H)(x) = (a³+ab²+αb³)² x (x+a) R(x,a,b) R(x+a,a,b)` requires symbolic computation
   over `F_2[x,y,α,a,b]`. Is symbolic resultant machinery in scope for this repo, or should the
   omission simply be documented in `theorem4.jl`?
4. **Julia availability**: all statements about the repo's *own* test suite (pass/fail, 78
   assertions) remain unverified. If a Julia toolchain can be provided, `make test`,
   `make section4_1`, `make table3` and `make remark1` should all be rerun before this README
   is considered final.
