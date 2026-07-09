# Kaleyski_202203 Review

Paper: Nikolay Kaleyski, "Deciding EA-equivalence via invariants".

Reproduction path: `papers/Kaleyski_202203/`

Verdict: Partial. The reproduction covers the main invariant and EA-equivalence machinery in bounded form, and the default tests pass, but it does not reproduce the full paper experiments and one concrete Section 5 `n=8` claim fails when exercised.

## Issue Catalog

### Paper Issues

- Candidate paper/source issue: Section 5 reports that the Gold-like `n=8` partition has bucket sizes `1,70,185` at `input/Kaleyski - 2022 - Deciding EA-equivalence via invariants.tex:567`. The reproduction's direct enumeration and Walsh-formula path agree on bucket sizes `[1,85,170]` up to sorting. This needs a convention check before treating the paper value as a confirmed typo.

### Reproduction Issues

- Section 5 `n=8` Gold partition check
  - Location: `papers/Kaleyski_202203/section5.jl:134`, `section5_report`
  - Symptom: `julia --project=. -e 'include("papers/Kaleyski_202203/section5.jl"); section5_report(; n_values=[8], limit=1)'` fails. Actual bucket sizes are `[170,85,1]`; expected bucket sizes are `[185,70,1]`.
  - Root cause: the reproduction encodes the paper's reported Section 5 value, but the implemented direct enumeration and Walsh-formula computation produce a different partition. It is unresolved whether this is a paper typo or a convention mismatch.
  - Resolution plan:
    1. Recompute the Section 5 invariant from the paper definition, including the exact `s` and partition convention.
    2. If the paper value is a typo, document the counter-evidence and update the reproduction expectation.
    3. If the convention differs, rename or adjust the reproduction check so it matches the paper's convention.

- Algorithm 1 non-equivalence coverage is weak
  - Location: `papers/Kaleyski_202203/test/test_algorithm1.jl:23`
  - Symptom: the test labels a "Non-EA-equivalent pair" but uses different dimensions and only checks that signatures exist, not that rejection behavior is correct.
  - Root cause: the test is a smoke test rather than a same-dimension negative EA-equivalence case.
  - Resolution plan:
    1. Add a same-dimension pair whose EA inequivalence is known or independently certified.
    2. Assert that the Algorithm 1 partition/signature comparison rejects or separates the pair.
    3. Keep the current smoke coverage only as a separate dimension-sanity test if still useful.

- Outer permutation search may over-enumerate candidates
  - Location: `packages/VBF/src/equivalence/ea/outer_permutation.jl:76`, `packages/VBF/src/equivalence/ea/outer_permutation.jl:161`
  - Symptom: the implementation groups bucket maps by bucket size, while Algorithm 2 requires mapping each multiplicity bucket `K_i` to the corresponding `C_i`. Repeated bucket sizes may admit extra candidates.
  - Root cause: the implementation checks compatible sizes but does not appear to enforce exact multiplicity-bucket identity in all repeated-size cases.
  - Resolution plan:
    1. Build a repeated-bucket-size fixture from the paper's Algorithm 2 setup.
    2. Compare current candidate counts against exact `L1(K_i)=C_i` filtering.
    3. Tighten the grouping/filtering if the fixture demonstrates over-enumeration.

- Local helpers duplicate exported `VBF` APIs
  - Location: `papers/Kaleyski_202203/helpers.jl:14`, `papers/Kaleyski_202203/helpers.jl:66`
  - Symptom: `print_header` duplicates exported `print_banner`, and `gold_x3` duplicates exported `gold_apn`.
  - Root cause: paper-local helper code reimplements generic package functionality.
  - Resolution plan:
    1. Replace `print_header` with `print_banner`.
    2. Replace `gold_x3` with `gold_apn(N, 1)`.
    3. Keep only paper-specific helper logic in `helpers.jl`.

## Items Reproduced Exactly

- Proposition 1 / Corollary 3 are reproduced as bounded EA-invariance checks on Gold `x^3`, `n=6`, for `k = 2,3,4,6`.
- Proposition 4 is reproduced for the implemented square-function, `t=0`, mainly `k=4` case by comparing direct enumeration against the Walsh formula.
- Algorithms 1-3 are represented as bounded demos using core `VBF` EA partition, outer permutation, and inner permutation APIs.
- Table 1 is partially represented by the `Gold x^3`, `n=6`, `|K| = 1008` count.

## Test Results

- `julia --project=. papers/Kaleyski_202203/test/runtests.jl`: passed, 33 tests.
- `julia --project=. -e 'include("papers/Kaleyski_202203/section5.jl"); section5_report(; n_values=[8], limit=1)'`: failed on the explicit `n=8` Gold partition check. Actual `[170,85,1]`, expected `[185,70,1]`.

## Catalog Status

No new APN functions are defined by this paper. Section 5 cites new APN functions from another work but does not give their explicit formulas here. No Catalog-gap records were emitted.

## Library-Reuse Note

- Reuse violation: `gold_x3` in `papers/Kaleyski_202203/helpers.jl:66` duplicates exported `VBF.gold_apn`; use `gold_apn(N, 1)`.
- Reuse violation: `print_header` in `papers/Kaleyski_202203/helpers.jl:14` should use exported `print_banner`.
- Promote-to-core candidate: `sigma_multiplicities_vec` in `papers/Kaleyski_202203/helpers.jl:30` is generic and duplicates the core Walsh loop behind `sigma_multiplicities`, while preserving per-element values.

## Missing Or Partial Coverage

- Proposition 4 is stated for arbitrary `(n,m)`, arbitrary `t`, and positive `k`; the reproduction only verifies `M_k^F(0,s)` for square functions.
- Remark 5 / `Pi_F^0` equivalence is not reproduced.
- Proposition 6 coset structure is demonstrated only through automorphism counts, not full coset reconstruction.
- Proposition 7 and Algorithm 3 are only partially exercised; the demo recovers one linear `A2`, while the paper's Algorithm 3 returns all affine permutations.
- Table 1 timing columns and Table 2 are explicitly skipped.
- Section 5 full survey claims, including `21105` functions and `19300` partitions, are not reproduced; the implementation defaults to `n_values = [5,6]`.
