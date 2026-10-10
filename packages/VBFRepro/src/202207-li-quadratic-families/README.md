# Li_202207 — Two New Families of Quadratic APN Functions

## Audit corrections (2026-10-10)

The audit fixes F006/F007 now follow the supplied LaTeX Theorem 3 exactly:
`L(z)=z^(2^(m+s))+μ z^(2^s)+z`, with nonzero `v` in the **embedded** GF(2^m).
The constructor checks the norm, permutation and scalar hypotheses. Table V row
12 (`m=3,s=1,μ=32,v=336,modulus=529`) has a pinned LUT digest independently
recomputed with polynomial-bit field arithmetic, APN verification and an
ortho-derivative spectrum regression. Exhaustive μ search at `(m,s)=(2,1)`
returns no admissible parameter. Tests verify all seven nonzero embedded GF(8)
scalars and reject an ambient-field scalar. These are finite computational
checks; Γ-rank, family-wide coverage and literature novelty remain unverified.
The historical implementation issues below are retained as review history.


**Paper**: Li, Zhou, Li, Qu. "Two New Families of Quadratic APN Functions." *IEEE
Transactions on Information Theory* **68**(7):4761-4769, 2022.

**Reproduction path**: `packages/VBFRepro/src/202207-li-quadratic-families/`

**Verdict**: Partial

Theorem 2 is reproduced correctly and its hypothesis shown tight. Theorem 3 is implemented
with the **wrong Frobenius exponent**, which produces a *silent false PASS*: the search for
valid `μ` is internally consistent with the wrong `L`, so nothing ever trips, and the report
prints a PASS at m=2 where the paper's Theorem 3 is in fact vacuous. A stated hypothesis on
`v` is dropped. The paper's entire novelty and coverage argument (Tables IV and V, and the
two "our family covers X" claims) is unreproduced, even though the ortho-derivative part of
it is cheap.

---

## Paper Issues

**None found.** Every checkable claim in the `.tex` is correct: Theorem 2 is APN and its
hypothesis is tight; Theorem 3's conditions are tight; Table V row 12's instance is APN with
`L` a permutation and `μ^{2^{2m}+2^m+1} ≠ 1`; and both coverage claims are confirmed (see
Items Reproduced).

---

## Reproduction Issues

### 1. Theorem 3 uses the wrong Frobenius exponent (`2^{2m+s}` instead of `2^{m+s}`)

*Highest severity — it produces a silent false PASS.*

- **Location**: `helpers.jl:56` (`e_high = 1 << (2m + s)`) and `theorem3.jl:38` (the same).
  Mis-transcribed in prose at `helpers.jl:47`, `theorem3.jl:8`, `:19`, `:32` and `:67`.
- **Symptom**: `theorem3_report` and `theorem3_test` build
  `f(z) = (z^{2^{2m+s}} + μz^{2^s} + z)^{2^m+1} + v z^{2^m+1}`. The paper's Theorem 3
  (`.tex:179`) and Table V row 12 (`z^16 = z^{2^4}` with m=3, s=1) both give `z^{2^{m+s}}`.
  Actual versus expected at m=3, s=1: the repository's smallest valid `μ` is **12**, the
  paper's is **6**; the two 126-element `μ`-sets differ. The repository's n=9 output has
  ortho-derivative DDT `{0:169939, 2:68040, …}` versus the paper's Table V instance
  `{0:171178, 2:66297, …}`.
- **Root cause**: a transcription error `2^{m+s}` → `2^{2m+s}`, propagated consistently into
  `find_valid_mu`, so the search never trips.
- **Why the tests do not catch it** (established by execution, 2026-08-15): `tests/test_theorem3.jl:16-19`
  and `:24-25` guard each loop with `found || continue`. With the repo's wrong `e_high` the m=2
  iterations run and 10 assertions pass; with the paper's `L`, `find_valid_mu(2,1)` returns
  `(-1, false)`, the m=2 branch is *skipped*, and the suite silently drops to 7 assertions —
  still green. The suite is **structurally incapable of failing on this bug in either
  direction**, so the 18/18 pass recorded under "Test Results" carries no evidence whatsoever
  about Theorem 3. The pinned Table V row-12 regression test (step 3 below) is the only thing
  that would close this.
- **The wrong function is itself APN** (execution, 2026-08-15): `theorem3_sbox` with
  `e_high = 2^{2m+s}` yields `du=2, deg=2` at m=2 (n=6, μ=6) and m=3 (n=9, μ=12). Its n=9
  ortho-derivative DDT spectrum `{0:169939, 2:68040, 4:15561, 6:6034, 8:1533, 10:420, 12:126,
  14:21, 16:84, 18:189, 20:126, 22:63, 26:7, 512:1}` differs from the paper's Theorem 3
  instance and matches **no** n=9 catalog entry (TOML or sqlite). So the repository currently
  prints PASS for a quadratic APN function that is CCZ-inequivalent to the one the paper
  proves — not "not APN", but "APN and the wrong function". It must **not** be added to the
  catalog under Li's name.
- **Resolution plan**:
  1. Change both `e_high` sites to `1 << (m + s)`.
  2. Fix the five prose sites.
  3. Add a regression test pinning the Table V row-12 instance (n=9, modulus 529, `u=2`,
     `μ = u^5 = 32`, `v = u^73 = 336`) to δ=2.
  4. Re-run `report`.

### 2. Spurious PASS at m=2 (a consequence of issue 1)

- **Location**: `theorem3.jl:62` (`ms = [2,3]`), `report.jl:23`, and the
  `tests/test_theorem3.jl` loop `for m in [2,3]`.
- **Symptom**: the report prints
  `[PASS] m=2 n=6 diff-uniformity=2, μ (first valid) = 6`. With the paper's `L`,
  `find_valid_mu(2,1)` returns **no** valid `μ` at all — exhaustively over all 63 nonzero `μ`
  of `F_{2^6}`. Theorem 3 is vacuous at m=2, consistent with Remark 1's `m ≥ 3`.
- **Root cause**: issue 1 — the repository's `L` admits 12 valid `μ` at m=2.
- **Resolution plan**:
  1. Fix issue 1.
  2. Confirm the m=2 line changes to `[SKIP] no valid μ`.
  3. Change the `theorem3.jl:12-13` comment ("For m = 2 valid μ may or may not exist") to
     state the verified fact.
  4. Keep m=2 in `ms` only as a documented negative case.

### 3. Theorem 3's `v` hypothesis is mis-stated as `F*_{2^{3m}}`

- **Location**: `theorem3.jl:7` (comment), `:59` (docstring "any v ∈ F*_{2^{3m}} works"),
  `report.jl:33`; the `Makefile` exposes `v=`.
- **Symptom**: the paper (`.tex:179`) requires `v ∈ F*_{2^m}`. Counter-evidence at m=3, s=1,
  `μ=6` (the paper's `L`): exactly **7** of the 511 nonzero `v` give δ=2, and they are
  exactly `F*_{2^3} = {1, 28, 29, 332, 333, 336, 337}`; `v=2` gives δ=16.
- **Root cause**: the hypothesis was dropped during transcription. The default `v=1` masks
  it.
- **Resolution plan**:
  1. Correct the three documentation sites.
  2. Add a guard `in_subfield(v, m, 3m; modulus) && v != 0` in `theorem3_sbox`.
  3. Add a test asserting the 7-element `v`-set at m=3.

### 4. The novelty argument is entirely absent

- **Location**: `report.jl:31-32` dismisses Tables IV and V as "out of scope".
- **Symptom**: no reproduction of the Tables IV/V representatives, no inequivalence check,
  and no coverage check. The Γ-rank is indeed infeasible (`_design_rank_guard` caps `n ≤ 7`,
  `packages/VBF/src/invariants/design_ranks.jl:76`), but the ortho-derivative-based
  separation is cheap — it ran in seconds here — and both coverage claims are checkable at
  n=8 and n=9.
- **Root cause**: the whole novelty section was scoped out on the strength of the Γ-rank
  alone.
- **Resolution plan**:
  1. Add `table4.jl` / `table5.jl` building the 11+11 representatives.
  2. Replace the Γ-rank with `apn_ea_mugshot` pairwise separation, valid for CCZ among
     quadratic APN (Yoshiara).
  3. Add the Edel–Pott 1.9 and Beierle–Leander instances and assert mugshot equality with
     Theorem 2 (m=4) and Theorem 3 (m=3).

### 5. Docstring exponent typo

- **Location**: `theorem3.jl:31` writes `f(z) = L(z)^{2^{m+1}} + v·z^{2^{m+1}}`; the code
  (`:40`) correctly uses `(1<<m)+1`. Cosmetic, but it contradicts the neighbouring line.

### 6. Stray input file from a different paper

- **Location**: `input/tex_source/calderini_li_villa_2204.07462.tex`.
- **Symptom**: this is arXiv 2204.07462, "Two new families of bivariate APN functions"
  (Calderini–Li–Villa) — a *different* paper whose reproduction lives at
  `packages/VBFRepro/src/202306-calderini-bivariate-families/`. It is tracked in git under this paper's `input/`.
- **Resolution plan**: remove it from this paper's `input/`.

---

## Items Reproduced Exactly

| Paper item | Status | Evidence |
|------------|--------|----------|
| Theorem 2, `f(x,y)=(x³+xy²+y³+xy, x⁵+x⁴y+y⁵+xy+x²y²)` over `F_{2^m}²` | fully reproduced, APN verified | `theorem2.jl:30`. δ=2, deg=2 at m=2,4,5,7 (n=4,8,10,14) |
| `gcd(3,m)=1` hypothesis necessity | verified beyond what the repository checks | m=3 → δ=16; m=6 → δ=128 |
| `f(0,0)=(0,0)` and the guards | reproduced | `tests/test_theorem2.jl` |
| Theorem 3 *shape* (`L(z)^{2^m+1}+v z^{2^m+1}`, exhaustive `μ` search, APN check) | structure present, **formula wrong** | see reproduction issue 1 |

### Verified as reproducible but not implemented

- **Section II coverage claim 1** — Theorem 2 covers Edel–Pott Table 9 No. 1.9; the explicit
  polynomial is given at `.tex:240-242`. Verified: Li Theorem 2 at m=4 has ortho-derivative
  DDT signature `{0:38415, 2:22104, 4:4536, 6:456, 8:24, 256:1}`, identical to member **#12
  of the `edelpott2009_n8` corpus** (22 members, 22 distinct signatures). The claim holds;
  the reproduction does not check it.
- **Section II coverage claim 2** — Theorem 3 covers Beierle–Leander n=9 No. 9; the explicit
  36-term polynomial is at `.tex:249-257`. Verified: δ=2, deg=2, ortho-derivative DDT
  `{0:171178, 2:66297, 4:15911, …, 512:1}` — identical to Table V row 12 **and** to the
  Theorem-3 member `(s,μ,v) = (1,15,28)`. The claim holds; the reproduction does not check
  it.
- **Table IV** (n=8, 12 rows plus Γ-rank 14034 for Theorem 2) — the Γ-rank is legitimately
  out of scope, but the 12 representative functions and their pairwise ortho-derivative
  separation are cheap and are not built.
- **Table V** (n=9, 12 rows plus Γ-rank 48558 for Theorem 3) — same; row 12
  `(z^16+u^5 z^2+z)^9+u^{73} z^9` is not constructible at all with the current code (see
  reproduction issue 1).
- **Lemmas 1, 2, 3, 4, 5** — none implemented (Lemma 5(i)-(v) is the bulk of Section IV).
- **Remark 1** (Bartoli et al., `μ` exists for `m ≥ 3`, `s=1`) — only referenced in comments.

## Test Results

Reviewed 2026-08-15 on Julia 1.12.6, project `/home/tiago/VBF.jl` (instantiated + precompiled).

| | |
|---|---|
| Command | `make -C packages/VBFRepro/src/202207-li-quadratic-families test` (tests live in `tests/`, not `test/`) |
| Exit code | **0** |
| Wall time | **3 s** (including `Pkg.instantiate()`) |

| Testset | Pass | Broken | Fail/Error | Total | Time |
|---------|-----:|-------:|-----------:|------:|-----:|
| `theorem2_test` | 8 | 0 | 0 | 8 | 0.4s |
| `theorem3_test` | 10 | 0 | 0 | 10 | 0.4s |
| **Total** | **18** | **0** | **0** | **18** | — |

No `results/` artifact is produced or committed for this paper.

> **Caveat**: the green suite does **not** validate Theorem 3. The 10 passing assertions in
> `theorem3_test` are computed with the wrong Frobenius exponent (Reproduction Issue 1), and
> the suite is structurally blind to the bug — see the note under Issue 1.

Re-verified 2026-08-15 with the repository's own Julia API (`gf_pow`/`gf_mul`,
`differential_uniformity`, `algebraic_degree`, `ortho_derivative`+`ddt`, `apn_ea_mugshot`,
`load_apn_function`, `load_catalog`/`list_functions`/`corpus_function`): Theorem 2
(m=2,3,4,5,6,7); Theorem 3 under both exponent variants (m=1,2,3; s=1); Table V row 12; the
Edel–Pott and Beierle–Leander coverage claims; the `v`-set at m=3; catalog comparison at n=8
and n=9. **Every number reproduced exactly; no disagreement with the earlier Python
derivation.**

## Catalog Status

| Claimed-new object | Status | Evidence |
|--------------------|--------|----------|
| Theorem 2 family at n=8 (Table IV row 12) | **present** (unnamed) | ortho-derivative DDT `{0:38415, 2:22104, 4:4536, 6:456, 8:24}` matches `reprs8_11` and `SimonBerg_GF4_n8_class_7` in `BFA_catalog.sqlite`, and `edelpott2009_n8` member 12 — exactly as the paper predicts, since it covers Edel–Pott 1.9. Not in `n8_apn.toml` as a *named* entry |
| Theorem 3 family at n=9 (Table V row 12) | **missing** | compared against all quadratic APN n=9 database entries (`n9_Gold_x3/x5/x17/i5/i7/i8`, `n9_Kasami_i8`, `n9_Budaghyan2009_eq7/eq8`, `n9_BCL2008_Tr_x9_x3`, `n9_EdelPott2009_x3_x10_x136`, `n9_Yu2020_f7_known`) — no ortho-derivative DDT match |

### Catalog-gap record (1 entry)

```
target file : packages/VBFCatalog/src/entries/apn_catalog/n9_apn.toml
name        : n9_Li2022_thm3
n = 9, m = 9, is_permutation = false
algebraic_form : "(z^{2^{m+s}} + mu*z^{2^s} + z)^{2^m+1} + v*z^{2^m+1} over GF(2^9),
                  m=3, s=1, mu=u^5=32, v=u^73=336, modulus x^9+x^4+1 (=529), u = 2"
bib_key : Li_202207
source  : Li, Zhou, Li, Qu, IEEE Trans. Inf. Theory 68(7):4761-4769 (2022), Theorem 3;
          Table V row 12. Verified APN (differential_uniformity = 2, algebraic_degree = 2);
          L permutes GF(2^9) and mu^{2^6+2^3+1} != 1. CCZ-equivalent (OD-DDT evidence) to
          the Beierle-Leander 2021 sporadic No. 9 over F_2^9 that the paper claims to cover.
lut     : regenerate deterministically as
          [gf_pow(gf_pow(z,16,9;529) XOR gf_mul(32,gf_pow(z,2,9;529)) XOR z, 9, 9;529)
            XOR gf_mul(336, gf_pow(z,9,9;529)) for z in 0:511]
          first 16 = [0,419,133,318,250,47,192,13,165,216,385,484,149,414,270,29]
          sha256(csv)[:16] = 575b6e5c67cb81fa
equivalence evidence :
  OD-DDT spectrum = {0:171178, 2:66297, 4:15911, 6:5705, 8:1974, 10:385, 12:140, 14:84,
                     16:168, 18:147, 20:63, 22:63, 24:21, 26:7, 512:1}
  no n=9 catalog entry (data-raw TOML or BFA_catalog.sqlite) shares this spectrum.
```

**Optional (naming only)**: `n8_Li2022_thm2` for the bivariate Theorem-2 instance at m=4 —
the *class* already exists as `reprs8_11`, so this is an alias/naming gap, not a new class.
LUT: `bivariate_lut(4, …; modulus=19)`, first 16 =
`[0,17,104,111,124,122,113,97,26,127,31,108,24,106,120,28]`, sha256[:16] =
`d9328cf003817977`.

## Library-Reuse Note

| Helper | Line | Verdict |
|--------|------|---------|
| `bivariate_lut` | `helpers.jl:29` | **promote-to-core** — the same primitive is re-implemented in `packages/VBFRepro/src/202100-calderini-construction-relations/helpers.jl`. Belongs in `packages/VBF/src/` as e.g. `bivariate_lut(m, f1, f2; modulus)` |
| `find_valid_mu` permutation test | `helpers.jl:70-77` | **reuse violation (minor)** — a hand-rolled `seen` array; should be `is_permutation(SBox{3m}(L))` |
| `print_header` | `helpers.jl:16` | correct — delegates to `print_banner` |
| everything else | — | good reuse: `gf_mul`, `gf_pow`, `primitive_polynomial`, `differential_uniformity`, `algebraic_degree`, `print_section` / `print_check` / `print_kv` |
