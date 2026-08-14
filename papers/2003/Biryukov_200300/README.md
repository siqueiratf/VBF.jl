# Biryukov et al. (2003) — A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms

- **Citation:** A. Biryukov, C. De Cannière, A. Braeken, B. Preneel, "A Toolbox for
  Cryptanalysis: Linear and Affine Equivalence Algorithms", *EUROCRYPT 2003*.
- **Reproduction path:** `papers/2003/Biryukov_200300/`
- **Paper source:** `input/Biryukov et al. - 2003 - A Toolbox for Cryptanalysis Linear and Affine Equivalence Algorithms.tex`
- **Verdict:** **Partial** — the equivalence machinery and the Serpent/class-count results are
  correct, but Table 1 is computed with a wrong formula (masked by a tolerance), the headline
  Rijndael 2040-self-equivalence check is a vacuous PASS in the default path, and six sections
  are unreproduced.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Table 1 is misaligned in the source.** The `n` row has 9 entries
   (6, 8, 9, 10, 12, 12, 12, 16, 16) while the `m` / `k` / `l` rows have 8. The repo's reading
   — drop the trailing `n=16` column — is **confirmed correct**: once the `1/k!` factor is
   restored (see B-1), all 8 remaining columns reproduce the paper *exactly*.
2. **Table 2 rows are shifted** — the `AE (n−m=3)` row has one fewer body cell than its
   siblings.
3. **Several `\verb` algorithm blocks are OCR-mangled**, e.g.
   `check whether St(x\oplusa) and St{ St) \(x) dinearly equivalent`.

### Reproduction Issues

Defects introduced in our implementation.

#### B-1 — Table 1 SPN-layer bound drops the paper's `1/k!` factor

- **Location:** `section7.jl:108-119`, function `spn_layer_bound`.
- **Symptom:** `tests/test_section7.jl:21-24` (`table1_within_tolerance` loop) **passes**, but
  the computed values are wrong for 5 of 8 columns:

  | (n,m) | paper `l` | repo `l` | with `1/k!` |
  |---|---|---|---|
  | (9,3)  | 43   | **42**   | 43 |
  | (12,3) | 276  | **268**  | 276 |
  | (12,4) | 246  | **242**  | 246 |
  | (12,6) | 75   | **74**   | 75 |
  | (16,4) | 3196 | **3148** | 3196 |

- **Root cause:** the paper's Section 7 displayed formula is
  `(2^m!)^k · ( (1/k!) · (2^m!/|AGL(m,2)|²)^k · |AGL(n,2)| )^{l-1}`.
  Line 110 computes `per_round = agl_order(n) * affine_class_count(m)^k` and omits the `1/k!`
  divisor. The inflated per-round count reaches the target one-to-48 layers early. A 3%
  tolerance then hides the discrepancy, and a comment attributes it to the paper's own
  approximations.
- **Resolution plan:**
  1. Change `section7.jl:110` to
     `per_round = div(agl_order(n) * affine_class_count(m)^k, factorial(big(k)))`.
  2. Replace `table1_within_tolerance` (`section7.jl:138-139`) with exact equality
     `got == paper`; all 8 columns then match.
  3. Delete the misleading comment at `section7.jl:135-137` and the `print_kv "note"` at
     `section7.jl:177-181` that blames the gap on the paper's approximations.
  4. Update `tests/test_section7.jl:16-24` to assert exact equality for all 8 columns.

#### B-2 — `affine_class_count` uses exact values beyond the paper's stated range

- **Location:** `section7.jl:102-105`.
- **Symptom:** no numeric divergence at the tested parameters, but an undocumented deviation
  from the paper's method.
- **Root cause:** the paper's footnote 6 states that exact class counts were used for
  `m ∈ {3,4}` and the approximation `2^m!/|AGL(m,2)|²` for larger `m`. The repo uses exact
  values (via `TABLE5`) for all `m ≤ 5`.
- **Resolution plan:**
  1. Gate the exact branch on `m ≤ 4`.
  2. Note in a comment that `m = 5` (the `n = 10` column) yields 39 either way, so the choice
     is immaterial to Table 1.

#### B-3 — Rijndael 2040 self-equivalences: the algebraic explanation is never evaluated

- **Location:** `section4.jl:20-29` (the `A1 = [a]·Q^i, A2 = A(Q^{-i}·[a]·A^{-1})` explanation
  exists only as a `print_kv` string), `section4.jl:46-51`.
- **Symptom:** in the default path `section4_report` prints `[SKIP]` and `return true` — a
  vacuous PASS. `tests/test_section4.jl:5` then asserts that vacuous `true`.
- **Root cause:** only the expensive exhaustive `self_affine_equivalences(aes)` route is
  implemented (~580 s); the paper's *constructive* explanation, which is cheap, is not.
- **Resolution plan:**
  1. Build `[a]` (the GF(2⁸) multiplication matrix) and `Q` (the squaring matrix) under the
     Rijndael modulus `0x11B`.
  2. For each of the 8 × 255 = 2040 pairs `(i, a)`, construct `A₁, A₂` per eqs (10)/(11) and
     assert `A₂ ∘ S ∘ A₁ == S` pointwise on all 256 inputs.
  3. Assert the 2040 pairs are pairwise distinct — this establishes the count as a *lower
     bound* in seconds, independent of the exhaustive search.
  4. Keep `full_search=true` as the upper-bound confirmation, but make the default path return
     the constructive result instead of `true`.

#### B-4 — Table 3 only partly covered

- **Location:** `section5.jl:25-67`.
- **Symptom:** several Table 3 rows are unchecked: `{S0⁻¹, S1}`; the self-inverse memberships
  `S2 ~ S2⁻¹` and `S3 ~ S3⁻¹` (both independently verified **true**); `{S4⁻¹, S5⁻¹}` (verified
  **true**); and the entire Khazad row `{P, P⁻¹, Q, Q⁻¹}, s = 4`.
- **Root cause:** Khazad's P/Q S-boxes are absent from
  `packages/VBFCatalog/data-raw/literature_sboxes.toml`, which currently holds only AES,
  PRESENT, GIFT, Midori, SKINNY, Piccolo, SERPENT S0–S7, TWINE and KLEIN.
- **Resolution plan:**
  1. Add the four missing Serpent checks to `section5.jl`.
  2. Add Khazad P/Q either to `literature_sboxes.toml` or as paper-local data in `helpers.jl`.
  3. Add the Khazad row assertions (`s = 4`, the four-way equivalence).

#### B-5 — Whole sections unreproduced (currently declared out of scope)

- **Location:** no implementation exists for: Sect. 3.3 (birthday-paradox AE variant);
  Sect. 4.2 (non-bijective extension, including the concrete DES `S₄` self-equivalence, and
  eq. (9) complexity); Sect. 4.3 (almost-equivalence and its `(1−f)^{−const·n}` iteration
  count); Sect. 5.3 (DES 4×4 decomposition); Sect. 6 (generalized Even-Mansour); Table 2
  (complexity table); Table 4 (Misty S7/S9).
- **Symptom:** the reproduction covers roughly half the paper.
- **Root cause:** scope decision; several of these are cheap and were skipped anyway.
- **Resolution plan (ordered by value/cost):**
  1. **DES `S₄` self-equivalence (Sect. 4.2)** — the highest-value missing item: a fully
     specified, small, directly checkable statement (`A = I`, `B` = bit permutation
     `[4,3,2,1]`, `a = 101111₂`, `b = 0110₂`).
  2. **Table 2** — pure arithmetic; trivially reproducible.
  3. **Table 4, Misty S7** — 7-bit and computationally feasible (`s = 889 = 7×127`); S9
     (`s = 4599 = 9×511`) is the harder case.
  4. Remaining sections: record an explicit, unit-bearing reason for each skip rather than a
     bare "out of scope".

#### B-6 — Structural nits

- **Location:** `Makefile:14` (test directory), `helpers.jl:36-56` (`print_header`).
- **Symptom:** this paper uses `tests/` while `Budaghyan_200506`, `Bracken_200807` and
  `Brinkmann_200812` all use `test/` per the skill template; and `print_header` is hand-rolled
  where the other three use the exported `print_banner`.
- **Root cause:** drift from the repo template.
- **Resolution plan:**
  1. Rename `tests/` → `test/` and update `Makefile:14`.
  2. Replace `helpers.jl:36-56` with `print_banner(io, title, subtitle)`.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| Table 3 (Serpent), 3 equivalent pairs {S2,S6}, {S3,S7}, {S4,S5} | `section5.jl:25-35` | Confirmed by brute force over AGL(4,2) |
| Table 3, inverse pair {S0, S1⁻¹}; S0 ≁ S1 | `section5.jl:38-46` | Confirmed |
| Table 3 `s` column: S0,S1,S2,S6 → 4; S3,S4,S5,S7 → 1 | `tests/test_section5.jl:32-39` | Confirmed exactly (322 560 affine maps enumerated per S-box) |
| Table 5, n=1,2,3 class counts (2,1), (2,1), (10,4) | `section7.jl:30-36,78-85` | n=3 confirmed by union-find orbit count over Sym(8) under GL(3,2)² and AGL(3,2)²: 10 linear / 4 affine |
| Table 1 columns (6,3,2,8), (8,4,2,20), (10,5,2,39) | `section7.jl:124-133` | Confirmed (the other 5 columns are wrong — see B-1) |
| Sect. 2/3 LE & AE decision procedures | delegated to `are_linear_equivalent`, `linear_representative`, `affine_representative` | Core is a faithful — and better, 2ⁿ rather than 2²ⁿ — implementation of Sect. 3.2 |

---

## Test results

`make -C papers/2003/Biryukov_200300 test` → **could not run**: `make: julia: No such file or
directory`. No Julia toolchain exists in the review environment (`find / -name julia*` returns
nothing).

All figures above come from independent re-derivation. Note that the Table 1 test currently
**passes while producing wrong values** (B-1).

---

## Catalog status

Not applicable — this paper makes no APN claims.

---

## Library-reuse note

| Helper | Line | Verdict |
|---|---|---|
| `load_aes_sbox` / `load_aes_inv_sbox` / `load_serpent_sboxes` | `helpers.jl:15-34` | Thin wrappers over `load_literature_sbox`. Acceptable, low value |
| `print_header` | `helpers.jl:36-56` | **Duplicates** the exported `print_banner`. Fix target: `print_banner(io, title, subtitle)` |
| `agl_order` | `section7.jl:92-98` | Generic `|AGL(n,2)|`; no core equivalent. **Promote-to-core candidate** (`packages/VBF/src/linalg/`, alongside a `gl_order`) |
| Heap's-algorithm enumeration + representative bucketing | `section7.jl:40-85` | Legitimately paper-specific (Appendix C). A generic `linear_equivalence_class_count(n)` / `affine_equivalence_class_count(n)` would be a reasonable core promotion |

**Attribution note (core, not this paper folder):**
`packages/VBF/src/equivalence/linear/canonical_representative.jl:1-26` credits only Stennes /
sboxU (`@cite Perrin_202500`), yet the algorithm's `D_A/C_A/N_A/U_A` set structure and the
lexicographic-representative definition are verbatim Biryukov et al. Sect. 3.2. Consider
adding `@cite Biryukov_200300`.
