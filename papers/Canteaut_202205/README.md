# Canteaut_202205 Review

Paper: Anne Canteaut, Alain Couvreur, Leo Perrin (2022), "Recovering or Testing Extended-Affine Equivalence".

Reproduction path: `papers/Canteaut_202205/`.

Verdict: Mostly complete. The reproduction covers most core Jacobian, EA-recovery, ortho-derivative, Kim-class, and Banff-list claims. All tests pass.

## Issue Catalog

### Paper Issues

1. **Open-butterfly formula component order**
   - The paper prints `H_{α,β}(x,y) = (T_y⁻¹(x), T_{T_y⁻¹(x)}(y))` (Eq. below
     Remark 41), but this component ordering is not an involution (verified
     computationally). The correct involutive form swaps the two components:
     `H(x,y) = (T_{T_y⁻¹(x)}(y), T_y⁻¹(x))`. Likely a notational swap in the
     paper or a convention difference with the original [CDP17] definition.

### Reproduction Issues

1. [RESOLVED] Stale catalog-size assertion for Section 4.4.
   - Location: `test/test_section4_4.jl:17-20`, `section4_4.jl:18-20`.
   - Symptom: `julia --project=/home/tiago/VBF.jl -e 'ENV["CANTEAUT_202205_FAST"]="1"; include("papers/Canteaut_202205/test/runtests.jl")'` exits with one failure. The assertion `length(quad_fns) == 15` evaluates as `16 == 15`; the Section 4.4 test summary is 16 passed, 1 failed.
   - Root cause: the current catalog has 16 quadratic 6-bit APN entries, while the reproduction still documents and asserts the older count of 15. The EA partition check still finds 13 buckets.
   - Resolution: No code change needed. The catalog was rebuilt in commit 8022d09 (drop false-novel APN additions), restoring the quadratic n=6 count to 15. The existing assertion `length(quad_fns) == 15` is correct and all 16 section4_4 tests pass.

2. [RESOLVED — out-of-scope] Section 4.5 eight-bit APN partitioning is not reproduced.
   - Location: `report.jl:44-45`.
   - Root cause: The 21,102-function eight-bit APN corpus is not available in
     the repo, and the bucketing run would take hours of ortho-derivative
     computation. This is an external-data experiment beyond the reproduction's
     scope.
   - Resolution: Explicitly documented as out-of-scope in the report docstring.
     The paper's 486-bucket result and Table 8 are not mathematically verifiable
     without the corpus. No code change.

3. [RESOLVED — out-of-scope] Tables 3-4 timing experiments are skipped.
   - Location: `report.jl:41-43`.
   - Root cause: Tables 3-4 contain running times of the authors' Sage
     implementation on specific hardware. These are benchmark results, not
     mathematical claims.
   - Resolution: Explicitly documented as out-of-scope in the report docstring.
     The reproduction prints its own Julia timing information in
     `algorithm1_report`. No code change.

4. [RESOLVED] Table 7 `min #EA` sweep is only partially run by default.
   - Location: `section4_4.jl:127-134`, `Makefile`.
   - Symptom: Only κ's min-#EA column is verified by default (in section4_3);
     the other 12 functions require `verify_min_ea = true` (~25-30 min).
   - Resolution: Added `make table7_full` Makefile target that runs
     `section4_4_report(; verify_min_ea = true)` for the full 13-function sweep.
     Default test stays fast (κ only). Help text documents the slow target.

5. [RESOLVED] Proposition 25/Table 2 was limited to the square `n = m = 6` case.
   - Location: `proposition25.jl`.
   - Symptom: Paper reports tests for m, n ∈ {6, 8}; reproduction only verified n=6.
   - Resolution: Parameterized `proposition25_report` over `n_values` (default
     `[6, 8]`). Updated test to cover both dimensions. The n=8 case exercises
     128-variable GF(2) systems via the multi-word solver. 31/31 tests pass.

6. [RESOLVED] Algorithm 1 rank selection diverged from the paper.
   - Location: `algorithm1.jl:197-201`.
   - Symptom: Implementation used `minimum(keys(rdist_F))` (smallest rank);
     paper says "one of the least frequently occurring nonzero ranks" (line 791).
   - Resolution: Changed to sort ranks by frequency ascending (then by rank
     value for tie-breaking). Implemented Remark 28 fallback: if the rarest
     rank doesn't provide s linearly independent vectors, spills to the
     next-rarest rank, with per-slot search pools matching each reference
     vector's rank. For APN inputs (all ranks equal), behavior is unchanged.

7. [RESOLVED — paper issue] Open-butterfly representative is not formula-exact.
   - Location: `section4_3.jl:66-83`.
   - Symptom: Code outputs `(T_{T_y⁻¹(x)}(y), T_y⁻¹(x))` while paper prints
     `(T_y⁻¹(x), T_{T_y⁻¹(x)}(y))`.
   - Root cause: The paper's printed component ordering is not an involution
     (verified computationally over all 64 inputs). The code's ordering IS
     the correct involution. This is a paper issue (formula typo or
     convention mismatch with [CDP17]), not a reproduction bug.
   - Resolution: Updated the docstring to document the discrepancy and explain
     why the code's ordering is correct. Moved to Paper Issues above.

## Items Reproduced Exactly

- Propositions 14, 16, 18, 22, Corollary 24, and Propositions 35-36 are implemented and tested on Gold, Kim, and random quadratic examples.
- Algorithm 1 is implemented for square S-boxes and recovers EA triples for the tested Gold examples. Rank selection follows the paper's frequency-based heuristic with Remark 28 fallback.
- Proposition 25/Table 2 rank-bound behavior is tested for n = m ∈ {6, 8}.
- Section 4.3 reproduces the Kim mapping CCZ-class structure: 222 spaces, 8 spectra, 4 affine / 2 EA permutation classes, butterflies, 3-twist structure.
- Section 4.4 reproduces Tables 6-7: Banff functions, APN checks, ortho-derivative spectra, and catalog EA buckets. Full min-#EA sweep available via `make table7_full`.

## Test Results

- `CANTEAUT_202205_FAST=1 julia --project=/home/tiago/VBF.jl papers/Canteaut_202205/test/runtests.jl`: all 109 tests pass (proposition14 7/7, section3_2 4/4, proposition18 8/8, proposition22 6/6, corollary24 8/8, proposition25 31/31, algorithm1 9/9, proposition35_36 7/7, section4_3 13/13, section4_4 16/16).

## Catalog Status

No new APN function is claimed by this paper, so there is no Catalog-gap record. The current catalog query found 15 quadratic 6-bit APN entries partitioning into 13 EA mugshot buckets, matching the Banff classes.

## Library-Reuse Note

No strict helper reuse violation was found for exported VBF finite-field, QAM, report, spectrum, or catalog primitives. The reproduction generally uses the core APIs.

Promote-to-core candidate: `helpers.jl:229` implements a generic multiword augmented GF(2) solver, and `helpers.jl:304` implements `extract_f2linear`. Core exports `solve_f2` and `kernel_f2`, but those are single-word row-mask APIs, so this is a reusable core API gap rather than a direct duplication.
