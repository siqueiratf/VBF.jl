# Findings: the four "new" CCZ classes of Kuznetsov (2026) are Edel–Pott (2009) functions

**Status:** refutation of the central novelty claim, established three independent ways.
**Subject:** O. Kuznetsov, *"Quadratic APN Functions in Dimension 8 via Gröbner Basis
Search in a Self-Equivalence Subspace"* (arXiv:2606.11967; submitted to IEEE Trans. Inf. Theory).

---

## 1. Summary

The paper reports the discovery of **four new CCZ-equivalence classes** of quadratic
APN functions over GF(2⁸) — labelled CLASS-A, B, C, D (500 of its 566 functions) —
claimed to be *"absent from all known databases"* and certified new by the
ortho-derivative invariant.

**All four are CCZ-equivalent to functions published by Edel and Pott in 2009**
(*"A new almost perfect nonlinear function which is not quadratic,"* Adv. Math.
Commun. 3(1):59–81, 2009), specifically the entries of their **Table 9** (known
switching classes of APN's in F₂⁸):

| Kuznetsov (2026) | published σ-hash (its Table tab:fullsig) | = Edel–Pott (2009) Table 9 |
|------------------|------------------------------------------|----------------------------|
| CLASS-A | `9d95d9c4a5e2dfdd` | function **2.1** |
| CLASS-B | `c5f52f5659346f9f` | function **1.3** |
| CLASS-C | `74a30c1a17d45761` | function **1.2** |
| CLASS-D | `024ba500f4bac35b` | function **1.11** |
| CLASS-E | `11cc72af6d61925d` | function 1.1  (Gold x³) |
| CLASS-F | `d15183d1bdf9a1b4` | function 1.15 (Gold x⁹) |

Functions 1.2, 1.3, 1.11 all belong to Edel–Pott's **EA switching class of the Gold
function x³**, which their paper explicitly highlights: *"In the case n = 8, the EA
switching class of the Gold function x³ contains 17 CCZ inequivalent functions!"*
Kuznetsov's "gateway phenomenon" (CLASS-B, C, D appear only in Gold-x³-centered
slices) is therefore a **rediscovery of Edel–Pott's Gold-x³ switching class** by a
different (Gröbner-basis) method, unrecognised as such.

The four classes were published **17 years earlier**.

---

## 2. The paper's error

The paper's verification (its Theorem "Main result" and §"Verification") compares the
four classes only against:

1. Beierle et al. 2025 (Zenodo 16752428, 3,775,599 functions),
2. the BBL2021 file `apn_8bit.txt` (12,921 functions), and
3. the Gold classes directly.

It **never checks Edel–Pott 2009**, even though it cites that work in its own Related
Work ("the bivariate construction of Edel and Pott … yielded 8,157 new instances for
n = 8"). The 2025 database is, by construction, "new relative to the 32,892 known
through 2021"; the BBL2021 file is a *disjoint* 12,921-function set. Neither contains
the Edel–Pott switching-class functions, so the paper's "NO_MATCH" results are
correct for the files it checked — but the conclusion of novelty does not follow,
because the relevant 2009 database was omitted.

The same σ-signatures additionally appear in the **Yu–Wang–Li (2014)** and
**Simon–Berg** quadratic-APN families, so "previously known" is corroborated by
multiple independent pre-2026 sources.

---

## 3. Verification (reproducible, primary-source)

All three checks use the paper's *own* representatives and its *own* hashing recipe,
so the result does not depend on any third-party catalog.

### 3.1 The functions tested are the paper's
The author's class representatives (from the artifact `ccz_verify_representatives.m`)
reproduce the paper's published σ-hashes (Table tab:fullsig) **exactly** for all six
classes, computed with the paper's recipe (`sha256(repr(σ))[:16]`,
`σ = (diff-spectrum(π_F), abs-Walsh-spectrum(π_F))`, `src/classify_apn.py`).

### 3.2 Primary-source reconstruction (no third-party catalog)
Edel–Pott's Table 9 lists each function as a univariate polynomial over GF(2⁸) with
u a root of their **Table 2** primitive polynomial **u⁸ + u⁴ + u³ + u² + 1**.
Reconstructing these polynomials directly and hashing with the paper's recipe:

```
CLASS-A = Edel–Pott 2.1 :  x³ + x¹⁷ + u¹⁶(x¹⁸ + x³³) + u¹⁵x⁴⁸              → 9d95d9c4a5e2dfdd
CLASS-C = Edel–Pott 1.2 :  x³ + tr(u⁴⁸x³ + x⁹)                            → 74a30c1a17d45761
CLASS-B = Edel–Pott 1.3 :  x³ + u·tr(u⁶³x³ + u²⁵²x⁹)                       → c5f52f5659346f9f
                           ( ≡ x³ + u²⁴⁵x³³ + u¹⁸³x⁶⁶ + u²¹x¹⁴⁴ )
CLASS-D = Edel–Pott 1.11:  via the Gold-x³ switching chain               → 024ba500f4bac35b
   1.1 = x³
   1.2 = 1.1 + tr(u⁴⁸x³ + x⁹)
   1.5 = 1.2 + u⁵¹·tr(u²⁵³x³ + u¹⁰²x⁹)
   1.8 = 1.5 + u⁶⁸·tr(u¹⁵³x³ + u⁵¹x⁹)
   1.11 = 1.8 + u⁸⁵·tr(u²⁴³x³ + u¹⁷⁰x⁹)
(Gold x³ → 11cc72af… = CLASS-E, as a pipeline sanity check.)
```

Each reconstructed σ-hash equals the paper's published hash. (σ is a CCZ-invariant,
so the polynomials' F₂-coefficient parts are field-representation independent; the
u-coefficient parts use Edel–Pott's stated primitive polynomial.)

### 3.3 Exact code-equivalence
`sboxU.are_ccz_equivalent_from_code` (the exact test the paper itself uses) returns
`True` for CLASS-A vs Edel–Pott #18, B vs #5, C vs #3, D vs #4 (and A vs reprs8_17,
B vs reprs8_4), independent of the σ-invariant.

Three methods — the paper's σ-hash recipe on primary-source polynomials, exact
code-equivalence, and σ-matching across multiple pre-2026 catalogs — agree.

---

## 4. Secondary defect: the appendix S-box tables are corrupt

Independently of the novelty issue, the paper's Appendix (Table tab:reps, the printed
256-value lookup tables for A–D) is internally inconsistent with its own σ-hash table
(tab:fullsig). Under both VBF's and sboxU's σ (which agree), the four printed
representatives collapse to **only three distinct CCZ classes**, and the table
labelled "CLASS-B" is in fact Gold x³ (CLASS-E). The decimal transcription is
erroneous.

---

## 5. Scope and caveats (fair assessment)

- **Refuted:** the headline contribution — *four new CCZ classes / 500 new functions.*
  They are Edel–Pott (2009) functions, proven above.
- **Separate, minor, and correct:** the observation that the self-equivalence
  subspace V_A (BBL2021 class 22) *does* contain APN functions (Gold copies and a
  CLASS-A-equivalent), contradicting a zero-result from BBL2021's tree search. This
  stands, but yields only already-known classes.
- The fc22+sol22 parameterization and the NL=4 Gröbner-basis slicing are methods, not
  results; their claimed payoff ("functions that do not arise from any known
  construction") is false — the functions arise from Edel–Pott's switching
  construction.
- The exact-CCZ confirmation in §3.3 used sboxU; the primary-source reconstruction in
  §3.2 does not, so the refutation does not rest on any catalog's correctness.

---

## 6. Reproduction

Primitive field GF(2⁸) = F₂[u]/(u⁸+u⁴+u³+u²+1), u primitive (Edel–Pott Table 2).
Hash recipe: `σ = (json-stable(diff_spectrum(ortho_derivative(F))),
json-stable(abs_walsh_spectrum(ortho_derivative(F))))`, hash =
`sha256(repr(σ)).hexdigest()[:16]` (sboxU; matches the author's `src/classify_apn.py`).

A single self-contained script, **`verify_edelpott.py`** (in this directory),
reproduces the whole result: it rebuilds Edel–Pott's Table-9 functions from their
polynomials over their field, hashes with Kuznetsov's own recipe, and asserts the
match. Requirements: SageMath + sboxU (the paper's own tools). Run:

```
sage -python verify_edelpott.py
```

Expected output — all six classes match:

```
  CLASS-A  function 2.1   9d95d9c4a5e2dfdd = published  OK
  CLASS-B  function 1.3   c5f52f5659346f9f = published  OK
  CLASS-C  function 1.2   74a30c1a17d45761 = published  OK
  CLASS-D  function 1.11  024ba500f4bac35b = published  OK
  CLASS-E  function 1.1   11cc72af6d61925d = published  OK   (Gold x³)
  CLASS-F  function 1.15  d15183d1bdf9a1b4 = published  OK   (Gold x⁹)
```

Edel–Pott 2009 PDF: https://www.yvesedel.de/Papers/switch.pdf

---

## 7. Draft notification (authors / editor)

> Subject: Prior art for arXiv:2606.11967 — the four "new" CCZ classes are Edel–Pott (2009)
>
> The four CCZ classes reported as new (CLASS-A, B, C, D) are CCZ-equivalent to
> functions in Table 9 of Edel & Pott, *A new almost perfect nonlinear function
> which is not quadratic*, Adv. Math. Commun. 3(1):59–81, 2009 — specifically
> functions 2.1, 1.3, 1.2, 1.11, the latter three lying in the Gold-x³ switching
> class that paper explicitly discusses ("the EA switching class of x³ contains 17
> CCZ inequivalent functions"). This is verified by reconstructing the Table-9
> functions over Edel–Pott's own primitive field and reproducing the σ-hashes of
> your Table tab:fullsig with your own recipe (`classify_apn.py`); it is confirmed
> independently by exact code-equivalence (`sboxU.are_ccz_equivalent_from_code`).
> The verification omitted Edel–Pott 2009 (and Yu–Wang–Li 2014, Simon–Berg), which
> already contain these classes. A one-file reproduction is attached
> (`verify_edelpott.py`). Separately, the Appendix S-box tables (tab:reps) are
> internally inconsistent with tab:fullsig (three distinct classes, one mislabelled
> Gold).

---

## References

- Y. Edel, A. Pott. *A new almost perfect nonlinear function which is not quadratic.*
  Adv. Math. Commun. 3(1):59–81, 2009. doi:10.3934/amc.2009.3.59
- O. Kuznetsov. *Quadratic APN Functions in Dimension 8 via Gröbner Basis Search in a
  Self-Equivalence Subspace.* arXiv:2606.11967.
- S. Yoshiara. *Equivalences of quadratic APN functions.* J. Algebraic Combin.
  35(3):461–475, 2012.
- A. Canteaut, A. Couvreur, L. Perrin. *Recovering or testing extended-affine
  equivalence.* IEEE Trans. Inf. Theory 68(9):6187–6206, 2022.
- L. Perrin. *sboxU.* https://github.com/lpp-crypto/sboxU
