# Skill: add-experiment

Use this skill when the user asks to add a new paper reproduction experiment to
the repository. It orchestrates a six-agent pipeline where each agent produces a
named artifact consumed by the next. The orchestrator (main Claude) drives the
flow, holds the approval gate, and can intervene at any checkpoint.

---

## Inputs to gather before starting

Ask the user for these before spawning any agent:

1. **Paper slug** — `LastName_YYYYMM` format, e.g. `Smith_202309`.
2. **TeX file path** — absolute or repo-relative path to the converted `.tex`
   (or PDF if TeX is unavailable). Must already exist on disk.
3. **Author artifact** (optional) — path to any reference code the authors
   published (`.py`, `.sage`, `.m`, …).
4. **Routines checklist** (optional) — path to `routines_to_implement_list.txt`.
   If absent, the Paper Extractor will synthesise one.

Target directory: `papers/<slug>/`. If it already exists, read its current
contents before proceeding so agents do not overwrite existing work.

---

## Artifact chain

Each agent writes exactly one named artifact; the next agent reads it.

```
[TeX / PDF]
     │
     ▼
[1] Paper Extractor  ──►  papers/<slug>/EXPERIMENTS.md
                                  │
                                  ▼
[2] Scaffolder       ──►  papers/<slug>/  (files created)
                          papers/<slug>/SCAFFOLD_REPORT.md
                                  │
                                  ▼
[3] Reviewer/Planner ──►  papers/<slug>/PLAN.md  (created/updated)
                          papers/<slug>/Makefile  (mock, targets only)
                                  │
                          ◄── APPROVAL GATE ──►
                                  │
                                  ▼
[4] Implementer      ──►  papers/<slug>/*.jl  (code in stubs)
                                  │
                                  ▼
[5] Tester           ──►  test results + extended tests
                                  │
                                  ▼
[6] Final Reviewer   ──►  papers/<slug>/REVIEW.md
```

---

## Agent 1 — Paper Extractor

**Trigger:** after inputs are gathered.

**Goal:** parse the TeX (or PDF) and produce a structured experiment inventory
that downstream agents use as their shared ground truth.

**Prompt template** (fill `<SLUG>`, `<TEX_PATH>`, `<ARTIFACT>`, `<CHECKLIST>`):

```
You are the Paper Extractor agent for VBF.jl.

Your only job is to read the paper source and produce
`papers/<SLUG>/EXPERIMENTS.md`. Do NOT write any Julia code.

## Inputs
- TeX file: <TEX_PATH>
- Author artifact (optional): <ARTIFACT>
- Routines checklist (optional): <CHECKLIST>

## What to extract

Read the TeX carefully and write `papers/<SLUG>/EXPERIMENTS.md` with these
sections, in order:

### Paper metadata
- Full title, authors, year, venue, arXiv/DOI if present.

### Mathematical setting
- Dimension(s) n, the field GF(2^n), any special sub-fields or sub-spaces the
  paper relies on.

### Claims inventory
One sub-section per reproducible claim, ordered by paper appearance.
For each claim:
- **ID**: short kebab-case slug (e.g. `theorem2-apn-count`).
- **Type**: Theorem / Proposition / Conjecture / Algorithm / Experiment /
  Corollary.
- **Section + number** in the paper.
- **Statement**: one-sentence summary in plain English.
- **Reproducibility**: Exact | Bounded | Author-artifact | Out-of-scope.
  - Exact: can fully verify with small n or closed-form check.
  - Bounded: too expensive to run in full; run with a `limit`/`max_evaluations`
    guard and report whether exhaustive.
  - Author-artifact: validate against code the authors published.
  - Out-of-scope: computationally infeasible or requires external data; document
    why and leave a precise TODO citing the paper section.
- **VBF APIs likely needed**: list names from `packages/VBF/src/`.
- **Estimated cost**: Fast (<10 s) / Medium (10 s–5 min) / Slow (>5 min).
- **Proposed Julia file**: which `.jl` file this claim belongs in.
- **Proposed Makefile target**: snake_case name.

### Routines checklist
If `routines_to_implement_list.txt` was provided, reproduce its items verbatim
and annotate each with the claim ID it maps to. Otherwise synthesise the list
from the claims inventory.

### Open questions
Anything ambiguous in the TeX that a human should clarify before implementation.

## Output
Write exactly one file: `papers/<SLUG>/EXPERIMENTS.md`.
Report the absolute path and the number of claims extracted.
```

**Orchestrator check after Agent 1:**
- Read `EXPERIMENTS.md` and scan the "Open questions" section.
- If blocking ambiguities exist, surface them to the user before continuing.
- Otherwise proceed to Agent 2.

---

## Agent 2 — Scaffolder

**Trigger:** `EXPERIMENTS.md` exists and open questions are resolved.

**Goal:** create every file and directory that the paper folder needs, with
stub content. Do not write substantive Julia logic — only the skeleton.

**Prompt template:**

```
You are the Scaffolder agent for VBF.jl.

Read `papers/<SLUG>/EXPERIMENTS.md` (already written) and create the complete
directory skeleton for `papers/<SLUG>/`. Do NOT implement any mathematics.

## Reference layout (from papers/Yu_202211d/)
```
papers/<slug>/
  Makefile           ← PLACEHOLDER only; Agent 3 will replace it
  helpers.jl
  report.jl
  <claim1>.jl
  <claim2>.jl
  ...
  codes_mencioned_in_original_paper/
    routines_to_implement_list.txt  ← copy/create if not present
  results/           ← create empty .gitkeep
  test/
    runtests.jl
    test_<claim1>.jl
    test_<claim2>.jl
    ...
```

## Rules

- One `.jl` file per distinct "Proposed Julia file" in EXPERIMENTS.md.
- Each `.jl` file must start with the standard commented pseudocode block:
  ```julia
  # Implements <Paper Section / Theorem title>
  # Paper: <Author> et al. (<Year>), "<Title>", <Venue>
  # Section: <X.Y — Section title>
  #
  # Pseudocode:
  #   TODO: fill from paper
  # VBF API used: TODO
  ```
- helpers.jl: stub `print_header`, `print_section`, `print_check`, `print_kv`
  functions (empty bodies returning nothing).
- report.jl: stub `paper_report(io::IO=stdout)` that calls `print_header()` and
  one `print_section` per claim.
- Each `test/test_<claim>.jl`: one `@testitem "<claim>_test"` block with a
  single `@test false  # TODO` placeholder inside.
- `test/runtests.jl`: include each test file in order.
- `results/.gitkeep`: empty file so git tracks the directory.
- Makefile: write the single line `# PLACEHOLDER — replaced by Agent 3`.
- Do NOT add content to `codes_mencioned_in_original_paper/`; only create
  the directory if it doesn't exist.

## Output
Write every file. Then write `papers/<SLUG>/SCAFFOLD_REPORT.md` listing:
- Every file created (relative path, type: new/existed).
- Total file count.
- Any files that already existed and were NOT overwritten (list them).
Report the path to SCAFFOLD_REPORT.md.
```

**Orchestrator check after Agent 2:**
- Confirm every file from EXPERIMENTS.md's "Proposed Julia file" column appears
  in SCAFFOLD_REPORT.md.
- If anything is missing, ask Agent 2 to fill the gap before continuing.

---

## Agent 3 — Reviewer / Planner

**Trigger:** SCAFFOLD_REPORT.md exists.

**Goal:** audit the extracted scope and scaffold for coherence, then produce the
definitive PLAN.md and a complete (but mock) Makefile. This is the last
checkpoint before code is written.

**Prompt template:**

```
You are the Reviewer/Planner agent for VBF.jl.

Read these files and validate the proposed reproduction:
- `papers/<SLUG>/EXPERIMENTS.md`
- `papers/<SLUG>/SCAFFOLD_REPORT.md`
- `packages/VBF/src/` (search for APIs listed in EXPERIMENTS.md)

## Validation checklist

For each claim in EXPERIMENTS.md:
1. Does a corresponding `.jl` stub exist in the scaffold? (from SCAFFOLD_REPORT)
2. Does a corresponding test stub exist?
3. Are all "VBF APIs likely needed" actually exported from `packages/VBF`?
   Search `packages/VBF/src/` to confirm. If an API is missing, flag it with
   [MISSING-API] and propose whether it belongs in `packages/VBF` (reusable)
   or in `papers/<SLUG>/helpers.jl` (paper-local).
4. Is the reproducibility classification (Exact/Bounded/Author-artifact/
   Out-of-scope) consistent with the estimated cost?
5. Does any claim require a VBFCatalog import in the main experiment files?
   (Only allowed in catalog_validation.jl, if present.)

## Produce PLAN.md

Write `papers/<SLUG>/PLAN.md` following the template from `papers/Yu_202211d/PLAN.md`.
Sections required (keep each section concise):
1. Project Context (two sentences max)
2. Source Material
3. Reproduction Scope (exact / bounded / out-of-scope, one line each)
4. Architecture Restrictions (copy from `.claude/context/PROJECT.md` +
   any paper-specific additions)
5. Proposed File Layout (with one-line description per file)
6. Makefile Targets and overridable parameters
7. Implementation Phases (label them Phase 1…N)
8. Acceptance Criteria
9. Validation Findings (summary of your checklist above, including any
   [MISSING-API] flags and recommended resolution)

## Produce the Makefile

Write `papers/<SLUG>/Makefile`, replacing the placeholder from Agent 2.
Follow the template from `.claude/skills/reproduce-paper/SKILL.md`.
Rules:
- Include every Makefile target from EXPERIMENTS.md's "Proposed Makefile target"
  column plus: `help`, `test`, `report`, `clean_results`.
- Each claim target body: call `julia $(JULIA_PROJECT)` with an `include(...)` +
  the claim's entry-point function. Use the stub function names from the .jl files.
- Include all standard overridable parameters: `limit`, `max_evaluations`,
  `sample_size`, `save_results`, `seed`, `full_search`.
- The Makefile must be fully runnable (no shell errors) even though the Julia
  functions are stubs — the stub functions exist so `include` won't error.

## Output
Write PLAN.md and Makefile. Then print a structured summary:

VALIDATION SUMMARY
==================
Claims reviewed: N
Scaffold coverage: N/N files present
Missing APIs: [list or "none"]
VBFCatalog leaks: [list or "none"]
Reproducibility concerns: [list or "none"]
Ready for implementation: YES / NO (with reason if NO)
```

**Orchestrator: APPROVAL GATE**

After Agent 3 completes:
1. Show the user the VALIDATION SUMMARY.
2. Show the "Validation Findings" section from PLAN.md.
3. Ask the user: "The plan is ready. Proceed to implementation?" (yes/no/edit).
4. If "edit": ask what to change, update PLAN.md manually or re-run Agent 3.
5. Only proceed to Agent 4 after explicit user approval.

---

## Agent 4 — Implementer

**Trigger:** user has approved the plan.

**Goal:** write the substantive Julia code for each claim stub.

**Prompt template:**

```
You are the Implementer agent for VBF.jl.

Your job is to fill in the Julia code stubs in `papers/<SLUG>/`. Do not create
new files — only edit files listed in `papers/<SLUG>/SCAFFOLD_REPORT.md`.

## Inputs (read all of these before writing a single line of code)
- `papers/<SLUG>/PLAN.md` — architecture constraints, implementation phases,
  acceptance criteria.
- `papers/<SLUG>/EXPERIMENTS.md` — per-claim VBF APIs, pseudocode hints,
  reproducibility classification.
- `papers/<SLUG>/SCAFFOLD_REPORT.md` — which files exist and what they contain.
- `papers/<SLUG>/codes_mencioned_in_original_paper/` — any TeX, routines list,
  author artifact. Read them.
- `packages/VBF/src/` — search for each API before using it. Never use an API
  you haven't confirmed exists.

## Implementation rules

Architecture:
- NEVER add paper-specific math to `packages/VBF`. Only call its existing APIs.
- NEVER import VBFCatalog outside of catalog_validation.jl (if present).
- NEVER hard-code absolute paths; use `@__DIR__` and `joinpath`.
- All S-box values: zero-based integers, Julia 1-based storage (`lut[x+1]`).

Experiments:
- Every search or expensive loop must accept `limit` or `max_evaluations` kwargs.
- Every result-writing call must be guarded by `save_results::Bool` (default false).
- Results go to `joinpath(@__DIR__, "results", ...)`. Never write elsewhere.
- Every report output must state whether the run was exhaustive or budget-limited.
- Keep randomness deterministic: require `seed::Int` and print it.

Code quality:
- No comments except for non-obvious WHY. The pseudocode block at file top is
  the only multi-line comment allowed.
- Each function gets one-line docstring: concept + paper citation.
- Implement Bounded/Author-artifact claims fully (even if results are sampled).
- For Out-of-scope claims: leave the stub body but replace `# TODO` with a
  precise comment: `# TODO [<PaperSection>]: <what is missing>`.

helpers.jl:
- Implement `print_header`, `print_section(title)`, `print_check(ok, desc)`,
  `print_kv(key, val)` for report formatting.

report.jl:
- `paper_report(io::IO=stdout)` must run without any expensive search.
  Call each claim's report/print function; pass `limit=0` or `sample_size=5`
  where needed to keep the report fast.

## Implementation order
Follow PLAN.md's Implementation Phases in order. After each phase, summarise
what was written (file, function names, line count). Stop if you hit a missing
VBF API that blocks a claim; document the blocker and move to the next claim.

## Output
After finishing all phases, write a one-paragraph summary:
- Which claims are fully implemented.
- Which are partial (and why).
- Which are Out-of-scope stubs.
- Any [MISSING-API] blockers encountered.
```

**Orchestrator check after Agent 4:**
- Run `julia --project=/home/tiago/VBF.jl papers/<slug>/test/runtests.jl` to
  get an early signal before the Tester agent runs.
- If Julia errors on import or syntax, ask Agent 4 to fix them before proceeding.

---

## Agent 5 — Tester

**Trigger:** Agent 4 summary received.

**Goal:** run the tests, diagnose failures, extend test coverage.

**Prompt template:**

```
You are the Tester agent for VBF.jl.

## Context
Paper slug: <SLUG>
Paper folder: papers/<SLUG>/
Root Julia project: /home/tiago/VBF.jl

## Step 1 — Run tests
Run: make -C papers/<SLUG> test
Capture stdout and stderr.

## Step 2 — Diagnose failures
For each failing test:
- Read the relevant test file and the implementation file.
- Determine: wrong expected value, incomplete stub, missing VBF API, or
  test itself is wrong.
- Fix the issue in the appropriate file. Never delete a test; fix or annotate it.
- If the fix requires changing a VBF API (packages/VBF): flag it as
  [VBF-CHANGE-NEEDED] and leave a precise TODO instead of modifying VBF.

## Step 3 — Extend tests
For each claim marked "Exact" in EXPERIMENTS.md, the test must include:
- At least one closed-form / known-value check (not just `@test true`).
- At least one round-trip check if the claim involves a bijection or inverse.
For QAM claims specifically:
- `quadratic_apn_matrix(qam_to_sbox(M)) == M` round-trip.
- `is_qam(M)` agreement with `differential_uniformity == 2`.

Replace `@test false  # TODO` placeholders with real tests where possible.
Leave the placeholder (with an updated comment) only when implementation is
genuinely incomplete.

## Step 4 — Final run
Run make -C papers/<SLUG> test again after all edits.

## Output
Print a test report:
  Tests passed: N/N
  Fixed failures: [list]
  Remaining failures: [list with root cause]
  [VBF-CHANGE-NEEDED] items: [list or "none"]
  New test cases added: N
```

**Orchestrator check after Agent 5:**
- If remaining failures include [VBF-CHANGE-NEEDED] items, surface them to the
  user and ask whether to address them in this session.

---

## Agent 6 — Final Reviewer

**Trigger:** Agent 5 test report received.

**Goal:** independent correctness and quality review of the full implementation.
Does not fix anything — produces a prioritised fix list for the user.

**Prompt template:**

```
You are the Final Reviewer agent for VBF.jl.

Perform a read-only review of `papers/<SLUG>/`. Do NOT edit any files.

## What to check

### Correctness
- Does each claim implementation match the paper section it claims to implement?
  Read `papers/<SLUG>/EXPERIMENTS.md` for the mapping.
- Are there any indexing bugs (off-by-one, 0-based vs 1-based)?
- Are search loops correctly guarded by their limit/max_evaluations parameters?
- Are save_results guards present and correct?
- Does report.jl avoid triggering any expensive computation by default?

### Architecture compliance
- Is VBFCatalog imported anywhere outside catalog_validation.jl?
- Is any paper-specific math duplicated from packages/VBF/src/?
- Are there hard-coded absolute paths?
- Does any file include another paper's files?

### Test quality
- Does each claim marked "Exact" have at least one non-trivial test?
- Are there tests that depend on long-running searches (they shouldn't be)?
- Are author-artifact tests clearly labelled?

### Code quality
- Are there unexplained magic constants?
- Do function docstrings cite the paper?
- Is the pseudocode block at the top of each .jl file filled in (not just TODO)?

### Makefile
- Does `make help` list all targets?
- Does each claim target actually call its Julia function?
- Are all overridable parameters documented in help?

## Output
Write `papers/<SLUG>/REVIEW.md` with these sections:

### Critical (must fix before merging)
Numbered list: file:line — what is wrong — why it matters.

### Important (should fix)
Numbered list: same format.

### Minor (nice to have)
Numbered list.

### Passed checks
Brief list of what looks good.

### Summary
One paragraph: overall readiness, estimated effort to reach "merge-ready" state.
```

**Orchestrator final step:**
- Show the user the REVIEW.md Summary and Critical sections.
- If Critical is non-empty, offer to spawn Agent 4 again targeting only those
  items (pass the Critical list as additional context).
- If Critical is empty, the workflow is complete.

---

## Orchestrator checklist

Run through this before declaring the workflow done:

- [ ] `make -C papers/<SLUG> test` passes (or remaining failures are documented).
- [ ] `make -C papers/<SLUG> report` completes without a long search.
- [ ] PLAN.md exists and acceptance criteria section is filled.
- [ ] REVIEW.md exists with no Critical items (or Critical items are tracked).
- [ ] `papers/<SLUG>/results/` is in `.gitignore` (check `git check-ignore`).
- [ ] No VBFCatalog import outside catalog_validation.jl.
- [ ] No hard-coded absolute paths.

---

## Error handling and re-entry

- If any agent fails or produces an incomplete artifact, re-spawn it with the
  same prompt plus a "PREVIOUS ATTEMPT NOTE:" section describing what went wrong.
- If Agent 4 hits a missing VBF API that blocks more than one claim, surface it
  to the user before continuing — adding a new VBF API is a separate task that
  may belong in its own branch.
- PLAN.md and REVIEW.md are the auditable record of this session. Keep them
  current; update PLAN.md if scope changes after the approval gate.

---

## Reference examples

| Paper | Style |
|---|---|
| `papers/CanteautCouvreurPerrin2022_orthoderivative.jl` | single-file |
| `papers/Beierle_202107/` | multi-file, Makefile |
| `papers/Yu_202211d/` | multi-file, full (canonical reference) |