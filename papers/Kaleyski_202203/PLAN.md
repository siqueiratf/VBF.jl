# PLAN — Kaleyski_202203

## Paper
Nikolay Kaleyski, "Deciding EA-equivalence via invariants",
*Cryptography and Communications*, 2021 (arXiv 2022).

## Source material
- `input/kaleyski_2022_deciding_ea_equivalence_via_invariants.tex`
- `input/Kaleyski - 2022 - Deciding EA-equivalence via invariants.pdf`

## Reproduction scope

| Claim | Status | Notes |
|---|---|---|
| Proposition 1 (EA-invariance, even k) | **exact** | sigma multiset invariant under EA for even k |
| Proposition 2 (quadratic: can assume linear A1,A2) | **exact** | demo with explicit affine maps |
| Corollary 3 (quadratic: any k) | **exact** | follows from Prop 2 + Prop 1 |
| Proposition 4 (Walsh formula for multiplicities) | **exact** | walsh formula == direct computation |
| Algorithm 1 (partition by sigma_4 multiplicities) | **exact** | ea_partition |
| Algorithm 2 (outer permutation search) | **exact** | partition_automorphisms counts (Table 1 "Permutations" column only) |
| Algorithm 3 (inner permutation search) | **exact** | inner_permutation recovery |
| Section 5 (partition statistics for known APN) | **bounded** | catalog quadratic APN, n=5..8 |
| Table 1 timing columns | **skipped** | timing experiments excluded per scope |
| Table 2 (inner permutation timing) | **skipped** | timing experiments excluded per scope |

## Architecture restrictions
- No new VBF core math. All algorithms already in `packages/VBF/src/equivalence/ea/`.
- Paper scripts orchestrate VBF APIs.
- No dependency from VBF → VBFCatalog.

## File layout
```
papers/Kaleyski_202203/
  PLAN.md
  Makefile
  helpers.jl            shared utilities, sigma_multiplicities_vec
  proposition1.jl       Prop 1: EA-invariance of sigma multiplicities (even k)
  proposition2.jl       Prop 2: quadratic normalization to linear A1, A2
  proposition4.jl       Prop 4: Walsh formula matches direct computation
  algorithm1.jl         Algorithm 1: partition by sigma_4 multiplicities
  algorithm2.jl         Algorithm 2: outer permutation enumeration (counts only)
  algorithm3.jl         Algorithm 3: inner permutation reconstruction
  section5.jl           Section 5: partition statistics for catalog APN
  report.jl             Aggregate paper_report
  input/                (source material, read-only)
  results/              (generated, git-ignored)
  test/
    runtests.jl
    test_proposition4.jl
    test_algorithm1.jl
    test_algorithm2.jl
    test_algorithm3.jl
    test_section5.jl
```

## Makefile targets
- `make test` — fast suite (≤ 60 s, n ≤ 6)
- `make report` — aggregate report, bounded
- `make proposition1`, `proposition2`, ..., `section5` — individual claim runners

## Acceptance criteria
- `make test` passes.
- `make report` completes without long search.
- All expensive steps guarded by `limit` or `n_max`.
- Gold x^3 partition at n=6 gives 3 buckets.
- Walsh formula == direct formula for all n ≤ 6.
- inner_permutation recovers known A2 on n=5 test.
