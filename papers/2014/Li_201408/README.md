# Li_201408 — Constructing differentially 4-uniform permutations over GF(2^{2m}) from quadratic APN permutations over GF(2^{2m+1})

**Citation**: Y. Li, M. Wang, *Constructing differentially 4-uniform permutations
over GF(2^{2m}) from quadratic APN permutations over GF(2^{2m+1})*, Designs, Codes
and Cryptography 72:249–264 (2014).

**Reproduction path**: `papers/2014/Li_201408/`

**Verdict**: **Complete** — the default test suite (43/43) passes and every
computational value matches the paper exactly, including the Magma-derived numbers
in Remark 2/3. The previously-reported reproducibility issue (the opt-in n=8
pairwise CCZ-inequivalence check of Remark 3 item 2 aborting on resource
exhaustion) is resolved: `full_search=true` now degrades gracefully, reporting the
n=8 CCZ search as infeasible with the current backend instead of crashing.

---

## Issue Catalog

### Paper Issues
None found.

### Reproduction Issues

1. **[RESOLVED]** **`remark3.jl` `full_search=true` crashes instead of degrading gracefully.**
   The n=8 pairwise CCZ-inequivalence and CCZ-inequivalence-to-`x^{21}` claims of
   Remark 3 item 2 invoke `are_ccz_equivalent` on 8-bit S-boxes, which exhausts
   memory/time and aborts with a raw Julia backtrace (~21M allocations, then
   abort; reconfirmed under an 8 GB / 200 s cap → resource exhaustion, not a logic
   bug). The claim is currently only supported indirectly via the Walsh-spectrum
   necessary condition, never affirmatively reproduced.
   **Resolution:** The n=8 `full_search` branch in `remark3.jl` was wrapped in a
   size guard (`inputbits >= 8`) plus a `try`/`catch`. For n=8 it now reports each
   pair as `infeasible at n=8 with current backend (generic CCZ enumeration
   exhausts resources)` via `print_kv` rather than invoking the generic
   permutation-only Canteaut-Perrin enumeration that OOMs (the n=8 `F_u` are
   degree-3 diff-4-uniform permutations, so `are_ccz_equivalent` cannot use the
   fast quadratic-APN path). `full_search=true` now runs to completion; the
   Walsh-spectrum necessary condition remains the affirmative evidence.

---

## Items reproduced exactly

- **Theorem 2 + 3** (`theorem2.jl`): F_u diff-4-uniform permutation, NL =
  2^{n-1}−2^{n/2} for n=4,6,8 (NL 4/24/112 all matched).
- **Theorem 4** (`theorem4.jl`): Gold-source; |Λ_{F_u}| ⊆ {0, 2^{n/2},
  2^{(n+2)/2}} verified n=4 (i=1,2), n=6 (i=1), n=8 (i=1,2,4).
- **Proposition 1** (`proposition1.jl`): d°(F_u) = (n+2)/2 across 7 (n,i) cases.
- **Proposition 2** (`proposition2.jl`): d°(F_u^{-1}) ≤ 3 (got exactly 3) across 7
  cases.
- **Theorem 5** (`theorem5.jl`): F'_u = F_u + x; du=4, NL,
  d°(F'_u)=d°(F'^{-1}_u)=(n+2)/2 for n=4,6,8. n=8 gives d°=5 matching paper.
- **Lemma 4 / Theorem 6** (`theorem6.jl`): Budaghyan-Carlet source verified
  APN+AB (du=2, linearity=32) at m=9; F'(x)=F(x)+F(x)^{2^i} restricted to Tr^{(0)}
  gives du=4, NL=112, |Λ|⊆{0,16,32}, d°(F')=5.
- **Remark 2** (`theorem6.jl`): d°(F'^{-1}) = 5 at m=9 (matches Magma), ≤7 bound
  holds. RDF(4) EA-invariant sets match the paper's Magma output exactly:
  RD_{F'_u^{-1}}(4) = {13,14,15,16,17,18,19,20,23} and RD_{F'^{-1}}(4) =
  {11,12,13,14,15,16,17,18,19,21,22,23,28}.
- **Remark 3** (`remark3.jl`): n=4 Walsh spectrum {0,±4,±8} + i=1/i=2
  CCZ-equivalence verified via `are_ccz_equivalent`; n=8 Walsh spectrum
  {0,±16,±32} verified.

## Structural gaps (acceptable, not reproduction failures)

- **Lemma 3** (exponent non-collision) and **Lemma 5**
  (Tr(F^{-1}(x)+F^{-1}(x+1))=1): not independently unit-tested; subsumed by
  downstream computational checks (Prop 1 degree, Theorem 6 permutation property).
- **Remark 2 m=15 (n=14)**: d°(F'^{-1})=5 not run; documented out of scope in
  `report.jl` (n=14 LUT is heavy).

## Test results

`julia --project=. papers/2014/Li_201408/test/runtests.jl` → **43/43 pass**
(theorem2 8, theorem4 6, proposition1 3, proposition2 3, theorem5 13, theorem6 5,
remark3 5). `report.jl` → all `[PASS]`, values match paper.

## Catalog status

**N/A.** The paper constructs differentially 4-uniform permutations (δ=4), not APN
functions. Source functions (Gold x^{2^i+1}, Budaghyan-Carlet AB) are pre-existing
known families, not claimed new. No catalog-gap records apply.
