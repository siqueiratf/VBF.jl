# Kaleyski_202203 — Deciding EA-equivalence via Invariants

**Paper**: Kaleyski. "Deciding EA-equivalence via invariants." 2022.

**Reproduction path**: `packages/VBFRepro/src/202203-kaleyski-ea-invariants/`

**Verdict**: Partial

Algorithms 1-3 are structurally faithful and Proposition 4's identity is confirmed
independently. But Propositions 1 and 2 are tested *vacuously* — both EA-partners are built
from constants only, so the linear parts are the identity and the propositions' actual
content is never exercised. Table 1 is reproduced for 1 row of 37. Section 2 has no test file
at all. One test line materialises the whole of `GL(5,2)` (roughly 1 GB), `gold_x3` crashes
for every `n ≥ 9`, and a hard-coded partition constant is both wrong and on a dead code path
— which is why the paper's error in Section 5 stayed invisible.

> Every `|K|`, partition size and Proposition-4 identity below was first re-derived
> independently in Python (with the Section 5 values cross-checked against the paper's PDF as
> well as its `.tex`), and has since been re-confirmed against the repository's own Julia API
> on 2026-08-15 (Julia 1.12.6) — 17 reconciled values, zero disagreements.

---

## Paper Issues

### 1. Section 5's "Gold-like" partition sizes are wrong: `[1, 85, 170]`, not `[1, 70, 185]`

- **Location**: Section 5 — "splits the field into three partition classes, of size 1, 70,
  and 185", in the context of `F_{2^8}` with k=4. The PDF text confirms the `.tex` is
  faithful.
- **Computed counter-evidence** for `x³` over `GF(2⁸)`:

  ```
  Σ₄ partition (k=4): sizes [1, 85, 170], multiplicities {56832, 69120, 196096}
  |K| = 680   ← matches Table 1's n=8 row 1.1 exactly, so the partition itself is right
  ```

  `85 = (2⁸−1)/3` and `170 = 2·85` is the cube / non-cube split, matching the n=6 case
  `[1,21,42]` (`21 = 63/3`), which the paper's own Table 1 corroborates. Note that
  `1+70+185 = 256` as well, so a sum check does not catch the error.

### 2. The "linear permutations" counts are counts of *unordered bases*

- **Location**: Section 5 — "there are 27998208 linear permutations of `F_{2^6}`, and
  132640470466560 linear permutations of `F_{2^8}`".
- **Evidence**: the true values are `|GL(6,2)| = 20,158,709,760` and
  `|GL(8,2)| = 5,348,063,769,211,699,200`. The paper's figures are exactly
  `|GL(6,2)|/6! = 27,998,208` and `|GL(8,2)|/8! = 132,640,470,466,560` — both divisions
  verified exact.
- **Severity**: low; used only as a "for comparison" baseline.

### 3. Internal inconsistency in the Section 5 summary

- **Location**: Section 5.
- **Evidence**: "only the 'Gold-like' partition … has three classes, while all other observed
  partitions have at least 6 classes" contradicts, two paragraphs later, "For odd dimensions
  (n=7 and n=9) … these always yield a trivial partition … into a zero and non-zero
  elements" — a 2-class partition. Verified: all n=5 catalog functions give `[1,31]`. The
  census presumably covers even `n` only, but the text does not say so.

### 4. Table 1's n=6 row 2.9, `|K| = 7`, cannot be reproduced

- **Location**: Table 1, n=6 row 2.9.
- **Computed evidence**: `|K|` (k=4) for every n=6 APN representative in the repository's own
  catalog:

  ```
  reprs6_0  1008 | reprs6_1  336 | reprs6_3  336 | reprs6_6  60 | reprs6_13  48 (deg 3)
  reprs6_2    10 | reprs6_8   10 | reprs6_5,7,9,10,11,12 → 8 each
  ```

  The multiset over the 13 CCZ classes is `{1008, 336, 336, 60, 48, 10, 10, 8×6}`. The
  paper's 14 switching-class rows are `{1008, 1008, 336, 336, 60, 48, 10, 10, 8×5, 7}`.
  Since `|K|` is an EA-invariant and EA = CCZ for the 12 quadratic classes, one of the
  paper's "8"s appears to be printed as "7".
- **Status**: **open question, not a confirmed error.** An alternative reading is that row
  2.9 is a *second EA representative* of the one non-quadratic CCZ class, where EA ⊊ CCZ —
  possible in principle. Settling it needs the Edel–Pott switching-class list.

---

## Reproduction Issues

### 1. `test_algorithm2.jl` materialises the whole of `GL(5,2)` (roughly 1 GB)

- **Location**: `test/test_algorithm2.jl:18` — `auts5 = partition_automorphisms(gold_x3(5), 4)`.
- **Symptom**: at n=5 the partition is trivial (`[1,31]`), so `outer_permutations`
  (`packages/VBF/src/equivalence/ea/outer_permutation.jl:213`) enumerates **every**
  invertible linear map: `31·30·28·24·16 = 9,999,360` results, each a `Vector{UInt8}` of
  length 32 → roughly 0.9 GB of allocation plus an 80 MB pointer array, purely to assert
  `length(auts5) ≥ 1000`. This is the slowest and most memory-hungry line in the whole suite
  and can OOM a constrained CI runner.
- **Root cause**: the degenerate-partition case is enumerated instead of counted; the
  assertion needs only the count.
- **Resolution plan**:
  1. Replace the assertion with the exact closed form
     `@test length(auts5) == prod((1<<5) - (1<<i) for i in 0:4)` — **only if** a counting
     entry point exists.
  2. Otherwise drop the n=5 case and assert the degenerate behaviour on a size-bounded call,
     e.g. add `max_results` to `outer_permutations` and assert it caps.
  3. File a promote-to-core request for `count_partition_automorphisms` (DFS with a counter,
     no materialisation).
  4. Note in the file header that a trivial partition ⇒ `K = GL(n,2)`.

### 2. `gold_x3` is hard-wired to `UInt8`, so every `n ≥ 9` path crashes

- **Location**: `helpers.jl:66-69` — `SBox{N,UInt8}(UInt8.(gf_monomial_lut(N,3)))`.
- **Symptom**: `gold_x3(10)` raises `InexactError` (LUT values reach 1023). This is reachable
  from `section5_survey` (`section5.jl:118`, `gold_x3(n)` for even `n` in `n_values`) and
  from `algorithm1_report` (`algorithm1.jl:75`), both of which take `n_values` from the
  Makefile — and `make section5 n_values=[8,10]` is advertised in the Makefile help. It also
  blocks the paper's own n=10 claim ("only the Gold-like partition for all ten known
  representatives").
- **Root cause**: a fixed storage type chosen to satisfy the `SBox{N,T}` matching in
  `inner_permutation` / `outer_permutations`.
- **Resolution plan**:
  1. Pick `T` from `N` (`UInt8` for `N ≤ 8`, `UInt16` for `N ≤ 16`).
  2. Better: delete `gold_x3` and add a core storage-conversion helper
     `convert_storage(SBox, T)`.
  3. Add a `@test` at n=10 to lock the fix.

### 3. `proposition1.jl` has no test file at all

- **Location**: `test/runtests.jl:5-7` includes the proposition4, algorithm1/2/3 and section5
  tests — there is no `test_proposition1.jl`.
- **Symptom**: Propositions 1, 2 and Corollary 3 — the paper's whole Section 2 — are
  exercised only by the report, never by `make test`.
- **Root cause**: omission.
- **Resolution plan**:
  1. Add `test/test_proposition1.jl` asserting `proposition1_ea_invariance().all_ok` and
     `proposition2_quadratic_normalization().ok`.
  2. Include it from `runtests.jl`.

### 4. Propositions 1 and 2 are tested only with translations, so their content is never exercised

- **Location**: `proposition1.jl:32-35` (`G(x)=F(x⊕1)⊕2`) and `proposition1.jl:68-74`
  (`G(x)=F(x⊕1)⊕3`).
- **Symptom**: in both, the *linear* parts are `L₁ = L₂ = id`. Proposition 1's substance is
  `Σ_k^G(0) = {L₁(s)}` for a non-trivial `L₁`, and all of Section 3 rests on
  `L₁(K_i) = C_i`. With `L₁ = id` the multiplicity *vectors* are literally identical — this
  was verified: the labelled partitions of `F` and `G` coincide — so
  `sigma_multiplicities(F) == sigma_multiplicities(G)` passes even if the proposition were
  false.
- **Root cause**: the EA-partner is built from constants only.
- **Resolution plan**:
  1. Build `G = L₁∘F∘A₂ + A` with `L₁ = random_invertible_linear_map(n)`,
     `A₂ = random_linear_permutation(n) ⊕ c₂` and `A = random_linear_function(n) ⊕ c` — all
     core exports.
  2. Assert the multiset equality for `k ∈ {2,3,4,6}`.
  3. Assert the **elementwise** form
     `ea_multiplicities(G,k)[L₁(s)+1] == ea_multiplicities(F,k)[s+1]`, which is what Section
     3 actually consumes.
  4. For Proposition 2, take `c₂ ≠ 0`, construct `A′ = L₁∘F∘L₂ + G` explicitly and check
     `algebraic_degree(A′) ≤ 1`.

### 5. The `x^15` counterexample to Corollary 3 is missing

- **Location**: absent; it belongs in `proposition1.jl`.
- **Symptom**: the paper's justification that quadraticity is necessary rests on `x^15`
  versus `(x+α)^15` over `F_{2^6}` — 3 versus 5 Σ₃-classes. Nothing covers it, so the odd-`k`
  restriction is never shown to be real.
- **Root cause**: omission.
- **Resolution plan**: with `α=2` under `primitive_polynomial(6)`, **verified**: `x^15` → 3
  classes of sizes `[1,21,42]`; `(x+α)^15` → 5 classes of sizes `[1,8,9,18,28]` — exactly the
  paper's claim, and identical under the Conway modulus. Note that `ea_multiplicities`
  rejects odd `k` (`packages/VBF/src/equivalence/ea/partition.jl:117`), so use
  `sigma_multiplicities(F; k=3)` (which accepts `k ≥ 2`) or relax the core guard.

### 6. Table 1 is reproduced for 1 row out of 37; the Section-3 worked example is missing

- **Location**: `algorithm2.jl:72-98`, `report.jl:42-43`.
- **Symptom**: `algorithm2_report` prints `|K|` for the first 13 rows that
  `list_functions(db; is_apn=true, n=6)` returns — ordered by `id`, so the first 7 are all
  the named `n6_*` entries with `|K| = 1008` — and only spot-checks Gold → 1008. Table 1 has
  14 n=6 rows plus 23 n=8 rows = 37; none is targeted by index. Timing columns and Table 2
  are correctly out of scope, but the `|K|` column is squarely in scope.
- **Root cause**: no mapping from the paper's Edel–Pott [12] switching-class indexing to
  catalog names.
- **Resolution plan**:
  1. Record `TABLE1_N6_K = [1008,336,10,336,1008,8,60,8,10,8,7,8,8,48]` (14 values) and
     compare the *multiset* against `partition_automorphisms` over all 13 n=6 catalog APN
     representatives — **verified** to match except for the single `7` (paper issue 4).
  2. Add the paper's own Section-3 example: `x³` → `[1,21,42]`, `|K| = 1008` versus
     `G(x) = x³ + α¹¹x⁶ + αx⁹` → `[1,21,42]`, `|K| = 336` — **both verified** with `α=2`,
     DU=2, identical under `primitive_polynomial(6)` and Conway.
  3. Add the n=8 Gold row `|K| = 680` — **verified**.
  4. Record the `7` as an open question rather than silently omitting 36 rows.

### 7. `section5.jl` hard-codes the paper's wrong n=8 partition, on a dead code path

- **Location**: `section5.jl:126-138`, `expected = [185, 70, 1]` (line 130).
- **Symptom**: it is guarded by `if 8 in n_values`, but the default is `[5,6]`
  (`section5.jl:148`, `report.jl:31`, and the Makefile) and no test passes 8 — so the branch
  is dead code. If it did run it would print `[FAIL]` with the actual `[170, 85, 1]`; as
  written, paper issue 1 stays invisible.
- **Root cause**: the paper value was transcribed and never computed, and the only branch
  that would test it is unreachable.
- **Resolution plan**:
  1. Set `expected = [170, 85, 1]`.
  2. Include `8` in the default Gold-only checks — `ea_partition(gold_x3(8), 4)` is `2²⁴`,
     seconds, no catalog needed.
  3. `print_kv` the paper's stated `[1,70,185]` and flag the discrepancy.
  4. Add the structural assertion `sizes == [2(2ⁿ−1)/3, (2ⁿ−1)/3, 1]` for `n ∈ {6,8}` — both
     verified.

### 8. `report.jl` runs k=6 direct enumeration — `O(2^{n(k-1)})`

- **Location**: `report.jl:46` (`k_values=[4,6]`), consumed by `proposition4.jl:30`.
- **Symptom**: `ea_multiplicities(F,6)` at n=6 is `2³⁰ ≈ 1.07×10⁹` recursive leaves, run for
  up to three catalog functions per `n`. `test_proposition4.jl` sensibly uses k=4 only, so
  the cost is invisible to `make test` but hits `make report`.
- **Root cause**: k=6 added without a cost note.
- **Resolution plan**:
  1. Default `k_values=[4]`.
  2. Keep the k=6 cross-check at n=5 only (`2²⁰`).
  3. `print_kv` the `O(2^{n(k-1)})` cost — that asymmetry is exactly Proposition 4's point.

### 9. Algorithm 3 is a single trivial demo; Proposition 7 is not implemented

- **Location**: `algorithm3.jl:29-77`, `test/test_algorithm3.jl`.
- **Symptom**: one hard-coded `A₂` (swap bits 0 and 1), zero drift, `c₂=0`. The paper's
  Algorithm 3 additionally specifies (a) computing domains `D(x)` for all `x` via eq. (5),
  (b) ordering the basis by increasing `#D(x)`, and (c) looping over `c₂`. Core's
  `inner_permutation` hard-codes the standard basis and assumes linear drift. Neither the
  divergence nor Proposition 7 is documented or checked, and the paper's measurement ("a
  large number of the domains end up consisting of three elements … only 3ⁿ possibilities")
  is never reproduced.
- **Root cause**: full delegation to core without reproducing the paper's algorithm shape or
  its measurements.
- **Resolution plan**:
  1. Add `proposition7_domains(F,G; k=3)` implementing eq. (5).
  2. Print the domain-size histogram and check the "mostly 3" claim on n=6 catalog
     quadratics.
  3. Assert Proposition 7 itself (`L₂(x) ∈ D(x)` for a known `L₂`).
  4. Replace the bit-swap with `random_linear_permutation(n)` plus a random affine drift, and
     loop `c₂`.
  5. Document the basis-selection divergence in the file header.

### 10. Proposition 6 is asserted only via `|K|`

- **Location**: `algorithm2.jl:32-64` (the header comment cites Proposition 6).
- **Symptom**: only counts are computed; the group/coset structure — the whole point, since
  it is what enables precomputation — is unverified.
- **Root cause**: omission.
- **Resolution plan**:
  1. Closure test on sampled `L₁, L₂ ∈ K` using `compose` / `compositional_inverse` —
     **verified** for `reprs6_5`, `reprs6_9` and `reprs6_12`: the 8 maps are closed under
     composition.
  2. Coset test `P == {K∘L}`.
  3. Report `|P| = |K| = 1008` for the pair already built at `test_algorithm2.jl:21-26`.

### 11. Section 5's headline statistics are not reproduced and the surrogate is unlabelled

- **Location**: `section5.jl:49-141`.
- **Symptom**: the paper reports 21,105 functions → 19,300 distinct partitions, 18,103
  singletons, Gold-like induced by 21, a maximum of 22 classes, n=10 with all ten family
  representatives Gold-like, and 3 of 5 Beierle–Leander functions distinct. The reproduction
  surveys the handful of `n ∈ {5,6}` catalog entries and prints raw counts with no
  `print_check` tying anything to a paper figure.
- **Root cause**: the 12,923-function `F_{2^8}` dataset and the `boolean.h.uib.no` corpus are
  believed absent — though `packages/VBFCatalog/data/catalog.sqlite (dataset beierleleander2022_n8)`
  **does** contain exactly 12,923 members.
- **Resolution plan**:
  1. State explicitly that the 21,105-function census is out of scope.
  2. Reproduce the reachable claims — odd-`n` triviality at n=7 (500 catalog functions) and
     n=10 Gold-like `[1,341,682]`.
  3. Opportunistically survey the 12,923-member corpus (`corpus_function`) for the
     class-count distribution — that *is* the paper's dataset.

---

## Items Reproduced Exactly

- **Proposition 4** (`proposition4.jl:25-39`): `ea_multiplicities(F,k) == sigma_multiplicities_vec(F;k)`.
  Confirmed independently — the Walsh-power formula and direct `(k−1)`-tuple enumeration
  agree elementwise at n=5,6 with k=4.
- **Algorithm 1 / Section 5, Gold-like partition at n=6**: `[1, 21, 42]` ✔
  (`test_algorithm1.jl:32-33`, `test_section5.jl:8-9`).
- **Table 1, n=6 row 1.1**: `|K| = 1008` ✔ — confirmed by an independent backtracking search
  over `GL(6,2)`; group closure also verified.
- **Proposition 6 corollary** `|P| = |K| = 1008` for the EA-equivalent pair used at
  `test_algorithm2.jl:21-26` — confirmed: `G(x) = F(x⊕1)⊕2` induces the *identical labelled*
  partition, so `|P| = |K|`.
- **Section 5 odd-`n` triviality**: all 11 catalog n=5 APN functions give `[1, 31]` ✔.
- **Algorithm 3**'s recovery of a linear inner permutation with zero drift, and the negative
  case, are structurally sound.

## Test Results

Reviewed 2026-08-15 on Julia 1.12.6, project `/home/tiago/VBF.jl` fully instantiated.

```
make -C packages/VBFRepro/src/202203-kaleyski-ea-invariants test
```

**Exit code: 0** — **wall time: 11 s** — **36/36 assertions pass, 0 fail, 0 broken.**

| Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|
| `proposition4_test` | 4 | 0 | 0 | 4 | 2.2 s |
| `algorithm1_test` | 9 | 0 | 0 | 9 | 0.7 s |
| `algorithm2_test` | 6 | 0 | 0 | 6 | 3.8 s |
| `algorithm3_test` | 6 | 0 | 0 | 6 | 0.4 s |
| `section5_test` | 11 | 0 | 0 | 11 | 0.8 s |
| **Total** | **36** | **0** | **0** | **36** | **11 s** |

Peak memory: a re-run instrumented with `Sys.maxrss()` reported **1.70 GiB** peak RSS for the
suite, and `@timed` on `test/test_algorithm2.jl` alone reported **1.38 GiB allocated /
1.54 GiB peak RSS** — entirely attributable to `test/test_algorithm2.jl:18` (see reproduction
issue 1). Timings are load-dependent: the same suite re-run under concurrent load took 21.9 s
wall with `algorithm2_test` at 9.2 s.

All 17 load-bearing values previously derived in Python were re-checked against the
repository's own Julia API: **zero disagreements**.

Separately, `make -C packages/VBFRepro/src/202203-kaleyski-ea-invariants section5 n_values=[8] limit=3` was run and
prints the predicted failure — `[FAIL] Gold x^3 n=8 partition = [185, 70, 1] (paper Section
5)` against the actual `[170, 85, 1]` — while still **exiting 0** (see reproduction issue 7).

## Catalog Status

The paper introduces **no new APN functions** — it is an equivalence-testing method. Every
function it mentions (`x³`, `x⁵`, `x^15`, `x³+α¹¹x⁶+αx⁹`, the Edel–Pott representatives) is
already represented in the catalog (`n6_Gold_x3`, `reprs6_*`, `reprs8_*`).
`x³+α¹¹x⁶+αx⁹` over `GF(2⁶)` was verified APN (DU=2) with `|K| = 336`; it is EA-equivalent to
`reprs6_1` or `reprs6_3` (both `|K|=336`, partition `[1,21,42]`), so it is **present**.

**No catalog gaps.**

## Library-Reuse Note

- **`helpers.jl:30-59` `sigma_multiplicities_vec` duplicates core `sigma_multiplicities`**
  (`packages/VBF/src/invariants/sigma_multiplicities.jl:36-71`). The two bodies are
  line-for-line identical apart from `Spectrum` versus `Vector{Int}` accumulation. Fix
  target: add a `sigma_multiplicities_vector(F;k)` (or a `raw=true` keyword) to core and
  delete the local copy. Alternatively use core `ea_multiplicities` where `k` is even.
- **`helpers.jl:66-69` `gold_x3(N)` duplicates core `gold_apn(n, 1)`**
  (`packages/VBF/src/constructions/apn_families.jl:40-50`, which is
  `SBox(gf_monomial_lut(n, 2^k+1))` — exactly the same LUT). The only difference is `UInt8`
  storage; see reproduction issue 2.
- **`helpers.jl:14-19` `print_header`** hand-rolls a banner → use core `print_banner`.
- `helpers.jl:76` `apply_linear` is `lut[x+1]` — noise; delete.
- Correctly reused: `lat`, `SBox`, `ea_partition`, `ea_partition_signature`, `nbuckets`,
  `ea_multiplicities`, `partition_automorphisms`, `enumerate_bucket_maps`,
  `outer_permutations`, `outer_permutations_all`, `inner_permutation`, `are_ea_equivalent`,
  `load_catalog` / `list_functions` / `load_sbox`.
- **Promote-to-core candidate**: a *counting* variant of `outer_permutations` /
  `partition_automorphisms` (see reproduction issue 1) — the current API can only
  materialise, which makes the degenerate trivial-partition case unusable.

## Open Questions

- Table 1's n=6 row 2.9 `|K| = 7` (paper issue 4) — a typo, or a second EA representative of
  the non-quadratic CCZ class?
- Does the paper's 21,105-function census cover even `n` only (paper issue 3)?
- Should the reproduction consume `packages/VBFCatalog/data/catalog.sqlite (dataset beierleleander2022_n8)`
  (12,923 members = the paper's dataset [1]) for Section 5?
