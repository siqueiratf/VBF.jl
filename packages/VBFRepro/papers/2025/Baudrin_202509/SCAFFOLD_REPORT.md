# Scaffold report

The Stage 1 inventory existed and was retained. The following files were
created for the scoped Section 3 workflow; no core files or another paper's
files were modified by the scaffold stage.

| File | Type | Purpose |
|---|---|---|
| `.gitignore` | new | Ignore private inputs and optional generated artifacts |
| `helpers.jl` | new | VBF imports and paper-specific report banner |
| `section31.jl` | new | Native-generator Walsh-zero orbit pipeline |
| `section32.jl` | new | Six-bit known-class census |
| `conjecture1.jl` | new | Bounded switching evidence, not a proof |
| `catalog_validation.jl` | new | Isolated VBFCatalog dataset access |
| `report.jl` | new | Small aggregate report |
| `Makefile` | new | Bounded defaults and explicit full census target |
| `test/runtests.jl` | new | Fast test entry point |
| `test/test_section31.jl` | new | Orbit and certificate checks |
| `test/test_section32.jl` | new | Census input/count checks |
| `test/test_conjecture1.jl` | new | Budget and witness checks |
| `results/.gitkeep` | new | Optional output-directory placeholder |
| `PLAN.md` | new, locally ignored | Validated implementation contract |
| `input/main.pdf` | new, ignored | User-provided source PDF |

Total created: 15 files. Retained without replacement: `EXPERIMENTS.md`.
`README.md` and `REVIEW.md` are written by the implementation/review stages.

Theory inventory entries share the Section 3 checks where appropriate; there
are no separate empty theorem/proposition stubs. The inventory's proposed
`section32_switching.jl` maps to `conjecture1.jl`, matching the paper's own named
conjecture and explicitly including its preceding switching discussion.

At scaffold time computation functions return `:not_implemented`, and the
tests contain deliberate failing placeholders. These are transitional stage
artifacts to be replaced before the work is committed or called reproduced.
