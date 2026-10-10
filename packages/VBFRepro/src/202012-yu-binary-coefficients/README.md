# Yu_202012 — Classification of Quadratic APN Functions with Coefficients in F₂ for Dimensions up to 9

**Paper:** Y. Yu, N. Kaleyski, L. Budaghyan, Y. Li, *Classification of quadratic
APN functions with coefficients in F₂ for dimensions up to 9* (2020).

**Reproduction:** `packages/VBFRepro/src/202012-yu-binary-coefficients/` — `helpers.jl`, `theorem2.jl`,
`proposition1.jl`, `algorithm1.jl`, `table1.jl` … `table4.jl`, `report.jl`.

**Verdict:** partial, with explicit bounded scope (audit 2026-10-10).

`algorithm1.jl` now implements the printed odd-dimensional Algorithm 1:
GetNoneSquare selects one nonzero first-entry representative per Frobenius
orbit; TranFirRow propagates cyclic entries; GetElemC rejects the preceding
first-row span and non-proper rectangular submatrices (Definition 3). For a
full QAM every k-column restriction of a nonzero row combination has rank at
least k−1, so the proper-submatrix rejection is a necessary condition. Earlier
first-row entries must be independent, since every QAM row has rank n−1.
The source pseudocode explicitly assumes odd n = 2m−1; even dimensions retain
VBF's separately labelled odometer, rather than an undocumented extension.

Small complete controls compare **accepted matrices before bucketing**: at n=5,
pruned and unpruned traversals agree with the entire VBF odometer; expanding
Frobenius representatives under squaring recovers that full accepted set. The
n=7 run exhausted its declared Frobenius quotient with **265,957 attempted
prefixes, 208,208 completed-matrix tests, 31,315 span rejects and 24,340 proper
submatrix rejects**, recovering 14 invariant buckets matching Table 2. These are
coverage/invariant facts, not positive equivalence proofs or a complete 15-class
classification. The n=8/n=9 full regenerations remain unexecuted.

Budgets count attempted prefixes for odd n, completed candidates for the even
odometer. Unfinished search or EA confirmation returns BudgetHit; default
mugshot deduplication counts invariant buckets. `confirm=true` uses complete EA
decisions with explicit budgets and stops inconclusively on a comparison cap.
`algorithm1_search(...; prune=false,orbit_reduction=false)` exposes the control
traversal; `algorithm1_run` retains the SearchOutcome interface. Run/persist:

```sh
make -C packages/VBFRepro/src/202012-yu-binary-coefficients algorithm1 n_demo=7 timeout_seconds=60 save_results=true
```

A separate n=7 `confirm=true` run stopped with BudgetHit at an EA comparison
cap of 10 seconds, after 1,039 prefixes and 854 completed-matrix tests, with
nine confirmed class representatives. It does not establish the full region's
class count. The command exposes `equivalence_timeout_seconds` and
`max_equivalence_nodes` for further bounded attempts.

The saved report includes scope, counts and returned LUTs. Historical R8 below
records the former substituted implementation and is superseded by this note.

`table4.jl` verifies the eight explicit n=9 publication representatives are
quadratic APNs and almost bent. For s₁ and s₂ it compares exact ortho-derivative
invariant tuples with **all 12 quadratic APN entries in the current catalog
functions table**, and with all six admissible Gold indices
`k = 1, 2, 4, 5, 7, 8`. All these tuples differ. Matching invariant tuples for
the other representatives remain equivalence queries, rather than certificates.

[Yoshiara (2016), Theorem 2](https://link.springer.com/article/10.1007/s10801-016-0680-z)
states that, for n≥3, a quadratic APN is CCZ-equivalent to an APN power function
if and only if it is EA-equivalent to a Gold function. Complete Gold coverage
therefore proves that **s₁ and s₂ are CCZ-inequivalent to every APN power
function**, including power constructions outside the catalog. This covers the
six current nonquadratic n=9 reference functions: each is independently
identified as a literal power map by complete LUT equality to a VBF constructor.
Degree differences alone are never used to separate classes.

The result is separation from all **18 explicitly enumerated current catalog
APN entries**, plus the theorem's entire power-function scope. It does not
establish novelty with respect to unlisted non-power constructions, the entire
literature, or all n=9 APN classes. No n=9 bulk corpus is present. Incomplete
Gold coverage, invariant collisions and unavailable references remain
inconclusive. Gold references are replayed from their exact field parameters,
LUTs, hashes and invariant tuples before licensing an exclusion.

```sh
make -C packages/VBFRepro/src/202012-yu-binary-coefficients table4 save_results=true
```

This writes `results/table4_evidence.toml` with candidate/reference LUTs and
hashes, the catalog SHA-256, Gold parameters and exact invariants, theorem
hypotheses, per-target outcomes and source identities. It reads the catalog
directly and does not require or regenerate its signature index. The shared
consumer helper is `src/power.jl` under VBFSearch;
it uses VBF's field constructors and exact `sigma_key`, while VBFSearch's
independent APN/signature verifier remains specialized to n=8; graph-witness
replay now supports square dimensions 1:16. The older review
sections below are historical context and are superseded by these scoped
claims.

## Historical issue catalog

### Paper Issues

**P1. Table 2 has a duplicated row, and a class is lost with it.** — **[ADDRESSED
in our reproduction]** The paper's error stands (it is the authors'); `table2.jl` now
carries the erratum, lists **15** representatives including the recovered one, and
`test_algorithm1.jl` independently re-derives it from the exhaustive n=7 search.

Rows 4 and 10 of Table 2 are both `x³+x⁹+x¹⁸+x⁶⁶`. Confirmed in the **PDF**, so it
is an error in the published paper, not an OCR artifact. (`table2.jl:11-12`
already flags the duplicate — a **true** paper-issue claim, unlike two sibling
papers that fabricated errata.)

The consequence the reproduction missed: the paper's text says **15** CCZ classes,
its table lists only 14 distinct polynomials, and the duplicate is *why*. One class
is simply absent from Table 2. Recovered by exhaustive search (see R2):

> **x³ + x⁵ + x⁹ + x⁴⁰ + x⁹⁶** (n=7; DU=2, deg=2, AB)

The corrected n=7 breakdown is 3 power functions + 2 trinomials + 5 quadrinomials
+ **4** pentanomials + 1 hexanomial. The paper's prose ("six quadrinomials, three
pentanomials") is derived from its own corrupted table.

### Reproduction Issues

**R1. [RESOLVED]** Theorem 2 is reproduced in the wrong basis, and its check is a
tautology. **← was most serious**

> **Fix (honest option taken; a normal-basis QAM in core stays out of scope).**
> `helpers.jl` — the false docstring on `has_f2_cyclic_structure` is rewritten to say
> it is the Theorem-2 criterion *only in a normal basis*, and is **not** a test for
> "F has F₂ coefficients" on a bit-basis matrix. New `has_f2_coefficients(F)` (the
> `F(x²)=F(x)²` test) provides the property the paper actually means.
> `theorem2.jl` is rewritten to state plainly that it checks a **constructor
> invariant, not Theorem 2's iff**, and now *asserts the gap* instead of hiding it:
> `has_f2_cyclic_structure(quadratic_apn_matrix(x³), n)` is **false** for n=6..9
> though `x³` **does** have F₂ coefficients; and `search_qam(n,1)` outputs do **not**
> have F₂ coefficients yet **are** in the EA-class of x³ — so the classification is
> faithful **up to EA**, which is exactly what the rest of the paper needs. The
> tautological round-trip assert in `test_algorithm1.jl:10-11` is **removed** (with a
> comment recording why it could not fail).

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/helpers.jl:22-27` (`has_f2_cyclic_structure`),
  `packages/VBFRepro/src/202012-yu-binary-coefficients/theorem2.jl`, `packages/VBFRepro/src/202012-yu-binary-coefficients/test/test_algorithm1.jl:10-11`
- **Symptom:** Theorem 2 requires a **normal basis** (`α_{i+1} = α_i²`); the paper
  builds `H = Mα^t C_F Mα`. But VBF's `quadratic_apn_matrix`
  (`packages/VBF/src/constructions/qam.jl:30`) uses the **bit basis**
  `bᵢ = 2^{i-1}` — the polynomial basis of `primitive_polynomial(n)`. Verified
  consequences:
  - `has_f2_cyclic_structure(quadratic_apn_matrix(x³), n)` is **`false`** for
    n = 6,7,8,9 — even though `x³` has F₂ coefficients. The docstring
    ("True iff the QAM corresponds to a function with F₂ coefficients") is **false
    as implemented**.
  - Conversely, the functions returned by `search_qam(n,1)` do **not** have F₂
    coefficients (`F(x²) == F(x)²` is `false` on the n=4 and n=6 outputs).
  - So `theorem2.jl`'s check #1 is **true by construction** — `qam_from_cyclic`
    applies Frobenius along each orbit, and the code comment admits it ("This holds
    by construction"). `test_algorithm1.jl:10-11` re-derives a matrix from a
    function that `qam_to_sbox` built from that very matrix — a round-trip identity.
    **The "iff" of Theorem 2 is never tested.**
- **Root cause:** field-representation fragility — the paper pins a normal basis,
  the repo silently uses the bit basis of `primitive_polynomial(n)`.
- **Mitigating fact (state precisely, do not hand-wave):** the matrix set is
  basis-independent, and the bit-basis reading of a cyclic QAM yields `F ∘ L` (plus
  a linear map) for the paper's `F`. So the **EA/CCZ classes found by `search_qam`
  are still the right ones** — the classification is faithful *up to EA*. What is
  false is the claim that these are *the F₂-coefficient functions*.
- **Resolution plan:** Either add a normal-basis QAM pair to core (see
  Library-reuse) and make Theorem 2 testable in both directions, or rewrite
  `theorem2.jl` to say honestly that it checks a constructor invariant, and fix the
  `has_f2_cyclic_structure` docstring. **Needs a decision — see Open Questions.**

**R2. [RESOLVED]** Table 2 concludes "14 classes" where the truth is "a class is
missing".

> **Fix.** `table2.jl` now lists **15** representatives — the paper's 14 printed
> distinct rows plus the recovered **x³+x⁵+x⁹+x⁴⁰+x⁹⁶** — and asserts all 15 are APN,
> quadratic and AB; that they fall into exactly **14 σ-classes**; that the sole
> σ-collision is the Gold pair {x³, x⁹}; and that the recovered row is σ-**distinct**
> from all 14 printed rows. The Gold collision is then **settled with the complete EA
> decision** (`ea_mappings_from_ortho_derivative(x³, x⁹)` is *empty*, and EA = CCZ for
> quadratic APN — Yoshiara), giving **14 + 1 = 15 CCZ classes**, the paper's count.
> Independently corroborated in `test_algorithm1.jl`: the exhaustive `search_qam(7,1)`
> sweep's σ-set **equals** the σ-set of the 15 representatives.

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/table2.jl:11-12`
- **Symptom:** Having spotted the duplicate (P1), the file concludes there are 14
  classes and verifies 14 rows. The paper says 15, and the paper is right.
- **Root cause:** The duplicate hid a *missing row*, not a miscount.
- **Resolution plan:** Add the recovered representative
  **x³ + x⁵ + x⁹ + x⁴⁰ + x⁹⁶** and assert all 15 are APN and pairwise σ-distinct
  (modulo the Gold collision of R3). Evidence — exhaustive enumeration of all
  2²¹ = 2,097,152 homogeneous quadratics with F₂ coefficients over GF(2⁷), each
  tested with `is_qam`: **30,870 are APN**, falling into **14 σ-classes**; the σ-class
  of `x³` holds 4,116 polynomials (2 × 2058) while every other holds exactly 2058
  — because it contains **two** CCZ classes (`x³` and `x⁹`, see R3). 14 σ-classes +
  1 hidden = **15 CCZ classes**, exactly the paper's count. 13 of the 14 σ-classes
  appear in Table 2; one appears in no row.

**R3. [PARTLY RESOLVED — paper-side done; core-side is C1/C2, not ours]** σ, mugshot,
Γ-rank and Δ-rank all fail to separate two Gold classes.

> **Paper-side fix.** The n=7 Gold collision is no longer merely *documented* — it is
> **settled**: `table2.jl` runs the **complete EA decision**
> (`ea_mappings_from_ortho_derivative(x³, x⁹)` ⇒ **empty**, ~1.6 s), which *proves*
> x³ ≢ₐₐ₂ x⁹ since EA = CCZ for quadratic APN. So "no repo invariant separates them"
> is now **false** — the complete decision does; it is just not an *invariant*. This
> is what recovers the 15th class. A sanity guard asserts the same procedure *does*
> find mappings for x³ ~EA x³, so the empty result is not vacuous.
> The `search_qam` lower-bound caveat is now documented at n=7 as well as n=5
> (`algorithm1.jl`). **`classify_ccz`'s unsound `:known` is core-side (C1) and was
> fixed by the main thread — its match verdict is now `:sigma_match`. Every check in
> this paper is written in terms of σ-MISMATCH; none treats a σ-match as proof.**

- **Location:** `packages/VBFCatalog/src/data/sigma.jl` (`classify_ccz`), consumed
  throughout this paper
- **Symptom:** `σ(x³) == σ(x⁹)` over GF(2⁷) and `σ(x³) == σ(x⁵)` over GF(2⁵), for
  functions that are **CCZ-inequivalent**. The finer invariants do not help either:
  **Γ-rank 3610 = 3610 and Δ-rank 198 = 198** for x³ vs x⁹ (n=7); Γ-rank 330 = 330,
  Δ-rank 42 = 42 for x³ vs x⁵ (n=5). **No repo invariant separates them.**
  Consequently `classify_ccz(x⁹, n=7)` returns `(:known, "functions", 32)` — and
  row 32 is `n7_Gold_x3`, a **CCZ-inequivalent** function.
- **Root cause:** σ-**mismatch** is a rigorous CCZ-inequivalence certificate; σ-**match**
  proves nothing. `classify_ccz`'s `:known` uses the unsound direction.
- **Impact here:** the s₁/s₂ novelty argument is **not** damaged — it rests only on
  σ-mismatch. But `search_qam`'s mugshot de-duplication **merges CCZ classes**, so
  any class count it reports is a **lower bound**. `table1.jl:22-27` documents this
  honestly for n=5; the same effect at n=7 is undocumented.
- **Resolution plan:** Paper-side, document the n=7 case as `table1.jl` does for
  n=5. **Core-side this is a library bug — see "Core issues" below. Not fixed here.**

**R4. The "σ collision" reported by an earlier review was an artifact of a lossy
`show`.**

- **Location:** `packages/VBF/src/invariants/mugshot.jl` (`APNEAMugshot`'s `show`)
- **Symptom:** `string(APNEAMugshot)` prints `APNEAMugshot{kind=quadratic, 2
  components}` — dropping the actual spectra. So `sha256(string(apn_ea_mugshot(F)))`
  is **identical for every quadratic APN function**, and any probe that hashes the
  `show` output sees a universal collision.
- **Root cause:** `Base.==` / `hash` on `APNEAMugshot` are field-based and correct,
  and `table4.jl` uses those — so **the repo code is not affected**. Only ad-hoc
  probes are. It has now misled at least one review agent.
- **Resolution plan:** Core-side; see "Core issues".

**R5. [RESOLVED]** Table 3: the paper's headline n=8 claims are printed as if
verified, but never computed.

> **Fix.** The `note`-string-as-result is gone. `table3.jl` now **computes** the
> claims and labels each by what it is worth: the **headline** claim — the two
> near-identical trinomials are in **distinct** CCZ classes — is **PROVEN** by
> σ-mismatch (the rigorous direction), and corroborated by the complete EA decision
> (no mapping, instant). Cross-pairings are **rigorously excluded** by σ-mismatch.
> The two *positive* Edel–Pott equivalences cannot be established by a σ-**match**
> (which proves nothing), so they are reported as σ-candidates in the fast path and
> **proven** by the complete EA decision behind `full_ea` / `make table3_full`
> (~265 s per pair; 6144 mappings each). All 7 rows sit in 7 distinct σ-classes ⟹ 7
> rigorously CCZ-inequivalent classes.

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/table3.jl:9` (comment), `:38` (`note` string),
  and `table3_report`
- **Symptom:** `table3.jl` only tests `differential_uniformity == 2`. The paper's
  actual claims — `x³+x⁶+x⁷² ~CCZ~ x³+Tr(x⁹)`, `x³+x⁶+x¹⁴⁴ ~CCZ~ x⁹+Tr(x³)`, and
  *"despite their nearly identical structure, they belong to distinct
  CCZ-equivalence classes"* — live only in a comment and a `note` that the report
  **prints as a result** ("note: All 7 are CCZ-equivalent to known Edel-Pott (2009)
  representatives").
- **Root cause:** Overclaiming report line.
- **Resolution plan:** Compute them. All three hold (verified during review):
  `σ(x³+x⁶+x⁷²) == σ(x³+Tr(x⁹))`; `σ(x³+x⁶+x¹⁴⁴) == σ(x⁹+Tr(x³))`; cross-pairings
  differ; `classify_ccz` maps each pair to the same catalog row (`functions` 586 and
  585 = `SimonBerg_GF4_n8_class_5` / `_class_4`); and the two trinomials have
  **different** σ, so they are rigorously CCZ-inequivalent. All 7 Table-3 rows sit
  in 7 distinct σ-classes, all `:known` against the n=8 bulk corpora.

**R6. [RESOLVED]** Table 4: novelty checked against 3 functions out of the n=9
universe.

> **Fix.** `table4.jl` now compares s₁/s₂ by **σ-mismatch against every quadratic n=9
> catalog entry** (5 of them), not just x³/x⁵/x¹⁷, and asserts both limits explicitly
> rather than leaving them in prose: **(a)** `sigma_hash` **throws** on the 4
> non-quadratic n=9 entries — asserted, so the limit cannot be silently forgotten —
> and CCZ does *not* preserve degree, so "s₁/s₂ are quadratic and those are not" is
> **not** an argument; **(b)** **f₇ — which the paper treats as KNOWN — also reads
> `:new`**, which *proves* the n=9 catalog is missing known families, so `:new` here
> means "absent from our catalog", **not** world-novelty. A non-vacuity guard asserts
> f₅/f₆ *are* found (`:sigma_match`), so the `:new` verdicts are not an artefact of a
> broken index. `report.jl`'s "Exact" label is **downgraded** to an explicit
> Proven / Partial / NOT-done breakdown.

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/table4.jl:28,45-52`; `packages/VBFRepro/src/202012-yu-binary-coefficients/report.jl:32`
- **Symptom:** s₁/s₂ mugshots are compared against **only** x³, x⁵, x¹⁷. The paper
  claims CCZ-inequivalence to *any currently known APN function over F₂⁹*. The
  `note` at `table4.jl:63` is honest about the gap, but `report.jl:32` advertises
  "Exact: … EA-mugshot s₁,s₂", which reads as if the novelty claim were reproduced.
- **Resolution plan:** Compare s₁/s₂ against **all** quadratic n=9 catalog entries
  by σ, and state explicitly that (a) σ cannot reach the 4 **non-quadratic** entries
  (CCZ does not preserve algebraic degree), and (b) the catalog is missing known
  n=9 families — f₇ proves it (see Catalog status). Downgrade the report's "Exact"
  label.

**R7. [RESOLVED]** The AB property is never checked, though the abstract claims s₁
and s₂ "are also AB".

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/` (nowhere)
- **Fix:** `helpers.jl` gains `is_almost_bent(F)` (`linearity(F) == 2^((n+1)÷2)`,
  guarded to odd `n`). Asserted for **every** row of Table 2 (n=7, all 15 incl. the
  recovered one) and Table 4 (n=9, all 8 incl. s₁ and s₂), and for every class the
  exhaustive n=7 search returns. All hold.

**R8. [RESOLVED — substitution stated, not implemented]** Algorithm 1 is a one-line
wrapper; none of the paper's pseudocode exists.

> **Fix (the "state it plainly" branch of the plan — the paper's pruned search is
> *not* implemented).** `algorithm1.jl` now opens with a **SUBSTITUTION NOTICE** and a
> side-by-side table of what the paper does (`GetNoneSquare` orbit reduction,
> `TranFirRow` recursion, `GetElemC` span/proper-submatrix pruning) versus what we run
> (an unpruned odometer sweep over `qam_cyclic_orbits`, with the exact `is_cyclic_qam`
> oracle). It records that the **missing pruning is precisely why n=8 (2.7×10⁸) and
> n=9 (6.9×10¹⁰) are out of reach**, so the classification is reproduced only for
> n ≤ 7. It also states that because `search_qam` de-duplicates by `apn_ea_mugshot`,
> which **merges CCZ-inequivalent functions**, its class counts are **LOWER BOUNDS** —
> concretely 14 at n=7 where the truth is 15.

- **Location:** `packages/VBFRepro/src/202012-yu-binary-coefficients/algorithm1.jl`
- **Symptom:** It wraps `search_qam(n,1)`. The paper's `GetNoneSquare`, `TranFirRow`
  recursion, `GetElemC`'s span-size pruning (`#S < 2^{2j−4}`) and proper-submatrix
  pruning are all absent. `search_qam` is an odometer sweep with an exact
  `is_cyclic_qam` oracle — result-equivalent at tiny n, but not the paper's
  algorithm, and it is *why* n=8 (2.7 × 10⁸ candidates) and n=9 (6.9 × 10¹⁰) are out
  of reach.
- **Resolution plan:** Either implement the paper's pruned search, or state plainly
  that a different algorithm is substituted. **Needs a decision.**

**R9. [RESOLVED]** Debug junk, a discarded exhaustive search, and a tautological
assert.

- `algorithm1.jl:48-49` — the `print(result); print(typeof(result));` debug leak is
  **deleted**. The report is now clean (154 `[PASS]`, 0 `[FAIL]`, no stray output).
- `test/test_algorithm1.jl` — the discarded n=7 exhaustive search is now **asserted**,
  and is the paper's classification test: it checks the sweep returns **14** EA-classes
  (a lower bound — the mugshot key merges the Gold pair), that all are APN + quadratic
  + **AB**, and — the real content — that the **σ-set of the found classes equals the
  σ-set of the 15 Table-2 representatives**. A **mutation guard** asserts the same
  comparison *fails* if the recovered row is dropped (13 ≠ 14 σ-classes), so it cannot
  pass vacuously.
- `test/test_table2.jl:8` — the self-referential `n_verified == 14` is **replaced** by
  assertions about the mathematics (15 reps, 14 σ-classes, Gold split settled, 15 CCZ
  classes; recovered row APN + AB + σ-distinct from all printed rows).
- `Makefile` — dead `clean_results` target **dropped**; `theorem1`, `example1` and
  `table3_full` targets added.

**R10. [RESOLVED — the cheap items; two remain out of scope]**

- **Theorem 1** — **added** (`theorem1.jl`, `test/test_theorem1.jl`). Implemented as
  `theorem1_delta(F) = 2^(n − qam_min_row_rank(H))` and checked against a directly
  computed `differential_uniformity` on a **seeded** sample of 160 homogeneous
  quadratics over n=4..7. **Non-vacuity is enforced by the test itself:** the sample
  must contain APN *and* non-APN functions and span ≥ 4 distinct δ values (it spans
  δ = 2,4,8,16,32,64,128 — only 29/160 are APN), so the sweep cannot degenerate into
  "everything is APN". The corollary "F is APN ⟺ H is a QAM" is checked too.
  *(Note: Theorem 1, unlike Theorem 2, holds in **any** basis, so the bit basis is
  fine here — this is why it was testable and Theorem 2 was not.)*
- **Example 1** — **added** (`example1.jl`, `test/test_example1.jl`).
  `qam_cyclic_orbits(6,1)` gives orbits **[6,6,3]** (the paper's a, b, c); the length-3
  orbit forces **c = c^{2³} ⟺ c ∈ GF(2³)** (8 values), so the search space is
  64·64·8 = **2¹⁵**. The iff is verified **exhaustively over all 2¹⁸ triples** (0
  violations; both sides non-empty — 32,768 in-subfield vs 229,376 out), and the test
  pins both directions on explicit values, so the constraint is not vacuous.
- **Definition 3 (proper matrix)** — subsumed: Definition 4's QAM rank condition *is*
  the `is_qam` oracle, exercised throughout; the standalone "proper" predicate is only
  used by the paper's pruning, which we do not implement (R8).
- **Still out of scope:** the classification for **n=8/9** (blocked by R8 — a *time*
  limit, needs the paper's pruned search), and the Section-3.2 "≤ n terms / shortest
  representative" observation (an open problem in the paper, not a claim to verify).

---

## Core issues surfaced by this review

*(Not paper-local. These belong in `packages/`, as their own commits.)*

**C1. `classify_ccz`'s `:known` is a σ-match, not a proof.** `classify_ccz(x⁹, n=7)`
returns `(:known, "functions", 32)` = `n7_Gold_x3`, a CCZ-**inequivalent** function.
σ-mismatch is sound; σ-match is not. Callers that read `:known` as "already in the
catalog" will silently swallow genuinely new classes. Rename to `:sigma_match`, or
confirm with a real EA decision before claiming equivalence.

**C2. The committed σ-index merges CCZ-inequivalent classes.** Because it is keyed
on σ, `equivalence_classes` row 227 merges `n5_Gold_x3` + `n5_Gold_x5` and row 423
merges `n7_Gold_x3` + `n7_Gold_x9` — both pairs CCZ-inequivalent. (The n=6 and n=8
multi-member rows are legitimate: same class rediscovered across corpora.)

**C3. `APNEAMugshot`'s `show` is lossy** — `string(...)` renders every quadratic APN
identically, so hashing it collides universally. Field-based `==`/`hash` are correct;
only the printed form lies. It has already misled one review.

**C4. `search_qam` de-duplicates by `apn_ea_mugshot`**, which merges CCZ-inequivalent
functions (x³/x⁹ at n=7, x³/x⁵ at n=5). Every class count it reports is a lower
bound.

---

## Failure-pattern audit (explicitly checked)

| Pattern | Verdict |
|---|---|
| **Vacuous `print_check`** | **ABSENT** — uses VBF's exported `print_check`, no local shadow that throws. |
| **Copy-paste stubs** | **ABSENT** — each table file is genuinely distinct. |
| **Fabricated errata** | **ABSENT** — the one paper-issue claim (`table2.jl`) is **true**, confirmed in the PDF. |
| **Tautological asserts** | **FIXED** — both removed (R9's `test_table2.jl:8`, R1's Theorem-2 round-trip); new assertions are mutation-tested (below). |
| **Field-representation fragility** | **FIXED (documented, not hidden)** — R1: the normal-vs-bit basis gap is now *asserted* as a failing property, not silently passed. |
| **Overclaiming report** | **FIXED** — R5, R6: `note` strings no longer printed as results; `report.jl` states Proven / Partial / NOT-done. |

## Test results (as run)

All Julia through the 2 GiB wrapper, one process at a time. **No OOM; nothing
skipped for memory.**

| Command | Result |
|---|---|
| `test/runtests.jl` | **PASS 196/196** — theorem1 21, theorem2 15, example1 11, proposition1 8, algorithm1 13, table1 6, table2 63, table3 25, table4 34 — 38 s *(was 55/55)* |
| `report.jl` | **154 `[PASS]`, 0 `[FAIL]`**, no stray debug output (R9's leak deleted) |
| exhaustive n=7 F₂-coefficient enumeration (2²¹ candidates) | 30,870 APN → 14 σ-classes → **15 CCZ classes**; one absent from Table 2 |
| exhaustive n=7 `search_qam(7,1)` sweep (now **asserted** in the suite) | 14 EA-classes, σ-set **equals** that of the 15 Table-2 reps (16 s) |
| complete EA decision, n=7 `x³` vs `x⁹` | **empty ⇒ CCZ-inequivalent** (1.6 s) — settles the Gold split, recovering class 15 |
| complete EA decision, n=8 Edel–Pott pairs (`make table3_full`) | **6144 mappings each ⇒ both equivalences proven** (~265 s/pair) |

### Non-vacuity: new assertions were mutation-tested

Every headline assertion was checked to **fail** under a deliberate corruption (run on
a throwaway copy; the working tree was never mutated):

| Mutation | Detected? |
|---|---|
| Recovered 15th rep corrupted (`x⁴⁰ → x³⁶`) | **yes** — `algorithm1_test` |
| Recovered 15th rep replaced by a **duplicate of an existing class** (still APN, deg 2, AB — so every per-row check still passes) | **yes** — cleanly: `n_sigma_classes 13 == 14`, `n_ccz_classes 14 == 15` |
| `theorem1_delta` off-by-one (`n−rank` → `n−rank+1`) | **yes** — `4 == 2` |
| Table 3's two Edel–Pott references **swapped** | **yes** — 4 failures (both σ-match claims + both cross-exclusions) |
| s₁ replaced by `x³` (a **known** catalog function) | **yes** — 2 failures (σ-mismatch-vs-all, and `:new`) |
| f₅ corrupted so it is **not** in the catalog | **yes** — the non-vacuity guard fires |

**Not attempted, recorded rather than assumed:** Γ/Δ-rank at n=8,9 — blocked by
`_design_rank_guard` (n ≤ 7) and, at n=9, a ~8.6 GB matrix (far over the 2 GiB cap).
Exhaustive n=8 (2.7 × 10⁸) and n=9 (6.9 × 10¹⁰) QAM searches — a *time* limit, not
memory (and see R8: the pruning that would make them feasible is not implemented).

## Catalog status

| Function | Verdict |
|---|---|
| **s₁** = x¹³⁶+x¹³²+x⁹⁶+x⁸⁰+x³⁶+x³⁴+x¹⁸+x¹⁷+x¹² (n=9) | **missing — catalog gap.** APN (DU=2, deg 2, AB). σ = `ed9af5a8…` matches no `n9_apn.toml` entry; `classify_ccz` ⇒ `:new`. |
| **s₂** = x²⁸⁸+x²⁷²+x²⁶⁴+x¹⁶⁰+x¹⁴⁴+x¹³⁰+x⁴⁸+x³⁴ (n=9) | **missing — catalog gap.** σ = `e64887b6…`, no match, `:new`. σ(s₁) ≠ σ(s₂). |
| f₇ = x²⁶⁴+x¹⁶⁰+x¹⁴⁴+x¹³²+x⁸⁰+x⁷²+x⁶⁶+x⁴⁰+x¹⁷ (n=9, **not** claimed new) | `classify_ccz` ⇒ `:new` — **proof that the n=9 catalog is incomplete** |
| f₅, f₆ | **present** (σ-match `n9_Budaghyan2009_eq7` / `_eq8`) |
| n=8 trinomials x³+x⁶+x⁷², x³+x⁶+x¹⁴⁴ | **not-new**, as the paper says — new *representatives*, not new classes (σ-match `SimonBerg_GF4_n8_class_5` / `_class_4`) |

**Do not upgrade this verdict to world-novelty.** The n=9 catalog holds only 9
entries, 5 of them quadratic, and there are **no n=9 bulk corpora** in
`packages/VBFCatalog/corpora/` (all are n=8). f₇ — which the paper treats as *known*
— also comes back `:new`, which proves known n=9 families are simply absent. σ also
cannot compare s₁/s₂ against the 4 non-quadratic n=9 entries (CCZ does not preserve
degree), and Γ/Δ-rank at n=9 is out of reach.

Levels for s₁/s₂: formula reproduced ✔; APN verified ✔ (also AB, deg 2,
non-permutations); family validation n/a (sporadic); **novelty partially checked** —
rigorously CCZ-inequivalent to the 5 quadratic n=9 catalog entries via σ-mismatch,
but not to the non-quadratic entries nor to the known families the catalog lacks;
full claim reproduced ✘.

### Unresolved catalog proposals

The former write-ready s1/s2/f7 gap records are removed. The explicit formulas
remain in Table4, but catalog absence and signature mismatch against a partial
quadratic reference set do not establish novelty throughout the literature.
Any future catalog update must first verify source provenance, APN properties,
and equivalence against the relevant known constructions and references. No
new catalog classes were added in this audit.

## Library-reuse note

`helpers.jl` defines six functions and **none duplicates a core export**:
`sbox_from_exponents` (thin glue over `primitive_polynomial` + `terms_to_lut` +
`SBox`), `sbox_from_exponents_with_trace` (**new** — needed for the Edel–Pott n=8
reference forms of R5), `has_f2_cyclic_structure` (paper-specific; **docstring now
corrected**, R1), `has_f2_coefficients` (**new**, R1), `is_almost_bent` (**new**, R7)
and `qam_min_row_rank` (**new**, R10 / Theorem 1). Minor, unchanged:
`frobenius_squared_qam` (`proposition1.jl:23`) reimplements the elementwise Frobenius
VBF already has privately as `_frobenius` (`qam_search.jl:31`).

**Promote-to-core candidates** (core genuinely lacks these; all three are now
implemented paper-locally, so promotion is a de-duplication, not new work):
1. A **normal-basis** QAM pair — `quadratic_apn_matrix_normal(F)` /
   `qam_to_sbox_normal(M)`. Without it Theorem 2 cannot even be *stated* in this
   repo, let alone tested. Root cause of R1, and **still the one real gap.**
2. `is_almost_bent(F)` — every paper open-codes `linearity(F) == 2^((n+1)÷2)`.
3. `has_f2_coefficients(F)` — the `F(x²) == F(x)²` test; three lines, and it is
   precisely the property this paper is about.

## Open questions

*(1 and 2 were resolved by taking the honest branch — recorded here so the decision is
not silently re-litigated. 3 and 4 still need a human.)*

1. **R1 / Theorem 2 — DECIDED: reframed, not re-based.** `theorem2.jl` no longer
   claims Theorem 2; it checks a constructor invariant and *asserts the basis gap*.
   A normal-basis QAM pair in core (`quadratic_apn_matrix_normal` /
   `qam_to_sbox_normal`) would make Theorem 2 testable in both directions and remains
   the **promote-to-core candidate #1** — but it is a `packages/VBF` change and was
   out of scope for this paper-local pass.
2. **R8 / Algorithm 1 — DECIDED: substitution declared, not implemented.** The paper's
   pruned search is *not* written; `algorithm1.jl` says so prominently, and says that
   this is why n=8/9 are unreachable. Implementing it is the only route to claiming the
   n=8/n=9 classification.
3. **The missing n=7 class** (present in the built DB as `reprs7_3`, unnamed): add it
   to `n7_apn.toml` with the recovered shortest form `x³+x⁵+x⁹+x⁴⁰+x⁹⁶`? **Needs a
   human — this is a catalog write, deliberately not done here.** The erratum itself is
   now recorded in `table2.jl`.
4. **The n=9 catalog gap (s₁, s₂, and f₇).** The records below stay *records*: writing
   them into `n9_apn.toml` is a catalog change, out of scope for this pass. Note f₇ is
   the more urgent of the three — it is a **known** function that the catalog lacks, so
   its absence actively weakens every n=9 novelty verdict.
