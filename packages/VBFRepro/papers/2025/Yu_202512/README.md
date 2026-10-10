# Yu_202512 — Classification of Quadratic APN Functions with Coefficients in F₂ in Dimension 10

## Scoped feasibility review (2026-10-10)

**F004: Partial.** Fresh restricted-domain traversals completed at n=8 and n=9. Minimum-log representatives give **109 versus 142** and **25 versus 26** in the source table; minimum-value n=8 gives **82**. The n=6/7 agreement therefore does not settle the authors’ convention. Regression evidence and independent pruning controls are feasible; n=10 and faithful Table 2 reproduction remain unresolved.

This read-only review did not rerun the full paper test suite or establish new
catalog gaps. See the [eight-finding work plan](../../../../../audit/partial_feasibility.md)
and [bounded probe evidence](../../../../../audit/partial_feasibility_probes.toml)
for commands, hashes, acceptance criteria and mathematical limits. This current
assessment supersedes conflicting historical scope descriptions below.

## Audit corrections (2026-10-10)

F004: `fn_set` now exposes `reps=:min_value` and `:min_log`; Algorithm 3
and Table 2 record the selected convention. Exhausting the finite restricted
spaces gives `(1,117)` under minimum integer value and `(4,78)` under minimum
discrete logarithm at `n=(6,7)`. The latter is the explicit default and matches
the printed counts; the paper's Definition 2 does **not** specify which
representatives the authors used. This agreement does not resolve that missing
information or certify unrestricted class coverage. DFS now stops on its
actual evaluation budget and reports exhaustion only after traversal finishes.
Table 2 `n≥8` remains **UNREPRODUCED** by the bounded report.

F005: Table 3 uses the combined ortho-derivative differential **and Walsh**
mugshot. All six verified quadratic APNs have distinct combined invariants;
`x³` and `x³³` collide under the previous DDT-only filter. Unequal invariants
prove inequivalence for these verified quadratic APNs; equal invariants would
require an equivalence witness or a complete solver. This establishes six
classes, not an exhaustive classification at `n=11`.

The supplied LaTeX prints **x³** in Tables 1 and 3. Older reproduction notes
accusing it of printing x⁴ were incorrect and have been removed from the active
code. Historical review descriptions below are superseded where they disagree
with these corrections.


**Paper**: Yu, Li, Ichanska, Kaleyski. "Classification of quadratic APN functions with
coefficients in `F₂` in dimension 10." 2025.

**Reproduction path**: `packages/VBFRepro/papers/2025/Yu_202512/`

**Verdict**: Partial

The theory layer — Theorems 1-2, Corollary 1, the Examples, and Algorithms 1-2 — is faithful
and correct. Algorithm 1's correctness was confirmed decisively: an independent port of
`is_qam_fast` + `is_proper_sub` + `update_diagonal!` + `fn_set` reproduces exhaustive
brute-force counts exactly (n=5: 72 = 360/5; n=6: 32 = 192/6). But two of the three tables
mis-report against the paper, the paper's single novel contribution is never tied to its
claim, and one "paper error" recorded in the reproduction does not exist in the paper.

> **Re-review 2026-08-15, Julia 1.12.6**: every target below now executes. Both failures the
> earlier Python port predicted reproduce **exactly** in real Julia, so the Table-2 and
> Table-3 mismatches are confirmed genuine properties of the reproduction, not porting
> artifacts. Three absolute-Walsh spectra quoted in this file have been corrected — the Python
> port excluded the whole `b=0` column, while the repo's `absolute_walsh_spectrum`
> (`packages/VBF/src/spectra/linear.jl:61`) excludes only `(0,0)`, making the `0` bucket
> differ by exactly `2ⁿ−1`.

---

## Paper Issues

### 1. Example 1(ii)'s last equality is wrong

- **Location**: `.tex` lines 238-244.
- **Evidence**: the paper writes `Rank(H[3,:]+H[4,:]) = Rank(H[4,:]+H[1,:])`. It should be
  `H[4,:]+H[0,:]`. The cyclic shifts of `λ=(1,1,0,0,0)` are `(0,1,1,0,0)`, `(0,0,1,1,0)`,
  `(0,0,0,1,1)`, `(1,0,0,0,1)` → rows `{0,4}`; rows `{1,4}` correspond to `(0,1,0,0,1)` =
  integer 18, which lies in the cyclic class of 5 — a *different* class.
- **Computed counter-evidence** on the paper's own Example-1 `H` (n=5, `GF(2⁵)` mod
  `x⁵+x²+1`, `a=1`, `b=2`):
  `Rank(H[0]+H[1]) = Rank(H[1]+H[2]) = Rank(H[2]+H[3]) = Rank(H[3]+H[4]) = Rank(H[4]+H[0]) = 4`,
  but **`Rank(H[4]+H[1]) = 3`**. The same holds for `b = 3…7`.

### 2. Table 2 is not reproducible from the paper's text; `F_n` is under-specified and Algorithm 3's output depends on the choice

- **Location**: Definition 2 and §4.2 / Algorithm 3.
- **Evidence**: Definition 2 defines `F_n` only as "a maximal subset"; §4.2 and Algorithm 3
  never say which representative. The Algorithm-3 count is *not* invariant. Computed under
  Conway/Magma moduli for all four natural representative conventions:

  | n | min-integer | max-integer | min-disc-log | max-disc-log | **paper** |
  |---|-------------|-------------|--------------|--------------|-----------|
  | 6 | 1 | 2 | **4** | 5 | **4** |
  | 7 | 117 | 90 | **78** | 80 | **78** |
  | 8 | 82 | 102 | 109 | 84 | **142** |

  Min-discrete-log (`g = x`, Conway modulus) reproduces n=6 and n=7 exactly, but not n=8.
  With 30 orbits at n=8 there are `8³⁰` admissible `F₈` sets, so Table 2 cannot be
  reconstructed without the authors' Magma code.

### 3. Algorithm 3 is impossible as stated for even `n`

- **Location**: Algorithm 3, read against Definition 2.
- **Evidence**: it requires all free variables in `F_n`, but the self-paired entry
  `H[0, n/2]` must satisfy `v^(2^(n/2)) = v`, i.e. lie in `GF(2^(n/2))`, whose nonzero
  elements have Frobenius orbit `≤ n/2 < n` and are therefore *excluded from `F_n` by
  Definition 2*. Verified in Julia (2026-08-15): `F₆ ∩ GF(2³)* = ∅` (`fn_set(6)` =
  `[2,3,6,7,8,9,10,11,24]`, `subfield_nonzero(3,6)` = `[1,22,23,34,35,52,53]`), so no
  admissible self-paired value exists and Algorithm 3 as written admits **no** matrix for even
  `n` — yet Table 2 reports counts for n = 6, 8, 10.

  (Executing the literal variant through this repo's `update_diagonal!` returns **1** at n=6
  and 0 at n=8, not 0 at both: on the self-paired diagonal the two symmetric writes hit the
  same cell and the second overwrites the first, producing a matrix that silently violates
  Theorem 1. `algorithm3.jl:39-44` sidesteps this by keeping `GF(2^{n/2})*` on the
  self-paired diagonal — a documented, correct deviation from the printed pseudocode.)

### 4. Internal inconsistency in Definition 2's gloss

- **Location**: the sentence following Definition 2.
- **Evidence**: it says `F_n` is "a set of representatives from the equivalence classes
  induced by [cyclic equivalence] on `F*_{2ⁿ}`", but Definition 2 excludes all subfield
  elements: `|F₆| = 9`, not `63/6`.

### 5. Typesetting

- Algorithm 2 (`.tex` 403-404) duplicates the line `if IsQAM(5, H) then`.
- Table 2's caption never says it is produced by Algorithm 3 (only §4.2's prose does), and
  its n=10 "45 h" sits next to §4.1's "about 100 days" for the full search without
  disambiguation.

---

## Reproduction Issues

### 1. Table 2 counts do not reproduce; `make report` prints FAIL

- **Location**: `algorithm2.jl:25-43` (`fn_set`, `push!(result, minimum(uorb))`), consumed by
  `algorithm3.jl:34,39-44` (`partial_search_apn_f2`), asserted in `table2.jl:17,33-37`.
- **Symptom**: `make table2_n7` and `make report` — which calls `table2_report(io)` with the
  default `max_evaluations = 1<<24`, so `exhaustive` is true for n = 6, 7 — print
  `[FAIL] n=6: count == 4 (paper)` and `[FAIL] n=7: count == 78 (paper)`. Actual computed
  values: **n=6 → 1, n=7 → 117**.
- **Root cause**: `fn_set` picks the *minimum-integer* orbit representative; the count is
  representative-dependent (paper issue 2). The paper's Magma run used the
  discrete-log-minimal set.
- **Resolution plan**:
  1. Add `reps::Symbol = :min_log` to `fn_set` (`:min_int` | `:min_log`), the latter
     selecting the orbit element of least discrete log base `g = x`.
  2. Re-derive n = 6, 7 under `:min_log`; assert 4 and 78.
  3. For n = 8, record the computed value (109 under `:min_log`) and mark Table 2's n = 8, 9,
     10 **UNREPRODUCED**, with paper issues 2 and 3 as the reason — do not assert the paper's
     numbers.
  4. Document paper issues 2 and 3 in the `table2.jl` header.
  5. Keep the equality assertion only for n = 6, 7, and only under the documented convention.

### 2. Table 3's CCZ-inequivalence check is wrong and FAILs

- **Location**: `table3.jl:82`
  (`spectra = [differential_spectrum(ortho_derivative(F)) for F in boxes]`), used at
  `:86-92`.
- **Symptom**: `make table3` / `make report` print
  `[FAIL] F1 and F5: ortho-derivative spectra COLLIDE (unexpected)` and
  `[FAIL] all 6 ortho-derivative spectra pairwise distinct`. Computed: over `GF(2¹¹)` mod
  2053, **`x³` and `x³³` have identical ortho-derivative differential spectra**
  `{0:2411366, 2:1623271, 6:157619}`; all 14 other pairs differ.
- **Root cause**: the paper (§4.2 and Conclusion) uses "the differential **and Walsh**
  spectra of their ortho-derivatives". `table3.jl` uses only the differential spectrum. The
  ortho-derivative absolute-Walsh spectra *do* separate them — `x³`:
  `{0:319332, 8:652993, 16:517891, 24:497421, 32:427823, 40:427823, 48:337755, 56:247687,
  64:180136, 72:90068, 80:180136, 88:135102, 96:67551, 104:45034, 112:45034, 128:22517}`;
  `x³³`: `{0:386883, 8:743061, 16:405306, 24:452387, 32:405306, 40:315238, 48:450340,
  56:180136, 64:225170, 72:202653, 80:202653, 88:112585, 104:45034, 112:22517, 120:22517,
  136:22517}`. Verified in Julia that `(differential_spectrum, absolute_walsh_spectrum)` of
  the ortho-derivative separates all 15 pairs at n=11.
- **Resolution plan**:
  1. Use `σ = (differential_spectrum(π_F), absolute_walsh_spectrum(π_F))`.
  2. Re-assert pairwise distinctness — it then holds.
  3. Add the distinctness assertion to `tests/test_table3.jl`, which today tests only
     APN-ness and therefore hides the failure.

### 3. A paper error is invented ("x⁴")

- **Location**: `table1.jl:8` and `:21` comments; `table3.jl:6,16-17`; `report.jl:37-38`.
- **Symptom**: the report prints *"Note: paper writes 'x^4' as first entry in Table 1 and
  Table 3."* Both the `.tex` (lines 421-425, 463-473) and the PDF (`pdftotext` lines
  724-728, 779-783) print **x³**. The implemented exponent `[3]` is correct; only the
  annotation is false.
- **Root cause**: a transcription assumption never checked against the source.
- **Resolution plan**:
  1. Delete the note at `report.jl:37-38`.
  2. Delete the `x^4` comments at `table1.jl:8,21` and `table3.jl:6,16-17`.
  3. Add a grep-based note here recording that the paper text is `x³`.

### 4. Proposition 1's actual claim is never tested

- **Location**: `proposition1.jl:19-40`; the file's own pseudocode at `:9-10` promises
  "Verify F and the function corresponding to H' are EA-equivalent (same `apn_ea_mugshot`)".
- **Symptom**: the report prints only `H is QAM` / `H² is QAM` / `H ≠ H²`, and
  `tests/test_proposition1.jl` asserts the same three. The EA-equivalence content — the whole
  point of Proposition 1 — is untested.
- **Root cause**: docstring/implementation drift.
- **Resolution plan**:
  1. Recover both functions from `H` and `H²` in the normal basis.
  2. Compare with `VBF.apn_ea_mugshot` and confirm with `are_ea_equivalent` /
     `ea_mappings_from_ortho_derivative`.
  3. Use a non-monomial QAM (not Gold) so the check is not vacuous.
  4. Assert it in the test.

### 5. Example 1 is not driven from the paper's data

- **Location**: `example1.jl:13-19` `build_example1_matrix` — which *correctly* builds the
  paper's symbolic `H` from `(a,b)` — is dead code; `:25-64` substitutes a Gold-derived `H`
  and checks only one link (`r12sq == r23`).
- **Symptom**: neither of the paper's two rank chains is enumerated, so paper issue 1 is
  invisible.
- **Root cause**: the report bypasses the constructor it defines.
- **Resolution plan**:
  1. Drive `example1_report` from `build_example1_matrix(a, b)`.
  2. Print chain (i) `Rank(H[0..4])` and chain (ii) `Rank(H[i]+H[i+1])`.
  3. Add a `print_check` documenting paper issue 1 with the `a=1, b=2` counter-example.

### 6. The paper's only new contribution is never tied to its claim

- **Location**: `table1.jl:19-29` builds `x⁵¹³+x¹⁹²+x⁹⁶+x⁴⁸+x³³+x¹⁸+x¹²` but never builds
  `x³+Tr(x⁹)` over `GF(2¹⁰)`.
- **Symptom**: Table 1 entry 3 is verified to be *some* APN function CCZ-inequivalent to `x³`
  and `x⁹`, but the assertion that it is a **shorter representative of the `x³+Tr(x⁹)`
  class** — the paper's single novel result — is unchecked.
- **Root cause**: the `TR_X9` construction exists only in `table3.jl`, for n = 11.
- **Resolution plan**:
  1. Build `Tr_{GF(2¹⁰)/GF(2)}(x⁹)` with the same exponent-orbit trick.
  2. Assert σ-equality. This was verified here: the ortho-derivative differential spectrum
     `{0:633636, 2:322701, 4:75045, 6:13980, 8:1905, 10:285}` **and** the ortho-derivative
     absolute-Walsh spectrum
     `{0:106683, 8:203700, 16:178575, 24:158100, 32:128917, 40:96390, 48:69000, 56:44400, 64:29606, 72:15930, 80:9003, 88:3936, 96:2265, 104:1110, 112:510, 120:150, 128:240, 136:60}`
     are identical, while the LUTs differ.
  3. Attempt `ea_mappings_from_ortho_derivative` for a complete proof.
  4. Assert the "≤ n terms" claim (7 ≤ 10).

### 7. Wrong modulus label

- **Location**: `table1.jl:16` (`MOD10 = conway_polynomial(N10)  # 1135`) and `:55`
  `print_kv(io, "modulus (Conway x^10+x^3+1)", mod)`.
- **Symptom**: `conway_polynomial(10) = 1135 = x¹⁰+x⁶+x⁵+x³+x²+x+1`, whereas
  `x¹⁰+x³+1 = 1033 = primitive_polynomial(10)`. The label names a different polynomial than
  the value.
- **Root cause**: copied from the catalog's `n10_apn.toml` `algebraic_form` string — which
  itself says `x^10 + x^3 + 1` while entries load under Conway. That is a separate, minor
  catalog metadata inconsistency worth flagging to the catalog owner.
- **Resolution plan**:
  1. Fix the label.
  2. Note that all Table-1 results are modulus-independent — re-verified here under both 1135
     and 1033.

### 8. Hardcoded n=11 modulus with a non-argument

- **Location**: `table3.jl:18-23`
  (`MOD11 = 2053  # ... verified primitive (ord_2(2047)=11, 2^2047 ≡ 1 mod 2053)`), echoed at
  `algorithm3.jl:77`.
- **Symptom**: 2053 is exactly `VBF.primitive_polynomial(11)`; the parenthetical is not a
  primitivity argument.
- **Root cause**: the comment correctly notes `conway_polynomial(11)` is absent but does not
  check `PRIMITIVE_POLYNOMIALS`, which covers n = 2…16.
- **Resolution plan**: `const MOD11 = primitive_polynomial(11)`; drop the comment.

### 9. Algorithm 1's cross-check is vacuous

- **Location**: `algorithm1.jl:111-142` — it compares `is_qam_fast` against `is_qam` on four
  matrices, **all of which are QAMs**, so only the `true` branch is exercised.
- **Symptom**: `agree = 4/4` says nothing about false positives.
- **Root cause**: test inputs drawn only from `gold_apn`.
- **Resolution plan**:
  1. Include non-QAM `H` (random `(a,b)` at n = 5, 6) so both branches run.
  2. Better: delete `is_qam_fast` and call `VBF.is_cyclic_qam(H, 1)` (see the reuse note),
     keeping the agreement check against `is_qam` as a property test.

---

## Items Reproduced Exactly

| Paper item | File | Status |
|------------|------|--------|
| Theorem 1 (⇐ direction: `F₂` coefficients ⇒ `H[u+1,v+1]=H[u,v]²`) | `theorem1.jl` | fully reproduced |
| Theorem 2 (cyclic shift preserves rank) | `theorem2.jl` | fully reproduced — verified exhaustively over all 31 masks × all `(a,b) ∈ GF(2⁵)*²` of the paper's Example-1 matrix family: no violation |
| Corollary 1 (`K ≈ 2ⁿ/n`) | `corollary1.jl` | fully reproduced. `K = 7, 13, 19, 35, 59, 107, 187` for n = 5…11 |
| Example 2 (n=5 CR / IDlen / ID) | `example2.jl` | **exact** — `CR = (1,3,5,7,11,15,31)`, `IDlen = 7`, `ID = [[0,1,1,2,2,4,6],[1,2,3,3,4,4,5]]` |
| Algorithm 1 `IsQAM` / `GetIndices` / `getCyclicEquivalenceRepresentatives` | `algorithm1.jl` | fully reproduced (validated against exhaustive ground truth) |
| Algorithm 2 (DFS over diagonals) | `algorithm2.jl` | structurally exact |
| Table 1, APN part | `table1.jl` | fully reproduced. All three representatives are APN (δ=2) and degree 2 over `GF(2¹⁰)` under **both** moduli 1135 and 1033. Ortho-derivative differential spectra: `x³` → `{0:595386, 2:416361, 6:35805}`; `x⁹` → `{0:713031, 2:211761, 4:92070, 6:15345, 8:5115, 12:10230}`; the 7-term → `{0:633636, 2:322701, 4:75045, 6:13980, 8:1905, 10:285}`. Pairwise distinct ⇒ CCZ-inequivalent ✔ |
| Table 3, APN part | `table3.jl` | fully reproduced. `x³, x⁵, x⁹, x¹⁷, x³³, x³+Tr(x⁹)` all δ=2, degree 2 over `GF(2¹¹)` mod 2053 |
| Definition 2 (`F_n`) | `algorithm2.jl:25` | correct reading (subfield elements excluded). `|F_n| = 6, 9, 18, 30, 56, 99, 186` for n = 5…11 |

## Test Results

Environment: Julia 1.12.6, project `/home/tiago/VBF.jl` instantiated. Review date 2026-08-15.

### `make -C packages/VBFRepro/papers/2025/Yu_202512 test`

Exit code **0**, wall time **5 s**. (Note: this paper's tests live in `tests/`, not `test/`.)

| Testset | Pass | Broken | Fail | Total | Time |
|---------|------|--------|------|-------|------|
| `theorem1_test`    | 3  | 0 | 0 | 3  | 0.8s |
| `proposition1_test`| 3  | 0 | 0 | 3  | 0.4s |
| `example2_test`    | 10 | 0 | 0 | 10 | 0.3s |
| `algorithm2_test`  | 4  | 0 | 0 | 4  | 0.6s |
| `table1_test`      | 6  | 0 | 0 | 6  | 0.5s |
| `table3_test`      | 9  | 0 | 0 | 9  | 0.6s |
| **Total**          | **35** | **0** | **0** | **35** | |

### Additional make targets executed

| Target | Exit | Result |
|--------|------|--------|
| `make table2_n7` | 0 | **Reports 2 `[FAIL]`s.** `n=6: count: 1` → `[FAIL] n=6: count == 4 (paper)`; `n=7: count: 117` → `[FAIL] n=7: count == 78 (paper)`. |
| `make table3`    | 0 | **Reports 2 `[FAIL]`s.** All 6 functions `[PASS]` quadratic APN over GF(2^11), then `[FAIL] F1 and F5: ortho-derivative spectra COLLIDE (unexpected)` and `[FAIL] all 6 ortho-derivative spectra pairwise distinct`. |
| `make report`    | 0 | Runs all 11 sections. Theorem 1/2, Proposition 1, Example 1/2, Corollary 1, Algorithm 2, Table 1 all `[PASS]`; the same **3 `[FAIL]`s** appear. Prints `Julia version : 1.12.6`. |

**The suite exits 0 while `make report` prints 3 `[FAIL]`s** — none of the three failing
claims is asserted in `tests/`. `tests/test_table3.jl` asserts only APN-ness (lines 5–13);
Table 2 has no test file at all. A green `make test` is therefore not evidence here.

Every other value previously derived in Python was reproduced exactly by the repository's own
Julia API, including the full 4-convention Table-2 count tables at n=6/7/8 and the exhaustive
Algorithm-2 ground truth (360 QAMs → 72 at n=5; 192 → 32 at n=6).

## Catalog Status

The paper explicitly claims **no new APN functions**. Its one artifact is a shorter
representative, and the catalog is missing that class.

| Item | Status |
|------|--------|
| n=10 `x³` | **present** — `n10_Gold_x3` |
| n=10 `x⁹` | **present** — `n10_Gold_x9` |
| n=10 `x⁵¹³+x¹⁹²+x⁹⁶+x⁴⁸+x³³+x¹⁸+x¹²` (the `x³+Tr(x⁹)` class) | **missing** |
| n=11 `x³, x⁵, x⁹, x¹⁷, x³³` | **present** — `n11_Gold_i1…i5` (family `known-family`, no TOML) |
| n=11 `x³+Tr(x⁹)` | **missing** |

Evidence: the ortho-derivative differential spectrum was computed for all **14** n=10 and all
**22** n=11 catalog entries (from `BFA_catalog.sqlite.functions.lut_blob`); none matches.

### Catalog-gap record 1

```toml
target: packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml
name              = "n10_Yu2025_x3_tr_x9_short"
n                 = 10
m                 = 10
is_permutation    = false        # image size 342, 3-to-1 on GF(2^10)*
algebraic_form    = "x^513 + x^192 + x^96 + x^48 + x^33 + x^18 + x^12 in GF(2^10), modulus x^10+x^6+x^5+x^3+x^2+x+1 (=1135); CCZ-equivalent to x^3 + Tr(x^9)"
bib_key           = "Yu_202512"
source            = "Yu, Li, Ichanska, Kaleyski (2025), Table 1 third entry — the shortest known (7-term) representative of the x^3+Tr(x^9) CCZ class over GF(2^10)."
lut               = terms_to_lut([(1,513),(1,192),(1,96),(1,48),(1,33),(1,18),(1,12)], 10, 1135)
                    # first 16 values: 0, 1, 22, 7, 276, 21, 889, 616, 916, 553, 482, 79, 423, 282, 426, 263
```

Equivalence evidence: δ=2, algebraic degree 2, not a permutation. The ortho-derivative
differential spectrum `{0:633636, 2:322701, 4:75045, 6:13980, 8:1905, 10:285}` and the
ortho-derivative absolute-Walsh spectrum (listed in reproduction issue 6) differ from every
one of the 14 catalogued n=10 functions (`n10_Gold_x3`, `n10_Gold_x9`, `n10_Kasami_x57`,
`n10_Dobbertin_x339`, `n10_Gold_i7`, `n10_Kasami_i7`, `n10_Gold_i9`, `n10_Kasami_i9`,
`n10_Taniguchi_m1_a1_b1/b6/b7`, `n10_Taniguchi_m2_a1_b1/b8/b9`), and are identical to those
of `x³+Tr(x⁹)` built over the same field.

### Catalog-gap record 2 (needs a new file)

```toml
target: packages/VBFCatalog/data-raw/apn_catalog/n11_apn.toml   (does NOT exist yet)
name              = "n11_Gold3_plus_TrX9"
n                 = 11
m                 = 11
is_permutation    = false        # image size 1024, 3-to-1 on GF(2^11)*
algebraic_form    = "x^3 + Tr_{GF(2^11)/GF(2)}(x^9) in GF(2^11), modulus x^11+x^2+1 (=2053)"
bib_key           = "Yu_202512"
source            = "Yu, Li, Ichanska, Kaleyski (2025), Table 3 sixth entry (conjectured complete classification for n=11)."
lut               = terms_to_lut([(1,3)] ∪ [(1, 9*2^k mod 2047) for k in 0:10], 11, 2053)
```

Equivalence evidence: δ=2, degree 2. The ortho-derivative differential spectrum
`{0:2534148, 2:1289531, 4:307604, 6:53229, 8:7040, 10:682, 12:22}` matches none of the 22
n=11 catalog entries.

**Caveat**: there is no `n11_apn.toml`; the existing n=11 rows come from
`data-build/import_known_families.jl`, so maintainers should decide whether n=11 sporadics
belong in a new TOML or in that importer.

## Library-Reuse Note

Helpers duplicating a `VBF` core export:

| Helper | Line | Should call |
|--------|------|-------------|
| `get_cyclic_reps` | `algorithm1.jl:33` | `VBF.cyclic_qam_subset_representatives(n, 1)` — `packages/VBF/src/constructions/qam_search.jl:134` (an identical orbit-minimum representative set) |
| `is_qam_fast` | `algorithm1.jl:81` | `VBF.is_cyclic_qam(M, 1)` — `qam_search.jl:174`, documented as *exactly* this Theorem-2 reduction and exported at `exports.jl:90-91` |
| `update_diagonal!` | `helpers.jl:68` | `VBF.qam_from_cyclic` / `qam_cyclic_orbits` with m=1 — `qam_search.jl:77` / `:47` |
| `polynomial_sbox` | `helpers.jl:54` | `VBF.terms_to_lut` — `packages/VBF/src/representations/univariate.jl:331` |
| `subfield_nonzero` | `algorithm2.jl:46` | `VBF.subfield_elements(n, gcd(d,n); modulus)` minus 0 — `finite_field.jl:362` |
| `row_combo_rank` | `theorem2.jl:14` | the private `_qam_subset_rank` in `qam_search.jl:145` — export it, or reuse `is_cyclic_qam` |
| `find_normal_element` | `helpers.jl:15` | `minimum(VBF.independent_conjugate_elements(n, 1))` — `qam_search.jl:107`. **Caveat**: the core function has no `modulus` kwarg (`gf_pow(x, 1<<m, n)` uses the default `primitive_polynomial(n)`), so reuse needs a small core change — also a promote-to-core item |
| `MOD11 = 2053` | `table3.jl:23` | `VBF.primitive_polynomial(11)` — `finite_field.jl:128` |

Legitimately paper-specific (not flagged): `get_indices` (`algorithm1.jl:61`, Algorithm 1's
ID array), `is_proper_sub` (`helpers.jl:81`, Definition 4 on *leading k×k* submatrices —
`is_qam` is only the k=n case), `fn_set` (`algorithm2.jl:25`, Definition 2's `F_n`; **not**
the same as `independent_conjugate_elements`, which requires linear *independence* of
conjugates, not merely orbit size `n`), and `square_matrix` (`proposition1.jl:15`).

Promote-to-core candidates:

1. **`normal_basis_deriv_matrix`** — confirmed. `helpers.jl:41` is byte-identical (modulo one
   comment and an error string) to `packages/VBFRepro/papers/2024/Ichanska_202400/helpers.jl:53`, and
   `packages/VBFRepro/papers/2022/Yu_202211d/helpers.jl:52` carries the hardcoded-γ variant `normal_basis`.
   `VBF.quadratic_apn_matrix` (`packages/VBF/src/constructions/qam.jl:30`) exists but uses
   the **bit basis** `bᵢ = 2^(i-1)`, not a normal basis, so it cannot be substituted.
   Proposal: `quadratic_apn_matrix(F; basis)` or
   `normal_basis_derivative_matrix(F, γ; modulus)` plus a `normal_element(n; modulus)` in
   `packages/VBF/src/constructions/qam.jl`. `find_normal_element` (three copies) folds into
   the latter.
2. A `modulus` kwarg on `independent_conjugate_elements` (`qam_search.jl:107`).
3. `is_proper(H, k)` — Definition 4 properness of a leading submatrix; a generic QAM-search
   pruning primitive needed here and (per the `Ichanska_202400` README) there too.
4. `frobenius_orbit_representatives(n; modulus, select = :min_int | :min_log)` — needed both
   by `fn_set` and to settle the Table-2 convention (reproduction issue 1).

**Stale core docstring**: `packages/VBF/src/constructions/qam_search.jl` (above
`cyclic_qam_subset_representatives`, around line 130) refers to "the accelerated test
`is_qam(M; shift=m)`", which does not exist — the function is `is_cyclic_qam(M, m)`. Fixing
this matters because it is the string a paper author would grep for before writing
`is_qam_fast`.

## Open Questions

- Should Table 2 be asserted under the `:min_log` convention (matching n=6,7) with n ≥ 8
  marked unreproduced, or should all of Table 2 be demoted to "reported, not reproducible"?
- Should the n=11 catalog gap create `n11_apn.toml`, or be routed through
  `data-build/import_known_families.jl`?
- `n10_apn.toml`'s `algebraic_form` strings say "modulus x^10 + x^3 + 1" (=1033) while
  entries are stored and loaded under Conway 1135 — intentional metadata, or a catalog bug?
