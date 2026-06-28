# PLAN: Kalgin & Idrisova (2020) — Classification of Quadratic APN Functions in 7 Variables

## Source material

- `input/kalgin_idrisova_quadratic_apn_7_variables.tex` — full paper
- `input/paper_info.txt` — artefact availability summary
- No author code released. Clean-room replication only.

## Reproduction scope

| Claim | File | Status |
|---|---|---|
| Prop. 2: APN extension criterion via QAM | `proposition2.jl` | exact (small n); bounded demo n=5→6 |
| §3 recovery of all CCZ classes for n=3,4,5 | `proposition2.jl` | exact |
| §4 cyclic T matrix construction | `section4.jl` | exact (n≤6); n=7 function verified |
| §4 new n=7 APN function (univariate poly form) | `section4.jl` | exact |
| §5 five second-row cases for n=7 | `section5.jl` | exact (data) |
| §5 counts 3+2+0+220+263=488 CCZ-classes | `section5.jl` | loaded from paper (exhaustive infeasible) |
| §6 Table 3 stacked APN examples | `table3.jl` | exact |
| §6 stacked APN definition and switching theorem | `table3.jl` | exact (verification) |

Out of scope:
- Exhaustive n=7 classification (requires supercomputer time)
- n=8 second-row enumeration (stated as "being computed" in the paper)
- Multiplier groups / automorphism groups

## Architecture

- Paper folder is orchestration only. No new math added to `packages/VBF`.
- Reuses: `is_qam`, `qam_to_sbox`, `quadratic_apn_matrix`, `extend_quadratic_apn`,
  `apn_ea_mugshot`, `algebraic_degree`, `differential_uniformity`, `anf`, `mobius!`,
  `polynomial_to_lut`, `primitive_polynomial`, `gold_apn`.
- `VBFCatalog` used only in `report.jl` for optional catalog cross-check.

## File layout

```
proposition2.jl    §3 — secondary APN extension approach (Proposition 2)
section4.jl        §4 — cyclic matrix T construction + new n=7 APN function
section5.jl        §5 — five second-row cases for n=7, classification data
table3.jl          §6 — stacked APN function examples (Table 3)
helpers.jl         shared report utilities and quadratic_part extraction
report.jl          paper_report() top-level driver
Makefile
test/runtests.jl
test/test_proposition2.jl
test/test_section4.jl
test/test_section5.jl
test/test_table3.jl
```

## Makefile parameters

- `limit` — max APN functions per search (default: typemax)
- `save_results` — write TOML to results/ (default: false)
- `seed` — RNG seed (default: 42)
- `full_search` — enable exhaustive n=6+ searches (default: false)

## Acceptance criteria

- `make -C papers/Kalgin_202000 test` passes in under 2 minutes.
- `make -C papers/Kalgin_202000 report` completes without long search.
- New n=7 function verified APN and quadratic.
- Table 3 examples verified: F APN, F^(2) APN, deg(F)=3, deg(F^(2))=2.
- Proposition 2 verified on small examples.
