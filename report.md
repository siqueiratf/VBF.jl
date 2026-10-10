# APN reproduction audit — what to run next

Audited 2026-08-17 against the working tree (HEAD `bf15e59` plus uncommitted changes),
Julia 1.12.6, AMD Ryzen 5 5600G / 12 threads / 30.7 GB.
Backing data: [`audit/readme_index.yaml`](audit/readme_index.yaml),
[`audit/findings.yaml`](audit/findings.yaml),
[`audit/missing_sources.yaml`](audit/missing_sources.yaml),
[`packages/VBF/perf/historical/calibration.toml`](packages/VBF/perf/historical/calibration.toml).

## Summary

42 paper READMEs scanned; all 42 have paper text, a paper-local implementation and a test
directory on disk. **36 findings.**

- **Kind** — wrong_value 8, internal_inconsistency 8, unsound_negative 5, tool_limit 3,
  hard_limit 2, sampling_not_exhaustion 2, scope_restriction 2, wrong_condition 2, inferred 2,
  theory_limit 1, unproved_premise 1.
- **Tier** — recomputed 13, code_confirmed 12, readme_only 11. **Severity** — high 18, medium 17, low 1.

Top three leads (ranking key and full table below):

1. **F003** — Kuznetsov 2026's four "new" n=8 classes all return `is_novel = false`, and an in-repo
   document still instructs a catalog write of all four under a false `bib_key`. ~0.05 core h.
2. **F002** — Ichanska 2024's one claimed-new n=8 function is EA-equivalent to a 2013 function,
   proved here by the exact decision with working controls in 11.4 s. Lock it in.
3. **F001** — `n8_Taniguchi2025_ex4_2` is a 2009 class; the EA witness re-verifies at 0/256
   mismatches. The catalog's attribution is wrong today. ~0.11 core h.

**Largest threat to this report's validity:** 11 of 36 findings never left `readme_only`, and six
of the papers behind them took their numbers from Python/C because their reviewer had no Julia —
false on this machine. If those are wrong, a third of the findings are, and eight queued
catalog-gap LUTs are unsafe. Clearing it costs ~0.1 core hours (**F060**).

---

## Critical findings

Substantive errors and inconsistencies, ordered by severity. "Depends on it?" answers whether
anything in this codebase currently computes or asserts the wrong version.

### High severity

| # | Paper | Locator | What is wrong | What it changes downstream | Tier | Depends on it? |
|---|---|---|---|---|---|---|
| **F003** | Kuznetsov_202606 | §I-A, §VI-I, §VIII, Thm 6 | The four claimed-new CCZ classes all σ-match already-indexed functions; `is_novel` is false for all six representatives. Theorem 6's individual inequivalences hold, but its *premise* — that the 12,921-function file is the pre-2020 database — is false. | Claimed new classes 4 → 0. | recomputed | **Yes, dangerously.** `REVIEW_Kuznetsov_202606.md` still carries four catalog-gap records instructing a write of all four into `n8_apn.toml` under `bib_key = "Kuznetsov_202606"`. `FINDINGS.md`, in the same directory, says the opposite. |
| **F002** | Ichanska_202400 | Table 5 / Table 10 #10 | The single claimed-new (8,2) APN function is EA-equivalent — hence CCZ-equivalent, both quadratic — to member #9 of the tracked 2013 Weng–Tan–Gong corpus, eleven years earlier and absent from the paper's reference list. | Claimed new classes 1 → 0. | recomputed | No. The README already withdrew its own gap record; nothing asserts novelty. But no test pins the refutation, so it can silently return. |
| **F001** | Taniguchi_202501 (also Budaghyan_200910, Budaghyan_202101) | Example 4.2, catalogued at `n8_apn.toml:56` | `n8_Taniguchi2025_ex4_2` is EA-equivalent to Budaghyan–Carlet–Leander 2009 eq. (6) with `a = α`. A third reproduction independently reports identical extended-Walsh, ortho-derivative differential and Walsh spectra, and `\|S(F)\| = 86`, for Edel–Pott function 1.3. | A three-way provenance collision; the catalog credits 2025 for a 2009 class. | recomputed | **Yes.** The catalog entry is live and carries no prior-art note. |
| **F010** | Kuznetsov_202606 | §IV-E, Table I, §V-A, §VII-C | The paper claims the 24 intra-slice coordinates are free on `V_A`, giving 2¹⁶ = 65536 hyperplanes of dimension 24. Those 24 columns have **full rank 24**, so the projection is injective: 2⁴⁰ ≈ 1.10 × 10¹² slices, free split 32 + 8 not 16 + 24. | Table I's "coverage of `V_A` = 0.65 %" should be ≈ 3.9 × 10⁻⁸ %; §VII-C's "54 wall-clock days" understates by ≈ 1.7 × 10⁷. The paper's own 428-functions-from-428-slices figure agrees with the recomputation and contradicts its theory. | recomputed | Partly. `exhaustive_phase2.jl` computes the correct projection rank but is wired into neither `report.jl` nor `test/`, so nothing states the contradiction. |
| **F006** | Li_202207 | Theorem 3 (`.tex:179`), Table V row 12 | Implemented with Frobenius exponent `2^{2m+s}`; the paper and its own Table V row 12 give `2^{m+s}`. At the paper's own parameters the two readings produce **different LUTs**. | The repository computes an APN function the paper does not state, and prints PASS for it. | recomputed | **Yes.** `helpers.jl:56` and `theorem3.jl:38` both still read `1 << (2m + s)`. Both readings are APN, which is exactly why the green suite cannot see it. |
| **F004** | Yu_202512 | Table 2, rows n=6 and n=7 | Our counts are 1 and 117; the paper prints 4 and 78. Root cause is a real under-specification: Definition 2 fixes `F_n` only as "a maximal subset" and Algorithm 3's output is not invariant under the representative choice. | Table 2 is not reproducible from the paper's text at any `n`. | recomputed | **Yes.** `make report` prints two `[FAIL]` lines while `make test` stays green — Table 2 has no test file. |
| **F008** | core (surfaced by Yuyin_201300, Tang_201510) | `finite_field.jl:76` | `PRIMITIVE_POLYNOMIALS[8]` is the AES polynomial. `ord(2) = 51`, not 255, while the docstring states the entries generate the multiplicative group. | Any reproduction indexing `α^i` with `α = 2` at n=8 computes a meaningless exponent. Budaghyan_202008's README records this producing `\|W\| = 17` instead of 85 and 72 spurious mismatches. | recomputed | **Yes**, latently, across an unaudited set of call sites. |
| **F012** | Ichanska_202400 | Sect. 3.5, Theorem 3 | `_row_combo_rank` reads only the low 8 bits (`for bit in 0:7`). Correct at n=4, silently wrong at n ≥ 9 — the paper's (9,3), (10,1), (10,2) cases. | The reproduction **falsely refutes a true theorem** at n=10. | code_confirmed | **Yes.** The suite passes only because it is restricted to n=4. |
| **F013** | Li_202402 | Theorem 1 third root condition (`.tex:210`) | Implemented as `X^{q²+q+1}+X^{q²+q}+1`, the *reciprocal of condition c1*, hence logically redundant with c1 and never independently falsifiable. The paper requires `X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1`. | `@test c1 && c2 && c3` certifies a statement the paper does not make; the factor the proof actually uses is never checked. | code_confirmed | **Yes.** `theorem1.jl:70-72` and `proposition4.jl:42` are unchanged. |
| **F041** | Kuznetsov_202606 | Theorem 6, database (1) | `theorem6.jl` queries a corpus that does not exist, so `in_beierle2025` is always false and `[PASS]` prints regardless of truth. Absence of a source is used as evidence of inequivalence. | The largest of the three databases in Theorem 6 is never actually checked. | code_confirmed | **Yes**, and it bypasses `_assert_sigma_coverage`, the guard written to refuse exactly this. |
| **F040** | Yu_202012 (+8 more) | — | Every bulk corpus is n=8. There is **no n=9, n=10, n=11 or n=12 corpus**; curated TOMLs hold 9, 4, 0 and 2 entries there. | Every `:new` verdict at n ≥ 9 means "absent from our catalog", not "new". Standing proof in-repo: a function that paper treats as *known* also classifies `:new`. | recomputed | **Yes.** Six reproductions emit n ≥ 9 gap records whose novelty evidence cannot be stronger than 9 or 4 rows. |
| **F009** | Taniguchi_202501 (+5 more) | Example 4.2 (Γ-ranks 11818 / 13842) | `_design_rank_guard` refuses n > 7 saying n=8 "needs … hours — compute it with Magma". Measured with the same in-tree elimination: **166.8 s, 0.95 GB**, reproducing both published Γ-ranks exactly. | Six papers report their Γ-/Δ-rank columns as unverifiable because of one over-pessimistic guard. | recomputed | **Yes.** The guard is live; six READMEs cite it as their blocker. |
| **F061** | Beierle_202201 | Table 1 | `table1_invariants.jl` reproduces a table from a **different publication** (61 rows, Γ-rank/Δ-rank/multiplier columns that appear nowhere in this paper). `inputs/` does not exist at all and `*.txt` is gitignored, so eight make targets crash on a fresh checkout. | Every `results/table1_*.toml` is a stale artifact of checking a foreign table. | code_confirmed | **Yes.** The file, its targets, its test and its artifacts are all committed. |
| **F014** | Zha_201401 | Table 1 row 3; Sect. 5 Prop. 5 | Row 3 prints row 4's data. Corrected NL = 110 collides with the value the paper attributes to the family it is separating from, so the stated separation argument fails for that instance. Cross-corroborated by a second reproduction in this repo. | The paper's headline novelty argument is incomplete for one of its two n=8 instances. | readme_only | No — no `proposition5.jl` exists. |
| **F060** | six 2009–2015 papers | — | Six READMEs record "could not run: no Julia on this host" and substitute Python/C re-derivations. **Julia 1.12.6 is installed here.** Eight catalog-gap records carry LUTs that each warn they must be regenerated before any TOML write. None has been. | The largest readme_only block in the audit, and eight unsafe LUTs. | readme_only | No, but eight gap records are queued behind it. |

### Medium severity (condensed)

**F005** Yu_202512 Table 3 uses only the ortho-derivative *differential* spectrum where the
paper's criterion is differential **and** Walsh; x³ and x³³ collide over GF(2¹¹) and the repo
prints `[FAIL]` — `apn_ea_mugshot` fixes it in one line (recomputed).
**F007** Li_202207 documents Theorem 3's `v`-hypothesis as `F*_{2^{3m}}`; exactly 7 of 511
nonzero `v` give du = 2 and they are exactly `F*_{2³}`, confirming the paper (recomputed).
**F011** Gologlu_202207 Proposition III.4(ii) states η₃ = 2; recomputed η₃ = 3, and the
invariant fails to separate two genuinely CCZ-inequivalent functions at n=6 (recomputed).
**F062** `Gologlu_202503/Makefile:4` is the only one of 42 with `../..`; `make test` and
`make report` both fail. The suite is sound (210/210 in 103 s corrected), and its own
assertions confirm three claimed paper defects — a one-character fix promotes them from
`readme_only` to `code_confirmed` (code_confirmed).
**F021 / F025 / F030 / F032 / F063 / F064 / F071** — see `audit/findings.yaml`.

---

## Unexhausted regions, ordered by the ranking rule

Ordered by the same key as the leads table (printed in full below), **not** by size. Within each
tier the governing principle applies: a region skipped for a contingent reason outranks a larger
region skipped for complexity.

| # | Tier | Finding | Region left | Size | Stated by authors? | Method completeness |
|---|---|---|---|---|---|---|
| 1 | 2 | **F021** core `search_qam` | the interior of every multi-class mugshot bucket | at n=7, 14 buckets over a 15-class truth | no | heuristic |
| 2 | 2 | **F020** BBL2021 classes | 27 classes rejected by *search*, plus 5 the paper leaves open | per-class commutant-quotiented tree; no stated cardinality | no | pruned_search |
| 3 | 2 | **F025** Yu_202012 QAM | the n=8 and n=9 candidate spaces | 2.7 × 10⁸ and 6.9 × 10¹⁰ | yes | complete_within_region, but unpruned so unreachable |
| 4 | 2 | **F022** Kuznetsov slices | slices of `V_A` never visited | 2⁴⁰ − 428 ≈ 1.0995 × 10¹² | the paper states 65536, which is wrong (F010) | pruned_search |
| 5 | 4 | **F023** Kaleyski Conj. 22 | ≈ 3.9 × 10⁶ swaps at n=7, ≈ 1.5 × 10⁶ at n=8 | 3.9 × 10⁶ / 1.5 × 10⁶ | no | randomized |
| 6 | 4 | **F024** Budaghyan Thm VI.3 | 2²⁷ − 803 at n=9; all of 2³² at (8,2); ≈ 2³⁶ for §VII-D | 2²⁷ / 2³² / 2³⁶ | no | randomized |
| 7 | 5 | **F053** Canteaut §4.5 | the thickness and subspace claims; the Walsh claim is cheap | 21,102 functions | yes | complete_within_region |
| 8 | 5 | **F063** catalog gaps | ≈30 invariant-backed records across 9 papers | ≈30 entries | no | complete_within_region |
| 9 | 5 | **F051** Calderini Tables 2–4 | ≈ 47 bound-column rows | \|Z\| ≈ 2¹³–2¹⁴ per function | no | complete_within_region |
| 10 | 5 | **F050** Taniguchi Ex. 3.3 | the n=6 count under other normalisations | 2³⁰ candidates | no | complete_within_region |
| 11 | 6 | **F052** Beierle Table 4.1 | the full union under both pair orders | 32,916 functions | no | complete_within_region |
| 12 | 7 | **F031** Gologlu n=14 | all of it — the default path does not terminate | ≈ 9.2 × 10⁹ inner iterations | yes | unknown |
| — | seg. | **F071** Bracken_201103 | *inferred*: `(4,11)` entirely; all but one `(v,w)`; n=15 | 241 pairs per `(k,s)` | no | complete_within_region |
| — | seg. | **F070** Bracken_201205 | *inferred*: the n=30 permutation instance | 2³⁰ inputs | no | complete_within_region |

Rows 1 and 5 are the doors: both are contingent, both are within a day of this machine. Row 4 is
the wall — 2⁴⁰ slices at 30.7 s each is 9.4 × 10¹² core hours, so no emptiness claim can ever
come out of it and only sampling is affordable. Row 3 sits between: 2.7 × 10⁸ candidates at n=8
is 2691 core hours, i.e. 9.3 wall days here, so it is reachable without the paper's pruning at
all — the blocker is that nobody has run it.

---

## Proposed experiments — top ten leads

Every experiment below has a stop condition; any lead that could not carry one is not here.
Runtimes are from `packages/VBF/perf/historical/calibration.toml` and carry a ±2× band (see Method).

### E1 — Delete the actionable false-novelty record, then upgrade σ-match to proof (F003)

```julia
julia --project=. -e '
using VBF, VBFCatalog
include("packages/VBFRepro/papers/2026/Kuznetsov_202606/helpers.jl")
reps = representative_sboxes()
for nm in (:class_a, :class_b, :class_c, :class_d)
    F = getfield(reps, nm)
    src = classify_ccz(F)                       # expect (:sigma_match, "functions", …)
    G   = load_sbox(load_catalog(), src[3])
    m   = ea_mappings_from_ortho_derivative(F, G)
    println(nm, " sigma=", src, "  ea_mappings=", length(m))
end'
```

- **Expected runtime** 4 × 45.8 s ≈ 3 min (`exact_ea_decision.n8_are_ea_equivalent_seconds`);
  0.05 core hours.
- **Positive control** `class_e` and `class_f` must resolve to Gold x³ and x⁹ (`functions`
  rows 41 and 42) — they do; that calibrates the pipeline.
- **Inequivalence certificate** not needed in this direction. σ-*match* proves nothing on its
  own, which is why the exact decision is run; a non-empty mapping set is a constructed witness.
- **Stop condition** stop as soon as all four return a non-empty mapping set — the refutation is
  then proved, not inferred. If any returns **empty**, stop and escalate: a σ collision without
  equivalence would be a finding in its own right.
- **First action, before any compute:** delete or supersede the four catalog-gap records in
  `REVIEW_Kuznetsov_202606.md`. They are the only live instruction in the repository to write
  known functions into the catalog under a false attribution.

### E2 — Lock in the Ichanska refutation (F002)

```julia
julia --project=. -e '
using VBF, VBFCatalog
include("packages/VBFRepro/papers/2024/Ichanska_202400/helpers.jl")
include("packages/VBFRepro/papers/2024/Ichanska_202400/section5_1.jl")
F  = new_function_n8_m2(); db = load_catalog()
W9 = corpus_function(db, "wengtangong2013_n8", 9)
W1 = corpus_function(db, "wengtangong2013_n8", 1)
@show classify_ccz(F), is_novel(F)
@show are_ea_equivalent(F, W9; on_inconclusive = :throw)
@show are_ea_equivalent(F, W1; on_inconclusive = :throw)'
```

- **Expected runtime** 11.4 s measured this session; 0.003 core hours.
- **Positive control** `are_ea_equivalent(F, F)` → true and `(F, W1)` → false, both in the same run.
- **Inequivalence certificate** the negative control is the certificate path: an empty
  ortho-derivative mapping set is a rigorous CCZ-inequivalence proof for quadratic APN.
- **Stop condition** stop when the three assertions are committed as a regression test. If
  `(F, W9)` ever returns false, stop and re-open the novelty question.

### E3 — Close the third leg of the provenance collision (F001)

```julia
julia --project=. -e '
using VBF, VBFCatalog
include("packages/VBFRepro/papers/2009/Budaghyan_200910/helpers.jl")
F = SBox{8}(UInt8.(apn_eq6(8, 2)))              # BCL 2009 eq. (6), a = alpha
G = load_apn_function("n8_Taniguchi2025_ex4_2")
@show length(ea_mappings_from_ortho_derivative(G, F))   # expect 3072
@show apn_ea_mugshot(F) == apn_ea_mugshot(G)'
```

- **Expected runtime** 395 s for the full mapping set
  (`exact_ea_decision.n8_eq6_vs_taniguchi_seconds`), 45.8 s for the boolean; 0.11 core hours.
- **Positive control** the stored witness in `certificates/taniguchi_ea.json` re-verifies at
  0 mismatches over 256 inputs — re-run that first; it takes under a second.
- **Inequivalence certificate** not applicable — this is an *equivalence* witness, and it is
  constructed (A₁, A₂, A explicit), not an oracle verdict.
- **Stop condition** stop when `n8_apn.toml:56` carries a prior-art cross-reference to the 2009
  source. The third leg (Edel–Pott 1.3) needs that function built first and is a separate item;
  do not block on it.

### E4 — Wire the corrected `V_A` geometry into the report (F010)

```julia
julia --project=. -e '
using VBF
include("packages/VBFRepro/papers/2026/Kuznetsov_202606/helpers.jl")
M = build_M_A(build_A_matrix())
intra  = [col_idx(p,q,k)+1 for (p,q) in ((4,5),(4,6),(5,6)) for k in 0:7]
center = setdiff(1:224, intra)
# rank via the paper-local rref_f2!; expect 184, 24, 168
println((rank_of(M), rank_of(M[:,intra]), rank_of(M[:,center])))'
```

- **Expected runtime** 3 × 1.4 ms (`ker_MA_solve_n8`); ≈ 10⁻⁶ core hours.
- **Positive control** `rank(M_A) = 184` and `dim V_A = 40` must reproduce the paper's own
  §IV-C values before the derived ranks are believed — they do.
- **Inequivalence certificate** not applicable; this is a linear-algebra fact.
- **Stop condition** stop when `section4.jl` prints the corrected slice count 2⁴⁰ and a `[FAIL]`
  against the paper's 65536, and `test/test_section4.jl` asserts all three ranks. If a defensible
  index reading gives `rank(intra) < 24`, stop and withdraw the finding — both readings were
  tried here and both give 24.

### E5 — Fix the Li 2022 exponent and pin the paper's own instance (F006, F007)

```julia
# after changing helpers.jl:56 and theorem3.jl:38 to 1 << (m + s)
julia --project=. -e '
using VBF, VBFCatalog
include("packages/VBFRepro/papers/2022/Li_202207/helpers.jl")
F = theorem3_sbox(3, 1; mu = 32, v = 336)     # Table V row 12, modulus 529
@show differential_uniformity(F), algebraic_degree(F)
@show sorted_pairs(differential_spectrum(ortho_derivative(F)))'
```

- **Expected runtime** two n=9 mugshots ≈ 15 ms (`sigma_key_n9`); 4 × 10⁻⁶ core hours.
- **Positive control** the corrected build must reproduce Table V row 12's ortho-derivative
  differential spectrum, which the paper also attributes to the sporadic n=9 instance it claims
  to cover.
- **Inequivalence certificate** none is claimed — and none should be. The function classifies
  `:new` only because the σ-index has **no n=9 rows** (F040); it must not be catalogued.
- **Stop condition** stop when the pinned LUT test passes. If the corrected function's spectrum
  does **not** match Table V row 12, stop: the paper's own row is then in question and that is a
  larger finding.

### E6 — Settle the Yu 2025 Table 2 convention and repair Table 3's key (F004, F005)

```bash
make -C packages/VBFRepro/papers/2025/Yu_202512 table2_n7      # today: 1 and 117 against the paper's 4 and 78
make -C packages/VBFRepro/papers/2025/Yu_202512 table3         # today: two [FAIL] lines from a sigma collision
```
then add `reps = :min_log` to `fn_set` and switch `table3.jl:82` to `apn_ea_mugshot`.

- **Expected runtime** ≈ 1 min per target; ≈ 0.02 core hours. (`cost_model unknown` for the
  Algorithm-3 search itself — it is not a calibration key.)
- **Positive control** the four Gold rows x³, x⁵, x⁹, x¹⁷ must stay pairwise distinct under the
  corrected mugshot key; n=6 and n=7 must return 4 and 78 under `:min_log` before any n ≥ 8
  number is believed.
- **Inequivalence certificate** the ortho-derivative mugshot — differential **and** Walsh — which
  is the paper's own stated criterion and is complete for quadratic APN.
- **Stop condition** stop when n=6 and n=7 reproduce and n ≥ 8 is marked UNREPRODUCED rather
  than asserted. Do **not** keep searching conventions for n=8: with 30 orbits there are 8³⁰
  admissible sets and the search is unbounded.

### E7 — Make the n=8 primitive-polynomial trap a build failure (F008)

```julia
julia --project=. -e '
using VBF
ordof(x,n,m) = (o=1; y=x; while y != 1; y = gf_mul(y,x,n; modulus=m); o += 1; end; o)
for n in 2:16
    println(n, "  ord(2) = ", ordof(2, n, primitive_polynomial(n)), "  target ", 2^n - 1)
end'
```

- **Expected runtime** milliseconds; ≈ 4 × 10⁻⁶ core hours.
- **Positive control** n = 2…7 and 9…16 must all return `2ⁿ − 1`; that is the test's own
  non-vacuity. n = 8 returns **51**.
- **Inequivalence certificate** not applicable.
- **Stop condition** stop when the assertion is a package test (which fails today at n=8) **and**
  every `primitive_polynomial(8)` call site that also indexes `α^i` has been listed. Do not
  silently switch the constant: several reproductions pin `conway_polynomial(8)` deliberately and
  would change meaning.

### E8 — Evaluate the non-bent signature the reproduction declined to compute (F011)

```julia
julia --project=. -e '
using VBF
K = kim_apn(); G = gold_apn(6,1)
@show nonbent_signature(K), nonbent_signature(G)          # both [21, 28, 3, 0]
@show sorted_pairs(differential_spectrum(ortho_derivative(K)))
@show sorted_pairs(differential_spectrum(ortho_derivative(G)))'
```

- **Expected runtime** sub-second at n=6; ≈ 6 × 10⁻⁴ core hours.
- **Positive control** η₃(x³) must be 3, matching Proposition III.4(i) — it is.
- **Inequivalence certificate** the ortho-derivative spectra, which *do* separate the two
  functions that `N_F` does not — that separation is the point of the experiment.
- **Stop condition** stop when `proposition3_4.jl` prints a `[FAIL]` for the claimed η₃ = 2 with
  the computed 3 alongside. The absent reference that could explain a different η convention is
  logged in `audit/missing_sources.yaml` (MS01); do not chase it.

### E9 — Confirm every QAM class count that is currently a lower bound (F021)

```julia
julia --project=. -e '
using VBF
r  = search_qam_full(7, 1; confirm = false)
rc = search_qam_full(7, 1; confirm = true)
@show typeof(r), length(search_solutions(r))
@show typeof(rc), length(search_solutions(rc))'
```

- **Expected runtime** the n=7 sweep plus one EA confirmation of the colliding bucket ≈ 1.6 s
  (`cost_model` for the sweep itself is not a calibration key); ≈ 4 × 10⁻⁴ core hours for the
  confirmation.
- **Positive control** the known Gold x³ / x⁹ bucket must split under `confirm = true`, taking
  the count from 14 to 15.
- **Inequivalence certificate** `ea_mappings_from_ortho_derivative` — an empty mapping set is a
  rigorous CCZ-inequivalence proof for quadratic APN.
- **Stop condition** stop when every paper-local call site passes `confirm = true` and the
  reported counts are labelled as counts rather than lower bounds. If `confirm = true` never
  splits a bucket in a real sweep, downgrade the concern to theoretical.

### E10 — Turn "the search found nothing" into "the region is empty" (F020)

```julia
# after implementing Comm(M), isSmallest and Lemma 6 seeding
julia --project=. -e '
using VBF
include("packages/VBFRepro/papers/2021/Beierle_202107/algorithm1.jl")
out = APNSearch(6, A, B; timeout_seconds = 86_400)
@show typeof(out)                       # must be Exhausted, not BudgetHit
@show proves_emptiness(out), search_solutions(out)'
```

- **Expected runtime** **cost model uncertain.** The only figure available is the paper's own
  ≈ 8 h for one n=6 class *with* both reductions, on the authors' hardware; nothing at this
  scale is calibrated on this machine. Budget 64 core hours for the eight n=6 classes as an
  order of magnitude only, and re-measure on the first class before committing to the rest.
- **Positive control** n=6 class 5 must return the known 6-bit APN permutation, and the six n=7
  monomial classes must return their stored solutions — all seven are already verified in that
  directory.
- **Inequivalence certificate** an ortho-derivative σ mismatch against the local index. At n=6
  and n=7 that index is effectively complete, so the certificate would be strong; at n=8 it
  covers 230,404 rows over 8 named corpora and its parse is verified only by spot check.
- **Stop condition** stop the moment a class returns `BudgetHit` rather than `Exhausted` — that
  outcome proves nothing and must not be recorded as emptiness. `certified_empty_region` is
  defined only on `Exhausted`, so misuse is a `MethodError`, not a review comment.

> **Not in the top ten, but the cheapest high-leverage item in this report.** The ranking rule
> places **F009** (raise the Γ-rank guard to n=8) at rank 12, because our recomputation *agrees*
> with the published Γ-ranks rather than disagreeing. It costs 166.8 s per function, is already
> written and correct in-tree, and converts six papers' `[loaded]` transcriptions into computed
> checks. If the week has spare capacity, run it.

---

## Prioritized leads

**Ranking key**, applied in order:

1. Wrong values or internal inconsistencies where **our recomputation disagrees with a published
   or catalogued figure** — that is a result in itself, independent of any new function.
2. **Unsound negatives**: a claimed-empty region whose method completeness is `pruned_search`,
   `randomized` or `heuristic`. Emptiness reported by an incomplete search is not emptiness.
3. **Tool limits where we have an open-source path** around the blocking dependency.
4. **Sampling-not-exhaustion** where the remaining region is within ~3 orders of magnitude of
   measured throughput × one week × available cores (here: ≈ 2 × 10¹¹ `is_apn` calls at n=8,
   ≈ 5 × 10¹⁰ at n=9, ≈ 1 × 10¹⁰ at n=10).
5. **Scope restrictions** where the construction is already implemented and tested.
6. **Unproved premises** — falsifying one is a paper, assuming one is a bug.
7. Everything else.

Governing principle: **small regions skipped for contingent reasons outrank large regions
skipped for complexity**, because a region of size 10⁹ is usually a wall rather than a door.
`readme_only` findings never outrank a `paper_confirmed` one, and `inferred` findings are capped
at medium confidence and segregated below.

| Rank | Tier | ID | Paper | Lead | Tier of evidence | Cost (core h) |
|---|---|---|---|---|---|---|
| 1 | 1 | F003 | Kuznetsov_202606 | 4 claimed-new classes refuted; delete the live false-write record | recomputed | 0.05 |
| 2 | 1 | F002 | Ichanska_202400 | 2024 novelty refuted against a 2013 function; lock it in | recomputed | 0.003 |
| 3 | 1 | F001 | Taniguchi_202501 | catalog entry credits 2025 for a 2009 class | recomputed | 0.11 |
| 4 | 1 | F010 | Kuznetsov_202606 | slice count 65536 → 2⁴⁰; coverage off by 1.7 × 10⁷ | recomputed | 1e-6 |
| 5 | 1 | F006+F007 | Li_202207 | wrong Frobenius exponent → a different function, silently PASSing | recomputed | 4e-6 |
| 6 | 1 | F004+F005 | Yu_202512 | Table 2 counts disagree; Table 3's inequivalence evidence is void | recomputed | 0.02 |
| 7 | 1 | F011 | Gologlu_202207 | η₃ = 3, not the published 2 | recomputed | 6e-4 |
| 8 | 2 | F021 | core / Kalgin_202000 | mugshot dedup makes every QAM class count a lower bound | code_confirmed | 4e-4 |
| 9 | 2 | F020 | Beierle_202107 | 27 classes "empty" by a search that was never run | code_confirmed | ≈64 (uncertain) |
| 10 | 2 | F025 | Yu_202012 | unpruned substitute search; n=8/n=9 unreachable | code_confirmed | 2691 |
| 11 | 2 | F022 | Kuznetsov_202606 | 16-bit signature cannot separate 2⁴⁰ slices | recomputed | 8.5 per 1000 slices |
| 12 | 3 | F009 | Taniguchi_202501 +5 | Γ-rank at n=8 is 166.8 s, not "Magma territory" | recomputed | 0.046 |
| 13 | 3 | F030 | core | wide-F₂ elimination absent; two papers hand-roll it | code_confirmed | 4e-7 |
| 14 | 3 | F032 | Bracken_200807 | code equivalence needs Leon; no path exists in practice | code_confirmed | unknown |
| 15 | 4 | F023 | Kaleyski_201911 | Conjecture 22 exhaustive at n=7 fits in a day | code_confirmed | 81 |
| 16 | 4 | F024 | Budaghyan_202008 | Theorem VI.3's n=9 sample has injected positives | code_confirmed | 5145 |
| 17 | 5 | F063 | 9 papers | ≈30 invariant-backed catalog gaps, never written | readme_only | 3e-4 |
| 18 | 5 | F053 | Canteaut_202205 | §4.5 declared out of scope on a false premise | readme_only | 0.018 |
| 19 | 5 | F051 | Calderini_202009 | ≈47 rows behind one slow routine | readme_only | ≥23.5 |
| 20 | 5 | F050 | Taniguchi_202501 | n=6 count declared infeasible; it is 2³⁰ | readme_only | 0.07 |
| 21 | 6 | F052 | Beierle_202508 | Definition 4.1's pair order is unstated | readme_only | 14.8 |
| 22 | 7 | F008 | core | `PRIMITIVE_POLYNOMIALS[8]` is not primitive | recomputed | 4e-6 |
| 23 | 7 | F012 | Ichanska_202400 | 8-bit rank truncation falsely refutes a true theorem | code_confirmed | 1e-6 |
| 24 | 7 | F013 | Li_202402 | third root condition is c1's reciprocal | code_confirmed | 1.2e-5 |
| 25 | 7 | F062 | Gologlu_202503 | one-character Makefile fault blocks a 210-test suite | code_confirmed | 0.029 |
| 26 | 7 | F041 | Kuznetsov_202606 | absent corpus read as a passing check | code_confirmed | 587 |
| 27 | 7 | F061 | Beierle_202201 | reproduces a different paper's table | code_confirmed | 0.023 |
| 28 | 7 | F040 | Yu_202012 +8 | no corpus at n ≥ 9; every `:new` there is meaningless | recomputed | 6e-5 |
| 29 | 7 | F060 | six 2009–2015 papers | numbers never re-derived under Julia | readme_only | 0.1 |
| 30 | 7 | F014 | Zha_201401 | Table 1 row 3 duplicates row 4; separation argument fails | readme_only | 2e-5 |
| 31 | 7 | F031 | Gologlu_202207 | default report path does not terminate at n=14 | readme_only | unknown |
| 32 | 7 | F064 | Beierle_202107 | Corollary 1 cannot be regenerated | readme_only | unknown |
| — | seg. | F070 | Bracken_201205 | *inferred*: no genuine binomial below n=30 | readme_only, capped medium | 0.082 |
| — | seg. | F071 | Bracken_201103 | *inferred*: parameter grid, not author text | readme_only, capped medium | 3e-4 |

Ranks 23–28 are high- or medium-severity **code** defects that the rule places in "everything
else" because they are our bugs, not disagreements with a published figure. The rule optimises
for research leads, not repository hygiene; those six belong to the Critical Findings section
above and should be fixed regardless of their rank here.

---

## Reproduction debt

**READMEs with no paper text on disk: none.** All 42 paper directories carry both `.tex` and
`.pdf` under `input/`. One is misfiled: `packages/VBFRepro/papers/2022/Li_202207/input/tex_source/` contains the
`.tex` of a *different* paper, whose own reproduction lives elsewhere in the tree
(`audit/missing_sources.yaml` MS18).

**Papers with no implementation: none.** All 42 carry paper-local claim files (4–14 each) and a
test directory (3–13 files each). Six use `tests/` rather than `test/`.

**Constructions implemented but never tested against the paper's stated output:**

| Paper | What is built but unasserted |
|---|---|
| Yu_202512 | Table 2 has **no test file at all**; `make report` prints three `[FAIL]` lines while `make test` is green. |
| Zheng_202211 | no testset asserts the headline novelty result; `make test` exercises only m=5, and the n=14 value in the committed artifact comes from a different target. |
| Calderini_202306 | the paper's central Table 3 / `N_F` claim at n=12 is not in `make test`; the test asserts the *skip gate* instead. `section4_1.jl` and `remark1.jl` have no test file. |
| Beierle_202201 | `inputs/` does not exist, so one `@test_skip` stands in for three whole test files. |
| Li_202207 | the suite is *structurally incapable* of failing on F006 in either direction. |
| Li_202402 | the bivariate hypothesis of two theorems is never checked; its helper is dead code with zero call sites. |
| Budaghyan_202101 | three helpers implementing the paper's central Theorem 3.1 are defined and never called. |
| Ichanska_202400 | `lemma1_test` passes against a category definition that contradicts the paper; `theorem3_test` passes only because it is restricted to n=4. |
| Kaleyski_202203 | Propositions 1, 2 and Corollary 3 — the whole of Section 2 — have no test file. |
| Calderini_202100 | Proposition 7.5 is skipped by default, has no test, and is absent from `report.jl`. |
| Beierle_202508 | no test computes a profile of any real dimension-8 function; the only function ever profiled is a 4-bit one. |
| Chase_202110 | the Section 5 coverage claim has no file and no test. |

**Six papers whose recorded results were never produced by this repository's own code** —
Budaghyan_200904, Budaghyan_200910, Edel_200900, Bracken_201103, Yuyin_201300, Tang_201510.
Each records "could not run — no Julia toolchain" and substitutes a Python or C re-derivation.
Julia 1.12.6 is installed here. Eight catalog-gap records carrying full LUTs are queued behind
them, every one of which warns that its LUT must be regenerated first (**F060**).

---

## Findings we could not evaluate

### Still `readme_only` (11 of 36)

| ID | Why it did not advance | What would resolve it |
|---|---|---|
| F014 | The Zha Table-1 correction and its consequence for the separation argument are asserted in two READMEs; no file computes either. | A `proposition5.jl` building both families at n=8 — ≈ 2 × 10⁻⁵ core hours. |
| F050 | The n=6 count 35,648 is a C figure from another machine; the reproduction returns −1. | Hoist the loop-invariant and run 2³⁰ candidates — ≈ 0.07 core hours, but the per-candidate cost is *not* calibrated here. |
| F051 | The one attempt at the bottleneck routine was killed by a 700 s timeout, so no run has ever completed. | An optimised `extract_linear_subspaces`; until then the 23.5 core-hour estimate is a lower bound of unknown tightness. |
| F052 | Only 3 outliers and a 2000-member sample were examined; the pair order is unstated in the paper. | The full 32,916-member sweep under **both** orders — 14.8 core hours. |
| F060 | Six suites were never run under Julia. | `make test` and `make report` on all six — ≈ 0.1 core hours. **This is the cheapest large reduction available.** |
| F063 | ≈30 catalog-gap records across nine papers, none written. | One catalog pass plus a rebuild and gate run; blocked on a policy decision, not on evidence. |
| F064 | The generator named in the TOML headers has no definition anywhere. | Write `generate_tuple_matrix_constants_file(n)`; cost unmeasurable until it exists. |
| F070, F071 | *Inferred* boundaries — derived from parameter grids and tables, not from author text. Capped at medium confidence by rule. | Author confirmation, or the sweeps themselves. |
| F031 | Deliberately not run: the default path is expected to hang or OOM, and this audit did not spend a hang on it. | A bounded subspace representation first. |
| F053 | Two independent reviews agree on the multiplicities; this audit confirmed only the member counts (8179 + 12923 = 21102) by SQL. | A `section4_5.jl` — ≈ 0.018 core hours. |

### `cost_model: unknown` (3)

- **F031** — the current subspace materialisation grows superlinearly in η and was never bounded,
  so no defensible seconds-per-unit exists. Estimating it requires the rewrite first.
- **F032** — no implementation of code permutation-equivalence exists to time, and the algorithm's
  cost is strongly instance-dependent.
- **F064** — the generator does not exist, so its cost cannot be measured. The n=6 path runs
  inside a 2.3 s testset, but extrapolating two dimensions of canonical-form enumeration from
  that is not defensible.

Two further leads carry *stated but ungrounded* costs and are flagged rather than trusted:
**F020** (64 core hours, extrapolated from the paper's own hardware, not this machine) and
**F050** (0.07 core hours, from a C measurement elsewhere).

### Supersession not checked

- **F011** — the reference that could explain a different η convention is not on disk
  (`missing_sources.yaml` MS01). Until it is read, "the paper is wrong" and "the convention
  differs" cannot be separated.
- **F063** — supersession was checked only *partially*, per record. That matters: two gap records
  in this repository were withdrawn precisely because a supersession check refuted them (F002,
  F003). Writing the remaining ≈30 without the same check would repeat that failure.

---

## Method and limitations

**How findings were classified.** A defect was included only if it changes what a machine
computes: a parameter condition or admissible range, a coefficient, exponent, index or field
element in a stated construction, the direction or quantifier of a claim, a reported count,
cardinality or spectrum, a pruning rule, termination condition or search order, the scope of a
coverage claim, or a hypothesis stated as proved but only checked on examples. Prose, notation
drift, formatting, bibliography errors and figure mislabels were excluded — several READMEs
carry long lists of those and none of them appears here. Typo-likeness was **not** a filter: a
wrong Frobenius exponent (F006) and a reciprocal polynomial (F013) both look like typos and both
change the function computed. Borderline items were recorded with an explicit uncertainty rather
than dropped or inflated; two boundaries derived from parameter grids rather than author text are
marked `inferred`, segregated in the leads table, and capped at medium confidence.

**What was measured versus assumed.** Measured on this machine this session: the EA decision
Ichanska-2024 ↔ Weng–Tan–Gong-2013 (11.4 s, with both controls); `classify_ccz` / `is_novel` for
all six Kuznetsov representatives; the Taniguchi EA certificate re-verified pointwise at 0/256
mismatches; `rank(M_A) = 184`, `rank(intra 24) = 24`, `rank(center 200) = 168` under two index
readings; Li 2022's two exponent readings producing different LUTs and the 7-element admissible
`v`-set; `ord(2) = 51` under `primitive_polynomial(8)`; η₃ = 3 for the Kim function; the Yu 2025
Table 2 and Table 3 failures by executing the repository's own make targets; and the shape of the
σ-index by SQL (230,404 rows, 33,416 distinct σ, 9 sources, all n=8). Assumed, and labelled as
such throughout: every figure in a `readme_only` finding, and every cost derived from a
non-calibration key.

**Calibration.** `packages/VBF/perf/historical/calibration.toml` was generated 2026-08-16 — one day old, well inside
the thirty-day window — so it was **not** regenerated. It was spot-checked instead: `is_apn` at
n=8 reproduced to 7 %, at n=10 to 1.8×, and `ortho_derivative` at n=8 to 2.1×, the spread growing
with per-call cost, which is scheduler pressure rather than drift. **Every core-hour figure in
this report therefore carries a ±2× band.** No figure is quoted to more than two significant
digits. Where a cost could not be grounded in a measurement it is marked `unknown` with a reason;
where it rests on another machine's C or Python run — the exact thing this audit is meant to
avoid — that is said explicitly at the point of use (F020, F050, F070).

**Where the audit is knowingly incomplete.**

- Eleven findings never left `readme_only`, and six of the papers behind them ran their numbers
  outside Julia. This audit did **not** re-run those six suites. That is the single largest
  unverified block, and it is also the cheapest to clear.
- Novelty verdicts rest on the σ-index, whose parse was verified only by spot check: Gold x³ and
  x⁹ resolve to the expected rows, and the six Kuznetsov representatives resolve as expected. A
  novelty claim against a partially-parsed database is worthless, so this is a real limit.
- The index covers 8 n=8 corpora and **zero** rows at n ≥ 9. At n=8 it holds 33,416 distinct σ
  against a known landscape that a 2025 construction has taken past 3.7 million — about 0.9 %.
  Marginal novelty at n=8 is therefore cheap and low-value; at n ≥ 9 no certificate can be issued
  at all, and every `:new` verdict in this repository at those dimensions means only "absent from
  our catalog" (F040).
- Findings were drawn from the READMEs and then verified against the paper text, the code and, in
  thirteen cases, by recomputation. Defects present in a paper but discussed in **no** README are
  outside this audit's reach by construction. Silence is not a coverage claim, and no finding was
  recorded merely because a paper never mentioned something.
- Two contradictions between a README and the code are recorded but not resolved in the READMEs'
  favour or against: Kalgin's C1 and Beierle_202107's R2 both describe core behaviour that has
  since changed in the working tree (`confirm = true`, and the new `SearchOutcome` type). Those
  READMEs are stale, not wrong-at-the-time.
