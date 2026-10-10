# Beierle_202107 — Linearly Self-Equivalent APN Permutations in Small Dimension

Current audit (2026-10-10): bounded Algorithm1 outcomes already distinguish
Found, Exhausted and BudgetHit. Additional tests pin zero-time uncertainty and
completed small searches. Region evidence now records the actual input/output
linear LUTs, initial partial LUT, and verification/reduction settings; an empty
bounded result never proves absence outside that specified region. Commutant
quotient and extendability seeding are still missing, so the paper's pruned
Algorithm1 traversal and global table-negative claims are not reproduced.

`generate_tuple_matrix_constants_file(n;output=...,full_search=false)` now
regenerates tuple classes into an explicit output file. n6 generation and
extended-power-similarity class-set agreement with the committed17blocks are
tested. n7/n8 regeneration is opt-in (`VBF_REPRO_FULL_SEARCH=true` in tests),
with expected27/32 assertions enabled there. Generated representatives/order
are not assumed byte-identical to the historical file: blocks17–19 in n7 use
reciprocal representatives and block18 has the documented orientation anomaly.
This is BBL2021 APN-permutation numbering, separate from the quadratic-APN tuple
catalog of Beierle–Leander2022. No historical constants were silently rewritten.
The dated review below is historical; this status supersedes resolved plans.

**Paper**: Beierle, Brinkmann, Leander. "Linearly Self-Equivalent APN Permutations in
Small Dimension." IEEE Transactions on Information Theory, 2021.

**Reproduction path**: `packages/VBFRepro/papers/2021/Beierle_202107/`

**Verdict**: Partial

Corollary 1's tuple classification (17/27/32 classes for n=6/7/8) and the Proposition 4
and 5 admissibility filters are reproduced exactly and independently confirmed. What is
*not* reproduced is the part of the paper those filters feed into: Algorithm 1 is missing
both search-space reductions (Lemma 5's `isSmallest`/commutant quotient and Lemma 6's
extendability seeding), so the exhaustive per-class searches that establish Theorem 1
("only one APN permutation in dimension 6 up to CCZ"), Theorem 3 and Theorem 4 cannot
actually be run. Table 1's "no (Alg. 1)" column is never checked. Theorem 2 and all of
Section 3 are absent.

> Every numeric claim below marked "independently confirmed" was first re-derived from scratch
> in Python (GF(2^n) arithmetic, DDT, ANF degree, Walsh spectra, ortho-derivative invariants,
> Γ-rank) and has since been re-checked against the repository's own Julia API on 2026-08-15
> (Julia 1.12.6). All agree except the extended-Walsh index convention — see "Test Results".

> **Supersedes a previous revision.** An earlier version of this file listed the `A`/`B`
> self-equivalence relation as reproduction issue 1 — a wrong constant to be fixed. That
> was incorrect. The stored convention is the one that reproduces Table 1 verbatim; the
> mismatch is in the paper's own class labels (paper issue 1 below) and in two backwards
> source comments (reproduction issue 10). No code change is warranted.

---

## Paper Issues

### 1. Corollary 1's `(B, A)` labels are inconsistent with Table 1's "solutions" column

- **Location**: Corollary 1 (n=7 list, classes 4, 5, 7, 8, 9, 10) versus Table 1's n=7
  "solutions" column.
- **Computed counter-evidence**: for the paper's class 5,
  `B = Comp(X⁷+X⁶+X⁵+X⁴+X³+X²+1)` and `A = Comp(X⁷+X⁶+1)`. Interpreting `A ↦ ·α`,
  `B ↦ ·β` in a common field model and solving `α^d = β` — the paper's own relation
  `F ∘ A = B ∘ F` with `F = x^d` — gives `d ∈ {15,30,60,71,99,113,120}`, the cyclotomic
  class of `9⁻¹ mod 127`, **not** `9`. The same one-sided mismatch holds for every class:

  | class | Table 1 | `d` under `F∘A=B∘F` | `d` under `F∘B=A∘F` |
  |-------|---------|---------------------|---------------------|
  | 4  | `x⁶³` | 63 ✔ (self-inverse class) | 63 ✔ |
  | 5  | `x⁹`  | 15 (= `9⁻¹` class) | **9** ✔ |
  | 7  | `x⁵`  | 51 (= `5⁻¹`) | **5** ✔ |
  | 8  | `x⁷⁸` | 57 (= `78⁻¹`) | **78** ✔ |
  | 9  | `x⁸⁵` | 3 (= `85⁻¹`) | **85** ✔ |
  | 10 | `x⁸⁸` | 13 (= `88⁻¹`) | **88** ✔ |

- **Severity**: cosmetic. `F ~CCZ F⁻¹`, so per-class admissibility and all four theorems
  are unaffected, and Table 1's caption ("we list all the solutions for the
  CCZ-equivalence classes") makes either exponent a valid class label. But the pattern is
  systematic, and it is why the repository's apparently-"swapped" convention is the one
  that reproduces Table 1 term-for-term.

No other checkable numeric claim in the paper was found wrong: Corollary 1's three lists
and Table 1's Proposition 4 and Proposition 5 columns all verify exactly.

---

## Reproduction Issues

### 1. Algorithm 1 is only half-implemented — both feasibility reductions are absent

- **Location**: `algorithm1.jl:209-238` (`nextVal`)
- **Symptom**: Algorithm 1's pseudocode takes `C_A ⊆ Comm(A)`, `C_B ⊆ Comm(B)`, calls
  `isSmallest(sbox)`, and branches on `depth ≤ t`. The reproduction has no `C_A`/`C_B`
  parameters, no `isSmallest`, and no threshold `t`. Lemma 5 (`Comm(B) ∘ F ∘ Comm(A)`) and
  Definition 5 / Lemma 6 (extendable matrices — the trick that cut n=6 Class 14 to roughly
  8 hours by pre-fixing `F` on the 8 fixed points of `A`) are missing entirely. No test
  exercises Class 14.
- **Root cause**: only the bare depth-first backtracking with a partial DDT was ported.
- **Resolution plan**:
  1. Add a commutant enumerator `Comm(M)` over `GL(n, F₂)`.
  2. Add `isSmallest` (lexicographic minimum under `C_B ∘ F ∘ C_A`), gated by `depth ≤ t`.
  3. Implement Definition 5 `is_extendable` and Lemma 6's seeding of `Ord(A,1)` with the
     unique 3-bit APN permutation.
  4. Add a regression test that n=6 Class 14 terminates with 0 solutions.

### 2. Timeouts are silently indistinguishable from "class is empty"

- **Location**: `algorithm1.jl:292-338` (`APNSearch`) and `algorithm1.jl:346-383`
  (`APNSearchClasses`); `context.timed_out` is set at `algorithm1.jl:151-157`.
- **Symptom**: `APNSearch` returns `context.solutions`; the `APNSearchContext` — and with
  it `timed_out` — is discarded. The Makefile default is `timeout_seconds ?= 300`
  (`Makefile:11`). A class that timed out returns `[]`, exactly like a class exhaustively
  proven to contain no APN permutation. That distinction is the entire content of Table 1's
  "no (Alg. 1)" column and of Theorems 1, 3 and 4.
- **Root cause**: the timeout flag is computed but never propagated to the caller.
- **Resolution plan**:
  1. Return `(solutions, timed_out)` or a `NamedTuple` from `APNSearch`/`APNSearchClasses`.
  2. Make `APNSearchClasses` record `:exhausted` / `:timed_out` per class.
  3. Refuse to persist a "no solutions" verdict for a class that timed out.

### 3. Table 1's "no (Alg. 1)" column is never reproduced, so Theorems 1, 3 and 4 are asserted rather than verified

- **Location**: `report.jl:37-77` (`table1_report`)
- **Symptom**: only the Proposition 4 and Proposition 5 rejection sets are checked. The
  8 (n=6), 4 (n=7) and 15 (n=8) classes the paper rejects *by exhaustive search* are
  neither run nor recorded. Theorem 1 therefore rests on an unverified claim that classes
  1, 2, 3, 7, 10, 11, 14, 15 are empty.
- **Root cause**: a consequence of issues 1 and 2 — the runs were never performed or
  persisted.
- **Resolution plan**:
  1. After issues 1 and 2, run `APNSearchClasses(6, "all")` to exhaustion and persist
     per-class counts under `results/`.
  2. Add an "Alg. 1 rejects" column to `table1_report`, compared against Table 1.
  3. Mark the paper's own open classes (n=7: 16, 22, 23; n=8: 22, 30) explicitly rather
     than omitting the column.

### 4. Theorem 2 (n=7 shift-invariant APN ⇒ monomial) is missing

- **Location**: no file; `tuples/AllTuplesMatrices7.toml` block 1 has no `search =` key
  (only blocks 4, 5, 7, 8, 9, 10 do).
- **Symptom**: Class 1 (`B = A = Comp(X⁷+1)`) is the shift-invariant class whose exhaustive
  search is Theorem 2's whole content. Nothing in the reproduction touches it.
- **Root cause**: the paper's own run took "several days on a cluster with 256 cores".
- **Resolution plan**:
  1. Declare it explicitly out of scope in `report.jl`.
  2. Cheaply verify the six monomials *are* class-1 solutions (they satisfy the
     self-equivalence by Section 3.2) and mark the stored class-1 result set incomplete.

### 5. Corollary 1 cannot be regenerated; n=7/n=8 counts are unasserted

- **Location**: `test/runtests.jl:20-22`; `Makefile:21-30`; `helpers.jl:240`
- **Symptom**: `@test length(gen_permutation_tuples(6)) == 17` passes, but the `27` and `32`
  assertions are commented out. `make corollary1_n6n7n8 n=N` only `println`s two paths — it
  generates nothing. The TOML headers say "Regenerate it with
  `generate_tuple_matrix_constants_file(n)`"; `grep -rn generate_tuple_matrix_constants_file`
  over the repo finds **no definition** (only the string at `helpers.jl:240` and the
  README). Nothing checks that `gen_permutation_tuples(6)` agrees with the 17 committed
  blocks.
- **Root cause**: only the generator's output was committed.
- **Resolution plan**:
  1. Implement `generate_tuple_matrix_constants_file(n)` on top of the existing
     `_write_tuple_matrix_constants` (`helpers.jl:238`).
  2. Wire it into the Makefile target.
  3. Re-enable the n=7/n=8 count assertions behind a `full_search` flag.
  4. Assert generated-versus-committed equality.

### 6. n=7 blocks 17, 18, 19 are not the paper's Corollary 1 representatives

- **Location**: `tuples/AllTuplesMatrices7.toml`, blocks 17-19
- **Symptom** (decoded companion blocks):

  | # | paper `B` / `A` | TOML `B` / `A` |
  |---|-----------------|----------------|
  | 17 | `Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` / `Comp(X⁷+1)` | `Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` / `Comp(X⁷+1)` |
  | 18 | `Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` / `Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` | exactly the paper's pair, with `A` and `B` **swapped** |
  | 19 | `B = A = Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` | `B = A = Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` |

  These are reciprocal polynomials, hence extended-power-similar partners (Definition 3,
  condition 2), so the classes are the same. But block 18 also contradicts the file's own
  `A`/`B` labelling, which is used consistently by the other 24 blocks and by all of n=6
  and n=8.
- **Root cause**: `remove_extended_power_similar_pairs` (`corollary1_n6n7n8.jl:103-119`)
  keeps whichever representative survives its scan order.
- **Resolution plan**:
  1. Canonicalise to the paper's printed representative; or
  2. Record the reciprocal-polynomial correspondence in the TOML and README, and at minimum
     fix block 18's `A`/`B` order so the file's labelling is self-consistent.

### 7. `exponent_names` mislabels `x⁸⁵` as "Kasami"

- **Location**: `report.jl:125-126`; the same wording appears at `test/test_APNSearch.jl:201`
- **Symptom**: the map contains `85 => "Kasami"`. But `85·3 = 255 = 2·127 + 1`, i.e.
  `85 = 3⁻¹ mod 127`, so `x⁸⁵` is the compositional inverse of the Gold function `x³` and
  is CCZ-equivalent to it. Computed fingerprints agree: `x⁸⁵` has
  `(deg F, deg F⁻¹) = (4, 2)` and delta-rank 198 — the Gold value quoted in the same test's
  own comment — whereas the genuine n=7 Kasami exponents are 13 and 57.
- **Root cause**: the family name was assigned from the exponent's degree rather than from
  its cyclotomic/inverse class.
- **Resolution plan**:
  1. Relabel `85 => "Gold x^3 (inverse)"`.
  2. Add the derivation `85 ≡ 3⁻¹ (mod 127)` as a comment.
  3. Note the same for `78 ≡ 57⁻¹` and `88 = 2³·11`.

### 8. n=7 class identification for classes 4, 8, 9, 10 is invariant-based only

- **Location**: `report.jl:143-151`; `test/test_APNSearch.jl:221-230`
- **Symptom**: for non-quadratic monomials the check degrades to `algebraic_degree` plus
  `delta_rank`, which are necessary but not sufficient for CCZ-equivalence. The report
  nevertheless prints `CCZ=true`.
- **Root cause**: full `are_ccz_equivalent` is stated to exceed memory at n=7.
- **Resolution plan**:
  1. Rename the printed field to `CCZ-invariants match`.
  2. Close the gap rigorously with the field-theoretic argument used in this review: derive
     `d` from the minimal polynomials of `A` and `B` via discrete log. It pins the exponent
     exactly and is `O(2ⁿ)`.

### 9. Search output is written into tracked input data; `make report` target missing

- **Location**: `helpers.jl:342-367` (`save_search_result_constant`) rewrites
  `tuples/AllTuplesMatrices{n}.toml`, which is git-tracked; `test/test_APNSearch.jl:146-170`
  mutates and restores that tracked file during the test run. `Makefile:38-45` has
  `#proposition4:`, `#proposition5:` and `#report:` all commented out, so
  `make -C packages/VBFRepro/papers/2021/Beierle_202107 report` fails even though `report.jl` is runnable.
- **Root cause**: search persists in place; targets were left commented out.
- **Resolution plan**:
  1. Default `save_result` to `results/searchN_classK.toml`.
  2. Keep `tuples/` read-only in tests.
  3. Restore the `report`, `proposition4` and `proposition5` targets.

### 10. Minor: backwards comments, undocumented magic visit orders, over-general similarity predicate, stale notes

- **Backwards `A`/`B` docstrings.** `helpers.jl:4-7` and `algorithm1.jl:284-290` claim "the
  code's `(A,B)` corresponds to the paper's `(B,A)`", but `APNSearchClasses`
  (`algorithm1.jl:365-366`) feeds `precomputed_tuple_matrices` output — which is paper-`A`,
  paper-`B` — straight into `APNSearch(n, A, B)`. All seven stored LUTs were verified to
  satisfy `F(Bx) = A·F(x)` under the TOML's own labels. The math is right (it is what
  reproduces Table 1 — see paper issue 1); the comments are backwards. Fix the comments,
  not the code.
- **Magic visit orders.** `helpers.jl:137-145` (`c_reference_visit_order`) hard-codes offset
  16 for n=7 class 24 and offset 8 for class 26 "to reproduce the C reference search", with
  no paper justification. Both are Table-1 "no (Alg. 1)" classes, so nothing observable
  changes. Document the provenance (reference [2], Zenodo `cbe90/self_equivalent_apn`) or
  drop it.
- **`_matrix_is_similar` is over-general.** `helpers.jl:441-454` decides similarity by
  order, then `rank(A−I)` for order 2, else equal characteristic polynomials. Equal
  charpoly does **not** imply similarity in general; it is correct here only because
  Lemma 2 restricts to prime order. Rename to `_prime_order_matrix_is_similar` and assert
  primality.
- **Stale gitignore claim.** `test/test_APNSearch.jl:96-97` calls
  `tuples/AllTuplesMatrices3.toml` "a generated, git-ignored artifact". It is tracked
  (`git ls-files` lists it) and `git check-ignore` reports "not ignored".
- **Unguarded loop bound.** `is_power_similar` (`corollary1_n6n7n8.jl:68`) loops
  `i in 0:(limit-1)`; `i = 0` gives `A⁰ = I`, harmless only because all matrices have prime
  order. `proposition5_filter` never checks that the order is prime, which is Proposition
  5's hypothesis.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| Corollary 1, n=6 — all 17 tuples | Every companion block of `AllTuplesMatrices6.toml` decoded into its polynomial; **17/17 match the paper's list in order**, with TOML `A` = paper's `A` and TOML `B` = paper's `B` |
| Corollary 1, n=8 — all 32 tuples | **32/32 match in order** |
| Corollary 1, n=7 — 24 of 27 tuples | **24/27 match**; blocks 17, 18, 19 are equivalent-but-different representatives (reproduction issue 6) |
| Proposition 4 (`dim Ord ∉ {2,4,n−1}`) | Independent implementation rejects exactly `{6,9,13,16,17}` (n=6), `{12,13,14,15,20,21,25,27}` (n=7), `{13,18,19,20,21,25,26,28,32}` (n=8) — identical to Table 1 and to `report.jl:40-44` |
| Proposition 5 (no common quadrinomial multiple) | Independent quadrinomial search rejects `{4,8,12}` / `{2,3,6,11,19}` / `{3,7,11,12,17,24}` after removing Proposition 4 rejects — identical to Table 1. Totals match the paper's prose (8/17, 13/27, 15/32) |
| Beth–Ding even-weight DDT restriction | `helpers.jl:16-72` matches the paper's `addDDTInformation`/`removeDDTInformation` pseudocode, including the `−2 ⇒ break at 2` early exit |
| n=6 class-5 stored solution | `du = 2`, permutation, `deg = 4`, extended Walsh `{0:1008, 8:2688, 16:336}` and differential spectrum `{0:2016, 2:2016}` identical to `dillon_apn_permutation()` and `n6_Kim` — consistent with Theorem 1 |
| n=7 class 4/5/7/8/9/10 solutions | All `du = 2` and permutations. An independent field-theoretic derivation (minimal polynomials of the class matrices → discrete log) yields **exactly** the paper's Table-1 exponents `x⁶³, x⁹, x⁵, x⁷⁸, x⁸⁵, x⁸⁸` under the repository's relation. `class_to_exponent` at `report.jl:122-123` is **correct** |
| Rational canonical form enumeration | `get_rcfs`, `_companion_matrix_gf2`, `_valid_rcf_block_sequence` (`helpers.jl:460-530`) match Lemma 3 |
| Definition 3 (extended power-similarity) | `is_extended_power_similar` (`corollary1_n6n7n8.jl:76-81`) matches conditions 1 and 2 |

## Test Results

Re-run on 2026-08-15 with **Julia 1.12.6** (project `/home/tiago/VBF.jl`, fully instantiated).

| | |
|---|---|
| Command | `make -C packages/VBFRepro/papers/2021/Beierle_202107 test` |
| Exit code | **0** |
| Wall time | **66 s** (one of the slower paper suites; the two CCZ testsets account for ~48 s) |
| Totals | **223 passed, 0 failed, 0 errored, 0 broken, 0 skipped** |

| Testset | Pass | Broken | Fail | Time |
|---|---|---|---|---|
| Proposition 4 Direct Matrix Cases | 2 | 0 | 0 | 3.1 s |
| Proposition 4 Precomputed n = 6 Classes | 17 | 0 | 0 | 1.8 s |
| Proposition 4 Precomputed n = 7 Classes | 27 | 0 | 0 | 0.1 s |
| Proposition 4 Precomputed n = 8 Classes | 32 | 0 | 0 | 0.1 s |
| Proposition 5 Direct Precomputed Cases | 2 | 0 | 0 | 0.1 s |
| Proposition 5 Precomputed n = 6 Classes | 17 | 0 | 0 | 0.0 s |
| Proposition 5 Precomputed n = 7 Classes | 27 | 0 | 0 | 0.1 s |
| Proposition 5 Precomputed n = 8 Classes | 32 | 0 | 0 | 0.1 s |
| Dynamic DDT Updates | 6 | 0 | 0 | 0.2 s |
| S-box Search State Helpers | 3 | 0 | 0 | 0.0 s |
| APN Search Solution Callbacks | 4 | 0 | 0 | 0.1 s |
| S-box Polynomial Interpolation | 2 | 0 | 0 | 0.6 s |
| APN Search Class Selection | 6 | 0 | 0 | 0.4 s |
| APN Search Batch Classes | 3 | 0 | 0 | 0.4 s |
| APN Search Injected Result Persistence | 2 | 0 | 0 | 0.1 s |
| APN Search Matrix Constant Output | 2 | 0 | 0 | 0.6 s |
| N=6 Class 5 CCZ-Equivalence to Dillon's Permutation | 4 | 0 | 0 | 25.9 s |
| N=7 Search Result CCZ-Equivalence to Monomials | 28 | 0 | 0 | 22.3 s |
| Algorithm 1 APNSearch Entry Point | 1 | 0 | 0 | 0.0 s |
| Algorithm 1 C reference n = 7 class 4 | 3 | 0 | 0 | 0.1 s |
| Linearly self-equivalent APN permutation tuple experiment | 3 | 0 | 0 | 2.3 s |
| **Total** | **223** | **0** | **0** | — |

The suite mutates and restores the git-tracked `tuples/AllTuplesMatrices3.toml`
(`test/test_APNSearch.jl:146-170`); `git status --porcelain packages/VBFRepro/papers/2021/Beierle_202107/` was
clean after the run, so the restore works — but the write still targets tracked data
(reproduction issue 9).

`report.jl` is runnable directly (`julia --project=. packages/VBFRepro/papers/2021/Beierle_202107/report.jl`,
exit 0) and every check it prints is `[PASS]`. `make report` still fails: the `report` target
is commented out at `Makefile:44`.

> **Walsh convention**: `VBF.absolute_walsh_spectrum` ranges over all `(a,b) ≠ (0,0)` (4095
> entries, `packages/VBF/src/spectra/linear.jl:61-70`), while the extended Walsh spectrum
> quoted elsewhere in this file ranges over `b ≠ 0` only (4032 entries). The non-zero parts
> are identical; the zero counts differ by the 63 masks with `a = 0`, all giving `W = 0`
> because `F` is a permutation.

## Catalog Status

The paper claims **no new APN function**.

- Dillon's permutation / n=6 class-5 solution: **present** — `n6_Kim` in
  `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml` and `dillon_apn_permutation()` in
  core; identical extended Walsh and differential spectra, and identical Γ-rank 1166
  (computed).
- n=7 solutions `x⁵, x⁹, x⁶³, x⁷⁸, x⁸⁵, x⁸⁸`: **present** as `n7_Gold_x5`, `n7_Gold_x9`,
  `n7_Inverse_x126` (63·2 = 126), `n7_Niho_x39` (78 = 2·39), `n7_Gold_x3` (85 = 3⁻¹),
  `n7_Welch_x11` (88 = 2³·11).

**No catalog gaps.** Two read-only observations worth acting on separately:

- `n7_apn.toml` contains CCZ-**duplicates**: `n7_Kasami_x13` ≡ `n7_Welch_x11`
  (`13⁻¹ = 88 = 2³·11`) and `n7_Kasami_x57` ≡ `n7_Niho_x39` (`57⁻¹ = 78 = 2·39`). Its 8
  monomial entries cover only 6 CCZ classes.
- `packages/VBFCatalog/data-raw/le_automorphism_tuples/n7.toml` holds a *different* n=7
  LE-automorphism class numbering (Beierle–Leander 2022, quadratic APN functions, not
  permutations). Only `class1` coincides with this paper's class 1; classes 7, 16, 19 do
  **not** match Corollary 1's indices 7, 16, 19. Two incompatible "n=7 class number" schemes
  coexist in the repository — worth a cross-reference note.

## Library-Reuse Note

| Helper (`helpers.jl:line`) | VBF symbol to call | Verdict |
|---|---|---|
| `int_matrix_to_lut` (:153), `linear_map_lut` (:187), `_matrix_to_sbox` (:402) | `F2LinearMap` (columns as bitmasks) + broadcast | **duplicate** |
| `rank_gf2` (:536), `nullity_gf2` (:540), `fixed_space_dimension_gf2` (:544) | `rank_f2`, `kernel_f2` | **duplicate** (thin Nemo wrappers) |
| `gf2_bitmatrix` (:561, :570), `identity_bitmatrix` (:579), `gf2_bitmul` (:587), `precompute_gf2_bit_powers` (:613) | `F2LinearMap` + `compose` / `identity_linear_map` | **duplicate** — a second hand-rolled F₂ matrix layer |
| `_matrix_multiplicative_order` (:409), `bitmatrix_multiplicative_order` (:601) | `permutation_order(SBox{N}(lut))` | **duplicate** |
| `_is_apn` (:373) | `differential_uniformity(SBox{N}(lut)) == 2` | borderline — the raw-`Vector{Int}` hot path is defensible; add a cross-check test |
| `addDDTInformation` / `removeDDTInformation` / `even_hamming_weight_differences` (:16-72) | private `_add_point!`/`_remove_point!` in `packages/VBF/src/constructions/le_automorphism_search.jl` | **near-duplicate of core-internal machinery** — core's version is quadratic-specialised and unexported, so this is a *promote/expose* item, not a violation |

Legitimately paper-specific (not flagged): `orbit_orders` (:197), `nextFreePosition`, the
visit orders, the TOML tuple I/O, `proposition4_filter`, `proposition5_filter`,
`xor3_equals_identity`, `is_extended_power_similar`.

Promote-to-core candidates:

- Rational-canonical-form enumeration over F₂ — `get_rcfs`, `_companion_matrix_gf2`,
  `_monic_invertible_poly_coeffs`, `_integer_partitions` (`helpers.jl:460-530`).
- Prime-order matrix similarity testing over F₂.
- The commutant `Comm(M)` of an F₂ matrix — needed for reproduction issue 1, and generic.

## Open Questions

- Is the n=7 block 17/18/19 representative choice deliberate (matching the authors' Zenodo
  code) or accidental? If deliberate, the TOML should say so.
- Should `packages/VBFRepro/papers/2021/Beierle_202107/tuples/` be consolidated with
  `packages/VBFCatalog/data-raw/le_automorphism_tuples/`?
