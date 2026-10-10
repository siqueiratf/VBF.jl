# Feasibility of the eight remaining partial findings

Reviewed 2026-10-10 against `ed07cc5`, with three read-only reviewers: paper
source/reproductions, core equivalence, and reference/proposal coverage. This is
a work-scope assessment, not completion of the outstanding implementations.
All eight findings remain partial. Bounded probes, commands, input hashes and
environment are recorded in [partial_feasibility_probes.toml](partial_feasibility_probes.toml).
No catalog writes or full new corpus scans were performed.

| Finding | Achievable scope for a small agent round | Boundary to full closure |
|---|---|---|
| F004: Yu 2025 | Add exact n=8/9 regression evidence under both declared representative conventions; diagnose the source/pseudocode discrepancy. | The convention matching n=6/7 gives 109 versus 142 at n=8 and 25 versus 26 at n=9. Minimum-value representatives give 82 at n=8. Neither available convention reproduces the full table; author intent and higher-dimensional reproduction remain unresolved. |
| F032: binary codes | Implement a bounded exact coordinate-permutation solver for arbitrary Boolean generator matrices, with independently verified permutation certificates. | A factorial baseline is conclusive when exhausted, but does not promise practical high-dimensional classification. A scalable canonicalization/backend is a separate algorithm project. |
| F040: novelty scope | Add complete Gold-domain checks and theorem-backed exclusion of APN power constructions; publish explicit reference/construction coverage. | Literature-wide completeness cannot follow from a finite catalog or collected datasets. Non-power constructions require their own sourced coverage and conclusive comparisons. |
| F051: Calderini tables | Recover polynomial rows from the local PDF, reconcile field choices, and add bounded per-row enumeration/classification evidence. | Full table enumeration has unresolved runtime: trace-row probes hit node budgets without bounds. Counting simplex subspaces alone does not classify EA classes. |
| F052: Beierle profiles | Reconcile the input union, persist incremental per-member P6 results under both orders, and run a representative pilot before scheduling the full table. | The source ordering and 32,892-class input must be matched. A single completed P6 control does not establish full-scan runtime or reproduce the source table. |
| F063: 32 proposals | Complete checks against the named local snapshot and current catalog; retain nine positive witnesses and add missing n=12 Gold comparisons. | Most proposals are n=9/10, where no bulk corpus is registered. Finite-reference separation cannot close the literature-wide novelty requirement. |
| F070: Bracken 2012 n=30 | Implement and validate an exact coefficient-orbit reduction, then enumerate 49,981 normalized derivative/component cases. | Full closure is conditional on a proved orbit reduction, generator/coset verification, independent small-field controls and an actually completed run. The 256-case probe is evidence of feasibility only. |
| F071: Bracken 2011 | Construct the finite named earlier-family controls, reconcile trace formulas and persist exact pair decisions using existing APIs. | Classification of all coefficient grids and coverage of every prior construction remain separate requirements. n=15 graph-recovery memory and ambiguous comparison-source formulas prohibit a blanket completion promise. |

## Proposed three-worker implementation round

1. **Core equivalence worker:** own a new code-equivalence implementation under
   `packages/VBF/src/equivalence/ccz/`, include/export wiring and focused tests.
   Accept arbitrary generator matrices and return `Found`, `Exhausted` or
   `BudgetHit`. A witness permutation `p` must satisfy
   `rowspace(G[:,p]) == rowspace(H)`. Validate it independently with bijectivity,
   equal ranks and concatenated rank. Cover redundant rows, duplicate/zero
   columns, empty codes, equal-weight controls and independent exhaustive tiny
   codeword/permutation oracles. Apply budgets to preprocessing as well as DFS.
2. **Bracken n=30 worker:** own the Bracken 2012 reproduction and its tests.
   Derive the exact orbit formulas, verify all field orders/cosets, compare to
   direct small-field computations, and persist every completed rank/collision
   result. Use core GF(2) and finite-field APIs. This is a DU4 permutation
   experiment, not an APN novelty claim.
3. **Reference-evidence worker:** own the proposal-review consumer, Yu 2020
   Table 4 and comparison fixtures/manifests. Reuse the existing rebuilt stores
   and native equivalence APIs; explicitly cover all admissible Gold exponents,
   including n=12 indices 1,5,7,11. Missing sources, invariant collisions and
   interrupted comparisons remain unresolved. Replay all positive witnesses.

These three tasks have mostly disjoint files. Root review should check the
mathematical reductions and evidence independently before changing any finding
status. The expected targets for possible full scoped closure are F032's
missing API and F070's finite n=30 claim, conditional on completed validation.
F040/F063 can gain substantially stronger finite coverage while staying partial.
Source/table reconciliation for F004/F051/F052/F071 is a subsequent work batch;
do not fold it into a promise to finish all eight in the same round.

## Reference coverage and mathematical shortcuts

The current 32-proposal inventory contains 1 n=6, 1 n=8, 19 n=9, 9 n=10,
1 n=11 and 1 n=12 function. The n=6, n=8 and n=11 proposals already have
positive prior-art certificates. The n=8 proposal maps to corpus member 12658;
its novelty does not depend on a new bulk scan.

Current APN function rows, split by verified quadratic/nonquadratic status:

| Dimension | Quadratic rows | Nonquadratic rows | F063 proposals |
|---|---:|---:|---:|
| 6 | 19 | 2 | 1 |
| 8 | 67 | 3 | 1 |
| 9 | 12 | 6 | 19 |
| 10 | 11 | 3 | 9 |
| 11 | 11 | 11 | 1 |
| 12 | 2 | 0 | 1 |

These count function rows, not equivalence classes. All nine registered bulk
corpora are n=8 and contain 4,005,378 member records. The archived original-source
baseline at `data/apn/archive/census/results/signature_rebuild/` contains
3,809,037 distinct signature hashes across its declared input sources; it is
already available locally. Its source universe differs from the registered
corpus-row universe, so these totals are not interchangeable. Reuse its indexed
stores and raw readers; reconstruct matching records to compare full signatures
and, when necessary, recover equivalence witnesses. Different deterministic
hashes separate inputs; equal hashes never prove equivalence. Provenance and
independent reconstruction remain part of a defensible comparison claim.

[Yoshiara 2016, Theorem 2](https://link.springer.com/article/10.1007/s10801-016-0680-z)
states for n≥3 that a quadratic APN is CCZ-equivalent to an APN power function
precisely when it is EA-equivalent to a Gold function. Thus verified
quadratic/APN status and exact invariant separation from **every** admissible
Gold exponent can rule out **all APN power constructions**, including
nonquadratic power representatives. The saved evidence already separates the
22 remaining n=9/10 proposals from all their Gold indices. Turn that evidence
into an explicit theorem-backed certificate; do not merely filter reference
rows by algebraic degree. Equal Gold signatures remain inconclusive.

The n=12 proposal currently lacks explicit Gold coverage; construct and verify
indices 1,5,7,11. This theorem does not cover arbitrary non-power nonquadratic
constructions. Nor does an unknown source or an empty comparison set establish
absence. All current nonquadratic n=9/10/11 catalog targets are power
constructions, which makes the finite catalog comparison smaller than a generic
CCZ search against those targets.

For F071 the nonquadratic `x^993` comparison is also a power-function target;
the same reduction is applicable after verifying the source function is APN
and covering all Gold classes in the declared dimension. Do not apply
ortho-derivative signatures directly to the nonquadratic reference.

The general code API is not a prerequisite for every consumer. Existing
`partition_refinement_equivalence` already supplies native function CCZ/EA
decisions and witnesses, and `ea_class_orbits` has a partition-refinement
backend. Exhaustion of the relevant group, subspace and action computations is
still required. Native square-graph recovery's minimum estimated allocation is
256 MiB at n=12 and 16 GiB at n=15 before additional buffers; invariant
separation can avoid those searches when applicable.

## Fresh bounded evidence and source checks

Julia 1.13.1, one Julia thread, AMD RYZEN AI MAX+ 395. Times below measure the
probe bodies; they do not establish a whole-pipeline runtime guarantee.

- **Yu:** n=8 minimum-log traversal exhausted a 405,000-tuple restricted
  domain, 237,422 final evaluations, in 0.828 s, yielding 109. n=9 exhausted
  9,834,496 tuples, 7,220,898 evaluations, in 19.769 s, yielding 25. Both
  disagree with the source table (142 and 26). Minimum-value n=8 gave 82 in
  1.266 s. These are restricted-domain traversal results, not class counts.
- **Beierle:** member 9172 of `beierleleander2022_n8` completed both P6 orders
  in 0.403 s. The sixth-level pairs were lex `(58,90)` and bminK `(58,78)`;
  fifth-level pairs remain `(30,46)` and `(30,34)`. This is one control only.
- **Calderini:** n=7 and n=8 trace-construction probes with 100,000 nodes
  returned `BudgetHit`, no upper bound. The local PDF recovers Table 3 row 13's
  truncated LaTeX tail and row 14's missing initial line; the data are available
  for reconciliation rather than blocked on an absent external publication.
- **Bracken 2011:** Table 3's literal `x³+Tr(x³)` disagrees with the introduction's
  `x³+Tr(x⁹)`. For even n the literal table expression is an invertible
  output-linear transform of Gold; record that identity and treat the alternate
  source formula separately rather than silently substituting it.

For Bracken 2012 at n=30, e1=5, e2=1,052,672 and N=2³⁰−1 give
`gcd(e2-e1,N)=21483` and `N/21483=49981`. Scaling a nonzero derivative parameter
a yields the linear map
`L_c(y)=y⁴+y+c(y^(2²⁰)+y^(2¹²))`, with c in one multiplicative coset.
The affine collision equation has right-hand side `1+c`. Exhausting that coset
can certify differential uniformity from kernel dimensions and injectivity by
showing `1+c` outside each image. Component quadratic forms also reduce by
input scaling, since `gcd(5,N)=1`; their polar ranks determine Walsh support
inclusion by the standard quadratic-form theorem. Source Theorem 1.1 asserts
support inclusion, which must not be silently strengthened to a full frequency
distribution or exact value-set claim.

Only 256 coefficients were checked in this review: every derivative/polar rank
was 28 and every collision right-hand side lay outside the image. A repeat
probe took 0.089 s. No complete n=30 certificate exists from this probe.
The full implementation must prove both coset reductions, verify generator
orders and cover all 49,981 coefficients, with independent small-field checks.
The ignored probe script/log are retained under
`data/repro/audit/feasibility/`, bound by the TOML hashes above.
