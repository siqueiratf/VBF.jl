# Gologlu_202503 — Equivalences of Biprojective Almost Perfect Nonlinear Functions

**Paper**: Faruk Göloğlu, Lukas Kölsch. "Equivalences of biprojective almost perfect nonlinear functions." *The Electronic Journal of Combinatorics* (submitted Feb 2024, accepted Mar 2025).

**Reproduction path**: `papers/Gologlu_202503/`

**Verdict**: Complete.

Every computational claim in the paper is reproduced and passes: the new APN family **F₄** (Theorem 3.3) is verified APN exhaustively over all 504 admissible parameter triples at its smallest realisable dimension `m = 6` (`n = 12`), and — via the Lemma 2.1 F₂-kernel criterion, which sidesteps the DDT entirely — also at `n = 20` and `n = 28`. Theorem C.3 (F₄ is 3-to-1 with the classical Walsh spectrum), the group-theoretic machinery (Lemmas 4.5, 4.7, A.1, Theorem 4.8), the within- and between-family (in)equivalence results (Theorems 5.1, 6.1, Cor. 5.2), and Appendix B (Lemmas B.1/B.2, Theorem B.3) all check out.

Four issues were found in the paper (one substantive typo in Appendix C, three errors in the *explicit witness maps* printed inside proofs — none of which affects any theorem's conclusion). All are listed below with the corrected statements, and each correction is verified pointwise.

The paper publishes **no code and no data**: every result is proved by hand. There is therefore no author artifact to load, and every number in this reproduction is freshly generated.

---

## Paper Issues

### 1. Appendix C — the "classical" extended Walsh spectrum is stated with a wrong multiplicity

- **Location**: Appendix C, the paragraph after Definition C.1.
- **Stated**: the classical extended Walsh spectrum contains `0`, `2^{n/2}`, `2^{(n+2)/2}` precisely `(2ⁿ−1)·2^{n−2}`, `(2ⁿ−1)·2^{n+1}/3`, and `(2ⁿ−1)·2ⁿ/3` times respectively.
- **Correct**: the last multiplicity is `(2ⁿ−1)·2^{n−2}/3`, not `(2ⁿ−1)·2ⁿ/3` (off by a factor of 4).
- **Why it cannot be right as printed**: the three printed multiplicities sum to `5·2^{n−2}(2ⁿ−1)`, but there are only `2ⁿ(2ⁿ−1) = 4·2^{n−2}(2ⁿ−1)` pairs `(b ≠ 0, a)` in the multiset. The printed spectrum is impossible for *any* function. With the corrected entry the sum is exactly `2ⁿ(2ⁿ−1)`.
- **Evidence**: `theoremC_3.jl` computes the spectrum from core `lat` for a Gold function at `n = 6` (whose spectrum *is* the classical one by definition) and for F₄ at `n = 12`. Both match the corrected multiset and neither matches the printed one. Independent of the paper, the arithmetic identity `Σ printed ≠ #{(b≠0,a)}` is asserted in `test/test_theoremC_3.jl` for `n = 6, 8, 10, 12`.
- **Impact**: none on Theorem C.3's substance (F₄ *is* 3-to-1 and *does* have the classical Walsh spectrum). Only the definition of "classical" is misprinted.

### 2. Proof of Theorem 5.1(a),(b) — the explicit `q ↔ q̄` maps do not satisfy the identity

- **Location**: proof of Theorem 5.1, the paragraph beginning "For functions `F_q`, `F_{q'}` in the families `F₁`, `F₂` …".
- **Stated**: with `M₁ = M₄ = L₂ = L₃ = 0`, `M₂ = M₃ = x^{q̄}`, `L₁ = x`, the paper sets `L₄ = x^{q̄}` for `F₁` and `L₄ = x^{q}` for `F₂`.
- **Correct**: `L₄ = x^{q}` for `F₁` and `L₄ = x^{q²}` for `F₂`.
- **Derivation**: with `X = y^{q̄}`, `Y = x^{q̄}` and `q q̄ ≡ 1`,
  - `F₁`: `g(y^{q̄}, x^{q̄}) = y^{q+q̄} + x^{q̄}y^{q} + x^{q+q̄} = [g_{q̄}(x,y)]^{q}` ⇒ `L₄ = x^{q}`.
  - `F₂`: `g(y^{q̄}, x^{q̄}) = x^{q̄}y^{q²} + x^{q²}y^{q̄} = [g_{q̄}(x,y)]^{q²}` ⇒ `L₄ = x^{q²}`.
- **Evidence**: `theorem5_1.jl` evaluates both the printed and the corrected map on all `2¹⁰` points at `m = 5`. The printed one fails; the corrected one holds. `M` and `L₁` as printed are correct.
- **Impact**: none on the conclusion. `F_q ≅ F_{q̄}` is true — `theorem4_8.jl`'s search independently finds monomial-shaped witnesses and re-verifies them pointwise, and the class count `φ(m)/2` comes out right.

### 3. Proof of Theorem 5.1(c)(i) — wrong coefficient in the F₄ map

- **Location**: proof of Theorem 5.1, "Family `F₄`" paragraph.
- **Stated**: `F_{q,B,a} ∘ M = L ∘ F_{q̄, B, B^{Q+1}/a}` with `M₁ = M₄ = x^{q̄}`, `L₁ = x`, `L₄ = (B^Q/a)·x^Q`.
- **Correct**: `L₄ = (a/B)·x^Q`. Everything else (`M`, `L₁`, the target `a′ = B^{Q+1}/a`) is right.
- **Derivation**: `g(x^{q̄}, y^{q̄}) = x^Q y^{q̄} + (a/B)·x^{q̄} y^Q`, while `L₄(g′(x,y)) = c·x^{q̄}y^Q + c·(a′/B)^Q·x^Q y^{q̄}` (using `Q² ≡ 1`). Comparing coefficients gives `c = a/B` and `(a′/B)^Q = B/a`, i.e. `a′ = B^{Q+1}/a^Q = B^{Q+1}/a` since `a ∈ K^×`.
- **Evidence**: `theorem5_1.jl`, `theorem5_1_c` — both variants evaluated on all `2¹²` points at `m = 6`. The printed coefficient fails; `(a/B)` holds.
- **Impact**: none on the conclusion.

### 4. Theorem B.3's target lies outside Table 2.1's stated Zhou–Pott parameter range

- **Location**: Theorem B.3 vs. Table 2.1 (Zhou–Pott "Notes" column).
- **Issue**: the construction turns a Carlet function into `(xy, (1,0,0,u)_q)`. In Table 2.1's Zhou–Pott form `((1,0,0,d)_q, (0,0,1,0)_r)` that is `r = 2⁰`, i.e. **`j = 0`** — but Table 2.1 requires `0 < j < m`. Additionally the resulting pair has its two **output coordinates swapped** relative to the Table 2.1 ordering.
- **Impact**: none. An output-coordinate swap is an F₂-linear permutation of the codomain, hence an EA-equivalence; and Lemma A.1 explicitly speaks of "a Zhou–Pott function with `j ≠ 0`", showing `j = 0` members are contemplated elsewhere in the paper. At `j = 0` the admissibility condition `d ≠ a^{q+1}(b^q+b)^{1−r}` degenerates to "`d` is a non-cube", which is exactly what the construction delivers — so the target really is APN. Table 2.1's `0 < j` and Theorem B.3's usage are simply inconsistent as written.
- **Evidence**: `theoremB_3.jl` builds the map, verifies `L ∘ C ∘ M + N = (ZP with outputs swapped)` on all `2⁸` points, and confirms the `j = 0` target is APN with `u` a non-cube.

### 5. (Cosmetic) Eq. (A.6) transposes the Taniguchi second component

- **Location**: Appendix A, Eq. (A.6).
- **Issue**: Eq. (A.6) writes the Taniguchi second component as `x^{q²}y`, while Table 2.1 and the proof of Theorem 6.1 use `x·y^{q²}`. The two differ by swapping `x` and `y`.
- **Impact**: none — the conclusion drawn from the equation (`c₂ = c₃ = 0`) is the same either way. Recorded only because the two conventions coexist in the paper.

### Not a bug — but worth recording

- **`(q, m) ≠ (2, 4)`** (Theorem 6.1, for Taniguchi and F₁) is *necessary*, and its necessity is stronger than the paper spells out: at `m = 4` **every** Taniguchi / F₁ / Zhou–Pott instance has `l ≡ 2 = m/2 (mod 4)`, so Theorem 4.8's standing hypothesis `l₁ ≠ m/2` fails for all of them. And indeed `ZP(q=2, r=4, d=2)` and `F₁(q=8)` **are** genuinely CCZ-equivalent at `m = 4` — confirmed with core `are_ccz_equivalent` (exact, `n = 8`), not merely by an invariant. Since `F₁(q=8)` is the `q̄`-partner of `F₁(q=2)` at `m = 4` and hence in the same CCZ class, excluding the pair `(2,4)` does exclude the whole class, so the paper's phrasing is consistent. This is run as the *necessity control* in `theorem6_1.jl`.

---

## Reproduction Issues

### 1. `input/*.tex` is an OCR conversion, and one formula is mangled [RESOLVED]

- **Location**: `input/Göloğlu e Kölsch - 2025 - …tex`, Table 2.1, Gold row (`m` even).
- **Symptom**: the tex reads `b = Σ_{i=0}^{k-1} a^{2^{2}}` — an exponent with no dependence on the summation index. The tex also contains an `\includegraphics` where a displayed formula should be (Appendix A, F₄ case), confirming it is a machine conversion of the PDF rather than the authors' source.
- **Resolution**: the **PDF** (authoritative, p. 5) prints `b = Σ_{i=0}^{k-1} a^{2^i}`. `helpers.jl:gold_even` follows the PDF. The reading was also settled independently by brute force before the PDF was consulted: over `m ∈ {4,6,8}` and every admissible `(k,a)`, `Σ_{i<k} a^{2^i}` always lands in the APN-valid set for `b`, while the plausible alternative `Σ_{i<k} a^{2^{2i}}` (which coincides at `k = 1`, hiding the problem) fails for **every** admissible `a` at `m = 4, k = 3`. Both readings are asserted in `test/test_lemma2_1.jl` — one APN, one not.

### 2. Column/bit-index mismatch in the Lemma 4.7 matrix code [RESOLVED]

- **Location**: `lemma4_7.jl` (during development).
- **Symptom**: `dim C_GL(M)` came out as `2m` instead of the predicted `4m`, and the exhaustive `m = 2` count gave `|C| = 12` instead of `180`.
- **Root cause**: `M × M` is encoded as `(x << m) | y`, so the `x`-half occupies the *high* bits — but the matrix columns were being listed `x`-half first, i.e. indexed opposite to the bit positions the matrix-vector product used. The swap matrix came out as the identity.
- **Resolution**: introduced `map_columns`, which indexes every column by its bit position. All of Lemma 4.7 then verifies, including the exhaustive `m = 2` check (`|C_GL(M)| = |GL(2,F₄)| = 180`, `|N_GL(M)| = |ΓL(2,F₄)| = 360`, both enumerated over all 20160 elements of `GL(4,2)`).

### 3. Theorem 4.8's restricted search initially only handled the matched-exponent case [RESOLVED]

- **Location**: `theorem4_8.jl`.
- **Symptom**: the `q ↔ q̄` equivalences could not be found, because they live in the `k₁ ≡ −k₂` branch of the theorem, where the `L`-degrees become `2^{t+k}` and the two middle coefficients of the target are swapped.
- **Resolution**: `linear_equiv_thm48` now implements both sign branches and both `L`-shapes (`L₂=L₃=0` and `L₁=L₄=0`). Every candidate produced by the coefficient algebra is re-verified **pointwise** with `el_identity_holds`, so a bug there can only cause a miss, never a false positive.

### 4. Everything under `results/` is opt-in

`theorem3_3.jl` writes `results/theorem3_3_m6.txt` (the admissible F₄ parameter list) only under `save_results=true`; `report.jl` writes `results/paper_report.txt` likewise. Nothing is written by default. `results/` is git-ignored.

---

## Items Reproduced

| Paper object | File | What was checked | Evidence |
|---|---|---|---|
| Lemma 2.1 (APN criterion) | `lemma2_1.jl` | criterion ⇔ `differential_uniformity == 2` | 57 biprojective pairs at `m = 3,4,5`; 36 APN + 21 deliberately inadmissible; **zero disagreements** with the ground-truth DDT |
| Lemma 3.2 (gcd identities) | `lemma3_2.jl` | all six gcds, plus `gcd(k+m/2, m) = 2` | exhaustive for `m ≡ 2 (mod 4)`, `m ≤ 22`, all admissible `k` (28 pairs); all 37 inadmissible `k` break the identities |
| **Theorem 3.3 — F₄ is APN (NEW FAMILY)** | `theorem3_3.jl` | APN for every admissible `(k,B,a)` | **exhaustive: all 504 triples at `m=6` (`n=12`)** are APN; DDT-confirmed on the full `2¹²` LUT; **`n=20` and `n=28`** confirmed via the Lemma 2.1 kernel criterion (`full_search=true`) |
| Theorem 3.3 hypotheses are necessary | `theorem3_3.jl` | both conditions | `B` a cube ⇒ DU = 8; `B^{q+r} = a^{q+1}` ⇒ DU = 8 (42 such `(B,a)` pairs exist per `k` at `m=6`) |
| Theorem C.2/C.3 (3-to-1, Walsh) | `theoremC_3.jl` | `F(x,y) = F(ωx, ω²y)`; `is_3_to_1`; extended Walsh spectrum | identity holds for all `ω ∈ F₄^×`; image size `= (2¹²−1)/3 + 1 = 1366`; spectrum matches the **corrected** classical multiset (see Paper Issue 1) |
| Lemma 4.5 (`Z^{(q,r)} ≤ Aut_EL(F)`) | `lemma4_5.jl` | `F(ax,ay) = (a^{q+1}f, a^{r+1}g)` | 47 pairs at `m = 3..6`, exhaustive over `a ∈ M^×` and all `(x,y)`; `|Z^{(q,r)}| = 2^m − 1` |
| Lemma 4.7 (normalizer/centralizer) | `lemma4_7.jl` | `C_GL(M_P) = C_GL(M) ≅ GL(2,M)`; `N ≅ ΓL(2,M)` | `dim_F₂ C = 4m` for `m = 3,4,5` (solved as an F₂ linear system via core `kernel_f2`); **exhaustive at `m = 2`**: all 20160 elements of `GL(4,2)` enumerated ⇒ `|C| = 180`, `|N| = 360` |
| Lemma A.1 + condition (C) | `lemmaA_1.jl` | `[C_F : Z^{(q,r)}]` per family | Taniguchi → **1**; Zhou–Pott (`j≠0`), F₁, F₂, Carlet, **F₄** → **3** — exactly as Lemma A.1 predicts. `p ∤ index` for every instance. F₄'s three classes are exactly the `Z_ω^{(q,r)}`, `ω ∈ F₄^×` |
| Theorem 4.8 (shape theorem) | `theorem4_8.jl` | exponent condition; restricted search | positive: `F₁(q) ≅ F₁(q̄)` witnesses found and pointwise-verified; negative: every corpus pair violating the exponent condition is CCZ-inequivalent |
| Theorem 5.1(a),(b) | `theorem5_1.jl` | `φ(m)/2` classes for F₁, F₂ | `m = 5`: exactly 2 classes each = `φ(5)/2`; corrected `q ↔ q̄` maps verified pointwise (see Paper Issue 2) |
| Theorem 5.1(c) / Cor. 5.2 | `theorem5_1.jl` | F₄ class count at `m = 6` | 252 admissible `(B,a)` at `k=1` collapse to **exactly 1 CCZ class** (restricted-shape orbit = upper bound, distinct mugshots = lower bound, and they meet). `(c)(ii)` and `(c)(iii)` (`≤ m` choices of `a′`; observed max = 6) hold. Consistent with Cor. 5.2's `[1, 6]` — see caveat below |
| Theorem 5.1(d) (Carlet, `m` odd) | `theorem5_1.jl` | all same-`q` Carlet functions EL-equivalent; `φ(m)/2` classes | Lemma B.2's `G`-orbit covers all 10912 root-free tuples at `m=5`, giving the explicit `M` for every pair; 2 classes = `φ(5)/2` |
| Theorem 6.1 (between families) | `theorem6_1.jl` | pairwise CCZ-inequivalence | `m = 5` (`n = 10`): **160/160** cross-family pairs separated by distinct ortho-derivative mugshots, across Gold, Carlet, Taniguchi, F₁, F₂. With `full_search=true`, `m = 6` adds F₄: **28/28** separated |
| Lemma B.1 | `lemmaB_2.jl` | `#root-free = (2^m+1)2^m(2^m−1)²/3` | enumerated: 1176 (`m=3`), 20400 (`m=4`), 338272 (`m=5`, opt-in) — all match |
| Lemma B.2 | `lemmaB_2.jl` | `G` transitive; `|Stab| = 3(2^m−1)` | orbit = whole root-free set; `|Stab| = 21 / 45 / 93` for `m = 3/4/5` |
| Theorem B.3 | `theoremB_3.jl` | Carlet (`m` even) is EA-equiv to Zhou–Pott | `L ∘ C ∘ M + N = ZP` verified pointwise on all `2⁸` inputs at `m = 4` (see Paper Issue 4 for the `j=0` / coordinate-swap bookkeeping) |

### Caveat: Theorem 5.1(c), Cor. 5.2 and Theorem 6.1-with-F₄ cannot be tested *in range*

F₄ requires `m ≡ 2 (mod 4)`, while Theorems 4.8, 5.1, 6.1 and Cor. 5.2 all require `m ≠ 6` (at `m = 6` there is no primitive prime divisor of `2⁶ − 1 = 63` — the Zsygmondy exception — so the Sylow argument that drives the whole method collapses; `primitive_prime_divisor(6) === nothing` is asserted in the tests). The two conditions have **no computationally reachable overlap**: the next case is `m = 10`, i.e. `n = 20`, where a DDT has `2⁴⁰` cells and an ortho-derivative mugshot is out of reach.

So the F₄ *equivalence* numbers reported at `m = 6` are labelled **outside the theorem's stated range** throughout. They are *consistent* with Cor. 5.2's bounds `[1, 6]` (the observed count is 1, meeting the lower bound), but they are not a test of them. The F₄ *APN* claim (Theorem 3.3), which carries no `m ≠ 6` hypothesis, **is** tested in range and at `n = 20, 28` as well.

---

## Test Results

| Command | Result |
|---|---|
| `julia --project=. papers/Gologlu_202503/test/runtests.jl` | **PASS** — 12 test sets, **210 assertions**, 0 failures (~40 s) |
| `make -C papers/Gologlu_202503 report` | **PASS** — 78 `[PASS]`, 0 `[FAIL]` |
| `make -C papers/Gologlu_202503 report full_search=true` | **PASS** — adds F₄ at `n = 20` / `n = 28`, Lemma B.2 at `m = 5`, Theorem 6.1 with F₄ at `m = 6`; 0 failures |

Per-file: `lemma2_1` 13, `lemma3_2` 12, `theorem3_3` 22, `theoremC_3` 21, `lemma4_5` 10, `lemma4_7` 22, `lemmaA_1` 26, `theorem4_8` 16, `theorem5_1` 23, `theorem6_1` 15, `lemmaB_2` 14, `theoremB_3` 16.

**Every test set contains at least one discriminating negative.** No suite here asserts only "this never happens":

- `lemma2_1` — 36 APN *and* 21 non-APN pairs; a criterion returning a constant fails.
- `lemma3_2` — all 37 `k` with `gcd(k,m) ≠ 1` break the identities.
- `theorem3_3` — violating either hypothesis of Theorem 3.3 yields DU = 8, checked on the real DDT.
- `theoremC_3` — the printed Appendix C multiset is shown *impossible* by arithmetic, and a Taniguchi function at `n = 6` is APN but **not** 3-to-1, so `is_3_to_1` is discriminating.
- `lemma4_5` — a wrong exponent, and the non-biprojective perturbation `F + (x², 0)`, both lose the automorphism.
- `lemma4_7` — a transvection does *not* centralise `M`; both `4m` and the exhaustive `m=2` counts are computed, never transcribed.
- `lemmaA_1` — **both** predicted index values (1 and 3) occur in the corpus, and suppressing the `N`-part collapses the Carlet index 3 → 1.
- `theorem4_8` / `theorem6_1` — the positive control (`F₁(q)` and `F₁(q̄)` share a mugshot) proves the invariant *does* collapse equivalent functions, so "160/160 separated" is a real result; the `m = 4` necessity control exhibits a genuine CCZ-equivalence via exact `are_ccz_equivalent`.
- `theorem5_1` — the maps **as printed** are asserted to fail and the corrected ones to hold.
- `lemmaB_2` — a polynomial *with* a root is shown to lie outside the orbit.
- `theoremB_3` — for `m` odd there are no non-cubes at all, so the even-`m` hypothesis is essential.

No local `print_check` is defined anywhere in this folder (the four emitters come from core and none of them throws), so no `@test` is decorative.

---

## Catalog Status

**Nothing was added to the APN catalog** (out of scope for this task). The paper's new family produces one catalog-gap record:

### Catalog-gap record — Family F₄ (Theorem 3.3)

| Field | Value |
|---|---|
| **name** | `n12_GologluKolsch2025_F4` |
| **n**, **m** | 12, 12 |
| **bib_key** | `Gologlu_202503` |
| **source** | Göloğlu & Kölsch, *Equivalences of biprojective APN functions*, Electron. J. Combin. (2025), **Theorem 3.3** and Table 2.1, last row |
| **construction** | Bivariate over `M = GF(2⁶)`, `F = M × M ≅ GF(2¹²)`. `F(x,y) = (x^{q+1} + B·y^{q+1},  x^{r}y + (a/B)·x·y^{r})` with `q = 2^k`, `r = 2^{k+m/2} = qQ`, `Q = 2^{m/2}`. Conditions: `m ≡ 2 (mod 4)`, `gcd(k,m) = 1`, `B ∈ M^× ∖ (M^×)³` (a non-cube), `a ∈ K^× = GF(2^{m/2})^×`, and `B^{q+r} ≠ a^{q+1}`. |
| **representative** | `m = 6`, `k = 1` (`q = 2`, `r = 16`), `B = 2`, `a = 1`, **modulus `x⁶+x+1` (= 67)** — i.e. `VBF.primitive_polynomial(6)`. Packing: `z = (x << 6) \| y → (f << 6) \| g`. Reproduce with `family_f4(BiField(6), 1, 2, 1)` then `bipair_sbox`; the LUT is not inlined here (4096 entries). |
| **properties** | APN (`differential_uniformity == 2` on the full `2¹²` DDT), quadratic (`algebraic_degree == 2`), **not** a permutation, **3-to-1** (image size 1366), classical (Gold-like) extended Walsh spectrum. |
| **equivalence evidence** | CCZ-**inequivalent** to both existing `n = 12` catalog entries (`n12_CalderiniLiVilla2023_F1`, `n12_CalderiniLiVilla2023_F2`): all three are quadratic APN, so by Yoshiara's theorem (the paper's Theorem 4.2) CCZ = EA, and their `apn_ea_mugshot` (ortho-derivative Walsh + DDT spectra) differ — a *sound* inequivalence proof. Within F₄ itself, all 504 admissible triples at `m = 6` fall into a **single** CCZ class, so one representative suffices. Novelty against families *not* in the catalog is Theorem 6.1's business, verified here at `m = 6`: F₄ is separated from Gold, Zhou–Pott and Taniguchi (28/28 cross-family pairs). |
| **caveat for whoever ingests this** | The class count at `m = 6` is 1, so F₄ contributes exactly **one** new `n = 12` function, not 504. The family's advertised exponential growth (Cor. 5.2) only bites for `m ≥ 10`, i.e. `n ≥ 20`. |

---

## Library-Reuse Note

No core primitive was reimplemented. `helpers.jl` contains only paper-specific algebra (the biprojective 4-tuple representation, the `D_f^u` maps of Lemma 2.1, the Table 2.1 family constructors and their admissibility predicates, the `G`-action of Appendix B, and the `C_F` enumeration of Lemma A.1).

Core functions used directly: `gf_mul`, `gf_pow`, `gf_inv`, `gf_trace`, `gf_is_dth_power`, `in_subfield`, `subfield_elements`, `primitive_polynomial`, `kernel_f2`, `rank_f2`, `SBox`, `differential_uniformity`, `algebraic_degree`, `is_permutation`, `is_3_to_1`, `image_set`, `lat`, `ddt`, `ortho_derivative` (via `apn_ea_mugshot`), `apn_ea_mugshot`, `are_ccz_equivalent`, `gold_apn`, and the report emitters `print_banner` / `print_section` / `print_check` / `print_kv`.

The one architecturally interesting reuse: **Lemma 2.1's APN criterion is implemented on top of core `kernel_f2`**, because `D_f^u` and `D_g^u` are F₂-linear in `(x,y)` — so "exactly two solutions" is "kernel of dimension 1" on a `2m × 2m` matrix. That turns an `O(2^{2n})` DDT into an `O(2^m · m³)` rank computation and is the only reason F₄ can be certified APN at `n = 20` and `n = 28` at all.

### Promote-to-core candidates

Two paper-local helpers look general enough to be worth core status if a second paper needs them (**not** added here, per scope):

1. **`extended_walsh_spectrum(S)`** (`theoremC_3.jl`) — the multiset `{{|W_F(b,a)| : b ∈ F^×, a ∈ F}}`. Core's `absolute_walsh_spectrum` excludes only the single entry `(0,0)` rather than the whole `b = 0` column, so it contributes `2ⁿ − 1` spurious zeros and cannot be compared against the literature's "classical spectrum" multiplicities without correction. A core `extended_walsh_spectrum` (or a keyword on the existing one) would stop every future paper folder from rediscovering this.
2. **`primitive_prime_divisor(m)`** (`helpers.jl`) — the Zsygmondy primitive prime divisor of `2^m − 1`, returning `nothing` at `m = 6`. It is the object that explains every `m ≠ 6` hypothesis in this literature, and it is pure number theory with no paper-specific content.

Neither is a *missing* primitive that blocked the reproduction; both are small conveniences.
