# Beierle_202201 — New Instances of Quadratic APN Functions

**Paper**: Beierle, Leander. "New Instances of Quadratic APN Functions." *IEEE Transactions
on Information Theory* **68**(1):670-678, 2022 (arXiv:2009.07204).

**Reproduction path**: `papers/2022/Beierle_202201/`

**Verdict**: Partial

The reproduction covers Algorithm 1's basic variant plus Lemmas 4 and 5 as isolated
predicates, and those parts are faithful. But every *headline* result of the paper is
missing: the two dimension-9 APN permutations, the linearity-2⁷ 8-bit function, the six
extended Walsh spectra 𝒲₀…𝒲₅, Table 1, and the Section 4 LE-automorphism search that
actually produced all 12,921 / 35 / 5 instances. On top of that, one file reproduces a table
from a **different publication**, and the entire data-dependent half of the reproduction is
dead because `inputs/` does not exist and — for the `.txt` datasets — cannot be committed.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Every numeric claim below was re-derived independently in Python
> from the `.tex` source and from the repository's own committed data
> (`BFA_catalog.sqlite`, `corpora/*.sqlite`).

---

## Paper Issues

### 1. `addDegreeInformation` / `removeDegreeInformation` are not inverse on the early-return path

- **Location**: Section 3.2 pseudocode.
- **Evidence**: `addDegreeInformation(x)`'s `return 0` fires *inside* the loop over `u`,
  leaving `ctr[u]` and `sum[u]` un-incremented for every `u` not yet visited. `AddPoint`
  then returns 0, so `RemovePoint(x)` runs; `removeDDTInformation(x)` returns 1 (the DDT was
  fine — it was the *degree* check that failed), and `removeDegreeInformation(x)` decrements
  `ctr[u]` for **all** `u` with `wt(u) ≥ 3` and `x ⪯ u`, including the ones that were never
  incremented. `ctr` goes negative and the search state is corrupted.
- **Note**: the reproduction avoids this at `algorithm1.jl:53-68` and `:84-89` by always
  completing both loops and ANDing the results. That is the correct fix, but it is an
  undocumented divergence from the printed pseudocode.

### 2. Algorithm 1's `nextFreePosition` comment is inverted

- **Location**: Algorithm 1 pseudocode.
- **Evidence**: it reads `x ← nextFreePosition() ▷ Chooses the smallest i s.t. sbox[i] ≠ ⊥`;
  it must be `= ⊥`. The reproduction does the right thing (`algorithm1.jl:110-112`).

### 3. Table 1's column totals do not sum to the headline count, by design but without a note

- **Location**: Table 1 and Section 4.2.
- **Evidence**: summing the parenthesised "new" entries over all 9 rows gives **12,745**,
  not the 12,733 stated in Section 4.2 — because a function admitting two LE-automorphisms
  is counted in two rows. The caption says "lower bound … that admit the particular
  LE-automorphism" but never warns that rows overlap.

---

## Reproduction Issues

### 1. `table1_invariants.jl` reproduces the wrong paper's Table 1

*Highest severity.*

- **Location**: `table1_invariants.jl` (whole file); `check_ranks` at `:187-248` reading
  `inputs/table1.csv` at `:193`; `check_walsh` at `:286-332` reading it at `:288`;
  `multiplier_group_order` at `:345-354`.
- **Symptom**: `test_table1_invariants.jl:8` asserts `length(table) == 61` with rows
  `"6.1"…"10.17"` and columns `dim, id, polynomial, equiv, walsh_class, gamma_rank,
  delta_rank, multiplier`. **Beierle–Leander's Table 1 has none of this**: it is a 9-row ×
  6-column table indexed by LE-automorphism class number (1, 2, 21, 31, 38, 51, 55, 56, 113)
  against the extended Walsh spectra 𝒲₀…𝒲₅ (`.tex` lines 370-398). There is no Γ-rank,
  Δ-rank, "Walsh spectrum class" or "multiplier group" column anywhere in this paper. The
  parsed CSV is the "CCZ-inequivalent representatives from the known APN families for
  dimensions up to 11" table (boolean.h.uib.no) — a different source. The committed
  `results/table1_walsh.toml` and `results/table1_ranks.toml` are artifacts of checking that
  foreign table.
- **Root cause**: the reproduction was scaffolded against the wrong "Table 1".
- **Resolution plan**:
  1. Delete `table1_invariants.jl`, the `table1_invariants` / `walsh_spectrum` /
     `multiplier_group` Makefile targets, `test_table1_invariants.jl`, and
     `results/table1_*.toml`.
  2. Drop `check_ranks` / `check_walsh` from `report.jl:25-26` and its summary lines.
  3. Write a new `table1.jl` reproducing the *actual* Table 1. This needs the authors'
     canonical-class indices (from the `cbe90/quadratic_apn` repository); with those, bucket
     the `beierleleander2022_n8` corpus by (LE-automorphism class, extended Walsh spectrum).
  4. If the class indices cannot be obtained, reproduce the **column totals** instead (see
     issue 3), which are computable from repository data today.

### 2. The paper's three explicit functions are absent

- **Location**: no file. Section 1.1 gives (a) two dimension-9 APN permutations and (b) one
  8-bit APN function with linearity 2⁷.
- **Symptom**: `grep` finds no occurrence of `x^80`, `x^192`, `x^136`, `x^160`, `X^3+X+1` or
  `X^8+X^4+X^3+X^2+1` in the reproduction. Expected: three `SBox` constructors plus
  APN/degree/permutation/self-equivalence checks. Actual: none.
- **Root cause**: the reproduction went straight to bulk-dataset validation and skipped the
  paper's named representatives.
- **Counter-evidence that they are trivially reproducible** (independent Python, about 1 s
  each):
  - `F₁(x) = x³ + ux¹⁰ + u²x¹⁷ + u⁴x⁸⁰ + u⁵x¹⁹²` and
    `F₂(x) = x³ + u²x¹⁰ + ux²⁴ + u⁴x⁸⁰ + u⁶x¹³⁶` over `GF(2⁹)` mod `x⁹+x⁴+1` with `u = 28`
    (root of `X³+X+1`): both are **permutations** with **differential uniformity 2** and
    **algebraic degree 2**; both satisfy the paper's self-equivalence `F(u⁵x) = uF(x)`; all
    exponents are `≡ 3 (mod 7)` as the paper states; the Walsh spectrum of `F₁` is
    `{0:130816, 32:130816}` (almost bent).
  - The 26-term 8-bit function over `GF(2⁸)` mod `x⁸+x⁴+x³+x²+1`: **`du = 2`, degree 2,
    extended Walsh spectrum exactly `{0:12540, 16:48640, 32:4096, 128:4}` = 𝒲₅, linearity
    128 = 2⁷.**
- **Resolution plan**:
  1. Add `section1_1_instances.jl` building all three from the exact univariate forms and
     moduli in `.tex` lines 86-88 and 96-99 (use `terms_to_lut` with
     `primitive_polynomial(9)` or an explicit modulus 285).
  2. Assert `is_permutation`, `differential_uniformity == 2`, `algebraic_degree == 2`, the
     self-equivalence identity, and `absolute_walsh_spectrum == 𝒲₅`.
  3. Add `test_section1_1_instances.jl`.
  4. Emit the two dimension-9 LUTs to `results/` for the catalog updater.

### 3. The six extended Walsh spectra 𝒲₀…𝒲₅ (Section 4.2) are not reproduced, although the repository already ships the data

- **Location**: no file. `dataset_validation.jl` checks only counts,
  `differential_uniformity` and `algebraic_degree`.
- **Symptom**: no test mentions `absolute_walsh_spectrum`, `linearity`, 16320, 48640 or
  12540.
- **Root cause**: assumed to require the absent `inputs/apn_8bit.txt`. In fact
  `packages/VBFCatalog/corpora/beierleleander2022_n8.sqlite` holds all 12,923 functions.
- **Counter-evidence**: a full corpus scan in pure Python took **27.5 s** and found
  **exactly six** distinct extended Walsh spectra — exactly the paper's 𝒲₀…𝒲₅ — with
  multiplicities **𝒲₀ 9327, 𝒲₁ 3112, 𝒲₂ 308, 𝒲₃ 146, 𝒲₄ 26, 𝒲₅ 4**. The 𝒲₃ count 146
  matches Table 1 row 55; 𝒲₄'s 26 matches Table 1 rows 55+56 (25+1); and there are
  **exactly 4** members with linearity 2⁷ (indices 12658-12661), matching "there exist at
  least four CCZ-inequivalent 8-bit APN functions with linearity 2⁷". Those four have
  **pairwise distinct ortho-derivative differential spectra**, so they are pairwise
  CCZ-inequivalent; and index **12658**'s OD spectrum
  `{0:39420, 2:21345, 4:4041, 6:384, 8:27, 62:63}` equals that of the paper's explicit 𝒲₅
  polynomial.
- **Resolution plan**:
  1. Add `section4_2_walsh_spectra.jl` reading the corpus via
     `VBFCatalog.corpus_function` / `corpus_coefficients` plus `decode_quadratic_lut`.
  2. Assert the spectrum set has cardinality 6 and equals the six literals from `.tex` lines
     359-364.
  3. Assert exactly 4 members with `linearity == 128`, and that their `apn_ea_mugshot`s are
     pairwise distinct.
  4. Gate it behind `full_search` with a small default sample.

### 4. The entire Section 4 LE-automorphism search — the method that produced all the new instances — is unimplemented

- **Location**: no file. Paper Sections 4, 4.1 and 4.2 (Lemmas 1-3, rational canonical form,
  power-similarity, the canonical-class counts 128/157/217/401 with their 56/36/36,
  75/41/41, 111/53/53, 247/77/77 splits, and the post-Lemma-4/5 remainders 53 for n=7 and 67
  for n=8).
- **Symptom**: `lemma4.jl` and `lemma5.jl` are only unit-tested against 4- and 8-element toy
  maps (`test_lemma4.jl`, `test_lemma5.jl`); they are never applied to any canonical class.
  None of the paper's class counts appear anywhere in the reproduction.
- **Root cause**: only the Section 3 baseline search was ported.
- **Resolution plan**:
  1. Implement `lemma1_2_3.jl` generating rational canonical forms of prime order in
     `GL(n,F₂)` and the power-similarity quotient; assert the counts 128/157/217/401 with
     their three-way splits.
  2. Implement `section4_2_filters.jl` applying `lemma4_excludes` / `lemma5_excludes` to the
     generated classes; assert 53 remaining for n=7 and 67 for n=8.
  3. Implement the LE-constrained variant of Algorithm 1 (fix `F(Aⁱx) = Bⁱ(y)`; seed
     `F|_{Fix_A}` from a list of k-bit quadratic APN EA-representatives) as
     `algorithm1_le.jl`, with `limit` and `timeout_seconds`.
  4. Note that `data-raw/le_automorphism_tuples/n7.toml` holds only 4 classes (`class1`,
     `class7`, `class16`, `class19`) and is Beierle–Brinkmann–Leander data, **not** this
     paper's 128.

### 5. `inputs/` does not exist and cannot be committed; the data-dependent half of the reproduction is dead

- **Location**: `dataset_validation.jl:27,87,147`; `proposition1.jl:51`;
  `catalog_validation.jl:51`; `table1_invariants.jl:193,288`; `report.jl:22-27`;
  `test/runtests.jl:6`.
- **Symptom**: `ls papers/2022/Beierle_202201/inputs` → *No such file or directory*. Root
  `.gitignore` line 11 is `*.txt`, so `apn_8bit.txt` / `apn_9bit.txt` / `apn_10bit.txt` can
  never be tracked. `inputs/table1.csv` is not ignored, yet is also absent. `runtests.jl:6`
  therefore skips `test_table1_invariants.jl`, `test_proposition1.jl`,
  `test_catalog_validation.jl` and the file-dependent half of `test_dataset_validation.jl`,
  leaving only the LUT-parsing unit tests plus `test_algorithm1` / `test_lemma4` /
  `test_lemma5`. Worse, `report.jl`'s `paper_report` calls `dataset_counts`, `check_ranks`,
  `check_walsh` and `ccz_distinctness` unconditionally at `:22-27` and will **throw** on a
  fresh checkout. The committed `results/*.toml` are stale, unreproducible artifacts.
- **Root cause**: the reproduction was written against an untracked local copy of the Zenodo
  dataset instead of the repository's own bulk corpus.
- **Resolution plan**:
  1. Repoint `dataset_validation.jl`, `proposition1.jl` and `catalog_validation.jl` at
     `VBFCatalog`'s `beierleleander2022_n8` corpus (12,923 members, modulus 285,
     `quadratic-coeffs-v1`) as the primary source, keeping the TXT reader as an optional
     override.
  2. For n = 9 and n = 10 there is **no** corpus in the repository (`list_corpora` returns
     only the eight n=8 corpora), so either import the 35 + 5 LUTs into `data-raw` or make
     those checks skip explicitly with a documented reason.
  3. Make `paper_report` degrade gracefully when a source is unavailable.
  4. Delete or regenerate `results/*.toml`.

### 6. Proposition 1 is under-verified and hand-rolls an invariant core already exports

- **Location**: `proposition1.jl:25-29` (`ortho_derivative_signature`), `:39-105`
  (`ccz_distinctness`).
- **Symptom**: only the negative direction is checked ("sampled signatures differ from
  Gold's, and from each other"). Proposition 1's actual statement — *for EA-equivalent
  quadratic APN `F`, `G` the ortho-derivatives are linear-equivalent* — is never tested.
  Also the paper (and CCP21) uses the differential spectrum **and** the extended Walsh
  spectrum of `Π_F`; the reproduction uses only the differential spectrum.
- **Root cause**: scope drift toward a "distinctness demo".
- **Resolution plan**:
  1. Add the positive direction: pick `F`, draw random `A, B ∈ AGL(n,F₂)` and affine `C`,
     form `G = A∘F∘B + C`, and assert `apn_ea_mugshot(F) == apn_ea_mugshot(G)`.
  2. Replace `ortho_derivative_signature` with the exported `apn_ea_mugshot`, which already
     bundles the ortho-derivative differential *and* Walsh data.
  3. Reproduce the paper's Section 3.3 claim that the 8,191 previously-known 8-bit instances
     are pairwise separated by this invariant, using the `yuwangli2014_qam_n8`,
     `edelpott2009_n8`, `wengtangong2013_n8` and `taniguchi2019_n8` corpora.

### 7. The Section 5 switching construction (188 new n=8 instances) is unimplemented despite core support

- **Location**: no file. Paper Section 5, Definition 3 plus the EP09 linear-system method.
- **Symptom**: `grep switching papers/2022/Beierle_202201` returns nothing, while `VBF`
  exports `switching_neighbors`.
- **Root cause**: omitted.
- **Resolution plan**:
  1. Add `section5_switching.jl` calling `switching_neighbors` on a bounded sample of the
     n=7/n=8 corpora.
  2. Verify each neighbour is APN and quadratic.
  3. Bucket by `apn_ea_mugshot` and report how many are new relative to the input corpus.
  4. Accept `limit` and `timeout_seconds`.

### 8. `_walsh_class` is an ad-hoc, unsound family classifier

- **Location**: `table1_invariants.jl:261-277`.
- **Symptom**: it classifies any function with at most 2 distinct nonzero absolute Walsh
  values as `"Gold"`, otherwise `"Inverse"` if `n` is odd and `"Dobbertin"` if `n` is even.
  That is a spectrum-shape heuristic, not a family test — it would label every AB function
  "Gold" and any many-valued even-dimension function "Dobbertin".
- **Root cause**: written to satisfy a foreign CSV column.
- **Resolution plan**: removed together with issue 1.

### 9. `print_header` duplicates a core export

- **Location**: `helpers.jl:13-18`.
- **Symptom**: hand-rolls `"="^72` rules that `VBF.print_banner` already emits at exactly
  width 72.
- **Root cause**: written before the report emitters were factored into core.
- **Resolution plan**: replace the body with
  `print_banner(io, "Beierle, Leander (2022): New Instances of Quadratic APN Functions", "IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204")`.

### 10. `quadratic_apn_search` mutates the global RNG

- **Location**: `algorithm1.jl:151` (`Random.seed!(seed)`).
- **Symptom**: calling the search perturbs the caller's global RNG state; two `@testset`s
  that both call it become order-coupled.
- **Root cause**: global seeding instead of a local generator.
- **Resolution plan**: use `rng = Random.MersenneTwister(seed)` and pass it to
  `Random.shuffle!(rng, …)` at `:154`.

---

## Items Reproduced Exactly

- **Algorithm 1 (Section 3), basic variant** — `algorithm1.jl`. The incremental DDT
  (`_add_ddt!` / `_remove_ddt!`, Section 3.1) and incremental Möbius/ANF degree pruning
  (`_add_degree!` / `_remove_degree!`, Section 3.2) are faithful; `nextFreePosition` picks
  the smallest undefined index; `sbox[0] = 0` is fixed; the per-depth shuffled trial order
  `P[depth+1, z]` matches the paper's `P[depth][z]`; `timeout_seconds` implements the
  paper's "abort and restart after a predetermined amount of time".
- **Lemma 4** — `lemma4.jl`: `|Fix_B| < |Fix_A|` with exceptions `{(1,2),(2,4)}`, exactly
  the paper's statement (cardinalities, matching the proof's `(ℓ,k) ∈ {(0,1),(1,2)}`).
- **Lemma 5** — `lemma5.jl`: `lemma5_min_cycles` returns `(2ⁿ+1)/3` for odd `n` and
  `(2ⁿ+2)/3` for even `n`. These were verified equal to `⌈2^{2n}/(3·2ⁿ−2)⌉` for
  `n = 3,4,7,8,9,10` (3, 6, 43, 86, 171, 342).
- **Proposition 1, one direction only** — `proposition1.jl`: distinct ortho-derivative
  differential spectra ⇒ CCZ-inequivalent, on a 3-10 function sample.
- **Dataset well-formedness / APN / degree-2 verification** — `dataset_validation.jl`: the
  logic is correct, but currently unrunnable (reproduction issue 5).

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Beierle_202201 test` | **Not run** — `julia` is not installed. Static reading of `test/runtests.jl:6` shows that on the current checkout only `test_dataset_validation` (parse-only branch), `test_algorithm1`, `test_lemma4` and `test_lemma5` would execute; the other four testsets are skipped for missing `inputs/` |
| Independent Python: built and verified all three Section 1.1 functions; full Walsh-spectrum scan of `corpora/beierleleander2022_n8.sqlite` (12,923 members, 27.5 s); OD-spectrum comparison of the four 𝒲₅ members and of the two dimension-9 permutations against all 18 n=9 catalog rows | **All pass** |

## Catalog Status

| Claimed-new item | Status | Evidence |
|---|---|---|
| 12,733 new 8-bit quadratic APN instances (Section 4.2) | **present** (bulk corpus) | `bulk_corpora` row `beierleleander2022_n8`, 12,923 members, `bib_key = Beierle_202201`, side store `corpora/beierleleander2022_n8.sqlite` |
| The 4 instances with linearity 2⁷, including the explicit Section 1.1 polynomial | **present** (bulk corpus) but **missing from the curated catalog** | corpus indices 12658-12661 have extended Walsh spectrum 𝒲₅; index 12658's OD differential spectrum equals the paper's explicit polynomial's. `data-raw/apn_catalog/n8_apn.toml` has only 5 entries (`n8_Gold_x3`, `n8_Gold_x9`, `n8_Kasami_x57`, `n8_Calderini2021_thm62`, `n8_Taniguchi2025_ex4_2`) — no Beierle–Leander representative. Since the paper answers Carlet's open problem (the first quadratic APN with linearity `2^{n−1}` at n = 8), a curated entry is warranted |
| 188 new instances from switching (Section 5) | **unverifiable** | not separable from the corpus without the authors' provenance labels |
| 2 new dimension-9 APN permutations (Section 1.1, Section 4 "Results for n = 9") | **missing** — genuine catalog gap | see records below |
| Remaining 33 dimension-9 instances | **unverifiable** | LUTs not in the repository (no n=9 corpus) |
| 5 dimension-10 instances | **unverifiable** | no n=10 corpus; `n10_apn.toml` has 4 monomial entries only |

### Catalog-gap records

Do not apply without a Julia re-verification pass.

```
# Record 1
target file      : packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
name             : n9_BeierleLeander2022_perm1
n                : 9
m                : 9
is_permutation   : true
modulus          : 529                       # x^9 + x^4 + 1
algebraic_form   : "x^3 + u*x^10 + u^2*x^17 + u^4*x^80 + u^5*x^192 in GF(2^9), u the
                    element with minimal polynomial X^3+X+1 (u = 28 under modulus
                    x^9+x^4+1)"
bib_key          : Beierle_202201
source           : Beierle, Leander, "New Instances of Quadratic APN Functions", IEEE
                   Trans. Inf. Theory 68(1):670-678, 2022 — Section 1.1, first of the two
                   dimension-nine APN permutations.
lut              : <compute as gf_pow/gf_mul over GF(2^9) mod 529 with u = 28; verified
                    APN, degree 2, permutation>
```

```
# Record 2
target file      : packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
name             : n9_BeierleLeander2022_perm2
n                : 9
m                : 9
is_permutation   : true
modulus          : 529
algebraic_form   : "x^3 + u^2*x^10 + u*x^24 + u^4*x^80 + u^6*x^136 in GF(2^9), u the
                    element with minimal polynomial X^3+X+1 (u = 28 under modulus
                    x^9+x^4+1)"
bib_key          : Beierle_202201
source           : Beierle, Leander, "New Instances of Quadratic APN Functions", IEEE
                   Trans. Inf. Theory 68(1):670-678, 2022 — Section 1.1, second of the two
                   dimension-nine APN permutations.
lut              : <same construction with the second coefficient set>
```

Equivalence evidence for both records — computed ortho-derivative differential spectra:

- perm1: `{0:164199, 2:76734, 4:13524, 6:4312, 8:2205, 12:147, 16:294, 18:147, 20:49, 22:21}`
- perm2: `{0:172557, 2:68355, 4:12201, 6:3871, 8:1638, 10:735, 12:1470, 14:49, 16:147, 18:441, 20:147, 42:21}`

These differ from each other and from **all 18** n=9 APN rows in `BFA_catalog.sqlite`
(`n9_Gold_x3/x5/x17`, `n9_Gold_i5/i7/i8`, `n9_Kasami_i8`, `n9_Budaghyan2009_eq7/eq8`,
`n9_BCL2008_Tr_x9_x3`, `n9_EdelPott2009_x3_x10_x136`, `n9_Yu2020_f7_known` — all quadratic,
all with different OD spectra; plus the non-quadratic `n9_Inverse_x510`,
`n9_Kasami_x13/x241`, `n9_Welch_Niho_x19`, `n9_Kasami_i5/i7`, which cannot be CCZ-equivalent
to a quadratic APN unless the quadratic is EA-equivalent to a quadratic power map — excluded
by the Gold comparisons, per Yoshiara 2016). Exact-LUT match against all 18: none.

A third candidate, a curated-catalog gap only (the class is already in a bulk corpus):

```
# Record 3 (optional; class is already in the beierleleander2022_n8 corpus at index 12658)
target file      : packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml
name             : n8_BeierleLeander2022_lin128
n                : 8, m = 8, is_permutation = false
modulus          : 285                       # x^8 + x^4 + x^3 + x^2 + 1
algebraic_form   : "x^3 + g^60 x^5 + g^191 x^6 + g^198 x^9 + g^232 x^10 + g^120 x^12 +
                    g^54 x^17 + g^64 x^18 + g^159 x^20 + g^144 x^24 + g^248 x^33 +
                    g^203 x^34 + g^32 x^36 + g^18 x^40 + g^216 x^48 + g^78 x^65 +
                    g^46 x^66 + g^91 x^68 + g^27 x^72 + g^70 x^80 + g^52 x^96 +
                    g^224 x^129 + g^18 x^130 + g^197 x^136 + g^253 x^144 + x^160,
                    g primitive with X^8+X^4+X^3+X^2+1"
bib_key          : Beierle_202201
source           : Beierle, Leander (2022), Section 1.1 — a quadratic 8-bit APN function
                   with linearity 2^7 (extended Walsh spectrum W_5), answering an open
                   problem of Carlet.
evidence         : du = 2, degree 2, extended Walsh spectrum
                   {0:12540, 16:48640, 32:4096, 128:4}, linearity 128; OD differential
                   spectrum {0:39420, 2:21345, 4:4041, 6:384, 8:27, 62:63}, matching corpus
                   member beierleleander2022_n8 #12658 and distinct from #12659/#12660/#12661.
```

## Library-Reuse Note

- **Duplicate of a core export**: `helpers.jl:13-18` `print_header` → use `VBF.print_banner`.
- **Should use a core export**: `proposition1.jl:25-29` `ortho_derivative_signature` →
  `VBF.apn_ea_mugshot`, which already bundles the OD differential and Walsh invariants the
  paper prescribes.
- **Paper-specific, correctly local**: `parse_lut_line` / `stream_dataset`
  (`helpers.jl:28-57`); the incremental DDT/ANF machinery in `algorithm1.jl` (core's
  `mobius!` / `ddt` are batch, and the search needs incremental).
- **Promote-to-core candidates**: `lemma4.jl:20` `fixed_point_count` and `lemma5.jl:22`
  `cycle_count` — generic permutation statistics with no core equivalent
  (`permutation_order` is exported, cycle structure is not). They belong in
  `packages/VBF/src/representations/` as `fixed_points` / `cycle_count` / `cycle_type`.
- **To be deleted, not promoted**: `table1_invariants.jl`'s CSV plumbing (`_split_csv_line`,
  `_strip_backticks`, `_strip_csv_field`) and `_walsh_class`.

## Open Questions

- Is the authors' LE-automorphism class-index list (from `cbe90/quadratic_apn`) acceptable
  as a paper input, or must Table 1 be reproduced from generated rational canonical forms?
- Should the n=9 (35) and n=10 (5) instances be imported as new `data-raw` corpora, or are
  those two result sets deliberately out of scope?
