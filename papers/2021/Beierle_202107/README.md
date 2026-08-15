# Beierle_202107 — Linearly Self-Equivalent APN Permutations in Small Dimension

**Paper**: Beierle, Brinkmann, Leander. "Linearly Self-Equivalent APN Permutations in
Small Dimension." IEEE Transactions on Information Theory, 2021.

**Reproduction path**: `papers/2021/Beierle_202107/`

**Verdict**: Partial

Corollary 1's tuple classification (17/27/32 classes for n=6/7/8) and the Proposition 4
and 5 admissibility filters are reproduced exactly and independently confirmed. What is
*not* reproduced is the part of the paper those filters feed into: Algorithm 1 is missing
both search-space reductions (Lemma 5's `isSmallest`/commutant quotient and Lemma 6's
extendability seeding), so the exhaustive per-class searches that establish Theorem 1
("only one APN permutation in dimension 6 up to CCZ"), Theorem 3 and Theorem 4 cannot
actually be run. Table 1's "no (Alg. 1)" column is never checked. Theorem 2 and all of
Section 3 are absent. A previous revision of this file recorded a verdict of "Complete";
that was not supportable and has been corrected.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Every numeric claim below marked "independently confirmed" was
> re-derived from scratch in Python (GF(2^n) arithmetic, DDT, ANF degree, Walsh spectra,
> ortho-derivative invariants) rather than taken from the repository's own output.

---

## Paper Issues

None found. Every checkable numeric statement tested — Corollary 1's lists for n=6,7,8,
Table 1's Proposition 4 and Proposition 5 columns, and Theorem 1 — is correct.

---

## Reproduction Issues

### 1. Self-equivalence relation has `A` and `B` swapped; stored solutions are the inverses of the paper's functions

- **Location**: `algorithm1.jl:322-334` (the `apply_A ← B` / `apply_B ← A` swap),
  `helpers.jl:4-7`, `test/test_algorithm1.jl:36`
- **Symptom**: The paper (Corollary 1, definition of `Aut_LE`) requires `F ∘ A = B ∘ F`,
  i.e. `F(Ax) = B·F(x)`. The stored solutions satisfy the opposite relation:

  | n | class | `F(Ax)=B·F(x)` | `F(Bx)=A·F(x)` |
  |---|-------|----------------|----------------|
  | 6 | 5     | true (A=B)     | true           |
  | 7 | 4,5,7,8,9,10 | **false** | true          |

  Meanwhile the TOML files store `A`/`B` under the *paper's* naming — decoding every
  companion block confirms n=6 class 1 has `A = Comp(X⁶+X³+X²+1)`,
  `B = Comp(X⁶+X⁵+X⁴+X³+X+1)`, exactly Corollary 1's class 1. So `APNSearchClasses`
  feeds paper-`A` into the code slot documented as paper-`B`.
- **Root cause**: `APNSearch(n, A, B)` documents `F(Bx) = A·F(x)`; `APNSearchClasses`
  (`algorithm1.jl:365-366`) passes `precomputed_tuple_matrices` output `(A_paper, B_paper)`
  straight into that signature. The docstring note "code's `(A,B)` corresponds to the
  paper's `(B,A)`" contradicts the TOML labelling. Mathematically harmless
  (`F∘A=B∘F ⟺ F⁻¹∘B=A∘F⁻¹`, and `F ~CCZ F⁻¹`), so admissibility and CCZ classes are
  unchanged — but the persisted LUTs are the inverses of the paper's `F`, which silently
  breaks side-by-side reading. A prior revision documented this rather than fixing it.
- **Resolution plan**:
  1. Rename `APNSearch`'s parameters to `(B_paper, A_paper)`, or invert the internal
     wiring so the returned `F` satisfies `F(Ax) = B·F(x)` against the TOML's `A`, `B`.
  2. Update `test/test_algorithm1.jl:36` and `test/test_APNSearch.jl` to assert the
     paper's relation.
  3. Regenerate or relabel the six n=7 and one n=6 `search =` vectors, or add a TOML
     header note stating they are `F⁻¹`.
  4. Delete the now-wrong docstring notes at `algorithm1.jl:284-290` and `helpers.jl:4-7`.

### 2. Algorithm 1 is only partially implemented — both feasibility reductions are missing

- **Location**: `algorithm1.jl:209-238` (`nextVal`)
- **Symptom**: Algorithm 1's pseudocode (paper, p. 663) takes `C_A ⊆ Comm(A)`,
  `C_B ⊆ Comm(B)`, calls `isSmallest(sbox)`, and runs while `depth ≤ t`. The reproduction
  has no `C_A`/`C_B` arguments, no `isSmallest`, and no depth threshold `t`. Lemma 5
  (`Comm(B) ∘ F ∘ Comm(A)`) and Lemma 6 / Definition 5 (extendable matrices — the trick
  that cut n=6 Class 14 to roughly 8 hours by pre-fixing `F` on the 8 fixed points of `A`)
  are absent entirely.
- **Root cause**: only the bare depth-first backtracking with a partial DDT was ported.
- **Resolution plan**:
  1. Add `Comm(M)` enumeration (commutant of an F₂ matrix) and the `isSmallest`
     lexicographic-representative test, guarded by `depth ≤ t`.
  2. Implement Definition 5 (`is_extendable`) and Lemma 6's seeding of `Ord(A,1)` with the
     unique 3-bit APN permutation up to affine equivalence.
  3. Add a test that n=6 Class 14 terminates — it is the paper's hardest exhaustive case.

### 3. Table 1's "no (Alg. 1)" column is never reproduced, so Theorems 1, 3 and 4 are asserted rather than verified

- **Location**: `report.jl:37-77` (`table1_report`)
- **Symptom**: `table1_report` verifies only the Proposition 4 and Proposition 5 rejection
  sets. The 8 (n=6), 4 (n=7) and 15 (n=8) classes the paper rejects *by exhaustive search*
  are not checked and no artifact records them. The reproduction shows that one solution
  exists in n=6 class 5; it never shows that classes 1, 2, 3, 7, 10, 11, 14, 15 are empty,
  which is what Theorem 1 requires.
- **Root cause**: the exhaustive runs were never performed or persisted — partly a
  consequence of issue 2.
- **Resolution plan**:
  1. After fixing issue 2, run `APNSearchClasses(6, "all")` to exhaustion and persist
     per-class solution counts (0 or >0) under `results/`.
  2. Extend `table1_report` with an "Alg. 1 rejects" column compared against Table 1.
  3. For n=7 and n=8, mark the still-infeasible classes explicitly (`16,22,23` and `22,30`)
     instead of silently omitting the column.

### 4. Theorem 2 (n=7 shift-invariant APN permutations are monomials) is missing

- **Location**: no file; `tuples/AllTuplesMatrices7.toml` block 1 has no `search =` entry.
- **Symptom**: Class 1 (`B = A = Comp(X⁷+1)`) is the shift-invariant class, and Table 1
  lists six solutions `x⁵, x⁹, x⁶³, x⁷⁸, x⁸⁵, x⁸⁸`. Nothing in the reproduction touches it.
- **Root cause**: the paper's own run needed "several days on a 256-core cluster".
- **Resolution plan**:
  1. Document it as explicitly out-of-scope in `report.jl`.
  2. At minimum verify the six monomials *are* solutions for class 1 (cheap), and declare
     the class-1 stored result set incomplete.

### 5. Corollary 1's n=7 and n=8 counts are unverified and the tuple files cannot be regenerated

- **Location**: `test/runtests.jl:20-22`, `Makefile:21-30`, `helpers.jl:240`
- **Symptom**:
  - `@test length(gen_permutation_tuples(6)) == 17` passes, but the `27` and `32`
    assertions are **commented out** (lines 21-22).
  - `make corollary1_n6n7n8 n=N` only `println`s two file paths — it generates nothing.
  - The TOML headers say "Regenerate it with `generate_tuple_matrix_constants_file(n)`";
    `grep -rn generate_tuple_matrix_constants_file packages/ papers/` finds **no
    definition** anywhere in the repo.
  - Nothing checks that `gen_permutation_tuples(6)` agrees with the 17 stored blocks in
    order or content.
- **Root cause**: the generator was never written — only its output was committed.
- **Resolution plan**:
  1. Implement `generate_tuple_matrix_constants_file(n)` in `helpers.jl` (which already
     has `_write_tuple_matrix_constants`).
  2. Wire it into the `corollary1_n6n7n8` Makefile target.
  3. Re-enable the n=7/n=8 count assertions, guarded by `full_search` if slow.
  4. Add a test that the generated tuples match the committed TOML blocks.

### 6. n=7 classes 17, 18, 19 do not use the paper's Corollary 1 representatives

- **Location**: `tuples/AllTuplesMatrices7.toml`, blocks 17-19
- **Symptom**: decoding the companion blocks against Corollary 1's n=7 list gives:

  | # | paper `B` / `A` | TOML `B` / `A` |
  |---|-----------------|----------------|
  | 17 | `Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` / `Comp(X⁷+1)` | `Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` / `Comp(X⁷+1)` |
  | 18 | `Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` / `Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` | swapped w.r.t. paper |
  | 19 | `B=A=Comp(X³+X+1)⊕Comp(X⁴+X³+X²+1)` | `B=A=Comp(X³+X²+1)⊕Comp(X⁴+X²+X+1)` |

  These are reciprocal polynomials, i.e. the extended-power-similar partners (Definition 3,
  condition 2), so the classes are the same — but the printed matrices differ from the
  paper's. n=6 (all 17) and n=8 (all 32) match the paper **exactly**.
- **Root cause**: `remove_extended_power_similar_pairs` (`corollary1_n6n7n8.jl:103-119`)
  keeps whichever representative survives its scan order.
- **Resolution plan**:
  1. Add a canonicalisation preferring the paper's printed representative, or
  2. Record in the TOML/README that 17-19 are the extended-power-similar partners of the
     paper's list, with the reciprocal-polynomial evidence.

### 7. Sections 3.1–3.6 are entirely unreproduced

- **Location**: no files.
- **Symptom**: missing are Proposition 1 (`|Aut(F)| ≥ 2ⁿ` for quadratic `F`),
  Proposition 2 (binomial LE-automorphism from `ord(α) | (b−a)`), Proposition 3 (the
  multinomial version), Examples 1–5 (the concrete families of [32], [17], [6], [7]),
  Section 3.4's generalized butterflies (`H_{α,β} ∘ A = A ∘ H_{α,β}` with
  `A = diag(ζ³,ζ)`, plus the claim that these `A` are similar to
  `Comp(X⁶+X⁵+X⁴+X³+X²+X+1)` = Class 5), Remarks 1–3, Conjecture 1, and Section 5.4's
  randomized search.
- **Root cause**: not ported.
- **Resolution plan**: Propositions 2 and 3 are one-line checks and are the cheapest
  missing items — add `proposition1.jl`, `proposition2.jl`, `proposition3.jl` and the
  Section 3.4 butterfly check first.

### 8. Generated search artifacts are written into a tracked data directory

- **Location**: `helpers.jl:342-367` (`save_search_result_constant`), `algorithm1.jl:346-383`
- **Symptom**: search output is rewritten into `tuples/AllTuplesMatrices{n}.toml`, which is
  git-tracked *input* data. `AGENTS.md` ("Paper Reproductions") requires generated
  artifacts to be optional and written under the paper's `results/`.
- **Root cause**: the search persists in place rather than to an output directory.
- **Resolution plan**:
  1. Write solutions to `results/searchN_classK.toml` by default.
  2. Keep `tuples/` read-only.

### 9. `make report` target is missing

- **Location**: `Makefile:44-45` (`#report:` is commented out, as are `#proposition4:` and
  `#proposition5:`)
- **Symptom**: `report.jl` exists and is runnable, but
  `make -C papers/2021/Beierle_202107 report` fails.
- **Root cause**: targets were left commented out.
- **Resolution plan**: uncomment or re-add the `report`, `proposition4` and `proposition5`
  targets.

### 10. Undocumented magic visit-order offsets

- **Location**: `helpers.jl:137-145` (`c_reference_visit_order`)
- **Symptom**: n=7 class 24 uses offset 16 and class 26 uses offset 8, "to reproduce the C
  reference search". No paper statement justifies this. Both classes are Table-1
  "no (Alg. 1)" cases, so the offsets change nothing observable in the committed data.
- **Root cause**: carried over from the reference implementation without provenance.
- **Resolution plan**: document the provenance (reference [2] Zenodo code) or drop the
  special cases.

### 11. `_matrix_is_similar` is only valid for prime-order matrices

- **Location**: `helpers.jl:441-454`
- **Symptom**: similarity is decided by order, then `rank(A−I)` for order 2, else the
  characteristic polynomial. Equal characteristic polynomials do **not** imply similarity
  in general. It is correct for this paper's use (prime order `p` odd ⇒ the minimal
  polynomial divides the squarefree `Xᵖ+1` ⇒ semisimple), but the generic name invites
  misuse.
- **Root cause**: a specialised predicate given a general name.
- **Resolution plan**: rename to `_prime_order_matrix_is_similar` and add
  `@assert is_prime(order)`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| Corollary 1, n=6 — all 17 tuples | Every companion block decoded from `AllTuplesMatrices6.toml`; matches the paper's list 1–17 term-for-term, in order |
| Corollary 1, n=8 — all 32 tuples | Same; matches the paper's list 1–32 term-for-term |
| Corollary 1, n=7 — 24 of 27 tuples | Matches; 17–19 are equivalent-but-different representatives (issue 6) |
| Proposition 4 (`dim Ord ∉ {2,4,n−1}`) | Independent implementation rejects exactly `{6,9,13,16,17}` (n=6), `{12,13,14,15,20,21,25,27}` (n=7), `{13,18,19,20,21,25,26,28,32}` (n=8) — identical to Table 1 and to `report.jl`'s expectations |
| Proposition 5 (no common quadrinomial multiple) | Independent implementation rejects `{4,8,12}` (n=6), `{2,3,6,11,19}` (n=7), `{3,7,11,12,17,24}` (n=8) after removing Prop. 4 rejects — identical to Table 1 |
| Beth–Ding even-weight DDT restriction | `even_hamming_weight_differences` + `updateDDTInformationUnchecked` match the paper's `addDDTInformation`/`removeDDTInformation` pseudocode exactly, including the `−2 ⇒ break at 2` early exit |
| n=6 Class 5 solution | `du = 2`, permutation, `deg = 4`; differential spectrum and extended Walsh spectrum `((0,1008),(8,2688),(16,336))` identical to catalog `n6_Kim` — consistent with Theorem 1 |
| n=7 Class 4/5/7/8/9/10 solutions | All `du = 2` and permutations. Invariant fingerprints `(deg, deg F⁻¹, ext. Walsh)` identify cls 4→`x⁶³`, 8→`x⁷⁸`, 9→`x⁸⁵`, 10→`x⁸⁸` uniquely; the ortho-derivative differential spectrum separates cls 5→`x⁹` from cls 7→`x⁵`. The `class_to_exponent` map at `report.jl:122-123` is **correct** |
| Rational canonical form / companion-matrix enumeration | `get_rcfs`, `_companion_matrix_gf2`, `_valid_rcf_block_sequence` match Lemma 3 |
| Definition 3 (extended power-similarity) | `is_extended_power_similar` matches conditions 1 and 2 |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2021/Beierle_202107 test` | **Not run** — `julia` is not installed in the review environment |
| Independent Python re-derivation of Corollary 1 tuples, Prop. 4/5 filters, and the stored n=6/n=7 solutions | **All agree with the paper** (see table above) |

## Catalog Status

The paper claims **no new APN functions**. It confirms Dillon's permutation is the unique
n=6 APN permutation with non-trivial `Aut_LE`, and that the n=7 solutions are the six known
monomials.

- Dillon/Kim (n=6): **present** — `n6_Kim` in
  `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml`; spectra verified identical to the
  found permutation.
- n=7 monomials `x⁵, x⁹, x⁶³, x⁷⁸, x⁸⁵, x⁸⁸`: **present** up to cyclotomy as
  `n7_Gold_x5`, `n7_Gold_x9`, `n7_Kasami_x57` (covers `x⁸⁵`), `n7_Inverse_x126`,
  `n7_Niho_x39`, `n7_Welch_x11`.

**No catalog gaps.**

## Library-Reuse Note

Helpers duplicating VBF core exports:

| Helper (`helpers.jl:line`) | VBF symbol to call | Verdict |
|---|---|---|
| `int_matrix_to_lut` (:153) / `linear_map_lut` (:187) | `F2LinearMap` (columns as bitmasks) + broadcast | **duplicate** — `F2LinearMap` stores exactly this and evaluates `L(x)` |
| `_matrix_to_sbox` (:402) | same as above | **duplicate** |
| `rank_gf2` (:536), `nullity_gf2` (:540), `fixed_space_dimension_gf2` (:544) | `rank_f2`, `kernel_f2` | **duplicate** — they only wrap Nemo `rank` |
| `gf2_bitmul` (:587), `identity_bitmatrix` (:579), `gf2_bitmatrix` (:561/:570), `bitmatrix_multiplicative_order` (:601) | `F2LinearMap` + `compose` | **duplicate** — a hand-rolled second F₂ matrix arithmetic layer |
| `_is_apn` (:373) | `differential_uniformity(SBox{N}(lut)) == 2` | borderline — the raw-`Vector{Int}` hot path is defensible, but should be cross-checked against core in a test |

Legitimately paper-specific (not flagged): `even_hamming_weight_differences`,
`addDDTInformation`/`removeDDTInformation`, `orbit_orders`, `nextFreePosition`, the TOML
tuple I/O, `proposition4_filter`, `proposition5_filter`, `is_extended_power_similar`.

Promote-to-core candidates:

- `get_rcfs(n)` + `_companion_matrix_gf2` + `_integer_partitions` — rational canonical form
  enumeration over F₂ is generic linear algebra and belongs in `packages/VBF/src/linalg/`.
- Matrix multiplicative order and prime-order similarity testing over F₂ — generic; would
  remove the Nemo dependency except for `charpoly`/`minpoly`.
- `Comm(M)` (commutant of an F₂ matrix) — needed for issue 2, and generic.
