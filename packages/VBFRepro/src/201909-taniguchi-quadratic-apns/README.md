# Taniguchi_201909 — On Some Quadratic APN Functions

**Paper:** H. Taniguchi, *On some quadratic APN functions*, Des. Codes Cryptogr.
(2019).

**Reproduction:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/` — `helpers.jl`, `theorem3.jl`,
`theorem4.jl`, `section2_carlet_zhou_pott.jl`, `fact_helleseth_kholosha.jl`,
`theorem5_presemifield.jl`, `report.jl`.

**Verdict:** **Reproduced** (was: Partial). Theorem 3 — the paper's actual
contribution — is correctly implemented and exhaustively verified in both
directions. The gaps found in review have since been closed: the paper's
*headline claim* ("not CCZ equivalent to the former two families on F₂⁸") is now
asserted directly on F₂⁸ against both former families; Corollary 2 is implemented
as its actual `a = 1` branch instead of a copy of the Theorem-1 block; Theorem 4
is checked as the exact LUT identity the paper states rather than a necessary-only
proxy; the Section-3 `b⁵` table is reproduced exactly; and the Theorem 5 driver
now sweeps all 1020 admissible triples with an `a ≠ 0` witness. Everything the
paper claims is checkable in-repo, and it all holds.

Only Theorem 6 remains out of reach, and for an honest reason: it assumes
`[F:K] ≥ 3`, while VBF's characteristic-2 field machinery can only express the
`[F:K] = 2` instance (see R7).

---

## Issue Catalog

### Paper Issues

**None found.** Every claim checked against the `.tex` held up. In particular
the paper's remark *"if a = 0, then F(x,y) in Theorem 3 belongs to the family of
Theorem 2"* is confirmed: `Tan(a=0, b=2)` and `ZhouPott(i=2, α=2)` have
identical mugshots.

### Reproduction Issues

**R1. A VBF core docstring states something false, and contradicts a passing
test in its own package.** *(core library, not paper-local)*

- **Location:** `packages/VBF/src/invariants/design_ranks.jl:15-17`
- **Symptom:** The docstring reads: *"They distinguish CCZ-classes that share
  differential and Walsh spectra — e.g. Taniguchi's two new `F₂⁸` families have
  equal ortho-derivative fingerprints but Γ-ranks 13700 vs 13798."* The premise
  is false: the OD fingerprint separates the two new classes cleanly, three
  independent ways.
  - OD-DDT spectra differ:
    `(a=1,b=1)` → `0⇒39135, 2⇒21165, 4⇒4230, 6⇒1005, 256⇒1`;
    `(a=1,b=9)` → `0⇒38835, 2⇒21315, 4⇒4860, 6⇒495, 8⇒30, 256⇒1`
  - OD-Walsh spectra differ (`b=9` has ±56 entries; `b=1` has none).
  - `sigma_hash` maps the three Taniguchi reps to **three different** σ-index
    entries: `("functions", 580)`, `("functions", 595)`,
    `("beierleleander2022_n8", 14)`.
- **Root cause:** The motivating example was written from an assumption, not a
  computation. It is directly contradicted by
  `packages/VBF/test/unit/taniguchi_test.jl`, which asserts
  `taniguchi_apn_representatives` returns **3** classes on `half=4` — that
  function dedupes *by* `apn_ea_mugshot` (an OD fingerprint), so if the
  fingerprints were equal it would return 2 and the test would fail.
- **Resolution plan:**
  1. Replace the false example in the docstring. Γ-rank is still worth having;
     it just needs a motivating example that is actually true.
  2. Grep for other code or comments written in the belief that OD fingerprints
     collapse the Taniguchi classes.
  3. **Needs a decision — see Open Questions:** no verified OD-collision /
     Γ-rank-split pair is known in this repo, so a replacement example must be
     found or the sentence rewritten generically.

**R2. [RESOLVED] The paper's headline novelty claim is never tested.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem3.jl` (`theorem3_ccz_classes`),
  `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/section2_carlet_zhou_pott.jl` (`section2_verify`)
- **Symptom:** The abstract's claim is *"which are not CCZ equivalent to the
  former two families on F₂⁸"*. Nothing compared a Taniguchi `a≠0` function
  against a Carlet Theorem-1 function or a Zhou–Pott Corollary-1 function.
- **Root cause:** The cross-family comparison was never written.
- **Fix:** New `headline_claim_verify()` in `section2_carlet_zhou_pott.jl`, driven
  from `tests/test_section2_carlet_zhou_pott.jl`. On F₂⁸ it asserts both `a≠0`
  Taniguchi reps differ from a Carlet-Thm-1 rep and from a Zhou–Pott-Cor-1 (i=2)
  rep — by `apn_ea_mugshot` **and** by the exact `are_ccz_equivalent` oracle
  (quadratic APN ⇒ CCZ = EA, a complete decision) — and that Carlet ≠ Zhou–Pott.
  It also asserts the paper's own `a=0` remark as an expected **collision**:
  `Tan(a=0,b=2) == ZhouPott(i=2,α=2)`. That collision is what makes the block
  discriminating: a broken invariant that separated everything from everything
  would fail there.

**R3. [RESOLVED] "Corollary 2" was a verbatim duplicate of the Theorem 1 block.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/section2_carlet_zhou_pott.jl:138-153` (old)
- **Symptom:** The Corollary 2 block called the same `carlet_G1_rootless(n,m,0,1,0,0,t)`
  and `carlet_thm1_F(n,m,0,1,0,0,t)` with the same loop as the Theorem 1 block, so
  its `[PASS]` was a vacuous re-check of the line above.
- **Root cause:** The whole content of Corollary 2 is the **`a = 1` branch**, which
  was never built.
- **Fix:** Corollary 2 is now implemented as its actual proof, run as an algorithm:
  `carlet_cor2_normalize` performs the coordinate change `(x,y) ↦ (x, λx+y)` with
  `λ = (u/t)^{2^{-i}}` (killing `u`), then `Φ₁ : (u,v) ↦ (u, (v/s′)^{2^{-j}})`, then —
  for `a ≠ 0` — the change `(x,y) ↦ (a^{2^{-m}}x, y)` followed by
  `Φ₂ : (u,v) ↦ (u/c, v/(a·c))`. `carlet_cor2_chain_identity` checks the whole chain
  at LUT level: `Φ₂(Φ₁(F(c·x, λ·c·x+y))) == (xy + λ'x², G'(x,y))`, exactly.
  `carlet_cor2_verify` runs this over **every** Theorem-1 instance at n=4, i=1, j=0:
  all 20400 rootless ones normalize to `a' ∈ {0,1}`, all 20400 keep `G'(x,1)`
  rootless, all 20400 satisfy the chain identity, and **18000 reach the `a'=1`
  branch** (2400 reach `a'=0`). The Theorem-1 block's `u=v=0` instances can only
  ever reach `a'=0` — asserted — so the two blocks now test different things.
  Non-vacuity: `λ` is pinned by `u + t·λ^{2^i} = 0`, and the test feeds a wrong `λ`
  through `λ_override` and confirms the identity breaks.

**R4. [RESOLVED] Theorem 4 was checked with a necessary-only proxy.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem4.jl`
- **Symptom:** The paper says *"Theorem 3 is obtained from Theorem 4 by the
  substitution x ↦ x^{2^{2m}}"* — an **exact identity**. The reproduction compared
  `apn_ea_mugshot(F3) == apn_ea_mugshot(F4)`, and only on APN instances.
- **Fix:** New `theorem4_substitution_identity` / `theorem4_identity_verify` assert
  the exact LUT identity `F₃(x,y) == F₄(x^{2^{2m}}, y)` for **all** (a,b), APN or
  not. Verified exhaustively at `(half,m) ∈ {(4,1),(4,3),(5,1),(5,2)}` — 240, 240,
  992, 992 pairs. The mugshot check is kept as the (weaker) EA corollary.
  Non-vacuity: the `twist` keyword aims the identity at a *wrong* substitution
  exponent, and the tests assert it fails for `2^m` and `2^{3m}` — and that
  `F₃.lut != F₄.lut`, so the substitution is not the identity map.

**R5. [RESOLVED] The Theorem 5 driver exercised only the degenerate `a = 0` case.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem5_presemifield.jl`
  (`theorem5_find_params`)
- **Symptom:** It returned the *first* valid triple, `(a=0, b=2, α=2)`.
- **Fix:** `theorem5_find_params(; require_nonzero_a=true)` now defaults to an
  `a ≠ 0` witness (it returns `(a=1, b=6, α=2)`); the old behaviour is still
  reachable with `require_nonzero_a=false` and is pinned by a test. New
  `theorem5_sweep()` runs `theorem5_verify` on **all 1020** admissible triples
  (900 with `a≠0`, 120 with `a=0`) — zero failures — and adds two negative
  controls: each of the 5 norm-1 `α` and each of the 138 rooted `(a,b)` *does*
  produce a zero-divisor. Without those controls a no-zero-divisor scan is not a
  discriminating test. (A GF(2⁴) multiplication table keeps the full sweep at
  ~0.7 s.)

**R6. [RESOLVED] `_σ2(x) = x` hardcoded `σ² = id`.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem5_presemifield.jl:27` (old)
- **Fix:** `_σ2(x) = _σ(_σ(x))` — the Frobenius applied twice, computed rather than
  assumed. A `_T5_N % _T5_K == 0` guard now rejects a `K` that is not a subfield of
  `F`, and `_T5_DEG = [F:K]` is exposed. The tests assert `_σ2 == _σ∘_σ`, that it
  equals the identity here (and *only* because `[F:K] = 2`), and that `_σ` itself is
  not the identity.

**R7. [RESOLVED — re-scoped] The Theorem 6 `[skip]` note was misleading.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/helpers.jl`,
  `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem5_presemifield.jl` (Theorem 6 skip note)
- **Symptom:** Skipped as *"no nucleus algorithm in VBF"* / "algebraic proof only".
  The real problem is that Theorem 6 assumes `[F:K] ≥ 3`, and the reproduction's
  only instance is `[F:K] = 2` — so it was outside the theorem's own hypotheses and
  could not have been tested even in principle.
- **Fix (the "re-scope" option of the plan):** The skip note now says exactly that:
  the instance is `[F:K] = 2`, out of the theorem's scope; the smallest `[F:K] = 3`
  instance is `p=3, K=GF(3), F=GF(3³)`, which is **odd characteristic** — and VBF's
  `SBox`/GF machinery is characteristic-2 only. That, not the absence of a nucleus
  algorithm, is the actual blocker.
- **Still open:** whether to *implement* the `p=3` instance (new odd-characteristic
  field arithmetic) — see Open Questions.

**R8. [RESOLVED] Six re-implementations of the same rootless test.**

- **Location (old):** `theorem3.jl:17` (`_P_rootless`); `theorem4.jl:82-85` (inline
  closure); `fact_helleseth_kholosha.jl:26-29` (inline loop);
  `section2_carlet_zhou_pott.jl:55` (`carlet_G1_rootless`);
  `theorem5_presemifield.jl:42` (`_P_rootless_T5`); `tests/test_theorem4.jl:11-14`
  (inline loop)
- **Fix (paper-local):** the loop now exists **exactly once** in this directory, in
  `helpers.jl`: `carlet_G1_rootless(n,i,j,s,u,v,t)` is the general Carlet `G(x,1)`
  test, and `projective_polynomial_rootless(n,m,a,b)` is literally its
  `(i,j,s,u,v,t) = (m,0,1,0,a,b)` specialization (the two were checked to agree on
  every `(n,m,a,b)` for n ∈ 3..6). All six sites call it, including Theorem 5 (with
  `m = k`, `σ(x) = x^{2^k}`), and Fact 1 (with `a = 1`).
- **Deferred:** promoting `projective_polynomial_rootless` to `packages/VBF/src/` —
  it is currently private as `VBF._taniguchi_admissible` — remains a core follow-up.
  See the Library-reuse note.

**R9. [RESOLVED] `theorem3_ccz_classes` overstated what it computes.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem3.jl` (`theorem3_ccz_classes`)
- **Symptom:** Reported "3 CCZ-classes total". Distinct mugshots give a *lower
  bound* — mugshot equality is necessary, not sufficient.
- **Fix:** The return value is now `(; n_od_signatures, ccz_classes_lower_bound,
  pairwise_ccz_inequivalent, …)` and the report reads *"≥ 3 CCZ-classes (3 distinct
  OD signatures)"*. It is also **strengthened**: the three representatives are now
  certified pairwise CCZ-**in**equivalent by the exact `are_ccz_equivalent` oracle,
  not merely by an unequal invariant. It stays a lower bound, because members inside
  a single mugshot bucket are not proven mutually equivalent — the paper's Γ-rank
  argument has exactly the same strength.

**R10. [RESOLVED] The `b⁵ = 1` / `b⁵ ≠ 1` partition (Section 3 table).**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/theorem3.jl`
- **Fix:** New `theorem3_b5_partition(4)` groups **every** admissible APN `(m,a,b)`
  at half=4 by `apn_ea_mugshot`. The partition is exact and reproduces the paper's
  table: **20** members all `a=0` (Γ-rank 13642), **30** all `a≠0` with `b⁵=1`
  (13700), **120** all `a≠0` with `b⁵≠1` (13798) — 170 triples, 3 buckets, none
  mixed. Non-vacuity: replacing the `b⁵` predicate with `b³` makes buckets straddle
  rows and the suite fails.

**R11. [RESOLVED] `print_header` duplicated core `print_banner`.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/helpers.jl:3-7`
- **Fix:** `print_header` now calls `VBF.print_banner`; the hand-rolled `"=" ^ 70`
  is gone. (The paper-local wrapper is kept only to carry the scope block.)

**R12. [RESOLVED] Reasoning-in-progress comment shipped in a test.**

- **Location:** `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/tests/test_theorem3.jl:16-17`
- **Fix:** The self-correcting comment is gone. The spot-check now states the fact
  plainly (`P(x)=x³+1` has the root `x=1`, so `F` is not APN) and asserts the
  rootless predicate directly alongside the differential uniformity, in both the
  non-APN (`b=1`) and APN (`b=2`) directions.

---

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| **Theorem 1** (Carlet) | `section2_verify` checks the **iff** in `t` at n=4; `carlet_cor2_verify` sweeps all 57600 instances (s,t≠0) at i=1, j=0, of which 20400 are APN |
| **Corollary 2** (normalized Carlet, `a' ∈ {0,1}`) | `carlet_cor2_normalize` + `carlet_cor2_chain_identity`: the coordinate chain is verified **at LUT level** on all 20400 APN Theorem-1 instances; 18000 hit the `a'=1` branch |
| **Fact 1** (Helleseth–Kholosha count) | exhaustive at n=5 (11), n=6 (21), n=7 (43) |
| **Theorem 3** (the new family), Eq. (2) | `packages/VBF/src/constructions/taniguchi.jl:33` implements `G(x,y)` verbatim; `theorem3_verify` checks the **iff** in both directions exhaustively over all `(a,b)` at `half=4` (85 APN + 155 non-APN) and `half=5` (341 + 651) |
| **Theorem 3 — headline claim** ("not CCZ equivalent to the former two families on F₂⁸") | `headline_claim_verify`: both `a≠0` reps vs Carlet-Thm-1 and vs Zhou–Pott-Cor-1 (i=2), by `apn_ea_mugshot` **and** by `are_ccz_equivalent`; plus the paper's `a=0` remark as an expected collision |
| **Theorem 3 — Section-3 `b⁵` table** | `theorem3_b5_partition`: 20 / 30 / 120, exactly the three rows, no mixed bucket |
| **Theorem 4** + the substitution link | exact LUT identity `F₃(x,y) = F₄(x^{2^{2m}}, y)` over **all** (a,b) at (half,m) ∈ {(4,1),(4,3),(5,1),(5,2)} |
| **Lemma 2** | exhaustive on GF(2⁴) |
| **Theorem 5** (presemifield, Eq. 3) | `theorem5_sweep`: all **1020** admissible (a,b,α) (900 with `a≠0`), zero failures, plus two negative controls |
| Γ-rank table (13200/13642/13700/13798) | **unverifiable in-repo** — `gamma_rank` refuses n=8 by an explicit guard (needs ≈512 MB and hours; the paper's values come from Magma). Correctly labelled `[loaded]` by the repro. The *partition* the Γ-ranks certify is reproduced by mugshot (R10). |

## Not reproduced

Theorem 2 (Zhou–Pott, general σ — only Corollary 1 exists); Lemma 1 (`F` and
`F+L` CCZ-equivalent — used implicitly by Corollary 2, not asserted on its own);
**Proposition 2** (the Theorem-3 analogue of Corollary 2 — the paper itself says
its proof "is a copy of the proof of Corollary 2", which *is* now reproduced);
Lemma 3 (invertibility of `L_β`); **Theorem 6 + Propositions 3–6** (nuclei,
commutative center — see R7); §1 Carlet conditions 1/2/3 individually;
Proposition 1 (Edel–Pott: CCZ ⇒ equal Γ-rank — cheap smoke test for n ≤ 7).
Lemma 4 is cited from Lidl–Niederreiter and is reasonably skipped.

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper; `make` bypassed (it shells
out to bare `julia`). **No OOM; nothing skipped for memory.**

| Command | Result |
|---|---|
| `tests/runtests.jl` | **PASS** — section2_carlet_zhou_pott 39/39, theorem3 18/18, theorem4 106/106, fact_helleseth_kholosha 5/5, theorem5_presemifield 20/20 (**188 total**, was 108) |
| `report.jl` | **PASS** — all 40 `[PASS]`, no `[FAIL]` (was 14) |

**Non-vacuity.** Every new assertion was mutation-tested: disabling Corollary 2's
`a≠0` branch, swapping `b⁵`→`b³` in the Section-3 partition, replacing the
Zhou–Pott rep with the Carlet rep in the headline claim, neutering Theorem 4's
substitution exponent, and making the Theorem 5 driver ignore `require_nonzero_a`
each make the suite **fail**. Three mutation knobs are permanent parts of the
suite (`twist=`, `λ_override=`, `require_nonzero_a=false`), and Theorem 5 carries
two negative controls that exercise the failure path of the no-zero-divisor scan.

The only uncomputable item is the Γ-rank table at F₂⁸, blocked by an explicit
`n ≤ 7` guard in `packages/VBF/src/invariants/design_ranks.jl:68`, not by memory
pressure.

## Catalog status

`packages/VBFCatalog/data/apn/n8_apn.toml` has exactly 4 entries
(`n8_Gold_x3`, `n8_Gold_x9`, `n8_Kasami_x57`, `n8_Calderini2021_thm62`) and **no
Taniguchi entry**. All three Taniguchi reps are mugshot-distinct from all four
(and `n8_Kasami_x57` is separated by algebraic degree 4 ≠ 2).

**Important nuance — these are provenance gaps, not world-novelty.**
`classify_ccz` returns `:known` for all three reps (`("functions", 580)`,
`("functions", 595)`, `("beierleleander2022_n8", 14)`) — expected, since
Beierle–Leander classified all 8-bit quadratic APN CCZ classes. Adding them would
name and cite already-indexed CCZ classes, not assert a new discovery.
**Needs a decision — see Open Questions.** Full LUTs and equivalence evidence are
in the review transcript.

## Library-reuse note

- **Promote to core (still open):** `projective_polynomial_rootless` (R8). The six
  in-directory copies are gone — the loop now exists once, in
  `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/helpers.jl` — but the primitive still belongs in
  `packages/VBF/src/`, where it already exists as the *private*
  `VBF._taniguchi_admissible` (`packages/VBF/src/constructions/taniguchi.jl:72`).
  A seventh copy lives in `packages/VBFRepro/src/202306-calderini-bivariate-families/table3.jl`. Promoting it is a
  core change and was left out of the paper-local fix pass.
- **Promote to core (still open):** `carlet_apn` (Carlet 2011, Thm 1) and
  `zhou_pott_apn` (Zhou–Pott 2013) — two *named known APN families* living only in
  `packages/VBFRepro/src/201909-taniguchi-quadratic-apns/section2_carlet_zhou_pott.jl` (`carlet_thm1_F`,
  `carlet_cor2_F`, `zhou_pott_cor1_F`). Core already hosts `gold_apn`,
  `kasami_apn`, `taniguchi_apn`, `bcl_apn`, `bcp_apn`, `kim_apn`, `niho_apn`,
  `welch_apn`, `dobbertin_apn` — these two are the obvious missing siblings, and
  this paper is *about* their relationship.
- `is_cubic(α, n)` brute-forces what a one-line `gf_pow` / `gf_is_dth_power` test
  would do. Minor; left as is.
- `print_header` → `print_banner` — **done** (R11).
- Correctly paper-local: `taniguchi_thm4`, `carlet_cor2_normalize` /
  `carlet_cor2_chain_identity` (Corollary 2's proof-as-algorithm), the presemifield
  arithmetic (`presemi_mul`, `_circ`, `_norm`), `helleseth_kholosha_formula`.

## Open questions (need a decision before fixing)

1. **R1 replacement example.** The Γ-rank docstring needs a motivating example
   that is actually true. No verified OD-collision / Γ-rank-split pair is known
   in this repo — find one, or rewrite the sentence generically?
   *(The false sentence itself has been removed in core; the question is only what,
   if anything, should motivate Γ-rank in its place.)*
2. **R7 scope.** Is an odd-characteristic (`p=3, [F:K]=3`) instance in scope?
   VBF is characteristic-2 only, so Theorem 6 would need new field arithmetic.
   The skip note has been re-scoped to say exactly this; *implementing* it is the
   open call.
3. **Catalog.** Add the two `a≠0` Taniguchi records (plus optionally the `a=0`
   one) to `n8_apn.toml` as named/cited references into already-indexed CCZ
   classes — or leave them out, since they are not world-novel?
   *(No catalog change was made: `classify_ccz` returns `:known` for all three
   reps, so writing them to the TOML would name already-indexed CCZ classes, not
   assert a discovery.)*
