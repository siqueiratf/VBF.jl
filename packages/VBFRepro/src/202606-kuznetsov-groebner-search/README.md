# Kuznetsov_202606 — Quadratic APN Functions in Dimension 8 via Gröbner Basis Search in a Self-Equivalence Subspace

**Paper**: Kuznetsov. "Quadratic APN Functions in Dimension 8 via Gröbner Basis Search in a
Self-Equivalence Subspace." 2026.

**Reproduction path**: `packages/VBFRepro/src/202606-kuznetsov-groebner-search/`

**Verdict**: Partial

Current audit (2026-10-10): `theorem6_exact.jl` replays independently verified EA
witnesses for artifact representatives A/B/C/D against Edel–Pott2009 corpus
members18/5/3/4. Positive equivalence is established by the full affine graph
identity, never by signature equality. `recover=true` runs a bounded native
search; an unfinished comparison stays inconclusive. These four representatives
are therefore previously known CCZ classes. The former catalog-gap proposals in
`REVIEW_Kuznetsov_202606.md` have been removed.

`section4.jl` and its tests now compute the full geometry: total rank184,
intra-column rank24, center-column rank168, center projection kernel0,
projection dimension40, and **2^40** distinct slices meeting V_A. The RREF free
coordinates split32center/8intra. `exhaustive_phase2.jl` uses the correct
pair-major projection indices; phase2's output-major variable indices cannot be
substituted. `slice_identifier` records all200center coordinates losslessly.
Phase1 remains sampling with replacement and never reports exhaustive coverage.

`make theorem6` and `make novelty` report missing/incomplete named sources as
inconclusive and signature matches as candidates for an exact check. They do not
certify completeness throughout the literature. The exact witnesses use the
tracked19-member reference corpus and need no large signature index.

Run `make test` for the bounded regressions; `make theorem6_exact` replays the
positive proof. A witness can be regenerated with
`theorem6_exact_run(;recover=true,timeout_seconds=60,max_nodes=10^6)`.
The historical review below describes the earlier implementation; its line
numbers, test counts, and resolution plans are superseded by this status.

---

## Paper Issues

### 1. §IV-E's slice geometry is false; Table I's coverage figures and §VII-C's scalability estimate follow from it

*New in this review. Major.*

- **Location**: §IV-E, Table I, §V-A, §VII-C.
- **The claim**: *"the pairs with p > 4 are exactly (5,6), (5,7), (6,7), contributing 3×8 =
  24 intra-slice bits. The remaining 40−24 = 16 free bits are center bits. This induces a
  partition of `V_A` into 2¹⁶ = 65536 non-overlapping affine hyperplanes of dimension 24."*
- **Computed counter-evidence**, from the paper's own `A` (Eq. 1) and its own `M_A` (Eq. 2):
  - `rank(M_A) = 184`, `dim V_A = 40` ✔ (the paper is correct here)
  - **`rank(M_A[:, 24 columns of pairs (5,6),(5,7),(6,7)]) = 24` (full rank).** No element of
    `V_A` can have those 24 coordinates free: the projection **`V_A → F₂²⁰⁰` (the `p ≤ 4`
    coefficients) is injective**.
  - `rank(M_A[:, 200 center columns]) = 168`, so the natural RREF gives **32 center free bits
    and 8 intra-slice free bits** — not 16 and 24.
  - Consequence: each NL=4 slice contains **at most one** element of `V_A`, and the number of
    NL=4 slices meeting `V_A` is **2⁴⁰ ≈ 1.10×10¹²**, not `2¹⁶ = 65536`.
- **The paper's own data confirms the computation and contradicts its theory**: Table I /
  §VI-E report exactly 428 IN_CLASS22 functions from 428 slices, and the paper writes *"428 =
  the number of slice centers (one per slice)"* — precisely what injectivity predicts, and
  flatly incompatible with a 24-dimensional `V_A` hyperplane per slice, which would give
  `2²⁴` members each.
- **Downstream errors**: Table I's "Total NL=4 slices in `V_A` = 65536" and "Coverage of
  `V_A` = 0.65%" are wrong (true: `428/2⁴⁰ ≈ 4×10⁻¹⁰`, i.e. about `3.9×10⁻⁸` %); §VII-C's
  "exhausting `V_A` ≈ 54 wall-clock days" is off by a factor of roughly `1.7×10⁷` (about 1.7
  million years at the stated rate); and §V-A's 16-bit slice signature cannot identify a
  slice at all, since it cannot separate `2⁴⁰` of them — so Algorithm 1's deduplication
  silently discards *distinct* slices.
- **Note**: the repository's own `exhaustive_phase2.jl::build_projection_basis` computes
  exactly this projection rank and would print `Projection Rank: 40 / Total Slices:
  1099511627776` — the correct value — but nothing in the repository states the
  contradiction.

### 2. §V-B(1) contradicts §VI-E and Theorem 4

*New in this review.*

- **Location**: §V-B(1).
- **The claim**: *"Since F₀ ∈ V_A by construction, the normalization equations are consistent
  with the self-equivalence constraint. Any APN function in the same NL=4 slice as F₀ also
  lies in V_A."*
- **Counter-evidence**: false, and the paper refutes itself — Table III reports 138
  OUT_CLASS22 functions found in exactly those slices. Verified directly here: `class_e ∈ V_A`
  while `class_b, class_c ∉ V_A`, and all three occupy the same NL=4 slice.
- **Root cause of the error**: the paper conflates two different objects — the `V_A`-internal
  fibres of §IV-E and the full-224-space affine slices actually used in Phase 2.

### 3. The four "new" CCZ classes are not new — they are Edel–Pott (2009)

- **Location**: §I-A, §VI-I, §VIII, Theorem 6.
- **Computed counter-evidence**, re-verified from scratch using σ = (differential spectrum of
  `π_F`, absolute-Walsh spectrum of `π_F`) — the paper's own invariant:

  | Class | `edelpott2009_n8` | `yuwangli2014_qam_n8` |
  |-------|-------------------|------------------------|
  | CLASS-A | member **#18** | member **#3** |
  | CLASS-B | member **#5** | member **#6** |
  | CLASS-C | member **#3** | member **#4** |
  | CLASS-D | member **#4** | member **#5** |
  | CLASS-E (control) | #1 = Gold `x³` ✔ | #1 ✔ |
  | CLASS-F (control) | #2 = Gold `x⁹` ✔ | #2 ✔ |

  Both corpora are already tracked in `bulk_corpora`
  (`packages/VBFCatalog/BFA_catalog.sqlite (dataset edelpott2009_n8)`, 22 entries, modulus 285; and
  `yuwangli2014_qam_n8.sqlite`, 8,179 entries). The match is on full σ — differential *and*
  Walsh — not merely the differential spectrum.
- **Where the paper goes wrong**: Theorem 6's individual inequivalences are correct (0
  matches confirmed in the 12,923-entry file, and `beierle_scan.out` records 0 matches in the
  3.78M set), but its **premise** — that the 12,921 file is "the BBL2021 pre-2020 database" —
  is false. The genuine pre-2020 set contains all four. §I-A and §VIII cite Edel–Pott [6];
  §VI-I never checks it.

### 4. Table VII (Appendix representative S-boxes) is corrupt and contradicts Tables II, III and VI

- **Location**: Appendix, Table VII (`.tex` lines 827, 829, 831, 833).
- **Computed counter-evidence**, parsing the four 256-value LUTs straight from the `.tex`
  (all APN with δ=2, degree 2, non-permutation):
  - `σ(Table-VII CLASS-A) = σ(artifact CLASS-C)`
  - `σ(Table-VII CLASS-B) = σ(artifact CLASS-E) = σ(Gold x³)` — the row labelled "CLASS-B" is
    a Gold-`x³` function
  - `σ(Table-VII CLASS-C) = σ(Table-VII CLASS-D) = σ(artifact CLASS-D)`

  So the four printed rows realise only **three** distinct CCZ classes.
- `V_A` membership also contradicts Table III: Table-VII CLASS-A ∉ `V_A` (Table III says
  CLASS-A ∈ `V_A`); Table-VII CLASS-B ∈ `V_A` (Table III says CLASS-B ∉ `V_A`).
- Slice structure contradicts Theorem 4(3): Table-VII CLASS-A and CLASS-B share one NL=4
  slice, while CLASS-C and CLASS-D are each alone.

### 5. Remark 8's condition (2) is vacuous

- **Location**: Remark 8.
- **Evidence**: `det(M_a) = 0` is automatic, since `L_a(a) = F(0)+F(a)+F(a)+F(0) = 0`, so
  `a ∈ ker(L_a)` and `rank(M_a) ≤ 7` for every `a ≠ 0`. The paper presents it as a necessary
  extra generator "ensuring that rank-8 matrices are excluded".
- **Note**: `phase2.jl:16-20` correctly drops it and explains why — a case of the
  reproduction improving on the paper.

### 6. Citation and cross-reference defects

- §I-A and §VIII attribute *"8157 new instances by a bivariate construction"* to Edel–Pott
  [6]; the 8157 figure belongs to Yu–Wang–Li [7]. This mis-attribution is causally linked to
  paper issue 3: the author's model of "what Edel–Pott contributed" was wrong, so their
  switching-class table was never checked.
- [8] and [9] are duplicate references to the same WCC 2013 paper.
- "Section VI-H0b" is a broken cross-reference, used twice.
- §II-D's differential spectrum `{2^{2^7}·0, (2^8−1)2^7·2}` confuses exponent with
  multiplicity.

---

## Reproduction Issues

### 1. Two in-repo documents give opposite verdicts, and the wrong one emits catalog writes

- **Location**: `REVIEW_Kuznetsov_202606.md` (Catalog-gap records section:
  `n8_Kuznetsov2026_classA` … `classD`) versus `FINDINGS.md` §1-3.
- **Symptom**: `REVIEW_Kuznetsov_202606.md` instructs the catalog updater to add four
  already-published classes to `packages/VBFCatalog/src/entries/apn_catalog/n8_apn.toml` under
  `bib_key = "Kuznetsov_202606"` — the exact failure mode `sigma.jl:55-60` warns about.
- **Root cause**: the REVIEW's σ-comparison covered only `n8_apn.toml` (3 curated entries)
  instead of `list_corpora` / `bulk_corpora`, which already hold Edel–Pott 2009 and
  Yu–Wang–Li 2014.
- **Resolution plan**:
  1. Delete or supersede the Catalog-gap records in `REVIEW_Kuznetsov_202606.md`.
  2. Fold `FINDINGS.md`'s conclusion into this README as the paper verdict (done).
  3. Run `VBFCatalog.build_sigma_index!(load_catalog())` over **all** corpora and record
     `classify_ccz(reps.class_a) == (:sigma_match, "edelpott2009_n8", 18)`, and likewise for
     B, C, D.
  4. Add a regression test asserting those four `:sigma_match` sources, so the "new" claim
     cannot silently return.

### 2. `theorem6.jl` passes the Beierle-2025 check vacuously

- **Location**: `theorem6.jl:29` `const DB_BEIERLE2025 = "beierle2025_n8"`, used at `:52` and
  `:69`.
- **Symptom**: no such bulk corpus exists — `bulk_corpora` holds only `edelpott2009_n8`,
  `wengtangong2013_n8`, `yuwangli2014_qam_n8`, `taniguchi2019_n8`, `beierleleander2022_n8`,
  `beierleleanderperrin2022_n8`, `yuperrin2022_qam_n8` and `simonberg_gf4_n8`. `_sources_of`
  therefore never returns it, `in_beierle2025` is always `false`, and
  `[PASS] CLASS-X inequiv to (1),(2),(3)` prints regardless of the truth.
- **Root cause**: absence of a source is treated as evidence of inequivalence. The raw SQL at
  `:37-41` also bypasses `VBFCatalog._assert_sigma_coverage`, the guard written precisely to
  refuse this.
- **Resolution plan**:
  1. Call `VBFCatalog.list_corpora` first and print `[SKIP] database (1) not tracked` when
     `beierle2025_n8` is absent.
  2. Route lookups through `classify_ccz`, which enforces `sigma_coverage`, rather than raw
     SQL.
  3. Import the 3.78M set with the existing
     `packages/VBFCatalog/src/import/import_beierle2025.jl`, or record an explicit coverage
     gap.

### 3. `theorem6.jl` runs only when the σ-index happens to have been built elsewhere

- **Location**: `theorem6.jl:46` `idx = VBFCatalog._open_sigma_index()`.
- **Symptom**: `data/catalog/ccz_sigma_index.sqlite` is a regenerable,
  git-ignored side store (`packages/VBFCatalog/.gitignore:3`) that the `theorem6` target never
  builds. On 2026-08-15 the index existed (built by another workflow) and `make theorem6`
  exited 0; on a clean checkout `_open_sigma_index` throws *"σ-index side store not found"*
  and the target errors out. `theorem6.jl` is not in `test/runtests.jl`, so nothing catches
  either case. (An earlier revision of this file recorded the target as unconditionally
  broken; execution shows the failure is environment-dependent.)
- **Root cause**: the target assumes a build step it never performs.
- **Resolution plan**:
  1. Have the Makefile `theorem6` target run `build_sigma_index!(load_catalog())` first.
  2. Make `theorem6_report` degrade to a documented `[SKIP]` when the index is missing.
  3. Add it to `runtests.jl` behind an index-present guard.

### 4. The reproduction never evaluates Table VII but claims to

- **Location**: `theorem4.jl:1-8` header ("cross-checks Table VII"), `:42`
  `print_section("... (Table VII S-box verification)")`; `helpers.jl:242-250` docstring ("The
  six representative S-boxes from Table VII / Table III ... Source: the author's artifact").
- **Symptom**: the LUTs are the artifact's (`ccz_verify_representatives.m`), not the paper's.
  For example, paper CLASS-A begins `0,0,0,63,0,42,97,116,…` while `helpers.jl:253` begins
  `0,0,0,50,0,41,100,127,…`. The paper's printed Table VII is never evaluated, so paper issue
  4 is invisible to `make report`.
- **Root cause**: silent data substitution with a docstring claiming otherwise.
- **Resolution plan**:
  1. Add `table7.jl` that embeds or parses the four Table-VII LUTs from the `.tex`.
  2. Verify δ=2, degree 2, non-permutation.
  3. Compute σ, `V_A` membership and NL=4 slice, and `print_check` the three explicit
     contradictions with Tables II/III/VI.
  4. Retitle `theorem4.jl` to "artifact representatives" and state in `helpers.jl:242` that
     these are *not* the paper's printed tables.

### 5. §IV-E and Table I are neither reproduced nor contradicted, though the repository can do it in one line

- **Location**: `section4.jl:57-75` checks only `dim V_A = 40` and `rank = 184`;
  `exhaustive_phase2.jl:5-66` computes the projection rank but is wired into neither
  `report.jl` nor `test/`.
- **Symptom**: `make report` prints `Section IV (V_A via RREF): exact` while the paper's
  §IV-E slice count is off by `2²⁴`.
- **Root cause**: the reproduction stops at the two quantities the paper gets right.
- **Resolution plan**:
  1. In `section4.jl`, additionally report `rank(M_A[:, intra24]) = 24`,
     `rank(M_A[:, center200]) = 168`, the free-column split (32 center / 8 intra), and the
     projection rank 40.
  2. `print_check` that the paper's 16/24 split and its 65536 slice count **FAIL**, printing
     the computed values.
  3. Add these assertions to `test/test_section4.jl`.
  4. Record paper issue 1 with the corrected coverage figure (done above).

### 6. `exhaustive_phase2.jl` mixes two ANF coordinate layouts

- **Location**: `exhaustive_phase2.jl:20-25` builds `fixed_indices` with
  `ph2_vi(j,p,q) = j*28 + pair_index(p,q)` (`phase2.jl:35`), while `apply_fc22_sol22` returns
  a vector in the `col_idx(p,q,k) = pair_index(p,q)*8 + k` layout (`helpers.jl:86`).
- **Symptom**: the projected coordinate set is a permuted, wrong subset. The printed rank
  happens to still be 40, because the projection is injective either way — but
  `basis_param_indices`, which `run_slice` uses to enumerate slices, is derived from the
  wrong projection.
- **Root cause**: `helpers.jl` and `phase2.jl` use different 224-coordinate layouts, and
  `exhaustive_phase2.jl` includes both.
- **Resolution plan**:
  1. Unify on one layout, or convert explicitly at the boundary.
  2. Add a round-trip assertion `quad_anf_coeffs(quadratic_lut(c)) == c` for random `b`.
  3. Re-check `run_slice`'s slice indexing.

### 7. Algorithm 1's reported "empirical APN density" is meaningless at the default budget

- **Location**: `algorithm1.jl:23` (`sample_size::Int = 100`), `:52`
  `print_kv("empirical APN density", …)`; `report.jl:31`.
- **Symptom**: with §IV-D's density of about `10⁻⁴`, 100 samples give 0 APN with probability
  about 0.99, so the report prints `0.0 %` and labels it the empirical density — next to a
  `completeness: budget-limited (100 evaluated)` line.
- **Root cause**: the default budget is four orders of magnitude below what the claim
  requires.
- **Resolution plan**:
  1. Raise the default to `≥ 10⁵`, or expose `sample_size` in the Makefile with documented
     runtime.
  2. Report a Clopper–Pearson interval.
  3. `print_check` that the interval covers `10⁻⁴`.
  4. Otherwise label the item "density NOT estimated" instead of printing a number.

### 8. `test_novelty.jl` encodes the refuted claim as a passing assertion

- **Location**: `test/test_novelty.jl`, testset *"paper's new classes flagged novel vs small
  catalog"* — comment `# class A (a genuinely new Kuznetsov class)` and
  `@test classify_against_catalog(reps.class_a, idx) == :new` against a 4-element catalog.
- **Symptom**: a green test asserting novelty that `FINDINGS.md` refutes and that this review
  re-refuted.
- **Root cause**: the test predates the refutation, and its "catalog" is two BLP22 LUTs plus
  two Gold functions.
- **Resolution plan**:
  1. Rename the testset to describe what it actually tests (oracle mechanics).
  2. Drop the "genuinely new" wording.
  3. Add the Edel–Pott / Yu–Wang–Li `:sigma_match` assertion from issue 1.

### 9. `novelty.jl` re-implements and contradicts the VBFCatalog σ oracle

- **Location**: `novelty.jl:43` `sig_hash`, `:124` `sigma_index`, `:127` `build_sigma_index`,
  `:145-155` `save_index`/`load_index`, `:158-159`
  `classify_against_catalog(...) = (sig_hash(F) in index) ? :known : :new`.
- **Symptom**: `VBFCatalog.classify_ccz` deliberately renamed this verdict `:sigma_match`
  (`sigma.jl:290-292`: *"The status was formerly `:known`, which invited callers to read a σ
  collision as 'already in the catalog' and silently discard a genuinely new class"*).
  `novelty.jl` reintroduces `:known`, plus a parallel UInt128-truncated σ index duplicating
  `ccz_sigma_index`.
- **Root cause**: paper-local reimplementation of a core service.
- **Resolution plan**:
  1. Delete the private index.
  2. Call `VBFCatalog.sigma_hash` / `classify_ccz` / `is_novel`.
  3. Keep only the paper-specific catalog fetch and parse.
  4. Drop `:known` in favour of `:sigma_match`.

### 10. Dead and unscoped artifacts

- `solve_n7_class16.jl` (n=7, BBL2021 class 16) corresponds to nothing in this paper.
- `beierle_matches.log` is empty (0 bytes).
- `beierle_scan.out` is a committed run log with no in-repo script to regenerate it — the
  scanner lives on the `gpgpu` branch per the Makefile comment.
- `codes_mencioned_in_original_paper/apn_all.json` is gitignored, so
  `load_catalog(paper=true)` is a no-op.
- **Resolution plan**: either scope these here as "out-of-paper exploration / non-reproducible
  evidence", or move them out of the paper directory.

---

## Items Reproduced Exactly

| Paper item | File | Status |
|------------|------|--------|
| §IV-A: `A = block_diag(C(q),C(q))`, Eq. (1) | `helpers.jl:28` / `section4.jl` | exact. `A⁵ = I₈`; `A^k ≠ I₈` for k = 1,2,3,4 ✔ |
| §IV-B: `M_A` from Eq. (2) | `helpers.jl:98` | correct — the same system was re-derived independently from `F(Ax) = A F(x)` on quadratic monomials |
| §IV-C: RREF, 184 pivots / 40 free, `dim V_A = 40` | `helpers.jl:121,160` / `section4.jl` | exact ✔ (`rank(M_A) = 184`) |
| `fc22+sol22` parameterization (Eqs. 3-4) | `helpers.jl:177` | `b = 0` and random `b` land in `V_A` ✔ |
| Table III / Theorem 4 (1)(2) membership | `table3.jl`, `theorem4.jl` | exact on the six artifact representatives: **A, E, F ∈ V_A; B, C, D ∉ V_A** ✔ (direct `F(Ax) = A F(x)` test) |
| §VI-C property checks | `theorem4.jl` | all six representatives δ=2, degree 2, non-permutation ✔ |
| Table II σ distinctness and Gold identification | `table2.jl` | all six σ distinct ✔; `σ(CLASS-E) = σ(Gold x³)`, `σ(CLASS-F) = σ(Gold x⁹)` ✔ |
| Theorem 4(3) slice structure | implicit | verified directly: **class_b, class_c, class_e share one NL=4 slice** (identical 200 coefficients of pairs with `p ≤ 4`); **class_d, class_f share another**; class_a is alone. Matches Theorem 4(3) |
| §V-B Phase 2 (Gröbner) | `phase2.jl` | reimplemented open-source via `AlgebraicSolving`/msolve, with two real author slices embedded as ground truth in `test/test_phase2.jl` (exact set equality). **Executed and passing** (2026-08-15): `phase2_test` 6/6 in 59.9 s reproduces both embedded author slices — the 4-solution MULTI slice (centre + 3 neighbours) and the 1-solution SINGLE slice — with msolve and no Magma. It also *correctly* drops the paper's redundant `det(M_a)=0` generator with a written justification; Remark 8's vacuity is now verified numerically (`rank(L_a) = 7` for every `a ∈ 1..255` on all six representatives) |
| Theorem 6, database (2) | — | **NO_MATCH confirmed**: scanning `packages/VBFCatalog/BFA_catalog.sqlite (dataset beierleleander2022_n8)` (12,923 entries = the "12,921 file") gives **zero** ortho-derivative-differential-spectrum matches for CLASS-A…F |
| Theorem 6, database (1) | `beierle_scan.out` | a committed run log shows 3,775,599 Beierle-2025 entries processed, 0 matches. Not re-runnable in-repo |

## Items Missing

- §IV-D APN density experiment (10⁸ samples) — see reproduction issue 7.
- §V-A slice-signature dedup logic.
- §VI-B Table I search statistics (428 slices, 566 functions, coverage) — and Table I is wrong
  anyway (paper issue 1).
- §VI-H Table IV / Theorem 5 comparative experiments (Exp B: 532 Beierle-2025 centers; Exp C:
  20 random) — entirely absent.
- Table VI full σ-hash strings — never computed. The paper's recipe is sboxU's
  `sha256(repr(σ))[:16]`, whereas VBF's `string(sigma_key(F))` yields a different digest
  (confirmed here), so these hashes are not reproducible with VBF alone.
- Table VII — see reproduction issue 4.
- Table V's remaining rows.
- Phases 3 and 5 (collection/dedup, streaming database comparison) as runnable code.

## Test Results

Reviewed 2026-08-15 on **Julia 1.12.6**, project `/home/tiago/VBF.jl` instantiated.

```
make -C packages/VBFRepro/src/202606-kuznetsov-groebner-search test
```

**Exit code: 0. Wall time: 68 s** (one of the slower paper suites; `phase2_test` alone is
59.9 s of it — it runs two real msolve Gröbner-basis slice computations).

| Testset | Pass | Broken | Fail | Total | Time |
|---------|-----:|-------:|-----:|------:|-----:|
| `section4_test`   |  9 | 0 | 0 |  9 | 1.1 s |
| `algorithm1_test` |  8 | 0 | 0 |  8 | 0.6 s |
| `theorem4_test`   | 28 | 0 | 0 | 28 | 0.7 s |
| `table2_test`     | 15 | 0 | 0 | 15 | 1.5 s |
| `table3_test`     |  7 | 0 | 0 |  7 | 0.5 s |
| `phase2_test`     |  6 | 0 | 0 |  6 | 59.9 s |
| `anf storage`     |  7 | 0 | 0 |  7 | 0.4 s |
| `novelty oracle`  | 16 | 0 | 0 | 16 | 1.1 s |
| **Total**         | **96** | **0** | **0** | **96** | **68 s** |

Individual make targets exercised:

| Target | Exit | What it actually does now |
|--------|-----:|---------------------------|
| `make section4`   | 0 | `[PASS]` on A⁵=I₈, A^k≠I₈ (k=1..4), `dim V_A = 40`, `rank(M_A) = 184`, b=0 and random b land in `V_A`. Still reports **only** the two quantities the paper gets right (reproduction issue 5). |
| `make table2`     | 0 | Prints all six σ-signatures; `[PASS] σ(CLASS-E)=σ(Gold x³)`, `[PASS] σ(CLASS-F)=σ(Gold x⁹)`, `[PASS] all 6 σ distinct`. |
| `make table3`     | 0 | `[PASS]` A,E,F ∈ `V_A`; B,C,D ∉ `V_A`; `[PASS] all membership results match paper (Theorem 4)`. |
| `make theorem4`   | 0 | 30 `[PASS]` lines: all six reps `\|LUT\|=256`, δ=2, degree 2, non-permutation, correct `V_A` flag. |
| `make algorithm1` | 0 | Prints `APN functions found: 0` / `empirical APN density: 0.0 %` / `completeness: budget-limited (100 evaluated)` — **confirms reproduction issue 7 by execution**. |
| `make theorem6`   | 0 | **Runs.** The σ-index side store `data/catalog/ccz_sigma_index.sqlite` was present in this environment, so `_open_sigma_index()` succeeded. Output: `[PASS]` literal inequivalences for A–D, `[PASS] CLASS-A..D ∈ Edel-Pott 2009 (genuine pre-2020)`, and `[FAIL] PREMISE HOLDS (no pre-2020 set contains A..D)` — i.e. the script itself declares the paper's premise false. |
| `make novelty`    | 0 | **Runs but is a no-op.** Full output is two lines: the banner plus `catalog: MISSING — run ./fetch_catalog.sh`. `novelty_report.jl:14-16` returns early because `catalogs/` is git-ignored (`.gitignore:8`) and **`fetch_catalog.sh` does not exist anywhere in the repository**. No novelty check is performed by this target. |

`make report` and `make full` were not run (outside this review's compute budget).

**σ scan of `simonberg_gf4_n8` (196,863 entries) — now completed** via the in-repo σ-index,
confirming `FINDINGS.md`: CLASS-A 4264 hits, CLASS-B 4128, CLASS-C 2064, CLASS-D 2123,
CLASS-E 2064, CLASS-F 2127. All other tracked bulk corpora were scanned as before.

## Catalog Status

| Claimed-new class | Status |
|-------------------|--------|
| CLASS-A | **signature match** — exact Edel–Pott equivalence now verified by witnesses; other σ matches `edelpott2009_n8` #18 and `yuwangli2014_qam_n8` #3 |
| CLASS-B | **not-new** — `edelpott2009_n8` #5, `yuwangli2014_qam_n8` #6 |
| CLASS-C | **not-new** — `edelpott2009_n8` #3, `yuwangli2014_qam_n8` #4 |
| CLASS-D | **not-new** — `edelpott2009_n8` #4, `yuwangli2014_qam_n8` #5 |
| CLASS-E | **present** — equivalent to `n8_Gold_x3` |
| CLASS-F | **present** — equivalent to `n8_Gold_x9` |

**No catalog gaps. Do not add CLASS-A…D under `bib_key = "Kuznetsov_202606"`.**

**Caveat on the method**: σ-equality is necessary, not sufficient. It is exactly the
criterion the paper itself uses both to certify inequivalence (Theorem 6) and to identify
CLASS-E/F as Gold, so applying it symmetrically is fair. `FINDINGS.md` additionally reports
sboxU `are_ccz_equivalent_from_code == True` for the same four pairs, which could not be
executed here. To close it in-repo, run `VBF.ea_mappings_from_ortho_derivative` on each pair
— the complete decision for quadratic APN, by Yoshiara.

If maintainers want first-class entries for the Edel–Pott switching classes, add them under
`bib_key = "Edel_200900"` with algebraic forms from Edel–Pott Table 9 — **not** as Kuznetsov
discoveries.

## Library-Reuse Note

Helpers duplicating a `VBF` / `VBFCatalog` core export:

| Helper | Line | Should call |
|--------|------|-------------|
| `apply_matrix`, `matmul_f2`, `build_A_lut` | `helpers.jl:45, :59, :68` | `VBF.F2LinearMap` (`packages/VBF/src/representations/f2_linear_map.jl:37`) + `compose`; `permutation_order` would replace `section4.jl:42-46`'s manual `A²,A³,A⁴,A⁵` chain |
| `sigma` / `sigma_key` | `table2.jl:20-31` | `VBFCatalog.sigma_key` (`packages/VBFCatalog/src/data/sigma.jl:30`) — the definition is byte-identical |
| `sig_hash`, `sigma_index`, `build_sigma_index`, `save_index`/`load_index`, `classify_against_catalog` | `novelty.jl:43, :124, :127, :145-155, :158` | `VBFCatalog.sigma_hash` (`sigma.jl:42`), `build_sigma_index!` (`:153`), `classify_ccz` (`:298`), `is_novel` (`:322`) |
| `quad_anf_coeffs` / `coeffs_to_lut` / `quadratic_lut` | `phase2.jl:53, :66`, `helpers.jl:202` | three near-duplicates of the same F₂-ANF ↔ LUT map across two layouts; consolidate (see reproduction issue 6) |

**Correction to `REVIEW_Kuznetsov_202606.md`**: that file calls `rref_f2!`
(`helpers.jl:121`) the "strongest flag" as a duplicate of `gauss_jordan!`. It is **not** a
duplication — `gauss_jordan!` (`packages/VBF/src/linalg/f2_arith.jl:53-57`) asserts
`1 ≤ nbits ≤ 8*sizeof(T)` for `T<:Unsigned`, capping at 64 columns, whereas `M_A` has 224.
This is a genuine **core gap**, not a reuse violation.

Legitimately paper-specific (not flagged): `pair_index` / `row_idx` / `col_idx`, `build_M_A`,
`fc22_sol22`, `apply_fc22_sol22`, `in_va`, `ph2_build` / `ph2_det` / `ph2_variety` /
`ph2_to_bp`, and `representative_sboxes`.

Promote-to-core candidates:

1. **Wide-F₂ RREF** returning `(pivot_cols, free_cols, reduced_rows)` for more than 64
   columns — needed by `helpers.jl:121` and again by `solve_n7_class16.jl`; core's
   `gauss_jordan!` / `kernel_f2` cannot cover it.
2. **`self_equivalence_subspace(A)` / `in_self_equivalence_subspace(F, A)`** — the `V_A`
   construction is generic (the BBL2021 framework), not specific to class 22 or n=8.
3. **F₂-ANF quadratic pack/unpack** (`anf.jl`'s `anf_pack` / `anf_unpack`, 37-byte monomial
   packing). This is a *different object* from `VBF.encode_quadratic` /
   `decode_quadratic_lut` (`packages/VBF/src/representations/univariate.jl:382` / `:407`),
   which pack univariate `GF(2ⁿ)` coefficients — so `anf.jl` is not a duplicate, but the two
   belong side by side in core as `encode_quadratic_anf` / `decode_quadratic_anf`.

## Open Questions

- Should `REVIEW_Kuznetsov_202606.md` be deleted, or retained with a "SUPERSEDED by this
  README" banner? Its Catalog-gap records are actively dangerous to the updater.
- Is importing the Beierle-2025 3.78M corpus (`src/import/import_beierle2025.jl`) in scope,
  so `theorem6.jl` stops passing check (1) vacuously?
- `FINDINGS.md` references `verify_edelpott.py` "in this directory" — it is not present. Was
  it dropped, or gitignored?
- `solve_n7_class16.jl` and `beierle_scan.out` / `beierle_matches.log` belong to a
  `gpgpu`-branch pipeline. Should they stay under this paper directory?
