# PLAN — Gologlu_202207

## Context
Biprojective APN functions paper. Introduces (q,r)-biprojective polynomial pairs
F(x,y) = [f(x,y), g(x,y)] on F_{2^m}×F_{2^m}, proves two infinite families (F1,F2)
and one sporadic function (F3) are APN, shows CCZ-inequivalence via the NF
EA-invariant (= `nonbent_signature` in VBF).

## Source material
- `input/Gologlu_202207.tex` — full paper
- `input/paper_info.txt` — artifact assessment (no code released)

## Reproduction scope
| Claim | Approach |
|---|---|
| Def III.1 biprojective form | construction in helpers.jl |
| Thm III.2 (F1 APN) | exact: DDT check for small m (3,5,7) |
| Thm III.2 (F2 APN) | exact: DDT check for small odd m (3,5,7) |
| Thm III.2 (F3 APN) | exact: DDT check, m=5 |
| Prop III.4 η_m(NBF) bounds | exact: compute via `nonbent_signature` for m=3,5 |
| Table I (n=10) | exact: `nonbent_signature` for F1,F2,F3,T on F_{2^{10}} |
| Table II (n=14) | opt-in (`full_search=true`): `nonbent_signature` on F_{2^{14}} |
| Prop VI.2 (BHK ⊆ F1) | bounded: EA-equiv check for m=5 |
| Table III (known APN n=10) | exact: load catalog + nonbent_signature |

## File layout
```
helpers.jl            — biprojective_sbox + print helpers
theorem3_2.jl         — F1/F2/F3 constructors + APN verification
proposition3_4.jl     — η_m(NBF) bounds
table1.jl             — NF sequences n=10 (Table I + Table III)
table2.jl             — NF sequences n=14 (Table II, opt-in)
report.jl             — paper_report
Makefile
test/runtests.jl
test/test_theorem3_2.jl
test/test_proposition3_4.jl
test/test_table1.jl
```

## Key math
Biprojective polynomial: `(a0,b0,c0,d0)_q` means
  `f(x,y) = a0·x^{q+1} + b0·x^q·y + c0·x·y^q + d0·y^{q+1}`, q=2^i

Families on F_{2^m}×F_{2^m}:
- F1: [(1,0,1,1)_{2^i}, (1,1,0,1)_{2^{2i}}], gcd(3i,m)=1
- F2: [(1,0,1,1)_{2^i}, (0,1,1,0)_{2^{3i}}], gcd(3i,m)=1, m odd
- F3: [(0,1,1,0)_2, (1,u,u^3,u^13)_{2^3}], m=5, u = primitive element of GF(2^5)

Packing: input = x|(y<<m), output = f(x,y)|(g(x,y)<<m) → SBox{2m}
NF = `nonbent_signature(F)` (Gológlu nonbent signature, already in VBF)

## Acceptance criteria
- `make -C papers/Gologlu_202207 test` passes
- `make -C papers/Gologlu_202207 report` completes ≤ 5 min
- F1,F2,F3 APN verified for m ∈ {3,5}
- Table I NF values match paper for F1,F2,F3 on n=10
- All experiments have explicit limits; n=14 is opt-in
