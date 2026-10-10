# Gologlu_202503 — Equivalences of Biprojective Almost Perfect Nonlinear Functions

**Paper**: Göloğlu, Kölsch. "Equivalences of biprojective almost perfect nonlinear
functions." *Electronic Journal of Combinatorics*, 2025.

**Reproduction path**: `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/`

**Verdict**: Mostly complete

Mathematically the strongest reproduction in the 2024-2026 set: every claim that could be
independently checked came out exactly as the reproduction says, **including all three "paper
bug" claims**, which were re-derived by hand *and* numerically during this review. The verdict
is not "Complete" only because `make test` / `make report` are **broken by a Makefile path
bug**, this README's paths and commands were stale after the `packages/VBFRepro/src/` reorganisation,
and the catalog gap the previous revision prepared is still open.

> **Environment note** (re-review 2026-08-15, Julia 1.12.6): `make test` **fails as written**
> — confirmed, see Test Results — but the suite itself is sound: run with the project
> corrected it is **210/210 pass in 103 s**. Every numeric claim below was originally derived
> in Python/C and has now been re-verified against the repository's own Julia API.

---

## Paper Issues

All three are confirmed independently — by hand derivation *and* by numerical
counter-example.

### 1. Appendix C — the classical extended Walsh spectrum multiplicity is wrong

- **Location**: Appendix C, the paragraph after Definition C.1.
- **Printed**: `2^{(n+2)/2}` with multiplicity `(2ⁿ−1)·2ⁿ/3`. **Correct**:
  `(2ⁿ−1)·2^{n−2}/3`.
- **Counter-evidence**: the printed multiset sums to `5·2^{n−2}(2ⁿ−1)`, but only
  `2ⁿ(2ⁿ−1) = 4·2^{n−2}(2ⁿ−1)` pairs `(b≠0, a)` exist. At n=12: printed sum **20,966,400**
  versus actual **16,773,120**. Measured spectra: Gold `x³` on `F₂⁶` →
  `{0:1008, 8:2688, 16:336}` (the corrected form predicts 336, the printed one 1344); 𝓕₄ at
  n=12 → `{0:4193280, 64:11182080, 128:1397760}`; the Table 2.1 Gold-even function
  `gold_even(BiField(4), 1, 8)` on `F₂⁸` → `{0:16320, 16:43520, 32:5440}`. All match the
  corrected form, none the printed one. (An earlier revision attributed the `F₂⁸` spectrum to
  an "Example 4.2"; the paper contains no such example — only Theorem 4.2. The numbers are
  correct, the label was not.)
  Cross-confirmed by Taniguchi et al.'s independent statement of the same spectrum in their
  Remark 3.6.2.
- **Impact**: none on Theorem C.3's substance.

### 2. Proof of Theorem 5.1(a),(b) — the printed `L₄` in the `q ↔ q̄` maps is wrong

- **Location**: proof of Theorem 5.1, the paragraph "For functions `F_q, F_{q′}` in the
  families `𝓕₁, 𝓕₂` …".
- **Printed**: `L₄ = x^{q̄}` for 𝓕₁ and `L₄ = x^{q}` for 𝓕₂. **Correct**: `x^{q}` and
  `x^{q²}`.
- **Derivation**, with `M(x,y) = (y^{q̄}, x^{q̄})` and `q q̄ ≡ 1`:
  𝓕₁ `g_q(M) = y^{q+q̄} + x^{q̄}y^{q} + x^{q+q̄} = [g_{q̄}(x,y)]^{q}`;
  𝓕₂ `g_q(M) = x^{q̄}y^{q²} + x^{q²}y^{q̄} = [g_{q̄}(x,y)]^{q²}`.
- **Numerical counter-evidence**: over all `2^{2m}` points, at **m=5 and m=7**, for **every**
  admissible `k`, the printed `L₄` fails and the corrected one holds (20/20 cases).
- **Impact**: none — `F_q ≅ F_{q̄}` still holds.

### 3. Proof of Theorem 5.1(c)(i) — wrong coefficient in the 𝓕₄ map

- **Location**: proof of Theorem 5.1, the "Family 𝓕₄" paragraph.
- **Printed**: `L₄ = (B^Q/a)·x^Q`. **Correct**: `L₄ = (a/B)·x^Q`. (`M₁=M₄=x^{q̄}`, `L₁=x`,
  and the target `a′ = B^{Q+1}/a` are all correct.)
- **Derivation**: `g_{q,a/B}(x^{q̄},y^{q̄}) = x^Q y^{q̄} + (a/B)x^{q̄}y^Q`, while
  `c·x^Q ∘ g′ = c·x^{q̄}y^Q + c(a′/B)^Q x^Q y^{q̄}` (using `Q² ≡ 1`), so `c = a/B` and
  `(a′/B)^Q = B/a ⟺ a′ = B^{Q+1}/a`.
- **Numerical counter-evidence**: at m=6, k=1, over the 252 admissible `(B,a)`, the printed
  `L₄` holds only in the degenerate case `a² = B^{Q+1}` (e.g. B=2, a=22, a′=22) — **1/8** in
  the sample — while `(a/B)` holds **8/8**. The printed `B^Q/a` equals `a′/B`, i.e. the
  *target's* parameters were used.
- **Bonus finding, not in the previous revision**: the paper only checks
  `B^{Q+1}/a ∈ F_Q` and never re-checks `B^{q̄+r̄} ≠ a′^{q̄+1}`. This was verified to hold for
  **252/252** admissible triples at m=6, so the omission is harmless there — worth recording
  as verified rather than assumed.

### 4 and 5. Theorem B.3's `j = 0` target versus Table 2.1's `0 < j < m`; Eq. (A.6) transposition

- As documented in the previous revision. The textual inconsistency is confirmed, but neither
  has mathematical impact.

---

## Reproduction Issues

### 1. Historical `Makefile` root mismatch — resolved by the shared runner

The observation below describes the previous layout. The current Makefile uses
`papers/paper.mk` and selects the root workspace consistently.

      (CONFIRMED BY EXECUTION, 2026-08-15, Julia 1.12.6)

- **Location**: `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/Makefile:4` —
  `ROOT := $(abspath $(MAKEFILE_DIR)/../..)`, consumed by `Makefile:5`
  `JULIA_PROJECT := --project=$(ROOT)`.
- **Observed failure** (exit code 2, 2 s):
  `julia --project=/home/tiago/VBF.jl/papers .../test/runtests.jl` →
  `ERROR: LoadError: ArgumentError: Package VBF not found in current path.`
  `in expression starting at .../test/runtests.jl:2`
- **Symptom**: it resolves to `/home/tiago/VBF.jl/papers`, which has **no `Project.toml`**
  (verified absent), so `--project=$(ROOT)` activates an empty environment and `using VBF`
  cannot resolve from the workspace. The `packages/VBFRepro/src/Manifest.toml` that appears is an empty,
  gitignored by-product of the failing `Pkg.instantiate()` step — not a legitimate separate
  environment. **Verified**: this is the **only** one of **42** paper Makefiles with `../..`;
  the other **41** — including `Beierle_202508/Makefile:4` and `Taniguchi_202501/Makefile:4` —
  use `../../..`. `make report` is broken the same way: `report.jl` includes `helpers.jl`,
  whose line 26 is `using VBF`.
- **Root cause**: the paper directory was moved from `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/` to
  `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/` and the Makefile was not updated.
- **Resolution plan**:
  1. Change line 4 to `ROOT := $(abspath $(MAKEFILE_DIR)/../../..)`.
  2. Re-run `make test` and `make report` and confirm the counts the previous revision quoted
     (12 test sets / 210 assertions / 78 `[PASS]`), which were produced under the old layout.

### 2. Cross-paper duplication of the biprojective primitive, with an *inconsistent packing convention*

- **Location**: `helpers.jl:119-129` (`biproj_eval`), `helpers.jl:143-153` (`bipair_sbox`)
  versus `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl:27` (`biprojective_sbox`).
- **Symptom**: two independent implementations of "evaluate a `(q,r)`-biprojective pair →
  `SBox{2m}`". Worse, they disagree on the identification of `M × M` with `F₂^{2m}`: the 2022
  file packs `x | (y<<m) → f | (g<<m)`; the 2025 file packs `(x<<m) | y → (f<<m) | g`. The
  **existing n=12 catalog entries** (`n12_CalderiniLiVilla2023_F1/F2`) use the
  2022/Calderini convention, so a 𝓕₄ LUT emitted under the 2025 convention would not be
  byte-comparable with its neighbours. They remain CCZ-equivalent, but exact-LUT dedup would
  miss.
- **Root cause**: no core primitive, so each paper rolled its own.
- **Resolution plan**:
  1. **Promote to core**: `biprojective_sbox(m, k, coeff_f, l, coeff_g; modulus, packing = :y_high)`
     in `packages/VBF/src/constructions/`, with the packing convention documented and
     defaulted to the one the catalog already uses.
  2. Rewrite `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl` and
     `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/helpers.jl:143` to call it.
  3. Pin the convention in the 𝓕₄ catalog record below so it matches
     `n12_CalderiniLiVilla2023_*`.
  4. The `D_f^u` / `D_g^u` Lemma-2.1 kernel criterion (`helpers.jl:163-222`) should ride
     along — it is the only thing that makes n=20/28 tractable, and it is fully general.

### 3. `f4_parameters` re-evaluates its inner iterables and materialises the whole product

- **Location**: `helpers.jl:423-430`.
- **Symptom**: `for k = 1:(fld.m-1), B in noncubes(fld), a in kstar(fld)` re-evaluates
  `noncubes(fld)` once per `k` and `kstar(fld)` once per `(k,B)` pair. At m=14
  (`theorem3_3.jl` with `full_search=true`, which calls `f4_parameters(BiField(14))` and then
  uses only `first(ps)`): `kstar` is rebuilt about 65,500 times, each enumerating
  `subfield_elements(14,7)` over 16,384 elements (roughly `10⁹` operations), and the returned
  vector holds about 8.3M triples (roughly 200 MB).
- **Root cause**: a convenience full-enumeration API used where only one element is needed.
- **Resolution plan**:
  1. Hoist `nc = noncubes(fld)` and `ks = kstar(fld)` out of the loop.
  2. Add `f4_first_parameter(fld)` — or make `f4_parameters` lazy / `Channel`-based — and use
     it in `theorem3_3.jl:186-190`, `lemma4_5.jl` and `lemmaA_1.jl`, which all take only the
     first element.

### 4. `centralizer_classes` enumerates `2^{4m}` tuples before the projective filter

- **Location**: `helpers.jl:568` — `for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)`
  then `cs[idx] == 1 || continue`.
- **Symptom**: the docstring promises `1 + 2^m + 2^{2m} + 2^{3m}` candidates, but the loop
  actually visits `2^{4m}` and discards. At m=5 that is 1,048,576 visits for 33,825 useful
  ones (a factor of 31 wasted); `lemmaA_1_report` calls it for many instances.
  `theorem4_8.jl:80` and `theorem5_1.jl:63` have the same pattern.
- **Root cause**: projective normalisation implemented as a filter rather than as the
  generator.
- **Resolution plan**: generate the projective representatives directly — branch on the index
  of the first nonzero coordinate — and reuse them across all four call sites.

### 5. The reuse note overstated the audit

- **Location**: the previous revision's "Library-Reuse Note" — *"No core primitive was
  reimplemented."*
- **Symptom**: true against `VBF` exports, but it missed issue 2 (cross-paper duplication) and
  did not mention `frob` (`helpers.jl:61`), `primitive_element` (`helpers.jl:624`) or
  `prime_factors` (`helpers.jl:591`) — all generic.
- **Resolution plan**: superseded by the Library-Reuse Note below.

---

## Items Reproduced Exactly

| Paper item | Independent result |
|------------|--------------------|
| **Theorem 3.3 (new family 𝓕₄)** | At m=6 (n=12, modulus `primitive_polynomial(6)=67`): 42 non-cubes, `\|K^×\|=7`, **504 admissible (k,B,a)**; **all 504 APN** by the Lemma 2.1 kernel criterion; DDT-confirmed du=2, deg=2 on the full `2¹²` LUT for sampled triples. `test_theorem3_3.jl` asserts exactly 504 ✓ |
| Theorem 3.3 hypotheses necessary | `B` a cube → not APN (6/6); `B^{q+r}=a^{q+1}` (42 such pairs per `k`) → not APN (6/6) ✓ |
| m=2 and m=4 admit no 𝓕₄ | m=2: `B^{q+r}=a^{q+1}=1` always; m=4: `m≢2 (mod 4)` ✓ |
| **Theorem C.3** | n=12: `is_3_to_1` ✓, image size **1366** = `(2¹²−1)/3+1` ✓, extended Walsh spectrum `{0:4193280, 64:11182080, 128:1397760}` = the **corrected** classical multiset ✓ |
| Lemma B.1 | root-free counts **1176** (m=3, k=1,2) and **20400** (m=4, k=1,3) = `(2^m+1)2^m(2^m−1)²/3` ✓ |
| Theorem 5.1(c)(ii)/(iii) at m=6 | 252 admissible `(B,a)` at k=1; every `B′` occurs in one class; max **6** = `m` choices of `a′` per `B` ✓ |
| Theorem 5.1(c) class count | All 252 collapse to **exactly 1 class** under the Theorem 4.8 restricted shape (262,080 projective invertible tuples × 6 twists) — matching `test_theorem5_1.jl`'s `c.classes == 1`, and inside Corollary 5.2's `[1,6]` ✓ |
| Theorem 6.1 necessity control (m=4) | `ZP(k=1,j=2,d=2)` and `F₁(k=3)` have **identical** ortho-derivative fingerprints — necessary for the CCZ-equivalence the reproduction asserts via `are_ccz_equivalent` ✓ |
| Table 2.1 Gold-even reading | PDF p. 5 prints `b = Σ_{i=0}^{k−1} a^{2^i}`; the `.tex` OCR shows `a^{2^2}`. The reproduction's `gold_even` (`helpers.jl:316-322`) follows the PDF ✓ |

## Test Results

Reviewed 2026-08-15 on Julia **1.12.6**, project fully instantiated.

### As written — FAILS

```console
$ make -C packages/VBFRepro/src/202503-gologlu-biprojective-equivalence test
julia --project=/home/tiago/VBF.jl/papers -e 'using Pkg; Pkg.instantiate()'
     Project No packages added to or removed from `~/VBF.jl/packages/VBFRepro/src/Project.toml`
    Manifest No packages added to or removed from `~/VBF.jl/packages/VBFRepro/src/Manifest.toml`
julia --project=/home/tiago/VBF.jl/papers /home/tiago/VBF.jl/packages/VBFRepro/src/202503-gologlu-biprojective-equivalence//test/runtests.jl
ERROR: LoadError: ArgumentError: Package VBF not found in current path.
- Run `import Pkg; Pkg.add("VBF")` to install the VBF package.
in expression starting at /home/tiago/VBF.jl/packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/test/runtests.jl:2
make: *** [Makefile:24: test] Error 1
```

Exit code **2**, wall time 2 s. Root cause: `Makefile:4`
`ROOT := $(abspath $(MAKEFILE_DIR)/../..)` resolves to `/home/tiago/VBF.jl/papers`, which has
**no `Project.toml`** — so `--project=` activates an empty environment. `packages/VBFRepro/src/Manifest.toml`
(empty `[deps]`, gitignored) is a side effect of the failing `Pkg.instantiate()` step, not a
real separate environment. `make report` fails identically: `report.jl` includes `helpers.jl`,
whose line 26 is `using VBF`.

### With the project corrected — PASSES

```console
$ make -C packages/VBFRepro/src/202503-gologlu-biprojective-equivalence test JULIA_PROJECT=--project=/home/tiago/VBF.jl
```

Exit code **0**, wall time **103 s**.

| Testset | Pass | Broken | Fail/Error | Total | Time |
|---|---|---|---|---|---|
| `lemma2_1_test`   | 13 | 0 | 0 | 13 | 1.3 s |
| `lemma3_2_test`   | 12 | 0 | 0 | 12 | 0.4 s |
| `theorem3_3_test` | 22 | 0 | 0 | 22 | 1.2 s |
| `theoremC_3_test` | 21 | 0 | 0 | 21 | 1.8 s |
| `lemma4_5_test`   | 10 | 0 | 0 | 10 | 0.7 s |
| `lemma4_7_test`   | 22 | 0 | 0 | 22 | 1.0 s |
| `lemmaA_1_test`   | 26 | 0 | 0 | 26 | 1.6 s |
| `theorem4_8_test` | 16 | 0 | 0 | 16 | 9.8 s |
| `theorem5_1_test` | 23 | 0 | 0 | 23 | 5.7 s |
| `theorem6_1_test` | 15 | 0 | 0 | 15 | 73.0 s |
| `lemmaB_2_test`   | 14 | 0 | 0 | 14 | 2.0 s |
| `theoremB_3_test` | 16 | 0 | 0 | 16 | 2.2 s |
| **Total (12 testsets)** | **210** | **0** | **0** | **210** | **103 s** |

This confirms the "12 test sets / 210 assertions" the previous revision quoted from the
pre-`packages/VBFRepro/src/` layout. The suite's own assertions now independently confirm all three
paper bugs: `test_theorem5_1.jl:12` `@test !row.paper_map_holds`, `test_theorem5_1.jl:19`
`@test !c.ci_paper_ok`, and `test_theoremC_3.jl:11` `@test r.walsh_matches_paper == 0`.

`make report`'s "78 `[PASS]`" was **not** re-run and remains the only unverified count here.

## Catalog Status — Family 𝓕₄ (Theorem 3.3)

**Status: missing.** `packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml` contains only
`n12_CalderiniLiVilla2023_F1` and `n12_CalderiniLiVilla2023_F2`. The previous revision
prepared a record but the TOML was never updated.

### Catalog-gap record

- **target file**: `packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml`
- **name**: `n12_GologluKolsch2025_F4`
- **n / m**: `12` / `12`
- **is_permutation**: `false` (3-to-1; image size 1366)
- **algebraic_form**: `Bivariate F(x,y) = (x^{q+1} + B*y^{q+1},  x^{qQ}*y + (a/B)*x*y^{qQ})
  over M = GF(2^6), q = 2^k = 2, Q = 2^{m/2} = 8, r = qQ = 16, B = 2 (a non-cube), a = 1 in
  K^x = GF(2^3)^x; modulus x^6+x+1 (=67)`
- **bib_key**: `Gologlu_202503`
- **source**: `Göloğlu & Kölsch, "Equivalences of biprojective almost perfect nonlinear
  functions", Electron. J. Combin. (2025), Theorem 3.3 and Table 2.1 (last row).
  Representative m=6, k=1, B=2, a=1 built by family_f4(BiField(6), 1, 2, 1) then bipair_sbox
  in packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/helpers.jl.`
- **lut**: 4096 entries. **Two candidate encodings — pick the one matching the existing n=12
  entries:**
  - `(x<<6)|y → (f<<6)|g` (this paper's `bipair_sbox`): starts
    `[0, 128, 1024, 1920, 384, 2816, 3392, 1216, 3072, 2304, 3008, 3520, 2176, 1920, 1920, 2944, …]`,
    ends `[…, 3043, 2287, 1012, 1016, 3881, 1573, 4094, 1522]`, **sha256 of the
    comma-space-joined decimal list =
    `ec1425f4303aa1b7c1ef24030c531b0e1bdc8c2870ef8b35cb1e9fd4313a505a`**
  - `x|(y<<6) → f|(g<<6)` (**the convention already used by `n12_CalderiniLiVilla2023_*` —
    recommended**): starts `[0, 1, 8, 15, 3, 22, 59, 40, 24, 18, 54, 58, 17, 15, 15, 23, …]`,
    ends `[…, 2827, 653, 3931, 1755, 355, 2289, 1283, 3223]`, **sha256 =
    `6b0d2363f8278ce0fb2fe4f5dad57d1229769ae90110ffd70474ece0fb24d555`**
- **verified properties** (independent computation, n=12): `differential_uniformity = 2` (full
  `2¹²` DDT), `algebraic_degree = 2`, 3-to-1, image size 1366, extended Walsh spectrum
  `{0:4193280, 64:11182080, 128:1397760}` (classical).
- **equivalence evidence** — ortho-derivative fingerprint (OD differential spectrum + OD Walsh
  spectrum), a sound EA⇒CCZ certificate since all compared functions are quadratic APN:

  𝓕₄ OD-DDT =
  `{0:10284120, 2:4972275, 4:1217160, 6:246393, 8:40320, 10:7560, 12:1386, 14:1134, 16:945, 18:756, 20:693, 22:378}`
  — **distinct from every one of**:
  `n12_CalderiniLiVilla2023_F1`
  `{0:10231011, 2:5093109, 4:1162917, 6:228501, 8:42462, 10:2268, 12:6615, 16:1134, 20:3969, 22:1134}`;
  `n12_CalderiniLiVilla2023_F2`
  `{0:10172943, 2:5089491, 4:1269000, 6:211509, 8:26829, 10:3006, 12:288, 16:18, 18:36}`;
  Gold monomials `x³`/`x²⁰⁴⁹` `{0:9832095, 2:6220305, 6:716625, 8:4095}` and
  `x³³`/`x¹²⁹` `{0:10077795, 2:5225220, 4:1253070, 6:212940, 8:4095}`;
  biprojective Gold (m=6 even form) `{0:9832095, 2:6220305, 6:716625, 8:4095}`;
  Taniguchi (m=6, k=1, d=6)
  `{0:10161144, 2:5117994, 4:1247967, 6:214578, 8:28728, 10:2268, 12:441}`;
  Zhou–Pott (m=6, k=1, j=2, d=2)
  `{0:10120950, 2:5169087, 4:1263276, 6:191835, 8:25452, 10:2268, 12:189, 36:63}`;
  Carlet (m=6, k=1)
  `{0:10278072, 2:4954194, 4:1252503, 6:237384, 8:42462, 10:7938, 20:567}`.
- **caveat for the updater**: the entire 𝓕₄ family collapses to **one** CCZ class at m=6, so
  exactly **one** entry, not 504. The family's exponential growth (Corollary 5.2) only starts
  at m=10 (n=20). Also: `Gologlu_202207`'s families 𝓕₁/𝓕₂ do not exist at m=6 (𝓕₁ needs
  `gcd(3k,6)=1`, 𝓕₂ needs `m` odd), so they are correctly absent from the comparison.

## Library-Reuse Note

- **Flagged duplicate**: reproduction issue 2 — `biproj_eval` / `bipair_sbox` versus
  `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl:biprojective_sbox`, with divergent packing
  conventions.
- **Borderline, not violations**: `gmul` / `gpow` / `ginv` / `gdiv` (`helpers.jl:50-53`);
  `f4star` (`helpers.jl:78-81`, which could use `subfield_elements(m,2)`).
- **Promote-to-core candidates**:
  1. `biprojective_sbox` plus the `D_f^u` Lemma-2.1 kernel APN criterion (issue 2).
  2. `frob(fld, x, e)` = `x^{2^e}` with automatic exponent reduction (`helpers.jl:61`) — core
     has `gf_pow` but no Frobenius helper.
  3. `primitive_element(fld)` (`helpers.jl:624`) — core has `primitive_polynomial` but no
     generator finder.
  4. `extended_walsh_spectrum` (`theoremC_3.jl:52-60`).
  5. `primitive_prime_divisor` (`helpers.jl:615`).

No `VBF` core primitive is reimplemented within the paper directory itself.

## Open Questions

- Which packing convention should the 𝓕₄ catalog entry use — this paper folder's
  `(x<<m)|y`, or the catalog-incumbent `x|(y<<m)`? It affects exact-LUT dedup only.
- The test counts quoted in the previous revision (12 test sets / 210 assertions / 78
  `[PASS]`) were produced under the pre-`packages/VBFRepro/src/` layout and should be regenerated
  after reproduction issue 1 is fixed.
