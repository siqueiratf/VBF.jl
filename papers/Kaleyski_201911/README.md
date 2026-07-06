# Kaleyski_201911 — Changing APN Functions at Two Points

**Paper:** N. Kaleyski, "Changing APN functions at two points," arXiv:1911.02608 /
Des. Codes Cryptogr. 88(8):1387–1416, 2019.

**Reproduction:** `papers/Kaleyski_201911/`

**Verdict:** **Mostly complete** — the paper's central computable claims
(Theorem 17 / Eq. 29, formula (34) / Table 2, Conjectures 21 & 22, structural
Table 1) are correctly implemented and pass 47/47 tests. `Δ_F`/DDT indexing
matches the paper exactly. One genuine soundness gap in the `F(0)=F(1)`
degenerate case; several theoretical sections reasonably not reproduced.

---

## Issue Catalog

### Paper Issues

None found. The paper's stated hypotheses are consistent (it explicitly
restricts to `F(u₁)≠F(u₂)` via Observation 7 / `v_i≠0`); the gap below is in the
reproduction not enforcing that precondition.

### Reproduction Issues

> **Status:** all three items below **resolved** (this branch). 47/47 tests pass;
> `results/report.toml` all-green.

1. **[RESOLVED] `normalize_apn` violates its own contract on `F(0)=F(1)` degenerate case (27 functions)**
   - **Location:** `helpers.jl:18-27` (`normalize_apn`); consumed by
     `conjecture22_report`, `table1_report`.
   - **Symptom:** Docstring promises `F(0)=0, F(1)=1`. Function applies only
     output shift+scale (no input transform). When `F(0)=F(1)` (n=6:1, n=7:9,
     n=8:17 catalog functions = 27 total), shifting `F(0)→0` forces `F(1)=0`, and
     the guard `if v1 != 0 && v1 != 1` silently leaves `F(1)=0`. Theorem 17's
     `F(1)=1` hypothesis is then violated but `theorem17_holds` runs anyway.
     Independent cross-check: the literal `{0,1}`-swap of these 27 is a **no-op**
     (`G=F`, still APN, `differential_uniformity==2`), yet the arithmetic returns
     `holds=false` — flagged as 27 biconditional "mismatches". Conjecture 22's
     conclusion ("no counterexample") stays correct but for an **unsound reason**
     on these 27.
   - **Root cause:** Missing enforcement of the paper's `F(u₁)≠F(u₂)`
     precondition; output-only normalization cannot achieve `F(1)=1` when
     `F(0)=F(1)`.
   - **Impact contained:** test suite exercises only n=5 (conjecture22) and n=5,6
     limit=3 (table1) — never hits the 9 n=7 / 17 n=8 cases.
   - **Resolution (applied):**
     1. Added `is_swap_degenerate(s)` predicate to `helpers.jl`.
        `normalize_apn` now **throws `ArgumentError`** on `F(0)=F(1)` instead of
        silently emitting an invalid `F(1)=0`.
     2. `conjecture22_report` and `table1_report` pre-filter degenerate functions,
        counting/reporting them as "degenerate F(0)=F(1) skipped" (n=6:1, n=7:9,
        n=8:17 = 27 total, confirmed end-to-end).
     3. Added `test_theorem17.jl` cases: `is_swap_degenerate` on power fns is
        `false`; a constructed degenerate SBox is detected and `normalize_apn`
        `@test_throws ArgumentError`.

2. **[RESOLVED] `formula34` duplicated as `_formula34_local`**
   - **Location:** `conjecture21.jl:20-28` (local copy to avoid double-include).
   - **Symptom:** Two definitions of the same closed form; drift risk.
   - **Root cause:** Include-ordering workaround.
   - **Resolution (applied):** `formula34` moved into `helpers.jl` (shared by
     `table2.jl` and `conjecture21.jl`); `_formula34_local` removed; both call
     sites reference the single definition.

3. **[RESOLVED] `conjecture21_report` tested non-power APN against the power-only formula**
   - **Location:** `conjecture21.jl` — iterated all of `apn_catalog_names()` with
     no power-function filter.
   - **Symptom:** After catalog growth (546→550), 3 non-power APN
     (`n6_Kim`, `n6_Bracken2008_fam1_trinomial`, `n8_Calderini2021_thm62`) entered
     the list; their genuine `S1 ≠ formula34(n)` flipped `conjecture21_ok` to
     `false`. Latent bug — Conjecture 21 governs only power functions (per its own
     docstring); the failing functions are outside its scope. **Not caused by the
     de-dup** (formula byte-identical); surfaced when regenerating the report.
   - **Root cause:** Missing power-function filter; relied on the curated name list
     historically containing only power functions.
   - **Resolution (applied):** Filter to catalog entries declaring a
     `monomial_exponent` (authoritative power-function marker). Now tests 24 power
     APN, all match; `conjecture21_ok = true`.

---

## Items reproduced exactly

- **Theorem 17 (Eq. 29)** — `helpers.jl:theorem17_holds` computes `6·Δ_F(1,0)`
  vs `S1+S2` from the DDT. Indexing verified: `Δ_F(a,b)=ddt[a+1,b+1]`,
  `S1=Σ_y Δ_F(y,F(y)⊕1)`, `S2=Σ_y Δ_F(y⊕1,F(y))`. Cross-check confirmed the
  biconditional `differential_uniformity(G)==2 ⟺ theorem17_holds` for all 550
  non-degenerate catalog APN n=5..8 (0 mismatches).
- **Formula (34) / Table 2** — `table2.jl:formula34`; DDT-verified n=2..10,
  matches paper values 30,78,126,222,510,1086 (n=5..10) exactly.
- **Conjecture 21** — `conjecture21.jl` verifies `S1(F)=formula34(n)` for all
  catalog power APN; `report.toml` `conjecture21_ok=true`.
- **Conjecture 22** — `conjecture22.jl` confirms Theorem 17 condition fails for
  all 546 catalog APN n=5..8; no counterexample.
- **Table 1 (structural)** — `table1.jl` computes S1,S2 and verifies
  `S1+S2 > 12` (Observation 18 logic).

## Not reproduced (reasonable — theoretical/out-of-scope)

- **Table 1 exact numeric (S1,S2) pairs** per Edel-Pott index — repo uses catalog
  representatives (superset) + inequality check only; acknowledged in
  `table1.jl:14-18`. S1,S2 are representative-dependent.
- **Walsh-transform derivation chain** (Props 12–16; Obs 11,15) — only final
  Eq. 29 evaluated.
- **§3 general two-point change** (Prop 4, Cor 5, Prop 6).
- **§6 power-function proof** (Obs 23–27, Prop 26), **§7 equivalence**
  (Props 28–30) — theoretical.

## Test results

- `julia --project=. papers/Kaleyski_201911/test/runtests.jl` → **47/47 pass**
  (theorem17 13/13, table2 9/9, table1 21/21, conjecture22 4/4; ~5s).
- `results/report.toml`: all five claim flags `true`, `total_checked=546`.

## Catalog status

**N/A** — no new APN functions claimed. Paper is a construction/characterization
using pre-existing APN inputs (power functions + Edel–Pott 2009 switching
classes). No catalog-gap records.

## Library-reuse note

`helpers.jl` correctly reuses VBF core (`SBox`, `ddt`, `gf_inv`, `gf_mul`,
`print_section`, `print_check`, `print_kv`, `gf_monomial_lut`,
`primitive_polynomial`, `inputbits`). Paper-specific helpers (`normalize_apn`,
`compute_s1/s2`, `theorem17_holds`, `formula34`) correctly kept local. Minor:
`print_header` (`helpers.jl:11`) hand-rolls a banner where core `print_banner`
exists (optional). No promote-to-core candidates.
