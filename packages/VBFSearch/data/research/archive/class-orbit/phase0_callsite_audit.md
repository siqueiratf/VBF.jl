# Phase 0 — call-site audit: where a budget stop was read as a proof of emptiness

Generated during the n=8 quadratic-APN search run. Repo HEAD `bf15e59`.
Cross-references audit findings F020, F022, F023.

## The defect, located

Two families of routine collapse "budget stopped the walk" into "the region is
empty", and one decision procedure collapses "undecided" into "inequivalent".

### A. `APNSearch` / `APNSearchClasses` — the only wall-clock budget in the tree

`papers/2021/Beierle_202107/algorithm1.jl`

```
 20:    timed_out::Bool                              # field declared
151: function search_timed_out!(context)             # sets it
155:     context.timed_out = true
213:     search_timed_out!(context) && return context.solutions
```

`grep -rn "timed_out" --include=*.jl .` over the whole repository returns
**exactly those four lines plus this audit**. The flag is written at line 155
and **never read anywhere**. `APNSearch` returns `context.solutions`;
`APNSearchClasses` returns `Dict{Int, Vector{Vector{Int}}}`. The context — the
only object that knows a deadline expired — is dropped on return.

So for any class index:

| what happened | what the caller receives |
|---|---|
| tree fully walked, no APN permutation exists | `Vector{Int}[]` |
| 300 s deadline expired at depth 3 | `Vector{Int}[]` |

These are the same value. Distinguishing them is the entire content of Table 1's
`no (Alg. 1)` column and of the paper's Theorems 1, 3 and 4.

### B. `search_qam` / `search_qam_full` — evaluation-count budget

`packages/VBF/src/constructions/qam_search.jl:217` and `:302`. Both return a bare
`Vector{SBox}`. `evals >= max_evaluations && break` exits the odometer loop with
no record that it did, so a budget-truncated sweep and a completed sweep are
indistinguishable at the call site.

### C. capped equivalence decisions → `false`

`packages/VBF/src/equivalence/ea/api.jl:135` — `on_inconclusive = :best_effort`
is the default, which warns and returns `false` when the search is capped. The
`:throw` / `:missing` options exist but every caller must opt in. Same disease,
different shape: undecided read as a proved negative.

## Call sites

Every consumer of a budget-capable search in the tree, classified by what it does
with the ambiguous value.

### Silently converts a budget stop into a completeness or emptiness claim — 5

| # | call site | what it does |
|---|---|---|
| 1 | `papers/2021/Beierle_202107/Makefile:algorithm1` target | runs `APNSearchClasses(n, class_indices; timeout_seconds=300, save_results=true)`. A class that times out simply writes no `search = [...]` line into `tuples/AllTuplesMatrices<n>.toml`. The absence of that line is then read by everything downstream as "this class has no APN permutation". This is the persisted form of the collapse and the most consequential one. |
| 2 | `papers/2022/Yu_202211d/small_searches.jl:19` | `exhaustive = n_classes < limit && max_evaluations > 1 << 24 - 1` — derives the exhaustiveness flag from the *parameters passed in*, never from whether the odometer actually rolled over. A sweep that consumed exactly its budget is reported `exhaustive = true`. |
| 3 | `papers/2020/Yu_202012/algorithm1.jl:80,84` | prints `completeness = "exhaustive (n=6 search space = 2^15, per Example 1)"` and returns `(; exhaustive = true)` as unconditional literals, regardless of the `max_evaluations` actually used. |
| 4 | `packages/VBF/test/unit/qam_full_search_test.jl:19` | `@test isempty(search_qam_full(6; max_evaluations = 0))` — codifies the collapse as the *expected contract*: a zero budget must look exactly like an empty region. This is the test that has to change for the distinction to exist. |
| 5 | `papers/2008/Brinkmann_200812/theorem5.jl:76-83` | reports "All 7 functions pairwise EA-inequivalent" from `are_ea_equivalent(...) == false` under the `:best_effort` default. Per F022, 2 of the 21 pairs are undecided (degenerate Heggebakk partition for `(x^7, x^11)`; `max_inner_affine = 1e7` exceeded for `(f6(1), f6(2))`) and are counted as proved-inequivalent. |

### Consumes the ambiguous value but fails loudly rather than claiming emptiness — 3

| # | call site | what it does |
|---|---|---|
| 6 | `papers/2021/Beierle_202107/report.jl:theorem1_report` | reads the persisted `blocks[5].search`; `nothing` prints `[FAIL] n=6 class 5 search result stored`. Loud, but it cannot tell a timed-out class from an empty one. |
| 7 | `papers/2021/Beierle_202107/report.jl:n7_monomials_report` | same, over 6 classes. |
| 8 | `papers/2020/Yu_202012/table1.jl:44` | `ok = length(classes) == expected`; a budget hit yields too small a count and the check fails — but it fails as "the paper's count is wrong", misattributing the cause. |

### Consumes it safely — 5

`papers/2020/Yu_202012/theorem2.jl:102-118` (explicitly guards its negative claim
with `!isempty(classes)`), `papers/2022/Yu_202211d/paper_invariants.jl:132` and
its test (uses "lower bound" language), `packages/VBF/test/unit/qam_search_test.jl:67`
(asserts a positive), `papers/2022/Yu_202211d/small_searches.jl:37` (reports
counts, claims no coverage), `papers/2021/Beierle_202107/test/test_algorithm1.jl:22`
(a timeout would fail the test loudly).

## Answer to the question asked

**5 call sites had been silently treating a budget stop as a proof of emptiness**
(3 of them for a search budget, 1 codifying it in a test, 1 for a capped
equivalence decision). **3 more consume the same ambiguous value** and fail loudly
without being able to name the cause.

The single most consequential is #1: it is not a transient in-memory value but a
*persisted* one. `tuples/AllTuplesMatrices<n>.toml` is the results table Phase 1
targets, and a missing `search` field in it means "no APN permutation OR the
300 s budget expired", with no way to tell which from the file.

## Status of the fix

`packages/VBF/src/search/outcome.jl` introduces the three-case type
(`Found` / `Exhausted` / `BudgetHit`) with `certified_region` and
`certified_empty_region` defined **only** on `Exhausted`, so handing them a
`BudgetHit` is a `MethodError` from Julia's dispatch rather than a review
comment. `packages/VBF/test/unit/search_outcome_test.jl` — 75 assertions, all passing — fails if
the distinction is collapsed, including a test that fails if a future edit adds a
`::SearchOutcome` fallback for either certifying accessor.

**All call sites above are now fixed.** The operator lifted the `papers/` +
`packages/` freeze for exactly these files.

Gate: the VBF suite was run on a pristine `git worktree` at HEAD `bf15e59`
beforehand — `108306 passed, 6 failed` — and after the changes:
`108378 passed, 6 failed`. The same 6 failures, +72 new passing tests, zero new
failures. The 6 are a pre-existing catalog desync (the tracked SQLite DB holds
34 APN functions where `data-raw/` declares 35, the missing entry being
`n8_Taniguchi2025_ex4_2` added in `dd688fd` without a DB rebuild) and are
unrelated to this work. The four affected paper suites — Beierle_202107,
Yu_202012, Yu_202211d, Brinkmann_200812 — all pass.

Behaviour change worth noting: `papers/2008/Brinkmann_200812/theorem5.jl` now
FAILS its aggregate claim where it used to pass. That is correct. Asking for
`on_inconclusive = :missing` shows 19 of 21 pairs decided soundly and 2 —
`x^7/x^11` and `f6(1)/f6(2)` — undecided, exactly as F022 predicted. The claim
"all 7 pairwise EA-inequivalent" was never established; it only looked
established because a capped search returned `false`.
