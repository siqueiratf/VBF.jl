# PLAN — Li & Wang (2014)

**Paper:** "Constructing Differentially 4-Uniform Permutations over GF(2^{2m}) from
Quadratic APN Permutations over GF(2^{2m+1})"
Designs, Codes and Cryptography 72:249–264, 2014.
Authors: Yongqiang Li, Mingsheng Wang.

## Source material

- `input/Li_201408.tex` — full paper (converted)
- `input/paper_info.txt` — reproducibility assessment
- No author artifact released (all computations done in Magma, no scripts provided)

## Paper summary

The paper constructs differentially 4-uniform permutations over GF(2^n) (n even) by
restricting maps built from quadratic APN permutations over GF(2^{n+1}). Key idea:
for F quadratic APN perm over GF(2^{n+1}), define L_u(x) = F(x)+F(x+u)+F(u), whose
image H_u is an n-dimensional subspace. Then F_u = L_u ∘ F^{-1} restricted to H_u is
a differentially 4-uniform permutation over F_2^n (Theorem 2). Specializing to Gold
functions gives concrete constructions with NL = 2^{n-1} - 2^{n/2} and algebraic
degree (n+2)/2 (Theorem 4, Proposition 1). A modification F_u' = F_u + x also has
inverse degree (n+2)/2 (Theorem 5). A non-quadratic source (Budaghyan 2007 AB perm)
gives a third family with degree (n+2)/2 and inverse degree ≤ 7 (Theorem 6).

## Reproduction scope

| Claim | Status | Notes |
|---|---|---|
| Theorem 2 (general construction) | **Exact** | diff-4-uniform perm, n=4,6,8 |
| Theorem 3 (NL = best known) | **Exact** | linearity check n=4,6,8 |
| Theorem 4 (Gold, Walsh spectrum) | **Exact** | Walsh ⊆ {0,±2^{n/2},±2^{(n+2)/2}} |
| Proposition 1 (deg F_u = (n+2)/2) | **Exact** | verified n=4,6,8 |
| Proposition 2 (deg F_u^{-1} ≤ 3) | **Exact** | verified n=4,6 |
| Theorem 5 (F_u', deg of inverse) | **Exact** | verified n=4,6,8 |
| Theorem 6 (Budaghyan source) | **Exact** | n=8 (m=9), i=1 |
| Remark 2 (deg F'^{-1}=5, m=9) | **Exact** | computational, fast |
| Remark 3, n=4 CCZ check | **Exact** | i=1,2 CCZ-equivalent |
| Remark 3, n=8 Walsh spectrum | **Exact** | {0,±16,±32} for i=1,2,4 |
| Remark 3, n=8 CCZ-inequivalence | **Bounded** | opt-in via `full_search=true` |
| RDF(4) sets (EA-inequivalence) | **Exact** | n=8 i=1, Theorems 5 and 6 |

## Architecture

- `helpers.jl` — `gf_trace`, `gf_relative_trace`, `sbox_inverse`, `make_nbit_lut`,
  `build_fu`, `build_fu_prime`, `tr0_subspace`, `rdf_set`, report formatting
- `theorem2.jl` — Theorem 2 (general framework) + Theorem 3 (nonlinearity)
- `theorem4.jl` — Theorem 4 (Gold, Walsh spectrum)
- `proposition1.jl` — Proposition 1 (alg degree of F_u)
- `proposition2.jl` — Proposition 2 (alg degree of F_u^{-1})
- `theorem5.jl` — Theorem 5 (modified F_u', degree of inverse)
- `theorem6.jl` — Theorem 6 (Budaghyan source) + Remark 2 (degree = 5)
- `remark3.jl` — Remark 3 (Walsh spectra, CCZ-inequivalence, RDF sets)
- `report.jl` — `paper_report()` top-level driver
- `Makefile` — targets: test, report, theorem2..6, remark3, clean_results

## Key implementation note

The subspace restriction `make_nbit_lut(G_lut, H_sorted)` is the shared primitive:
given G: GF(2^N)→GF(2^N) and a sorted n-dim subspace H, produce the n-bit LUT by
identifying H with {0,...,2^n-1} via sorted order. Used by all theorem files.

## Acceptance criteria

- `make -C papers/Li_201408 test` passes in under 2 min
- `make -C papers/Li_201408 report` completes without expensive searches
- All claims labeled exact/bounded/not-executed
- RDF sets match paper values for n=8
