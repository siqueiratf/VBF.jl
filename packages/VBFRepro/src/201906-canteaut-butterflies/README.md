# Canteaut_201906 — If a Generalised Butterfly is APN then it Operates on 6 Bits

**Paper:** A. Canteaut, L. Perrin, S. Tian, *If a generalised butterfly is APN
then it operates on 6 bits*, Cryptogr. Commun. (2019).

**Reproduction:** `packages/VBFRepro/src/201906-canteaut-butterflies/` — `helpers.jl`, `definition1.jl`,
`equivalences.jl`, `lemma1.jl`, `proposition1.jl` … `proposition6.jl`,
`report.jl`.

**Verdict:** **Complete.** Every numbered result has a corresponding file, all
sweeps are exhaustive over the dimensions covered, and all **186 tests pass**
(87 before the R1–R10 fix pass). Both halves of Definition 1 are now built (the
closed butterfly `V_R` *and* the open butterfly `H_R`, the APN permutation the
paper is about); Lemma 1 is evaluated from its statement formula; Proposition
6's counting argument is reproduced step by step; and Theorem 1 is swept up to
`n = 15` via the refined trace condition (no LUT needed).

---

## Issue Catalog

### Paper Issues

**P1. Proposition 4's displayed formula has a spurious α.** *(already flagged by
the repro at `proposition4.jl:22-24`; independently confirmed)*

The tex (line 476) prints `e·α·(1+α)²`, while the paper's **own proof** (tex
lines 582/590) derives `e·(1+α)²`. Re-deriving `1 + V/U` by hand gives the
proof's version.

This is empirically decisive, not a matter of taste: the proof-form condition
selects exactly the 3 APN α at n=3 (α ∈ {2,4,6}); the literal statement-form
selects **0** — which would contradict the paper's own Theorem 1. The
reproduction correctly implements the proof form.

`lemma1.jl`'s implicit claim that `Q_α(β) = 0` makes `B` undefined is also true
(the raw denominator factors as `α^{2^{2i}} · Q_α(β)^{2^i}` — now verified
directly by `lemma1_B`, which evaluates the statement formula and throws on
`Q_α(β) = 0`).

**P2. Section 2.2's exponent bullet claims the wrong partner.** *(found while
resolving R6; documented, not "fixed")*

The tex (line 157) says: if the exponent is `e = (2^i+1)·2^t`, the closed
butterfly is affine-equivalent to the one with `e = 2^i+1` **"and the same
α, β"**. The α does *not* survive. The exact identity is

```
R^{(t)}_{α,β}(x, y) = R_{α^{2^t}, β}(x^{2^t}, y^{2^t})        (input Frobenius)
                    = (R_{α, β^{2^{-t}}}(x, y))^{2^t}          (output Frobenius)
```

so the partner is `(α^{2^t}, β)` — or, after applying bullet 2 (Frobenius)
`t` times, `(α, β^{2^{-t}})`. One of the two parameters is always twisted.

This is empirically decisive: DU is an affine invariant, and at `n=3, i=1`
**30 of the 147 `(t,α,β)` triples have `DU(V^{(t)}_{α,β}) ≠ DU(V_{α,β})`**
(`exponent_du_build`, asserted in `test_equivalences.jl`). The literal reading is
therefore false.

The paper's **conclusion is unaffected**: its statements are quantified over all
`α, β` and the family is closed under the twist, so "all results presented in the
paper also hold" for the twisted exponent remains true. `equivalences.jl`
implements the corrected identity in both forms.

### Reproduction Issues

**R1. [RESOLVED] The open butterfly `H_R` (Definition 1) is not implemented anywhere.**

*Fixed:* `helpers.jl:butterfly_open_lut` builds
`H_R(x,y) = (R_{R_y^{-1}(x)}(y), R_y^{-1}(x))` (inverting `R_y` with the core
`compositional_inverse`, which throws unless `R_y` is a permutation). New artifact
`definition1.jl` (`definition1_build` / `definition1_report`) sweeps all 49 `(α,β)`
at `n=3` (i∈{1,2}) and the `β=1` slice at `n=5`, asserting: `is_permutation` ✓,
involution ✓, `DU(H_R) == DU(V_R)` ✓, `algebraic_degree == n+1` ✓ and
`are_ccz_equivalent(H_R, V_R)` ✓ on all 6 APN pairs. Tests in
`test/test_definition1.jl` (26 tests), including `is_permutation(H) &&
!is_permutation(V)` for the paper's `V_{α=2,β=1}` — i.e. an APN *permutation* on
6 bits.

Two scoping notes:
- The degree claim `deg(H_R) = n+1` is the tex's claim for the **`β=1`
  subfamily with `α ≠ 0,1`** (Perrin et al.). For general `β` the degree drops to
  `n` on 13 of the 49 pairs at `n=3, i=1` — but never on an APN pair. The
  assertion is scoped to where the paper makes it (`deg_np1_count == 36 < 49` is
  asserted, so the scoping is itself locked in).
- `are_ccz_equivalent` is run **only on the APN pairs**. Those take the
  quadratic-APN fast path (~0.7 s each); on a non-APN 6-bit pair the general CCZ
  search exhausts memory here.

**R2. [RESOLVED] Theorem 1 is covered only for n ∈ {3,5}, and the stated reason is wrong.**

*Fixed:* the claim *"n=7 omitted (2^{14} LUT too large for fast test)"* was
false — by Proposition 5, APN-ness is equivalent to the refined trace condition,
a `2^n`-element check needing **no LUT**. New `theorem1_rtc_sweep` in
`proposition6.jl` sweeps every `n ∈ {3,5,7,9,11,13,15}` and every coprime `i`
(48 (n,i) pairs) in ~2 s: `rtc_count == 3` at `n=3` (the 6-bit APN case) and
`rtc_count == 0` everywhere above. The misleading comment is gone; the file
header now states the LUT-free route explicitly.

**R3. [RESOLVED] Proposition 6's counting argument is not reproduced at all.**

*Fixed:* `prop6_counting` in `proposition6.jl` reproduces the proof step by step
— `D = 1/(1+α²)`, `F_D`, `Im(F_D)`, `g_D(c)`, `T`, `i₁ = |T∩S₁|`, `i₃ = |T∩S₃|`,
Eq. (6), Eq. (7), Eq. (8), the lemma `|T| = |Im(F_D)\{0,1}|`, the four bounds,
and `prop6_contradiction(n)` for the closing arithmetic
`(2^{n−1}+5)/3 > 4 ⟺ n > 3`.

The reproduction is **discriminating**, which is the point:
- Eq. (6) and Eq. (7) are partition identities — true for *every* α.
- The lemma, Eq. (8) and `|Im(F_D)| ≤ 2^{n−1}` hold **exactly on the RTC α**:
  3 of 6 at `n=3`, 0 of 30 at `n=5`, 0 of 126 at `n=7`. The tests assert both
  that they hold on the 3 RTC α (`|Im|=3, |T|=2, i₁=1, i₃=1`, so Eq. (8) reads
  `4 == 1 + 3·1`) **and that they fail on the 3 non-RTC α**. A hardcoded
  "always true" implementation fails the suite.

**R4. [RESOLVED] Lemma 1 evaluates only the simplified form, not the statement formula.**

*Fixed:* `lemma1_B(n, i, α, β)` now returns all three forms along the proof chain
— the **statement** formula
`(α+α^{2^{i+1}−1})^{2^i−1} · (α^{2^{i+1}+1}+α^{2^{i+1}−1}+α^{2^i}β) /
(α^{2^{2i+1}+2^i}+α^{2^i}+α^{2^{2i}}β^{2^i})`, the middle form
`λ^{q−1}(λ+Q)/Q^q`, and the simplified `p^q + p^{q−1}` — and `lemma1_build`
asserts all three agree before taking the trace. **0 mismatches** over n=3 (43
pairs), n=5 (931), n=7 (16003). `lemma1_B` throws on `Q_α(β) = 0` (β = β₂, where
`B` is undefined). A concrete non-zero witness (`α=3, β=5` at n=3) is asserted so
the agreement is not a trivial `0 == 0`.

**R5. [RESOLVED] No parameter guards — meaningless results are returned silently.**

*Fixed:* `check_params(n, i)` in `helpers.jl` asserts `isodd(n)`, `0 < i < n` and
`gcd(i,n) == 1`, and is called by every builder (`butterfly_closed_lut`,
`butterfly_open_lut`, `tau_exp`, `beta_pair`, `refined_trace_cond`,
`equivalences_build`, `lemma1_build`, `proposition6_build`, `prop6_counting`).
`proposition6_build(4, 1)` and `proposition6_build(9, 3)` now throw
`AssertionError` instead of returning a meaningless `rtc_count=0` (asserted in
`test_proposition6.jl`).

**R6. [RESOLVED] Section 2.2's first equivalence bullet is not checked.**

*Fixed:* `exponent_equiv_check` and `butterfly_exponent_lut` in `equivalences.jl`
verify the exponent bullet pointwise, in both Frobenius forms, for every twist
`t ∈ {0,…,n−1}` and every `(α,β) ≠ 0` (147 cases at n=3, 4805 at n=5, all coprime
`i`); `exponent_du_build` confirms the DU consequence at the SBox level. **This
is where paper issue P2 was found** — the partner is `(α^{2^t}, β)`, not "the same
α, β"; see P2 above.

**R7. [RESOLVED] `report.jl` labels weakened items "exact".**

*Fixed:* R2–R4 are now closed, so the labels are earned rather than softened.
`report.jl`'s scope block was rewritten to say what is actually covered (Def 1
both halves; Sec 2.2 including the exponent twist and its P2 caveat; Lemma 1 from
the statement formula; Prop 6's counting argument; Thm 1 to n=15) and to point at
P1 and P2.

**R8. [RESOLVED] Representation-independence is real but never tested.**

*Fixed:* `test_definition1.jl`, `test_lemma1.jl`, `test_equivalences.jl` and
`test_proposition6.jl` each now run a case under the **non-default** modulus
`13` (`x³+x²+1`) instead of the default `11` (`x³+x+1`) for GF(8). All counts are
invariant (6 APN pairs, `rtc_count = 3`, `i₁ = i₃ = 1`, 43 Lemma-1 pairs, 36
degree-`n+1` open butterflies), and `test_proposition6.jl` additionally asserts
that the APN **α values really do permute** between the two representations — so
the test would catch a builder that silently ignored `modulus`.

**R9. [RESOLVED] Dead `clean_results` Makefile target.**

*Fixed:* the target is dropped (with its `help` line), and a `definition1` target
added. No `results/*.toml` is emitted: the paper is a negative result and its only
APN butterflies are the already-known 6-bit ones (see *Catalog status* below), so
there is nothing to record.

**R10. [RESOLVED] Dead branch.**

*Fixed:* `Ft_den == 0 && return true` deleted from `refined_trace_cond` —
unreachable, since `t == D` is excluded one line above. Replaced by a comment
saying so.

---

## Failure-pattern audit (explicitly checked)

| Pattern | Verdict |
|---|---|
| **Vacuous tests** | **ABSENT.** n=3 supplies genuine positive cases and the tests assert exact counts (`test_proposition4.jl` → `count(r.cond) == 3`, `sum(n_apn) == 6`; `test_proposition5.jl` → `count(r.apn) == 3`; `test_proposition6.jl` → `length(apn_pairs) == 6`). A hardcoded "always false" implementation would **fail** these. The new Prop 6 counting tests go further and assert the argument **breaks down on the 3 non-RTC α**, so a hardcoded "always true" fails too. |
| **False paper-issue claims** | **ABSENT.** Both claims made (P1, P2) are **true and empirically decisive** — each is settled by an invariant (APN count for P1, differential uniformity for P2), not by taste. |
| **Copy-paste stubs** | **ABSENT.** Each `propositionN.jl` computes a genuinely distinct quantity. |
| **Field-representation fragility** | **ABSENT and now tested** — four test files run a non-default modulus (13); see R8. |
| **Overclaiming README** | Addressed: R7 rewrote `report.jl`'s scope block, and the labels are now earned (R2–R4 closed). |

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| Def. 1, closed butterfly `V_R` | `helpers.jl:butterfly_closed_lut` — matches `R_y(x)=(x+αy)^{2^i+1}+βy^{2^i+1}` verbatim |
| Def. 1, open butterfly `H_R` | `helpers.jl:butterfly_open_lut` + `definition1.jl` — permutation, involution, `deg = n+1`, `DU(H_R)=DU(V_R)`, `H_R` CCZ≅ `V_R` on all 6 APN pairs |
| Sec. 2.2 bullet 1 (exponent `(2^i+1)·2^t`) | `equivalences.jl:exponent_equiv_check` — both Frobenius forms, all `t`, all `(α,β)`; the paper's "same α, β" is wrong (P2) |
| Sec. 2.2 bullets 2–3 (Frobenius; `β↔β′`; mirror `β₂`) | `equivalences.jl` — the `β′` identity re-derived by hand: `m·R_{β′}(L(x,y)) = R_β(x,y)` exactly |
| Prop. 1 (Helleseth–Kholosha) | exhaustive, n=3,5, all coprime `i` |
| Prop. 2 (all three cases) | exhaustive over all `(U,V,C)` |
| Lemma 1 (statement formula → simplified) | `lemma1.jl:lemma1_B` — all three forms of the proof chain agree, 0 mismatches over n=3,5,7 |
| Prop. 3 (APN ⟹ `β ∈ {β₁,β₂}`) + `α=1` exclusion | full β sweep; `min_du = 4` confirmed |
| Prop. 4 (iff, **both** directions) | non-vacuous: 3 α satisfy the condition at n=3, 6 APN pairs |
| Prop. 5 (refined trace condition ↔ APN) | exhaustive |
| Prop. 6 (counting argument) | `proposition6.jl:prop6_counting` — Eq. (6)–(8), `T`, `i₁`, `i₃`, the lemma, the bounds, the contradiction |
| Thm. 1 | by LUT n∈{3,5}; by refined trace condition n∈{3,…,15}, all coprime `i` |

`is_quadratic_apn` is a **sound** APN test here: `algebraic_degree(V) == 2` for
*every* `(α,β)` at n=3 and n=5, and `is_quadratic_apn == (differential_uniformity
== 2)` with **0 mismatches** over all 49 + 961 pairs.

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper; `make` bypassed (it shells
out to bare `julia`). **Nothing hit the OOM cap.**

| Command | Result |
|---|---|
| `test/runtests.jl` | **186/186 PASS** (definition1 27, equivalences 31, prop1 12, prop2 9, lemma1 18, prop3 11, prop4 13, prop5 9, prop6 56), 28 s |
| `report.jl` | **117 `[PASS]`, 0 `[FAIL]`**, 24 s |

Before the R1–R10 fix pass: 87/87, 2.9 s. The added time is dominated by the 18
`are_ccz_equivalent` calls on the APN open butterflies (R1) and the exhaustive
exponent-twist sweep at n=5 (R6).

**Do not call `are_ccz_equivalent` on a non-APN 6-bit butterfly here** — the APN
pairs take the quadratic-APN fast path (~0.7 s), but the general CCZ search on
those inputs exhausts memory (OOM at the 2 GiB cap).

## Catalog status

The paper is a **negative result** — it claims **no new APN functions** ("all APN
generalised butterflies were already known", Sec. 6). The only APN butterflies it
acknowledges are the 6-bit ones.

`V_{α=2, β=1}` (n=3, i=1): `differential_uniformity = 2`, `algebraic_degree = 2`
→ APN verified. Its `apn_ea_mugshot` matches **`n6_Kim`** (and not `n6_Gold_x3` /
`n6_Kasami_x48`), and `are_ccz_equivalent(V, load_apn_function("n6_Kim")) == true`.

**Status: present / not-new** — consistent with the paper's claim. **No catalog
gap, no TOML record to emit.**

## Library-reuse note

`helpers.jl` duplicates **no** VBF core export. It correctly delegates to
`gf_mul`, `gf_pow`, `gf_inv`, `gf_trace`, `primitive_polynomial`, `SBox`,
`is_permutation`, `compositional_inverse`, `print_banner/section/check/kv`, and
uses `is_quadratic_apn` / `differential_uniformity` / `algebraic_degree` /
`are_ccz_equivalent` from core.

**Promote-to-core candidates (still open — deliberately NOT done in this pass,
which is paper-local):**
- A generic **butterfly builder**. `packages/VBFRepro/src/202205-canteaut-ea-equivalence/section4_3.jl:70`
  defines its own hardcoded n=3, i=1 `open_butterfly`; this paper now has general
  `butterfly_closed_lut` / `butterfly_open_lut` (R1). A
  `butterfly_closed(n,i,α,β)` / `butterfly_open(n,i,α,β)` pair in
  `packages/VBF/src/constructions/` would serve both. Needs a core-API decision.
- `tau_exp(n,i) = invmod(2^i−1, 2^n−1)` — the recurring Helleseth–Kholosha τ.

## Open questions (resolved by the R1–R10 fix pass)

1. ~~**Is the omission of the open butterfly `H_R` deliberate**?~~ **Resolved: it
   was an oversight.** `H_R` is now built and tested (R1). CCZ-invariance would
   have *justified* omitting it, but the paper's title and motivation are about
   permutations, and `V_R` is not one — only `H_R` is. `is_permutation(H_R) &&
   !is_permutation(V_R)` is now asserted on the paper's own `V_{α=2,β=1}`.
2. ~~**Should Prop 6's counting argument be reproduced as its own artifact?**~~
   **Resolved: yes.** It is cheap and, crucially, *discriminating* — the lemma and
   Eq. (8) hold on exactly the RTC α and fail on the others, so reproducing the
   argument tests strictly more than the brute-force conclusion did (R3).
