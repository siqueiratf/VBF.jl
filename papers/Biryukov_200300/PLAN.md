# PLAN — Biryukov_200300

Paper: Biryukov, De Cannière, Braeken, Preneel (2003),
"A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms," Eurocrypt 2003.

## Two-sentence context

The paper presents efficient algorithms for deciding linear (LE, O(n³·2ⁿ)) and affine (AE,
O(n³·2²ⁿ)) equivalence of bijective S-boxes, then applies them to AES, Serpent, Khazad, DES,
and other ciphers. VBF.jl already provides these algorithms (`are_linear_equivalent`,
`are_affine_equivalent`, `linear_representative`, `self_affine_equivalences`); this
reproduction verifies the paper's key numerical claims against those implementations.

## Source material

- PDF/TeX: `input/Biryukov et al. - 2003 - ...tex`
- No author artifact (paper_info.txt: "A — no source code released")

## Reproduction scope

| Claim | Status |
|---|---|
| Section 2: LE algorithm is correct (round-trip + rejection) | Exact |
| Section 3.2: linear representative is canonical | Exact |
| Section 3 (AE): affine equivalence detection works | Exact |
| Section 4.1 / Table 3 right: Rijndael S-box has 2040 affine self-equivalences | Exact (expensive, opt-in) |
| Section 5 / Table 3 left: Serpent S-box equivalence pairs | Exact |
| Section 4.2 (non-bijective LE/AE) | Out of scope — VBF has no n→m equivalence API |
| Section 4.3 (almost-equiv) | Out of scope — no API |
| Section 6 (Even-Mansour attack) | Out of scope — algorithmic demo only |
| Section 7 (SPN decomposition bounds / Table 1) | Out of scope — combinatorial counting |
| Khazad P/Q equivalences | Out of scope — not in VBFCatalog |
| DES S-box analysis (6×4-bit, non-bijective) | Out of scope — non-bijective |
| Misty/Kasumi (s=889, s=4599) | Out of scope — 7/9-bit, very expensive |
| Table 2 (complexity benchmarks) | Out of scope — timing only |

## Architecture constraints

- No new math in `packages/VBF`.
- No VBF→VBFCatalog dependency.
- VBFCatalog used only as optional comparison layer.
- Serpent SERPENT_S0..S7 and AES are in catalog — load via `load_literature_sbox`.
- All expensive computations guarded by `full_search` flag.

## File layout

```
papers/Biryukov_200300/
  PLAN.md
  helpers.jl               # S-box loading helpers, print utilities
  section2.jl              # Section 2 — LE algorithm correctness
  section3.jl              # Section 3 — AE algorithm / linear representative
  section4.jl              # Section 4.1 — self-equivalences (Rijndael 2040)
  section5.jl              # Section 5 — cipher applications / Table 3 (Serpent)
  report.jl                # paper_report() entry point
  Makefile
  input/                   # paper PDF + TeX
  results/                 # generated (gitignored)
  test/
    runtests.jl
    test_section2.jl
    test_section3.jl
    test_section4.jl
    test_section5.jl
```

## Makefile targets

- `test` — fast correctness checks (all n≤5 or small examples)
- `report` — all sections fast; Rijndael 2040 shown as bounded/skipped unless `full_search=true`
- `section2`, `section3`, `section4`, `section5` — individual section reports
- `rijndael_2040` — explicit opt-in target to run the expensive AES self-equiv count

## Parameters

- `full_search=false` — set `true` to run the Rijndael 2040 self-equiv count
- `seed=42` — deterministic RNG (not needed here — algorithms are deterministic)

## Implementation phases

1. helpers.jl — load AES + Serpent S-boxes, print utilities
2. section2.jl — LE correctness: linear-equiv pairs agree, non-equiv pairs rejected
3. section3.jl — AE correctness: affine_representative is stable under known transforms
4. section4.jl — self_affine_equivalences(AES) count; fast path reports "2040 expected"
5. section5.jl — Serpent equivalence table (fast); verify all 3 pairs + inverse-equiv pair
6. report.jl — compose paper_report()
7. Test files
8. Makefile

## Acceptance criteria

- `make -C papers/Biryukov_200300 test` passes in under 2 minutes.
- `make -C papers/Biryukov_200300 report` completes without long search.
- `make -C papers/Biryukov_200300 rijndael_2040` returns count = 2040.
- All claims labelled: exact / bounded / out-of-scope.
