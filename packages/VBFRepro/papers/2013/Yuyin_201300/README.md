# Yuyin_201300 — Constructing Differentially 4 Uniform Permutations from Known Ones

Current audit application (2026-10-10, Julia 1.13.1): `make test` and `make report` ran successfully. The suite now passes 157 assertions (including newly added regressions where applicable). VBFRepro retained source/input hashes and logs under `data/repro/runs/Yuyin_201300/` for the recorded runs. The older “no Julia” review below is historical and is superseded by these executions.


**Citation**: Y. Yu, M. Wang, Y. Li, *Constructing Differentially 4 Uniform
Permutations from Known Ones*, Chinese Journal of Electronics 22(3):495–499
(2013).

**Reproduction path**: `packages/VBFRepro/papers/2013/Yuyin_201300/`

**Verdict**: **Mostly complete** — every constant the reproduction asserts is
correct (independently recomputed: 1176, A=54, 30/441/9180, 32385, nl=110,
A=477, A(I)=255, δ=6 for m even), but coverage is narrow: 6 of the paper's 11
formal statements have no implementation and no out-of-scope declaration, the
abstract's headline CCZ-inequivalence conclusion is never asserted, and the
permutation property — the paper's *title* claim — is never checked on any
constructed function.

---

## Issue Catalog

### Paper Issues

1. **Remark 2's ">230 nonzero coefficients" claim is false** (`.tex` l.508).
   The paper states each of the 32385 functions "has more than 230 nonzero
   coefficients". Interpolating the univariate polynomial of all 32385 functions
   over GF(2⁸) with x⁸+x⁴+x³+x²+1 gives a nonzero-coefficient range of
   **[169, 254]**, with **765 of 32385** at ≤ 230 (255 functions with exactly
   169, 510 with exactly 204). Smallest counterexample: (u,v) = (1, 214) =
   (g⁰, g⁸⁵), i.e. v/u a primitive cube root of unity → 169 coefficients, δ=6,
   Tr(u/v)=Tr(v/u)=0. The paper hedges with "according to our observation", but
   the quantified statement is wrong. (Sanity check on the interpolation: I(x)
   interpolates to the single term x²⁵⁴.)

2. **Corollary 2 omits a hypothesis on L₂** (`.tex` l.506). It requires only
   that "L₁ is a permutation", but δ(L₂ ∘ H ∘ L₁) = δ(H) needs L₂ bijective
   too: L₂ ≡ 0 makes (L₂∘I∘L₁)₍u,v₎ constant, hence δ = 2ⁿ for every (u,v),
   independently of the trace condition. The identity at l.504 is fine for any
   L₂; the differential-uniformity conclusion is not.

3. **Remark 1 and Remark 2 read as contradictory** (`.tex` l.423 vs l.508).
   Remark 1 gives nl(I₍₀,ᵥ₎)=112 at m=4; Remark 2 gives nl=110 for the 32385
   functions. Both are true — 32385 = C(255,2) counts only uv≠0, so the u=0
   family is disjoint — but the paper never states that disjointness. Confirmed:
   nl(I₍₀,ᵥ₎)=112 for all 255 v; nl(I₍u,v₎)=110 for all 32385 pairs with uv≠0.

4. **Structural / typographic defects.** Section numbering jumps I → II → III →
   "V. Conclusion" (l.510); section IV does not exist. L.86 writes the Gold
   family as `x^{2^3+1}` where `x^{2^s+1}` is meant. L.96 "designed over
   $\mathbb{F}_{2^{2}}(t \geq 1)$" is garbled (should be F₂^{2t}). L.71
   references `p = 2` with p never introduced. Eq.(4) in the Proposition 1 proof
   (l.202) writes `Δ_G` where the argument needs `Δ_F`. Lemma 2 is called "this
   proposition" inside its own proof (l.136, l.163). Proposition 3's second
   branch adds `r ≥ 1` (l.354), excluding m=1 without comment — unnecessary,
   since m=1 also gives δ=4 ≤ 4.

### Reproduction Issues

1. **`full_search` is a dead knob.**
   - **Location**: `theorem1.jl:30` (`theorem1_report(io; full_search::Bool = true)`);
     `Makefile:33-36`, `Makefile:55`.
   - **Symptom**: `full_search` is declared but never referenced in the body.
     `make theorem1 full_search=false` runs the identical exhaustive n=4/6/8
     sweep (32385 δ-computations + 9180 LAT computations). `report.jl:18` calls
     `theorem1_report(io)` with no cost bound at all.
   - **Root cause**: the kwarg was added to satisfy the AGENTS.md rule
     "expensive searches must accept explicit limits" but never threaded into
     the loops.
   - **Resolution plan**:
     1. Gate the n=8 Remark 2 block on `full_search`; when false, cap the (u,v)
        sweep (e.g. `max_pairs::Int = 2000`) and skip the per-pair
        `nonlinearity`.
     2. Print which mode ran and the effective pair count, so a bounded run
        cannot be mistaken for an exhaustive one.
     3. Thread `full_search` through `paper_report` in `report.jl:13,18`.
     4. Add one fast-mode test so the bounded path is exercised.

2. **Remark 2 is tagged `[exact]` but three of its four claims are unchecked.**
   - **Location**: `helpers.jl:23` (scope banner); `theorem1.jl:87,101-104`.
   - **Symptom**: `nonlinearity(G)` is called *inside* the `if actual_du == 4`
     branch, so `nl_set == Set([110])` is asserted over 9180 of the 32385
     functions, not all of them. The CCZ-inequivalence conclusion and the
     coefficient-count observation are absent entirely.
   - **Root cause**: the nonlinearity call sits in the wrong branch, and no
     invariant comparison against I is performed.
   - **Resolution plan**:
     1. Move `push!(nl_set, nonlinearity(G))` above the `if actual_du == 4`,
        then assert `nl_set == Set([110])` over all 32385 (verified true).
     2. Add an explicit `print_check` that `nonlinearity(G) != nonlinearity(I)`
        ⟹ not CCZ-equivalent (nonlinearity is a CCZ invariant) — this is the
        abstract's headline claim.
     3. Do **not** implement the ">230 coefficients" check as a passing
        assertion; record Paper Issue 1 instead, or assert the true range
        [169, 254].
     4. Downgrade the banner tag for Remark 2 to `[partial]` until 1–2 land.

3. **`inverse_function_lut` re-implements a VBF core builder.**
   - **Location**: `helpers.jl:39-47`.
   - **Symptom**: hand-rolled loop `lut[1]=0; for x in 1:N-1 lut[x+1]=gf_inv(x,n;modulus)`.
   - **Root cause**: `gf_monomial_lut(n, (1 << n) - 2; modulus)`
     (`finite_field.jl:252`) produces exactly this vector, and
     `gf_inv_zero_safe` (`finite_field.jl:224`) is the elementwise equivalent.
     Neither was used. (`inverse_apn(n)` is correctly unusable here —
     `apn_families.jl:106` rejects even n by design.)
   - **Resolution plan**:
     1. Replace the body with `gf_monomial_lut(n, (1 << n) - 2; modulus = modulus)`.
     2. Keep the named wrapper (it documents Definition 2) but drop the loop.
     3. Update the `# VBF API used:` header at `helpers.jl:6-7`.

4. **`parameter_A` is dead code duplicating the DDT.**
   - **Location**: `helpers.jl:61-78`.
   - **Symptom**: never called anywhere under `packages/VBFRepro/papers/2013/Yuyin_201300/` (only
     `parameter_A_from_ddt` is used, at `proposition1.jl:40`,
     `theorem1.jl:113,116`, `test_proposition1.jl:16`). Re-derives DDT counts in
     an O(2³ⁿ) triple loop.
   - **Root cause**: an early brute-force draft left behind after the DDT
     version was written.
   - **Resolution plan**:
     1. Delete `parameter_A`.
     2. If a cross-check is wanted, keep it as a single test comparing against
        `get(differential_spectrum(F), 4, 0)`.

5. **`parameter_A_from_ddt` re-implements `differential_spectrum`.**
   - **Location**: `helpers.jl:83-95`.
   - **Symptom**: materializes the full 2ⁿ×2ⁿ DDT just to count entries equal
     to 4.
   - **Root cause**: `differential_spectrum` (`differential.jl:62-77`) already
     returns the multiset of DDT entries excluding row a=0 — exactly the
     parameter A of Problem 1 — while streaming one input difference at a time
     (O(2ᴺ) memory instead of O(2²ᴺ)).
   - **Resolution plan**:
     1. Rewrite as `parameter_A(F) = get(differential_spectrum(F), 4, 0)`.
     2. Drop the `ddt` allocation — it matters if A is ever extended to the n=8
        sweep (a 256×256 `Matrix{Int}` per call × 32385).

6. **`i0v_formula` re-implements `gf_inv_zero_safe` twice.**
   - **Location**: `proposition3.jl:21` and `proposition3.jl:26-30`.
   - **Symptom**: `xpv == 0 ? 0 : gf_inv(xpv, n; modulus=mod)`, and the same
     guard around `denom`.
   - **Root cause**: the exported `gf_inv_zero_safe` (`finite_field.jl:224`) was
     not used.
   - **Resolution plan**:
     1. Replace both guards with `gf_inv_zero_safe`.
     2. Add a comment tying the `0⁻¹ = 0` convention to Definition 2 / `.tex`
        l.293.

7. **Six paper statements have no implementation and no out-of-scope
   declaration.**
   - **Location**: no `lemma1.jl` / `lemma2.jl` / `corollary1.jl` / `lemma3.jl`
     / `proposition2.jl` / `corollary2.jl`; scope banner `helpers.jl:18-24`
     lists only 5 items and never mentions the omissions.
   - **Symptom**: a reader diffing the `.tex` against the directory finds
     Lemma 1, Lemma 2, Corollary 1, Lemma 3, Proposition 2 and Corollary 2
     simply absent, with no statement that they were deliberately skipped.
   - **Root cause**: scope was fixed to the three headline results.
   - **Resolution plan** (all cheap; each verified to hold, except the
     Corollary 2 hypothesis gap recorded as Paper Issue 2):
     1. `lemma3.jl`: for n=2,4,6,8 assert `ddt(I)[a+1,b+1] == 4 ⟺ b == gf_inv(a)`,
        and that the root set equals `{0, a, a·g^d, a·g^{2d}}` with
        d=(2^{2m}−1)/3. `g` must be primitive → use `conway_polynomial` at n=8.
     2. `proposition2.jl`: assert `δ(I₍u,v₎) ≤ 6` over all u≠v including
        u=0/v=0, for n=4,6,8. This is what actually pins Proposition 2; today it
        is only implied by the union of `proposition3.jl` and `theorem1.jl`.
     3. `corollary1.jl` (+ Lemma 2): exhaustively at n=4/5, assert
        `|δ(F)−δ(G)| ≤ 4` and `|nl(F)−nl(G)| ≤ 2` for swaps, and `≤2` / `≤1`
        for single-value changes.
     4. `corollary2.jl`: with random invertible affine L₁, L₂ on n=4/6, assert
        the criterion on `L₁(u), L₁(v)`; document in a comment that L₂ must also
        be bijective (Paper Issue 2).
     5. `lemma1.jl` (optional one-liner): `#{x : x²+x=c} > 0 ⟺ gf_trace(c,n)==0`.
     6. Either way, add every skipped item to the scope banner with an explicit
        `[missing]` / `[out of scope]` tag.

8. **The permutation property — the paper's title claim — is never verified on
   any output.**
   - **Location**: `proposition1.jl:23` (input only); `theorem1.jl` and
     `proposition3.jl` contain no `is_permutation` call.
   - **Symptom**: a reproduction of a paper titled "…Differentially 4 Uniform
     **Permutations**…" never checks that a single constructed function is a
     permutation, nor the sentence at `.tex` l.247 ("The above transformation
     will keep its permutation property if the original function is a
     permutation").
   - **Root cause**: treated as self-evident (it is, but it is also free to
     check).
   - **Resolution plan**:
     1. Accumulate an `all_perm` flag over the pair loops in
        `theorem1.jl:43-57,75-92` and `proposition3.jl:48-64`.
     2. Emit it as a `print_check` in each report and in the `report.jl` Summary.

9. **The test suite verifies far less than the reports print.**
   - **Location**: `test/test_proposition1.jl`, `test/test_proposition3.jl`,
     `test/test_theorem1.jl`.
   - **Symptom**: the headline constants appear in the reports but in **no**
     test: 1176 (Problem 1 examples), 32385 / 9180 (Remark 2),
     A(I₍g,g¹²₎) = 477, A(I) = 255, δ=6 for all v at n=8.
     `test_proposition1.jl:19-22` spot-checks 4 swaps out of 2016;
     `test_proposition3.jl:17-20` checks 4 values of v at n=6 and none at n=8.
     A regression in `parameter_A_from_ddt` or in the n=8 sweep would not fail
     `make test`.
   - **Root cause**: tests were scoped to sub-second runtime.
   - **Resolution plan**:
     1. Add the exhaustive n=6 Theorem 1 assertion to `test_theorem1.jl`: 1953
        pairs, 441 with δ=4, 0 mismatches (~0.1 s).
     2. Add `@test parameter_A_from_ddt(G) == 477` and
        `@test parameter_A_from_ddt(I_sbox) == 255` for n=8.
     3. Add the 1176 count as a test (≈2016 DDTs at n=6, seconds), or gate it
        behind an env var.
     4. Add `@test differential_uniformity(inverse_swap(0, v, 8; modulus=conway_polynomial(8))) == 6`
        for a handful of v (Proposition 3 at m=4 is currently untested).

10. **`g = 2` assumed primitive without assertion; sibling files disagree on the
    modulus.**
    - **Location**: `theorem1.jl:66,107-110` uses `conway_polynomial(8)` = 285
      with `g = 2`; `proposition3.jl:40` and `test_proposition3.jl:24` use
      `primitive_polynomial(8)` = 283 for the same field.
    - **Symptom**: Remark 2's example I₍g,g¹²₎ is only meaningful if g is
      primitive. Under `conway_polynomial(8)` it is (ord(2) = 255, checked).
      Under `primitive_polynomial(8)` = x⁸+x⁴+x³+x+1 (the AES polynomial,
      irreducible but **not** primitive) ord(2) = 51, so the same
      `gf_pow(2,12,...)` line copied to the sibling modulus would silently
      compute a meaningless "g¹²".
    - **Root cause**: no assertion links `g = 2` to the modulus in use; no
      comment explains why the two files use different moduli.
    - **Resolution plan**:
      1. Add a `print_check` / `@test` that the multiplicative order of 2 equals
         2ⁿ−1 under the modulus in use, immediately before the I₍g,g¹²₎ block.
      2. Use `conway_polynomial(8)` in `proposition3.jl` too, matching Remark 2
         — or add a comment that nonlinearity is representation-independent so
         the choice there is immaterial.
      3. (Core follow-up, separate task) `PRIMITIVE_POLYNOMIALS[8]` in
         `finite_field.jl:76` is a misnomer; see the Library-reuse note.

11. **Proposition 3 is absent from the Summary and from the saved artifact.**
    - **Location**: `proposition3.jl:34-96` (no return value — the trailing
      `for` loop makes it return `nothing`); `report.jl:18` assigns `r_prop3`
      and never uses it; `report.jl:20-26`, `report.jl:29-39`.
    - **Symptom**: `make report` prints a 5-line Summary with no Proposition 3 /
      Remark 1 entry, and `results/report.toml` persists only Proposition 1 and
      Theorem 1 fields. The other two claim functions return NamedTuples; this
      one does not.
    - **Root cause**: inconsistent return convention across the three claim
      files.
    - **Resolution plan**:
      1. Return `(; formula_ok, du_ok, remark1_ok)` from `proposition3_report`.
      2. Add the matching `print_check` lines to the `report.jl` Summary.
      3. Persist them in `report.toml`.

12. **Inaccurate `# VBF API used:` headers and an optimistic timing claim.**
    - **Location**: `helpers.jl:6-7`, `proposition1.jl:13`, `proposition3.jl:11`,
      `theorem1.jl:13`; `Makefile:48`.
    - **Symptom**: the headers list functions the file does not call
      (`helpers.jl` lists `dillon_apn_permutation`, `differential_uniformity`,
      `nonlinearity`, `gf_mul`, `gf_trace` — it uses none) and omit ones it does
      (`primitive_polynomial`, `ddt`; `is_permutation` and the four `print_*` in
      `proposition1.jl`; `conway_polynomial`, `gf_pow` in `theorem1.jl`).
      `Makefile:48` advertises `theorem1 … ~11s`; the n=8 block alone is
      ≈2.1×10⁹ DDT steps plus 9180 `lat` calls, so this looks understated.
    - **Root cause**: headers drifted after refactoring; the timing was likely
      measured on a smaller scope.
    - **Resolution plan**:
      1. Regenerate the API headers per file.
      2. Re-time `make theorem1` and update `Makefile:48`, or state the timing
         per sub-block.

13. **Test include layout deviates from the reference paper.**
    - **Location**: `test/runtests.jl:4-6` vs each `test_*.jl` doing
      `include(joinpath(@__DIR__, "..", "<claim>.jl"))` *inside* its `@testset`.
    - **Symptom**: `helpers.jl` is evaluated 3× under `make test` (4× under
      `make report`), so every run prints method-overwrite warnings for
      `print_header`, `swap_function`, `inverse_function_lut`, `inverse_swap`,
      `parameter_A`, `parameter_A_from_ddt`.
    - **Root cause**: the reference layout
      (`packages/VBFRepro/papers/2022/Yu_202211d/test/runtests.jl`) hoists all source includes to
      the top of `runtests.jl`.
    - **Resolution plan**:
      1. Move the three source `include`s into `test/runtests.jl` above the test
         file includes.
      2. Strip the `include` lines from the three `test_*.jl` files.

---

## Items reproduced exactly

| Paper item (`.tex` loc.) | Repro file | Independently confirmed |
|---|---|---|
| Table 1, Dillon APN perm on F₂⁶ (l.252-276) | `dillon_apn_permutation()` (VBF `sporadic_apn.jl:7-72`) | LUT matches Table 1 entry-for-entry; is_permutation ✓, δ=2 ✓ |
| Proposition 1: APN swap ⟹ δ(G) ∈ {2,4} (l.182) | `proposition1.jl:31-54` | all 2016 pairs → δ=4, 0 out-of-range |
| Example 1: δ(F₍₀,₁₎)=4, A=54 (l.280) | `proposition1.jl:45-48` | δ=4, A=54 ✓ |
| "1176 examples … i<j" (l.282) + Problem 1 (l.100) | `proposition1.jl:56-57` | 1176 ✓ |
| Definition 2, inverse fn (l.287-291) | `helpers.jl:39-47` | — |
| Proposition 3, Eq.(6) (l.347) | `proposition3.jl:19-32,58` | formula ≡ swap for m=1..4, all v ✓ |
| Proposition 3, Eq.(7) δ=6 iff m even (l.354) | `proposition3.jl:71-79` | m=2→δ=6 ∀v; m=3→δ=4 ∀v; m=4→δ=6 ∀v ✓ |
| Remark 1: nl(I₍₀,ᵥ₎)=112 (m=4), 24 (m=3) (l.423) | `proposition3.jl:87-93` | holds for **all** v (repro samples only v=1) |
| Theorem 1, Eqs.(9)(10) trace criterion (l.431,439) | `theorem1.jl:21-61,68-99` | 0 mismatches at n=2,4,6,8 |
| Remark 2: 32385 pairs, 9180 with δ=4 (l.508) | `theorem1.jl:94-99` | 32385 ✓, 9180 ✓ |
| Remark 2: I₍g,g¹²₎ δ=4, nl=110, A=477; I: nl=112, A=255 (l.508) | `theorem1.jl:106-123` | g¹²=205, δ=4, nl=110, A=477, A(I)=255, nl(I)=112 ✓ |

Field convention is right: `theorem1.jl:66` uses `conway_polynomial(8)` =
`0b100011101` = x⁸+x⁴+x³+x²+1, exactly the primitive polynomial Remark 2 names,
and `g = 2` genuinely has order 255 under it.

## Missing items

Lemma 1 (l.111), Lemma 2 (l.113-126), Corollary 1 (l.165-178), Lemma 3
(l.297-300), Proposition 2 (l.302-312), Corollary 2 (l.506) — see Reproduction
Issue 7. Also: nl over all 32385 rather than 9180, the CCZ-inequivalence
conclusion, the coefficient-count observation (Reproduction Issue 2); the n=7
half of the l.247 remark (verified separately: 0 of 8128 Gold-x³ swaps on F₂⁷
are APN, and 0 of 2016 Dillon swaps on F₂⁶); permutation preservation
(Reproduction Issue 8).

## Test results

**Not executed.** No Julia toolchain exists in this environment
(`make -C packages/VBFRepro/papers/2013/Yuyin_201300 test` → `make: julia: No such file or
directory`; `which julia` empty, no `~/.juliaup`). The paper is exercised by CI
upstream.

In place of running the suite, every asserted value was **independently
recomputed in C** (GF arithmetic, `ddt`, `lat`/WHT and moduli re-implemented to
match `packages/VBF/src`):

```
Proposition 1 (Dillon n=6): delta(F)=2, is_permutation=1
  2016 pairs: delta=2 count=0, delta=4 count=2016, out-of-range=0
  Example 1: delta(F_(0,1))=4, A=54 ; count with delta=4 and A<63 : 1176
Proposition 3: m=1..4 formula_ok=1 ; delta 4/6/4/6 ; nl 0/4/24/112
Theorem 1: n=4 105 pairs/30 delta4 ; n=6 1953/441 ; n=8 32385/9180 ; mismatch=0
  nl over ALL 32385 pairs = 110 ; nl(I)=112 A(I)=255 delta(I)=4
  I_(g,g^12): g=2, g^12=205, delta=4, nl=110, A=477
Lemma 3 (not in repro): iff-holds=1, root-set-holds=1 for n=2,4,6,8
Remark 2 polynomial form: nonzero-coeff range=[169,254], #(<=230)=765
```

Every assertion in `theorem1.jl`, `proposition1.jl`, `proposition3.jl` and the
three test files is therefore expected to **pass** — no wrong constant was found
anywhere in the reproduction.

## Catalog status

**Not applicable — the paper claims no new APN function.** Its subject is
differentially **4**-uniform permutations. Proposition 1 is the only place a new
APN function could arise (δ(G) ∈ {2,4}), and exhaustive checks of the paper's own
test range give **0 of 2016** APN swaps of the Dillon permutation on F₂⁶ and
**0 of 8128** APN swaps of Gold x³ on F₂⁷ — confirming the l.247 remark. The
Dillon permutation itself is already catalogued as `n6_Dillon_permutation`
(`packages/VBFCatalog/data-build/import_known_families.jl:113`, bib key
`Browning_201000`). Bibliography entry `Yuyin_201300` already exists
(`packages/VBFCatalog/data-raw/bibliography.bib:609`).

**No Catalog-gap records emitted.**

## Library-reuse note

Helpers duplicating `VBF` core: `inverse_function_lut` (→ `gf_monomial_lut` /
`gf_inv_zero_safe`), `parameter_A` (→ `differential_spectrum`; also dead code),
`parameter_A_from_ddt` (→ `get(differential_spectrum(F), 4, 0)`), and the
`i0v_formula` zero guards (→ `gf_inv_zero_safe`). See Reproduction Issues 3–6.

Legitimately paper-specific, do not flag: `swap_function`, `inverse_swap`,
`print_header`, the `i0v_formula` body (Eq. 6), `theorem1_predict` (Theorem 1's
criterion).

**Promote-to-core candidate**: LUT → univariate polynomial interpolation over
GF(2ⁿ). VBF has `polynomial_to_lut`, `terms_to_lut`, `evaluate_polynomial` and
`polynomial_terms` (a *string* parser, `univariate.jl:238`) but no inverse
direction. Remark 2's coefficient-count claim (and many other papers'
"polynomial form" statements) needs `lut_to_univariate(s::SBox; modulus)`
returning the 2ⁿ coefficients via `c₀ = F(0)`, `c_k = Σ_{a≠0} F(a)·a^{q−1−k}`,
`c_{q−1} = Σ_a F(a)`. Belongs in
`packages/VBF/src/representations/univariate.jl`, not in `helpers.jl`.

**Adjacent core issue (not caused by this paper)**:
`PRIMITIVE_POLYNOMIALS[8] = 0b100011011` (the AES polynomial,
`finite_field.jl:76`) is irreducible but **not** primitive — ord(2) = 51, not
255 — while the module docstring claims every entry generates the multiplicative
group. All other entries (n = 2…7, 9…16) are genuinely primitive. Worth raising
separately; it also surfaced in the `Tang_201510` review.

## Open questions

1. Should the differentially-4-uniform examples be catalogued at all?
   `literature_sboxes.toml` currently holds 18 *deployed cipher* S-boxes;
   I₍g,g¹²₎ on GF(2⁸) is a research construction. No gap record was emitted —
   confirm whether that file is meant to stay deployment-only.
2. How far should the n=7 half of `.tex` l.247 be reproduced? The paper does not
   say which F₂⁷ APN function it tested; Gold x³ was used above.
3. Is the coefficient-count refutation (Paper Issue 1) in scope? It requires the
   new core primitive above.
