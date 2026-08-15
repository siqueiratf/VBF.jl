# Kaleyski_202203 — Deciding EA-equivalence via Invariants

**Paper**: Kaleyski. "Deciding EA-equivalence via invariants." *Cryptography and
Communications*, 2022.

**Reproduction path**: `papers/2022/Kaleyski_202203/`

**Verdict**: Partial

Proposition 4's Walsh formula, Proposition 1, Algorithm 1, Algorithm 2 (the `|K|` column of
Table 1) and the odd-`n` triviality claim are reproduced and correct, and the algorithmic
content is properly delegated to `packages/VBF/src/equivalence/ea/` — which is the right
outcome for a paper of this kind. The gaps are in how the claims are *exercised*:
Propositions 1, 2, 6 and 7 are tested only in degenerate instances that cannot discriminate,
Algorithm 3 has a single trivial demo, Table 1 is reproduced for 1 of its 34 rows, and a
hardcoded constant transcribes an error from the paper on a branch that never executes.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. All numeric assertions that do not depend on the imported artifact
> database were re-derived independently in Python and match.

---

## Paper Issues

### P1. Section 5's "Gold-like" partition sizes are wrong

- **Location**: Section 5 — the paper states the Gold-like partition "splits the field into
  three partition classes, of size 1, 70, and 185, respectively" (context: `F_{2^8}`, `k = 4`).
- **Counter-evidence** for `x^3` over `GF(2^8)`:

  ```
  Σ_4 partition, k=4:  bucket sizes [1, 85, 170]   multiplicities {56832, 69120, 196096}
  Σ_3 partition, k=3:  bucket sizes [1, 85, 170]
  Σ_6 partition, k=6:  bucket sizes [1, 85, 170]
  ```

  Computed twice independently — via the Walsh formula of Proposition 4, and by direct
  DDT-convolution enumeration `M_4(0,s) = Σ_a Σ_v DDT[a][v]·DDT[a][v⊕s]`. The value
  `85 = (2^8−1)/3` with `170 = 2·85` is the cube/non-cube split, exactly matching the `n=6`
  case that the paper's own Table 1 corroborates (`[1, 21, 42]`, `21 = 63/3` — reproduced).
- **Note**: `1 + 70 + 185 = 256` as well, so the error is not detectable by a sum check.

### P2. The stated counts of linear permutations are counts of *unordered bases*

- **Location**: Section 5 — "there are 27998208 linear permutations of `F_{2^6}`, and
  132640470466560 linear permutations of `F_{2^8}`".
- **Counter-evidence**: the true values are `|GL(6,2)| = 20 158 709 760` and
  `|GL(8,2)| = 5 348 063 769 211 699 200`. The paper's figures are exactly
  `|GL(6,2)|/6! = 27 998 208` and `|GL(8,2)|/8! = 132 640 470 466 560` — the number of
  unordered bases, off by `n!`.
- **Severity**: low. The figures serve only as a "for comparison" baseline, so the
  qualitative conclusion (that the invariant prunes the search enormously) is unaffected.

### P3. Internal inconsistency in the Section 5 summary

- **Location**: Section 5 — "only the 'Gold-like' partition described above has three
  classes, while all other observed partitions have at least 6 classes" contradicts, two
  paragraphs later, "For odd dimensions (`n=7` and `n=9`) … these always yield a trivial
  partition of `F_{2^n}` into a zero and non-zero elements" — a 2-class partition.
- **Verification**: `x^3`, `x^5` at `n=5` and `x^3`, `x^5`, `x^9` at `n=7` all give
  `[1, 2^n−1]`. Most likely the 21105-function tally covers even `n` only, but the text does
  not say so.

---

## Reproduction Issues

### 1. `section5.jl` hardcodes the paper's wrong `n=8` Gold partition, on a code path that never executes

- **Location**: `section5.jl:126-138`, specifically `expected = [185, 70, 1]` (line 130)
- **Symptom**: the block is guarded by `if 8 in n_values`, but the default is
  `n_values = [5, 6]` (`section5.jl:148`, `report.jl:31`, `Makefile`), and no test file passes
  `8`. The check is dead code. If it *were* run it would emit `[FAIL]` with actual
  `[170, 85, 1]` vs expected `[185, 70, 1]` — but as written the transcription error is
  invisible and paper issue P1 goes undetected.
- **Root cause**: the paper's value was transcribed rather than computed, and the only branch
  that would test it is unreachable by default.
- **Resolution plan**:
  1. Change the constant to the computed truth: `expected = [170, 85, 1]`.
  2. Add `8` to the default `n_values` for the `gold_x3` checks only — `ea_partition(gold_x3(8), 4)`
     is `2^24` work, a few seconds, and does **not** require the catalog.
  3. Add a `print_kv` noting that the paper states `[1, 70, 185]`, recording the discrepancy
     as a paper issue.
  4. Add a companion assertion `sizes == [2*(2^n-1)÷3, (2^n-1)÷3, 1]` for `n ∈ {6, 8, 10}`
     documenting the cube-split structure (`n=6` → `[42,21,1]`, `n=8` → `[170,85,1]`, both
     confirmed).

### 2. Propositions 1 and 2 are tested only with translations, so their actual content is never exercised

- **Location**: `proposition1.jl:32-35` (`G(x) = F(x ⊕ 1) ⊕ 2`) and `proposition1.jl:68-74`
  (`G(x) = F(x ⊕ 1) ⊕ 3`)
- **Symptom**: in both cases the *linear* parts are `L₁ = L₂ = id`. Proposition 1's substance
  is `Σ_k^G(0) = {L₁(s) : s ∈ Σ_k^F(0)}` for a genuinely non-trivial `L₁`, and the whole of
  Section 3 rests on `L₁(K_i) = C_i`. With `L₁ = id` the multiplicity vectors are literally
  identical element-by-element, so `sigma_multiplicities(F) == sigma_multiplicities(G)` is
  trivially true and would pass even if the proposition were false. Likewise
  `proposition2_quadratic_normalization` reduces to `are_ea_equivalent(F, F(x⊕1)⊕3)`, which
  is trivially true for any affine perturbation and says nothing about the existence of `A′`
  with `L₁ ∘ F ∘ L₂ + A′ = G`.
- **Root cause**: the EA-equivalent partner `G` is constructed with constants only.
- **Resolution plan**:
  1. Build `G = L₁ ∘ F ∘ A₂ + A` with `L₁ = random_invertible_linear_map(n)`,
     `A₂ = random_linear_permutation(n) ⊕ c₂`, `A = random_linear_function(n) ⊕ c` — all four
     are VBF exports.
  2. Assert the multiset equality `sigma_multiplicities(F;k) == sigma_multiplicities(G;k)` for
     `k ∈ {2,3,4,6}`.
  3. Additionally assert the *element-wise* Proposition 1 statement:
     `ea_multiplicities(G,k)[L₁(s)+1] == ea_multiplicities(F,k)[s+1]` for all `s` — the form
     Section 3 actually consumes.
  4. For Proposition 2, take `F` quadratic and `A₂` with `c₂ ≠ 0`, then explicitly construct
     `A′ = L₁∘F∘L₂ + G` and `print_check("deg(A′) ≤ 1", algebraic_degree(SBox(A′)) ≤ 1)` —
     that is the proposition's actual claim.
  5. Add the paper's own counterexample showing quadraticity is necessary (see issue 3).

### 3. The `x^15` counterexample to Corollary 3 is not reproduced

- **Location**: absent (it would belong in `proposition1.jl`)
- **Symptom**: the paper's justification that "the condition of the function being quadratic
  is necessary" rests on `F(x) = x^15` vs `G(x) = (x+α)^15` over `F_{2^6}` — 3 vs 5
  multiplicity classes for `Σ_3`. Nothing in the reproduction covers it, so the odd-`k`
  restriction in Proposition 1 is never demonstrated to be real.
- **Root cause**: omission.
- **Resolution plan**: with `α = 2` under `primitive_polynomial(6) = x⁶+x+1`, build `x^15` and
  `(x⊕2)^15`, compute `M_3(0,·)` and count distinct multiplicities. **Verified**: `x^15` → 3
  classes with sizes `[1, 21, 42]`; `(x+α)^15` → 5 classes with sizes `[1, 8, 9, 18, 28]` —
  exactly the paper's claim. Note `ea_multiplicities` rejects odd `k`
  (`packages/VBF/src/equivalence/ea/partition.jl:117`), so either use
  `sigma_multiplicities_vec(F; k=3)` (which handles `k ≥ 2`, and was verified to agree with
  direct enumeration at `k=3`) or relax the core guard.

### 4. Algorithm 3 is reproduced as a single trivial demo; Proposition 7 and the paper's Algorithm 3 are not implemented

- **Location**: `algorithm3.jl:29-77`, `test/test_algorithm3.jl`
- **Symptom**: one hardcoded `A₂` (swap bits 0 and 1), zero affine drift, `c₂ = 0` — the
  easiest possible instance. The paper's Algorithm 3 additionally specifies (a) computing
  domains `D(x)` for **all** `x ∈ F_2^n`, (b) selecting the basis in increasing `#D(x)` order,
  and (c) looping over `c₂ ∈ F_2^n`. VBF's `inner_permutation`
  (`packages/VBF/src/equivalence/ea/inner_permutation.jl`) hardcodes the standard basis
  `b_i = 2^i` and assumes linear drift (`c₂` enumeration lives in `are_ea_equivalent`).
  Neither the divergence nor Proposition 7 / equation (5) is documented or checked, and the
  paper's empirical claim "A large number of the domains end up consisting of three elements …
  we end up with only `3^n` possibilities for `L₂`" is never measured.
- **Root cause**: full delegation to core without reproducing the paper's own algorithm shape
  or its measurements.
- **Resolution plan**:
  1. Add `proposition7_domains(F, G; k=3)` returning `D(x)` for every `x`, implementing
     equation (5) directly.
  2. `print_kv` the domain-size histogram and check the paper's "mostly 3" claim, for `n = 6`
     catalog quadratic APN.
  3. Assert Proposition 7 itself: for a known `L₂`, verify `L₂(x) ∈ D(x)` for all `x`.
  4. Replace the fixed bit-swap with `random_linear_permutation(n)` plus a random *affine*
     drift, and loop `c₂` per the paper.
  5. Document explicitly, in the file header, that core's basis selection differs from
     Algorithm 3's `#D(x)`-ordered choice.

### 5. Proposition 6 (`K` subgroup, `P` coset) is asserted only via `|K|`

- **Location**: `algorithm2.jl:32-64`
- **Symptom**: the file's header comment states Proposition 6, but the code only counts `|K|`
  and `|P|`. The group/coset structure — the whole point of the proposition, since it is what
  makes precomputation possible — is unverified.
- **Root cause**: omission.
- **Resolution plan**:
  1. Closure test: for sampled `L₁, L₂ ∈ K`, verify `L₁ ∘ L₂ ∈ K` and `L₁^{-1} ∈ K` using
     `compose` / `compositional_inverse`.
  2. Coset test: pick any `L ∈ P` and verify `P == {K ∘ L : K ∈ K}` as sets of LUTs, hence
     `|P| = |K|`.
  3. Report `|P| = |K| = 1008` for the `F`/`G` pair already built in `test_algorithm2.jl:21-26`.

### 6. Table 1 is reproduced for 1 row out of 34; Table 2 not at all

- **Location**: `algorithm2.jl:72-98`, `report.jl:42-43`
- **Symptom**: `algorithm2_report` iterates over whatever `list_functions(db; is_apn=true, n=6)`
  returns and spot-checks only Gold `x^3 → 1008` (Table 1 row 1.1). Table 1's `n=6` block has
  14 rows (`1.1, 1.2, 2.1 … 2.12`) with `|K| ∈ {1008, 336, 10, 8, 60, 7, 48}`, and the `n=8`
  block has 20 rows; none is targeted by index. The timing columns and Table 2 are correctly
  declared out-of-scope (`report.jl:42-43`), but the `|K|` column is squarely in scope and
  mostly unreproduced.
- **Root cause**: no mapping from the paper's `[12]` (Yu–Wang–Li switching-class) indexing to
  catalog names.
- **Resolution plan**:
  1. Record the paper's `n=6` `|K|` multiset as a constant
     `TABLE1_N6_K = [1008, 336, 10, 336, 1008, 8, 60, 8, 10, 8, 7, 8, 48]`.
  2. Compute `partition_automorphisms` for every `n=6` quadratic APN in the catalog and
     compare the resulting multiset against it.
  3. Additionally verify the paper's explicit textual example: `F(x) = x^3` → `|K| = 1008` and
     `G(x) = x^3 + α^11 x^6 + α x^9` → `|K| = 336`, both with partition `[1, 21, 42]`.
     **Verified independently** (`α = 2` under `primitive_polynomial(6)`): `G` is APN (DU = 2),
     partition `[1, 21, 42]`, `|K| = 336`; `x^3` gives `|K| = 1008`. This is the paper's own
     demonstration that `|K|` is strictly more discriminating than the bucket sizes, and it is
     currently absent.
  4. If the `[12]` indexing cannot be mapped, record it as an open question rather than
     silently omitting 33 rows.

### 7. `report.jl` runs `k = 6` direct enumeration, which is `O(2^{n(k-1)})`

- **Location**: `report.jl:46` (`k_values = [4, 6]`), consumed by `proposition4.jl:30`
  (`ea_multiplicities(F, k)`)
- **Symptom**: `ea_multiplicities(F, 6)` at `n = 6` is `2^30` recursive leaf calls, run for up
  to three catalog functions. `test/test_proposition4.jl` sensibly uses `k = 4` only, so the
  cost is invisible to `make test` but hits `make report`.
- **Root cause**: `k = 6` added to the default report path without a cost note.
- **Resolution plan**:
  1. Default `k_values = [4]` in `report.jl:46`; gate `k = 6` behind an explicit flag.
  2. Keep the `k = 6` cross-check at `n = 5` only (`2^25`, cheap).
  3. Add a `print_kv` stating the `O(2^{n(k-1)})` cost of the direct side — which is precisely
     the point of Proposition 4.

### 8. Section 5's headline statistics are not reproduced, and their bounded surrogate is not labelled as such

- **Location**: `section5.jl:49-141`
- **Symptom**: the paper reports 21105 functions → 19300 distinct partitions, 18103
  singletons, Gold-like induced by 21 functions, max 22 classes, `n=10` all ten
  infinite-family representatives Gold-like, and three of the five `[1]` functions with
  pairwise-distinct spectra. The reproduction surveys only the handful of `n ∈ {5,6}` catalog
  entries and reports raw counts with no comparison to any paper figure — a header line says
  "(Bounded: catalog functions only)" but no `print_check` ties the survey to a paper claim.
- **Root cause**: the underlying dataset (12923 `F_{2^8}` functions from [1] plus the
  `boolean.h.uib.no` corpus) is not in the repo.
- **Resolution plan**:
  1. State explicitly in the report that the paper's 21105-function census is **out of scope,
     dataset unavailable**, and say so in `report.jl`'s scope block.
  2. Reproduce the two claims that *are* in reach: (a) odd-`n` triviality — already done for
     `n=5`, extend to `n=7` (verified: `x^3`, `x^5`, `x^9` all give `[1, 127]`); (b) `n=10`
     Gold-like for the known infinite families — `ea_partition` at `n=10, k=4` is `2^30`,
     feasible; verify `[1, 341, 682]`.
  3. Add a `print_check` for the paper's arithmetic consistency:
     `19300 − 18103 − 1 = 1196` partitions each occurring 2–11 times must account for
     `21105 − 18103 − 21 = 2981` functions; `2392 ≤ 2981 ≤ 13156` holds.

---

## Items Reproduced Exactly

| Paper item | Reproduction | Independently verified |
|---|---|---|
| Proposition 4, eq. (2): Walsh formula ≡ direct `k`-tuple count | `proposition4.jl:25-39`, `helpers.jl:30-59` | at `n=6`, `k=3` and `k=4`; matches DDT-convolution at `n=8`, `k=4` |
| Proposition 1 (even `k`) / Corollary 3 (quadratic, any `k`) | `proposition1.jl:26-53` | confirmed, but only for translations — see issue 2 |
| Algorithm 1: partition by `Σ_4^F(0)` multiplicities | `algorithm1.jl:27-60`, core `ea_partition` | semantics match `M_k^F(0,s)` exactly |
| Algorithm 1: partition-signature equality is a necessary EA condition | `algorithm1.jl:47-60` | confirmed |
| Gold `x^3`, `n=6`: partition `[1, 21, 42]` | `test_algorithm1.jl:26-28`, `test_section5.jl:7-9` | confirmed |
| Gold `x^3`, `n=5`: trivial partition `[1, 31]` | `test_section5.jl:12-14` | confirmed |
| Table 1, row `n=6`/`1.1`: `\|K\| = 1008` | `algorithm2.jl:91-95`, `test_algorithm2.jl:6` | confirmed by independent backtracking search over `GL(6,2)` |
| Proposition 6 corollary `\|P\| = \|K\| = 1008` for an EA-equivalent pair | `test_algorithm2.jl:21-26` | confirmed |
| Section 5, odd-`n` trivial partitions | `section5.jl:105-112`, `test_section5.jl:17-22` | confirmed for `n=5` and (untested in repo) `n=7` |
| Algorithm 3: recovery of `A₂` from `F ∘ A₂` | `algorithm3.jl:29-77` | structurally correct, but a trivial instance — see issue 4 |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Kaleyski_202203 test` | **Not run** — `julia` is not installed in the review environment |
| Independent re-derivation of every numeric assertion not requiring the artifact database | **All match** |

Note: `test/test_algorithm1.jl:22` and `test/test_proposition4.jl:19` load
`load_sbox(db, "reprs6_1")`, which is **not** in
`packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml` (only `n6_Gold_x3`, `n6_Kasami_x48`,
`n6_Kim`) — it comes from the sboxU import path
(`packages/VBFCatalog/data-build/import_apn_reps.jl:210`). These tests therefore require a
built artifact and are environment-dependent; that dependency is undocumented.

## Catalog Status

The paper introduces **no** new APN functions — it is an algorithms and invariants paper. All
functions it touches (`x^3`, `x^15`, `x^3 + α^11 x^6 + α x^9`, the Yu–Wang–Li `n=6/8`
switching representatives) are pre-existing. **Not applicable — no catalog gap.**

Incidental note for the catalog maintainer: `G(x) = x^3 + α^11 x^6 + α x^9` over `GF(2^6)`
(paper Section 3) is verified APN here (DU = 2, partition `[1,21,42]`, `|K| = 336`) and is not
in `n6_apn.toml`; but it is a long-known `n=6` class and the paper makes no novelty claim, so
no gap record is emitted.

## Library-Reuse Note

Reuse violations:

1. `helpers.jl:30-59` — `sigma_multiplicities_vec` is a **verbatim copy** of the body of core
   `sigma_multiplicities` (`packages/VBF/src/invariants/sigma_multiplicities.jl:38-68`):
   identical `lat` call, identical `Int128` `rowsum` loop, identical `(-1)^{b·s}`
   accumulation, identical `>> (2N)` normalisation. The only difference is the return type
   (`Vector{Int}` vs `Spectrum`) — roughly 30 duplicated lines. **Fix target**: refactor core
   so `sigma_multiplicities` is `Spectrum(sigma_multiplicities_vector(F; k))`, export the
   vector form, and delete the paper-local copy. (The paper genuinely needs the indexed form —
   the multiset is insufficient for Algorithm 1 — so this is a promote-to-core refactor rather
   than a pure deletion.)
2. `helpers.jl:66-69` — `gold_x3(N)` duplicates the core export `gold_apn(n, 1)`
   (`packages/VBF/src/constructions/apn_families.jl:40`), which uses the same
   `gf_monomial_lut(n, 3; modulus=primitive_polynomial(n))` and additionally validates
   `gcd(k,n)=1`. Used in 12 places across `proposition1.jl:31,66`, `algorithm1.jl:75`,
   `algorithm2.jl:92`, `algorithm3.jl:30`, `section5.jl:118,128` and four test files.
   **Fix target**: `gold_apn(N, 1)`.
3. `helpers.jl:14-19` — `print_header` hand-rolls `"=" ^ 72`; core exports
   `print_banner(io, lines...)`. **Fix target**:
   `print_banner(io, "Kaleyski (2022): Deciding EA-equivalence via invariants",
   "Cryptography and Communications, 2021")`.
4. `helpers.jl:72-76` — `apply_linear` is dead code; `grep` finds no call site.

Correctly reused (no action): `ea_partition`, `ea_partition_signature`, `ea_multiplicities`,
`nbuckets`, `EAPartition`, `partition_automorphisms`, `outer_permutations`,
`outer_permutations_all`, `enumerate_bucket_maps`, `inner_permutation`, `are_ea_equivalent`,
`lat`, `gf_monomial_lut`, `SBox`, `print_section`/`print_check`/`print_kv`. This reproduction
is unusual in that virtually the entire algorithmic content already lives in
`packages/VBF/src/equivalence/ea/`.

Promote-to-core candidate:

- Relax `ea_multiplicities`' `iseven(k) && k ≥ 4` guard
  (`packages/VBF/src/equivalence/ea/partition.jl:117`) to `k ≥ 3`. Proposition 1 and Remark 5
  of this paper are explicitly about `Σ_3^F(0)` (the `Π_F^0` multiset), and the `x^15`
  counterexample (issue 3) needs `k = 3`. The recursion itself is already `k`-generic.
