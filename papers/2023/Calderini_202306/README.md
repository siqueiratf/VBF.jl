# Calderini_202306 — Extending two families of bivariate APN functions

**Citation**: M. Calderini, K. Li, I. Villa, *Extending two families of bivariate
APN functions*, Finite Fields and Their Applications (2023).

**Reproduction path**: `papers/2023/Calderini_202306/`

**Verdict**: **Complete** — both family formulas match the LaTeX term-by-term, the
APN property is verified computationally at n=6,8,12, and the n=12 novelty
invariants (N_F) reproduce the paper's Table 3 rows exactly. Both claimed-new APN
functions are already present in VBFCatalog. No paper errors, no reproduction
issues.

---

## Issue Catalog

### Paper Issues
None found.

### Reproduction Issues
None found.

---

## Items reproduced exactly

- **Theorem 3 (Family F1)** — `f = x^{q+1}+x y^q+α y^{q+1}`,
  `g = x^{q²+1}+α x^{q²}y+(1+α)^q x y^{q²}+α y^{q²+1}` (`helpers.jl:34-63`).
  APN verified (`du==2`) for (m=3,k=1), (m=4,k=1), (m=4,k=3). The 3∣m novel case
  (m=3, n=6) is covered.
- **Lemma 1 (i)+(ii)** — α² no-root preserved; `L(x)=x^{q²}+x^q+αx` permutation ⇔
  φ no-root (`theorem3.jl:24-42`). Lemma 1(iii) is a proof step, not separately
  tested (acceptable).
- **Lemma 2 (Williams [30])** — exhaustively verified over `F_{2^m}×F_{2^m}*` for
  m=3,4,5 (`theorem4.jl:38-76`); root-count trichotomy correct.
- **Lemma 3 (i)+(ii)** — `tr_m(1/α²)=tr_m(1)` and Eq.(5) unique solution `(α,1)`
  verified (`theorem4.jl:78-108`); matches paper Eq.(5) exactly.
- **Theorem 4 (Family F2)** — formula exact (`helpers.jl:65-93`); APN verified for
  m=3 (3∣m novel), m=4.
- **Theorem 5** — F1 members 3-to-1 ⇒ Gold-like; F2 members Gold-like but NOT
  3-to-1; verified n=6,8 (n=12 opt-in via `full_search`).
- **Table 1/2 known families (N.1–12)** — reconstructed as representatives in
  `table3.jl` via core constructors + parameter scans.
- **Table 3** — N_F recomputed for all 12 known families and for F1/F2; novelty
  confirmed (F1/F2 attain rows no known family attains).
- **Section 4.1 (n=12)** — independently reran: N_F1 = `[1365, 100100, 140664]`,
  N_F2 = `[1365, 100100, 144198, 192]` — exact match to Table 3.
- **Remark 1** — n=8 CCZ-equivalence to Theorem 1/2 families verified by default;
  n=10 documented as opt-in (CCZ search > 25 CPU-min), honestly disclosed.

## Test results

`julia --project=. papers/2023/Calderini_202306/test/runtests.jl` → **all pass**:
theorem3 16/16, theorem4 20/20, theorem5 21/21, table3 21/21 (78 total).

Independent n=12 check: α=6 found; F1 du=2, N_F1=`[1365,100100,140664]`; F2 du=2,
N_F2=`[1365,100100,144198,192]`; both LUTs byte-identical to catalog entries.

## Catalog status

Both claimed-new functions **present** (no gaps):
- **F1 → `n12_CalderiniLiVilla2023_F1`** — LUT (m=6, k=1, α=6, modulus 67)
  byte-identical to catalog; `du == 2`.
- **F2 → `n12_CalderiniLiVilla2023_F2`** — exact-LUT match; `du == 2`.

## Library-reuse note

No violations. `helpers.jl` is genuinely paper-specific
(`has_no_root_projective`, `find_alpha`, `family_f1_lut`, `family_f2_lut`,
`trim_signature`, thin `paper_banner`), building on core `gf_mul`/`gf_pow`/
`primitive_polynomial`/`SBox`. `theorem4.jl`'s local `trm`/`cube` compute the
F_{2^m} absolute trace / subfield cube-ness of embedded elements — deliberately
distinct from `gf_trace`/`gf_relative_trace`/`gf_is_dth_power`. All spectra/
invariants/equivalence primitives reuse core exports.

**Promote-to-core candidate (minor, optional)**: `has_no_root_projective` (Bluher
projective-polynomial test — existence of roots of `x^{2^k+1}+x+α` over `F_{2^m}`)
is a general finite-field primitive reused across biprojective-APN papers; could be
generalized into `packages/VBF/src/`. Not a reuse violation.
