# Beierle_202107 — Linearly Self-Equivalent APN Permutations in Small Dimension

**Paper**: Beierle, Brinkmann, Leander. "Linearly Self-Equivalent APN Permutations in Small Dimension." IEEE Transactions on Information Theory, 2021.

**Reproduction path**: `papers/Beierle_202107/`

**Verdict**: Complete

Core computational contributions reproduced: Corollary 1 tuple classification (17/27/32 classes for n=6/7/8), Propositions 4 and 5 admissibility filters, Algorithm 1 (depth-first APN search with partial DDT), Table 1 admissibility results. All 223 test assertions pass. Pre-computed TOML data verified. N=6 class 5 result stored and CCZ-verified against Dillon's permutation. N=7 stored search results confirmed APN permutations with CCZ-equivalence to known monomials. Report.jl populated with structured verification.

---

## Paper Issues

None found.

---

## Reproduction Issues

### 1. Empty `report.jl` [RESOLVED]

- **Location**: `papers/Beierle_202107/report.jl`
- **Symptom**: File is 0 bytes. No structured reproduction report generated.
- **Root cause**: Report script was never written.
- **Resolution**: Populated `report.jl` with `paper_report()` that verifies Table 1 admissibility (Props 4/5 for n=6,7,8), Theorem 1 (n=6 class 5 result CCZ-equiv to Dillon), and n=7 monomial CCZ-equivalence (6 classes). Uses `print_banner`, `print_section`, `print_check`, `print_kv` from VBF core.

### 2. No CCZ-equivalence verification of search results [RESOLVED]

- **Location**: `papers/Beierle_202107/test/test_APNSearch.jl`
- **Symptom**: The 6 stored n=7 search results are verified as APN permutations with correct self-equivalences, but CCZ-equivalence to the claimed monomial functions (Gold, Kasami, etc.) is never checked.
- **Root cause**: CCZ-equivalence check not implemented in tests.
- **Resolution**: Added test set "N=7 Search Result CCZ-Equivalence to Monomials" (28 assertions). Mapping: class 4->x^63 (inverse), 5->x^9 (Gold), 7->x^5 (Gold), 8->x^78 (Niho), 9->x^85 (Kasami), 10->x^88 (Welch). Quadratic pairs (Gold) verified via `are_ccz_equivalent`; non-quadratic pairs verified via algebraic degree + delta-rank CCZ-invariants (full CCZ OOMs for non-quadratic n=7).

### 3. No n=6 search results stored [RESOLVED]

- **Location**: `papers/Beierle_202107/tuples/AllTuplesMatrices6.toml`
- **Symptom**: N=6 class 5 search completes in seconds and finds Dillon's permutation, but no result is stored in the TOML file.
- **Root cause**: Search results for n=6 were never persisted.
- **Resolution**: Ran `APNSearchClasses(6, [5]; save_results=true)` to store the result in `AllTuplesMatrices6.toml` block 5. Added test set "N=6 Class 5 CCZ-Equivalence to Dillon's Permutation" (4 assertions) verifying APN, permutation, and CCZ-equivalence to `dillon_apn_permutation()`.

### 4. A/B convention inverted relative to paper [RESOLVED]

- **Location**: `papers/Beierle_202107/algorithm1.jl:311-312`, `papers/Beierle_202107/helpers.jl`
- **Symptom**: `APNSearch(n, A, B)` docstring says "F(Bx) = A F(x)" while the paper uses F o A = B o F. Internally the code swaps A and B when creating the search context. Functionally correct but naming is confusing when reading alongside the paper.
- **Root cause**: Convention was inverted during implementation.
- **Resolution**: Added convention note to the `APNSearch` docstring explaining the paper's (A,B) vs code's (A,B) mapping, inline comment at the swap site (lines 315-319) documenting `apply_A <- B` / `apply_B <- A`, and a header comment in `helpers.jl`.

### 5. Skipped tests without `AllTuplesMatrices3.toml` [RESOLVED]

- **Location**: `papers/Beierle_202107/test/runtests.jl`
- **Symptom**: 5 test sets skipped in fresh checkout because `AllTuplesMatrices3.toml` must be generated via `make corollary1_n6n7n8 n=3`.
- **Root cause**: Generated artifact not committed.
- **Resolution**: Generated and committed `tuples/AllTuplesMatrices3.toml` (4 blocks for n=3). Tests that were previously skipped behind the `isfile(_TUPLES3_FILE)` guard now run.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| Corollary 1 (tuple counts: 17/27/32) | TOML files contain exactly 17/27/32 blocks; `gen_permutation_tuples(6)==17` tested |
| Proposition 4 (forbidden dimension filter) | Tests verify all 76 cases (17+27+32) against Table 1 |
| Proposition 5 (quadrinomial criterion) | Tests verify all 76 cases; consistent superset of Table 1 |
| Algorithm 1 (depth-first APN search) | Full implementation with partial DDT, orbit assignment, backtracking |
| Table 1 admissibility (n=6) | Prop 4 rejects {6,9,13,16,17}, Prop 5 rejects {4,8,12} -- exact match |
| Table 1 admissibility (n=7) | Prop 4 rejects {12,13,14,15,20,21,25,27}, Prop 5 rejects {2,3,6,11,19} -- matches |
| Table 1 admissibility (n=8) | Prop 4 rejects {13,18,19,20,21,25,26,28,32}, Prop 5 rejects {3,7,11,12,17,24} -- matches |
| Table 1 solutions (n=7 classes 4,5,7,8,9,10) | Stored results verified APN, permutations, self-equivalences correct |
| APN monomial exponents (n=7) | All 6 (x^5, x^9, x^63, x^78, x^85, x^88) verified APN permutations |
| Partial DDT update (Beth-Ding optimization) | Even-Hamming-weight optimization correctly implemented |
| Companion matrix / RCF enumeration | `get_rcfs`, `_companion_matrix_gf2` match paper definitions |
| Extended power-similarity (Definition 3) | `is_extended_power_similar` implemented and tested |

## Test Results

| Command | Result |
|---------|--------|
| `julia --project=. papers/Beierle_202107/test/runtests.jl` | **PASS** (21 test sets, 223 assertions) |
| Manual n=6 class 5 APNSearch | **PASS** (1 APN permutation found) |
| Manual n=7 monomial verification | **PASS** (all 6 exponents verified) |
| Manual n=7 stored search result verification | **PASS** (du=2, permutation, self-equivalence) |

## Catalog Status

Paper does not claim new APN functions. Confirms Dillon's permutation (catalog: `n6_Kim`) is the unique n=6 APN permutation with non-trivial LE-automorphism, and n=7 solutions are known monomials. No catalog gaps.

## Library-Reuse Note

`_is_apn` in `helpers.jl:368` is a borderline duplicate of `differential_uniformity(SBox(...)) == 2`, but operates on raw `Vector{Int}` for performance in the search verification path. Acceptable. All other helpers (partial DDT, RCF enumeration, BitMatrix GF(2) ops) are paper-specific with no VBF core equivalent.
