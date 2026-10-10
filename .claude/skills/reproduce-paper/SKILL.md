# Skill: reproduce-paper

Use this skill when the user asks to reproduce a new paper in this repository.

---

## Goal

Reproduce a published cryptography paper using VBF/VBFCatalog primitives.
The aim is to reconstruct the authors' algorithmic path faithfully, not to
populate the catalog or produce a second implementation of core VBF logic.

---

## Inputs to gather before starting

1. **Paper identifier** — YYYYMM-author-subject slug, e.g. `202508-beierle-millions`.
2. **PDF (mandatory).** Place the paper PDF in `packages/VBFRepro/src/<slug>/input/`. The agent
   reads the PDF directly — no intermediate conversion. Place the
   `routines_to_implement_list.txt` checklist in
   `packages/VBFRepro/src/<slug>/codes_mencioned_in_original_paper/`.
3. **TeX source (fetch from arXiv when available).** TeX source is the
   preferred reading medium: theorem environments carry exact statement numbers,
   `algorithmic` blocks give pseudocode verbatim, and formula macros resolve
   unambiguously. Steps:
   a. Find the arXiv ID. Search `https://arxiv.org/search/` by author+title, or
      look for a DOI redirect. The ID looks like `2107.12345` or `cs/0312045`.
   b. Download the source tarball and extract it:
      ```bash
      mkdir -p packages/VBFRepro/src/<slug>/input/tex_source
      curl -L "https://arxiv.org/e-print/<arxiv_id>" \
           -o /tmp/paper_source.tar.gz
      tar -xzf /tmp/paper_source.tar.gz \
          -C packages/VBFRepro/src/<slug>/input/tex_source/ 2>/dev/null || \
        cp /tmp/paper_source.tar.gz \
           packages/VBFRepro/src/<slug>/input/tex_source/<slug>.tex
      ```
      (Some arXiv submissions are a single `.tex` file instead of a tarball;
      the fallback `cp` handles that case.)
   c. The `tex_source/` folder is gitignored (matches `packages/VBFRepro/src/*/input/`).
      Do not commit it.
   d. When the TeX source is present, **read it instead of the PDF** for
      theorem statements, algorithm bodies, and table definitions. Use the PDF
      only for figures or context the TeX alone does not clarify.
   e. If the paper is not on arXiv (proceedings-only, behind paywall with no
      preprint), skip this step and note it in `PLAN.md`.
4. **Author artifact** — any reference code the authors published (e.g. a `.py`
   file). Drop it in `packages/VBFRepro/src/<slug>/codes_mencioned_in_original_paper/`.
5. **Reproduction scope** — which theorems/claims are practical to validate?
   Identify which ones need only small/bounded runs and which are
   computationally infeasible to run in full.

---

## Folder structure to create

```
packages/VBFRepro/src/<slug>/
  Makefile
  helpers.jl
  report.jl
  <claim1>.jl               # one file per major paper claim / section
  <claim2>.jl
  ...
  input/
    <filename>.pdf          # source PDF (gitignored — copyrighted)
    paper_info.txt
  codes_mencioned_in_original_paper/
    routines_to_implement_list.txt
    <author_artifact>       # e.g. reference.py
  results/                  # generated artifacts (git-ignored via .gitignore pattern)
  test/
    runtests.jl
    test_<claim1>.jl
    test_<claim2>.jl
    ...
```

Use `packages/VBFRepro/src/202201-beierle-quadratic-instances/` as the canonical reference for multi-claim papers —
it is the most complete and consistently structured example in the repository.
Single-claim reproductions also use a slug folder with a Makefile and tests.

**Naming rule (MANDATORY for multi-file papers):** implementation file names must
mirror the paper's own section/theorem/algorithm names exactly — `theorem1.jl`,
`algorithm1.jl`, `lemma4.jl`, `proposition2.jl`, `table1.jl` — NOT descriptive
paraphrases like `correspondence.jl`, `search.jl`, or `classification.jl`.
This 1:1 mapping lets the paper be opened side-by-side with the code and read
directly against the implementation without translation.

---

## Architecture constraints

- **Do not add paper-specific algorithms to `packages/VBF`** unless they are
  general, reusable VBF functionality. The paper folder is an orchestration
  layer only.
- **Do not add any dependency from `VBF` to `VBFCatalog`.**
- Reuse existing VBF APIs — search `packages/VBF/src/` before writing new math.

### Reuse VBF core — do NOT reimplement in `helpers.jl`

`helpers.jl` is for **paper-specific** math only (the paper's own LUT builders,
its bespoke search/partition logic). Generic utilities already live in `VBF` and
are available after `using VBF`. **Never copy these into a paper folder** — call
the core function. If a paper needs a generic primitive that core lacks, add it
to `packages/VBF/src/` (general and tested), not to `helpers.jl`.

| Need | Use from `VBF` (do not redefine) |
|---|---|
| Report banner / section / check / kv / status | `print_banner`, `print_section`, `print_check`, `print_kv`, `status_str` |
| Field arithmetic | `gf_mul`, `gf_pow`, `gf_inv`, `primitive_polynomial`, `conway_polynomial` |
| Traces & subfields | `gf_trace` (absolute), `gf_relative_trace` (`Tr_{2ⁿ/2ᵏ}`), `in_subfield`, `subfield_elements`, `gf_is_dth_power` (cube/7th-power/…) |
| Monomial / polynomial LUT | `gf_monomial_lut`, `polynomial_to_lut`, `terms_to_lut`, `evaluate_polynomial` |
| Known families | `gold_apn`, `kasami_apn`, `welch_apn`, `niho_apn`, `dobbertin_apn`, `kim_apn`, `bcl_apn`, `bcp_apn`, `taniguchi_apn` |
| F₂ linear algebra | `rank_f2`, `kernel_f2`, `solve_f2`, `span_from_basis`, `smallest_basis`, `gauss_jordan!`, `F2LinearMap`, `F2AffineMap` |
| Spectra / invariants | `ddt`, `lat`, `walsh_transform`, `differential_uniformity`, `differential_spectrum`, `algebraic_degree`, `ortho_derivative` |
| APN / permutation tests | `is_quadratic_apn`, `is_permutation`, `is_qam`, `inverse_apn` (monomial `x^{2ⁿ−2}`), `compositional_inverse` (functional inverse of a permutation) |

The report emitters accept the `IO` either first or last (`print_check(io, label,
ok)` or `print_check(label, ok)` — `stdout` default). Keep only a paper-specific
`print_header`/banner local; the generic four come from core.

> `differential_uniformity` streams one input difference at a time (`O(2ᴺ)`
> memory), so it is safe for large `N` — do not reimplement a row-wise variant.
>
> Larger structures still living in individual paper helpers (promote to core
> only when a second paper needs them): the backtracking partial-DDT APN search
> engine (`Beierle_202107`), GF(2) matrix algebra over Nemo/BitMatrix —
> RCF/similarity/multiplicative-order (`Beierle_202107`, `Canteaut_202205`), and
> Jacobian/EA-recovery tooling (`Canteaut_202205`).
- Use `VBFCatalog` only as an *optional comparison layer*. Do not frame the
  reproduction as a database-population task.
- Keep S-box encoding consistent: zero-based integer LUT values, Julia 1-based
  array storage (`lut[x+1]`).
- No hard-coded absolute paths — use `@__DIR__`, Makefile-derived `$(ROOT)`, or
  `joinpath`.

---

## Single-claim script pattern

```julia
using VBF
using VBFCatalog   # only if needed

function reproduce()
    # ... compute ...
    (; field1 = val1, field2 = val2)   # NamedTuple
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# <Paper title>")
    # ... print key results ...
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
```

Add a `test/runtests.jl` in the reproduction folder that checks frozen expected
values from `reproduce()`. Give the folder a standalone Makefile test target.

---

## Multi-file paper Makefile template

```makefile
JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report clean_results

# Overridable parameters
limit          ?= 2147483647
max_evaluations ?= 1048576
sample_size    ?= 25
save_results   ?= false
seed           ?= 42
full_search    ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

# Add one target per paper claim/section
<claim_target>:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "<claim>.jl")); \
	   print_header(); <claim>_report()'

help:
	@echo 'Paper: <AuthorYear> — <Title>'
	@echo 'Targets: test  report  <claim_target>  clean_results'
	@echo 'Params:  limit  max_evaluations  sample_size  save_results  seed  full_search'
```

Always run under the root project (`--project=$(ROOT)`), never `--project=.`
inside a paper folder.

---

## Experiment constraints

- Every expensive computation must be guarded by `limit`, `max_evaluations`,
  `timeout_seconds`, or equivalent parameters.
- **Do not silently write generated results.** Require `save_results=true` or a
  dedicated Makefile target.
- Store generated artifacts under `packages/VBFRepro/src/<slug>/results/` (already excluded by
  `.gitignore` pattern `packages/VBFRepro/src/*/results/`).
- If a search is intentionally bounded, the output **must** state whether the
  result is exhaustive or budget-limited.
- Full/expensive searches are an **explicit opt-in** via `full_search=true` or a
  named Makefile target. The default path must complete in ≤ a few minutes.
- Keep randomness deterministic: require an explicit `seed` and print it.
- Deduplicate results with `apn_ea_mugshot` where appropriate.

---

## Each script file: opening pseudocode block

Every `.jl` file in the paper folder must begin with a short commented block:

```julia
# Implements <Paper Section / Theorem / Proposition title>
# Paper: <Author> et al. (<Year>), "<Title>", <Venue>
# Section: <X.Y — Section title>
#
# Pseudocode:
#   1. ...
#   2. ...
# VBF API used: <function1>, <function2>
```

Name algorithms, corollaries, and test-set entries after the paper's own
section/theorem names. If a claim is split across files, document the link.

---

## Report format

Use the report emitters exported by `VBF` (see the reuse table above). **Do not
define `print_section` / `print_check` / `print_kv` / `status_str` in
`helpers.jl`** — they are canonical in core. Each `<claim>_report` function
prints to an `IO` argument (default `stdout`):

```
## <Claim title>                    ← print_section(title, io)
  [PASS] <check description>        ← print_check(label, ok, io)
  key: value                        ← print_kv(key, value, io)
  completeness: exhaustive/budget-limited (N evaluated)
```

The top-level `paper_report` function (always named `paper_report`, not `report`)
prints a header with: paper name, field parameters, Julia version, date, and
reproduction scope (what is exact, what is bounded, what is intentionally not
run). Build the header from `print_banner(io, line1, line2, …)`; only the
header text is paper-specific.

---

## Test file conventions

Follow the `packages/VBFRepro/src/202201-beierle-quadratic-instances/test/` pattern exactly:

- `test/runtests.jl`: `using Test; using VBF` (add VBFCatalog only if the tests
  actually use it), then bare `include("test_<claim>.jl")` lines — no wrapper
  `@testset` here.
- Each `test/test_<claim>.jl`:
  - First line: `@testset "<claim>_test" begin`
  - Second line: `include(joinpath(@__DIR__, "..", "<claim>.jl"))` — the test
    file loads the implementation it tests
  - Then test assertions
  - Close with `end`
- Use small budgets in tests — `limit = 1..5`, `max_evaluations = 1 << 16..17`.
  Exhaustive counts (e.g., "n=6 → exactly 13 classes") belong in `paper_report()`,
  not in the fast test suite.
- For QAM papers: always include a round-trip test
  (`quadratic_apn_matrix(qam_to_sbox(M)) == M`) and a Gold-class recovery check.
- If author-artifact tests are included, clearly label them as
  "loaded reference artifact" vs "freshly generated by this run".

---

## PLAN.md

Write a `PLAN.md` in the paper folder before starting implementation:
- Project context summary (two sentences).
- Source material list (arXiv ID + TeX source in `input/tex_source/` if available, PDF, routines checklist, author artifact).
- Reproduction scope (exact / bounded / out-of-scope claims).
- Architecture restrictions applicable to this paper.
- Proposed file layout.
- Makefile targets and overridable parameters.
- Implementation phases (normalise → correspondence checks → core routines →
  bounded search → author artifact validation → reporting).
- Acceptance criteria.

The PLAN.md is the contract for the session — keep it current if scope changes.

---

## Acceptance criteria (minimum bar)

- `make -C packages/VBFRepro/src/<slug> test` passes.
- `make -C packages/VBFRepro/src/<slug> report` completes without a long search.
- Each script runs with the root Julia project.
- Tests cover at least one round-trip and one APN/invariant verification.
- All expensive experiments have explicit limits.
- Generated artifacts are optional and local to the paper folder.
- Claims from the paper are labelled: exact reproduction / bounded demo /
  loaded author artifact / not executed.
- Any routine that cannot yet be completed has a precise TODO referencing the
  paper section title and the missing mathematical or implementation step.

---

## Reference examples

| Paper | Style | Key files |
|---|---|---|
| `packages/VBFRepro/src/202201-beierle-quadratic-instances/` | **canonical multi-file reference** | `theorem1.jl`, `algorithm1.jl`, `lemma4.jl`, `paper_report()` |
| `packages/VBFRepro/src/202211-yu-qam/` | multi-file, full | `PLAN.md`, `helpers.jl`, `conjecture2_search.jl`, `Makefile`, `test/` |

---

## Recurring pitfalls / guardrails

Patterns seen across many prior reproductions. Assume they will recur.

### Paper formulas are often buggy — verify, correct, document

Published explicit formulas, table entries, and exponents frequently contain
typos. **Never transcribe a formula and assume it is right.** Always evaluate it
and check the claimed property (APN / differential uniformity / spectrum). If it
fails to verify:

1. Suspect a paper typo before suspecting your own code.
2. Derive the corrected form (common fixes: an exponent should be `2^m+1` not
   `2^{m+1}`; a permutation formula only works as the composition
   `F' = F2 ∘ F1^{-1}`, not the printed closed form; a stated nonlinearity /
   spectrum row is off).
3. Verify the corrected form computationally.
4. Record the discrepancy explicitly in `PLAN.md` / `paper_report()` as
   "paper bug: <section/table>, stated X, correct Y".

Seen in `Li_202402`, `Budaghyan_200506` (Thm 3/4), `Zha_201401` (Table 1),
`Budaghyan_202009` (Prop 6), `Li_202207` / `Zheng_202211` (exponent),
`Gologlu_202207`.

### Magma-only invariants are out-of-scope

Γ-rank / Δ-rank at large `n` and the paper's timing tables generally require
Magma and do not reproduce in-repo. Declare them **out-of-scope in `PLAN.md`**
up front rather than attempting them. If a small-`n` rank is feasible, compute
it and label it; otherwise state "Magma-only, not reproduced" (or "loaded from
Magma" if the paper supplies the value).

Seen in `Budaghyan_202011`, `Li_202207`, `Taniguchi_201909`, `Kaleyski_202203`.

### Field construction: conway vs primitive polynomial

Some dimensions need `conway_polynomial(n)` rather than `primitive_polynomial(n)`
to match the paper's field (e.g. `n=8` → `conway_polynomial(8) = 285`). If a
construction that should be APN verifies under one modulus but not the other,
the field polynomial is the likely culprit — try the Conway polynomial and
confirm the intended field before debugging the construction further.

Seen in `Budaghyan_202101`.
