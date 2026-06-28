# Bracken_200807 — Reproduction Plan

## Paper

Bracken, Byrne, Markin, McGuire (2008).
"New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials."
_Finite Fields and Their Applications_ 14 (2008), 703–714.

## Source material

- `input/bracken_2008_new_families_quadratic_apn_trinomials_multinomials.tex`
- `input/Bracken et al. - 2008 - New families of quadratic ...pdf`

## Theorem numbering

`\newtheorem{lemma}[theorem]{Lemma}` — lemma shares theorem counter.

| Counter | Label | Content |
|---|---|---|
| 1 | thm:family1 | **Theorem 1** — Family 1 APN on GF(2^{2k}) |
| 2 | lem:seventh | **Lemma 2** — seventh-power properties in GF(2^{3k}) |
| 3 | thm:family2 | **Theorem 3** — Family 2 trinomial APN on GF(2^{3k}) |
| 4 | thm:bent    | **Theorem 4** — Tr(f) bent for Family 1 |
| 5 | thm:code-ccz| **Theorem 5** — CCZ ↔ code equivalence |

## Reproduction scope

| Claim | Status |
|---|---|
| Theorem 1 — Family 1 APN on GF(2^{2k}) | exact (n=6 exhaustive; n=10 bounded demo) |
| Lemma 2 — seventh-power properties | exact (computed for k=2,3) |
| Theorem 3 — Family 2 APN on GF(2^{3k}) | exact (n=6 exhaustive; n=12 bounded demo) |
| Theorem 4 — Tr(f) bent for Family 1 | exact (bent_components check, n=6) |
| Theorem 5 Walsh — Walsh spectrum = Gold | exact (n=6) |
| Theorem 5 CCZ — Dillon trinomial CCZ equiv | exact (n=6, are_ccz_equivalent) |
| Theorem 5 — code equiv proof | out of scope (requires Magma) |

## File layout

```
papers/Bracken_200807/
  PLAN.md
  helpers.jl        — LUT builders, field utilities, print helpers
  theorem1.jl       — Theorem 1: Family 1 APN
  theorem3.jl       — Theorem 3: Family 2 APN + Lemma 2 checks
  theorem4.jl       — Theorem 4: Tr(f) bent via bent_components
  theorem5.jl       — Theorem 5: Walsh spectrum + Dillon CCZ checks (n=6)
  report.jl         — paper_report()
  Makefile
  test/
    runtests.jl
    test_theorem1.jl
    test_theorem3.jl
    test_theorem4.jl
    test_theorem5.jl
```

## Key parameters

**Theorem 1, n=6, k=3, s=1** (both odd, gcd=1):
- b = 2 (primitive ω in GF(64); not a cube: ω^{21} ≠ 1)
- c = 4 (= ω^2; c ∉ GF(8) since ord(ω^2)=63 does not divide 7)
- r = Int[] → trinomial; r = [ω^9, 1] → pentanomial (r_i ∈ GF(8))

**Theorem 3, n=6, k=2, s=1** (gcd(1,6)=1; 3∤2; 3|(2+1)):
- u = 2 (primitive in GF(64))
- v = 0 → binomial (CCZ-equiv to Gold x^3 per [Budaghyan-Carlet-Felke-Leander 2006])
- v = ω^{21} ∈ GF(4) → trinomial (new CCZ class, CCZ-equiv to Dillon T2)

## Acceptance criteria

- `make -C papers/Bracken_200807 test` passes (< 2 min)
- `make -C papers/Bracken_200807 report` prints all [OK] checks
- Each theorem file runs standalone
- All expensive runs guarded by `limit` / small n
