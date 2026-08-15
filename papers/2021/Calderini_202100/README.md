# Calderini_202100 — On Known Constructions of APN and AB Functions and Their Relation to Each Other

**Paper**: Calderini, Budaghyan, Carlet. "On known constructions of APN and AB functions and
their relation to each other." 2021.

**Reproduction path**: `papers/2021/Calderini_202100/`

**Verdict**: Mostly complete

Theorem 3.1, Theorem 4.3, Theorem 4.4, Theorem 6.2, Theorem 7.2, Proposition 7.5 and the
Section 7 dimension-6 example are all reproduced, and where feasible they are checked
*exhaustively* rather than by sampling — Theorem 6.2's iff-condition is verified over all
256 `(b,c)` pairs at `m=4` with zero mismatches. The reproduction is honest about what it
skips and it reuses `VBF` core well. The gaps are Theorem 4.1 / Proposition 4.2 (the general
four-parameter form and its reduction), Theorem 5.1's general condition together with
Remark 5.2, and Remark 7.3; plus Proposition 7.5 having no test and a `print_header` symbol
collision that makes include order load-bearing.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Claims marked "independently confirmed" below were re-derived from
> scratch in Python; the expensive sweeps (`section6_1` at n=10/n=12, `theorem7_1_report` at
> m=3) were out of reach and are marked unverifiable here.

---

## Paper Issues

### P1. Theorem 5.1's iff-condition has the inclusion inverted — it should read `α ∉ S`

- **Location**: Section 5, Theorem 5.1 (attributed to [54], Zhou–Pott): "Then
  `F(x,y) = (xy, G(x,y))` is APN if and only if
  `α ∈ {u^{2^i+1}(t^{2^i}+t)^{1−2^j} : u,t ∈ F_{2^m}}`. In particular if `j` is even, then
  `F` is APN if and only if `α` is not a cube."
- **Counter-evidence** (`m = 4`, `i = 1`, modulus `x⁴+x+1`):
  - `S \ {0} = {1, 8, 10, 12, 15}` for `j = 0` and for `j = 2` — exactly the 5 nonzero
    **cubes** of `GF(2⁴)`.
  - The `α` for which `F` is APN are `{2,3,4,5,6,7,9,11,13,14}` — exactly the 10
    **non-cubes**, **disjoint** from `S`.
  - So the literal "iff `α ∈ S`" contradicts the theorem's own "in particular" clause and
    contradicts computation. The correct statement is `α ∉ S`.
  - Consistency check for `j` odd (Remark 5.2): `S \ {0}` is all 15 nonzero elements and
    **no** `α` gives an APN function (`j = 1` and `j = 3`: the APN-`α` list is empty). Under
    the corrected reading `α ∉ S = ∅`, this exactly reproduces Remark 5.2's conclusion "the
    family of Zhou–Pott is not defined then"; under the paper's literal reading it would
    predict that *every* `α` works.
- **Severity**: a real but local typo. The paper's downstream use (Corollary 5.7,
  Section 6.1) relies on the corrected version.

### P2. Section 6.1.3's "second case for `b=0`" is ambiguous or mis-numbered

- **Location**: Section 6.1.3 (`n = 2·6`), case `F₂`: "`k=4, r=2` is equivalent to the second
  case for `b=0`."
- The `b=0` cases listed for `n=12` are, in order: `(h=2,r=4)` "could be inequivalent to the
  known cases", `(h=3,r=0)` "functions as in Theorem 6.2", `(h=5,r=4)` "Taniguchi". The
  reproduction finds empirically (`section6_1.jl:330-343`) that `F₂(k=4,r=2)` matches the
  **first**-listed `b=0` class `F₁(b=0,h=2,r=4)` and **not** the Theorem 6.2 class, and
  documents the discrepancy in-line. This is a genuine ambiguity in the publication.
- **Caveat**: the `n=12` mugshot comparison could not be re-run independently here, so this
  is recorded as reported-by-the-reproduction rather than independently confirmed.

---

## Reproduction Issues

### 1. Theorem 4.1 and Proposition 4.2 are not implemented

- **Location**: `helpers.jl:58-92` implements only the *post*-simplification form.
- **Symptom**: Theorem 4.1 states
  `G(x,y) = s·x^{2^i+2^j} + u·x^{2^i}y^{2^j} + v·x^{2^j}y^{2^i} + t·y^{2^i+2^j}` with the
  condition "`G(X,1) = sX^{2^i+2^j} + uX^{2^i} + vX^{2^j} + t` has no zero in `F_{2^m}`".
  Proposition 4.2 ([51], Taniguchi) reduces this to
  `G′(x,y) = x^{2^k+1} + a·xy^{2^k} + b·y^{2^k+1}` with `k = i−j`, `a ∈ {0,1}`, `b ∈ F₂^*`.
  Only `G′` (`bivariate_carlet_sbox`) exists; the general four-parameter `G` and the
  reduction step are never built or checked.
- **Root cause**: the reduction was taken on faith.
- **Resolution plan**:
  1. Add `theorem4_1_sbox(m,i,j,s,u,v,t)` and `theorem4_1_condition`.
  2. Assert `condition ⟺ du == 2` exhaustively at `m = 3` and `m = 4` over all `(s,u,v,t)`.
  3. Assert every APN `theorem4_1_sbox` mugshot appears among `bivariate_carlet_sbox(m,k,a,b)`
     mugshots (Proposition 4.2).

### 2. Theorem 5.1 is implemented only for `j ∈ {0,2}` and only via its "in particular" clause; Remark 5.2 is unverified

- **Location**: `theorem5_1.jl:41-51`
- **Symptom**: the loop is `for i in is, j in (0, 2)` and the assertion is
  `is_cube == !apn`. The general set `S = {u^{2^i+1}(t^{2^i}+t)^{1−2^j}}` is never built and
  `j` odd is never tested — so Remark 5.2 ("for `j` odd, `S = F_{2^m}` and the family is
  undefined") has no counterpart, and the paper's Theorem-5.1 typo (P1) is silently bypassed
  rather than flagged.
- **Root cause**: implemented from the corollary rather than from the theorem.
- **Resolution plan**:
  1. Add `zhou_pott_condition_set(m,i,j)` returning `S`.
  2. Assert `du == 2 ⟺ α ∉ S` for all `j ∈ 0:(m−1)` at `m = 4` (and `m = 6` behind a flag) —
     this reproduces both Theorem 5.1 (corrected) and Remark 5.2.
  3. Emit a `print_check` recording the paper's inverted-inclusion typo with counter-evidence.

### 3. Remark 7.3 is missing

- **Location**: no file.
- **Symptom**: Remark 7.3 gives an explicit substitution `L(x,y) = (αx, x+y)` (with `α ≠ 0,1`
  and `α^{2^i+1}+α+1 ≠ 0`) showing Göloğlu's `F₂` is EA-equivalent to form (7.1), and that
  `F₁` is of type (7.2). Neither is checked. `theorem7_1.jl` verifies the f1–f4 reduction only
  at `m=3`, where `F₁`/`F₂` do not exist (`gcd(3i,m)=3`).
- **Root cause**: omission.
- **Resolution plan**: add `remark7_3.jl` — build `F₂ ∘ L` at `(m,i)=(5,1)`, divide the
  components by `α^{2^i+1}+α+1` and `α^{2^{3i}}+α`, and assert the result matches the form
  (7.1) coefficient pattern and that its EA-mugshot matches `F₂`'s.

### 4. Proposition 7.5 and Theorem 7.4 have no test coverage and are absent from `report.jl`

- **Location**: `proposition7_5.jl:83-89` (default `skip = true`); `test/runtests.jl` has no
  `test_proposition7_5.jl`; `report.jl:6-16` does not `include` `proposition7_5.jl`.
- **Symptom**: the only way to exercise Proposition 7.5 / Theorem 7.4 is
  `make proposition7_5`. Neither `make test` nor `make report` touches them.
- **Independent verification**: at `(m,i,j) = (5,3,1)`, `F_KL` is APN (`du=2`) and Göloğlu
  `F₂(m=5,i=2)` is APN (`du=2`); applying `L(x,y) = (x^{2^{m−i}}, y)` to `F_KL`'s output gives
  **exact LUT equality** with `F₂(m=5,i=2)`. The claim holds and is provable by LUT identity
  rather than by mugshot comparison.
- **Root cause**: the check was written as an expensive opt-in before the cheap identity was
  found.
- **Resolution plan**:
  1. Add `test/test_proposition7_5.jl` asserting the **exact** identity `L ∘ F_KL == F_{G2}`
     — fast, needing no mugshot and no `skip` flag.
  2. Include `proposition7_5.jl` in `report.jl` with `skip=false`.
  3. Also cover the second parameter family `(m,i) = (7+6l, 5+4l)` — the paper says "follows
     in a similar way", so `l=0 → (m,i)=(7,5)` at `n=14` should at least be attempted behind
     `full_search`.

### 5. `print_header` collision with the Göloğlu reproduction makes include order load-bearing

- **Location**: `theorem7_1.jl:47-48`, `theorem7_2.jl:22-23`, `proposition7_5.jl:23-24` vs.
  `papers/2022/Gologlu_202207/helpers.jl:67`
- **Symptom**: both files define `print_header(io::IO = stdout)` with identical signatures.
  `proposition7_5.jl:23` carries an explicit comment ("Gologlu helpers first: both files
  define print_header and ours must win"). Any reordering silently changes which banner is
  printed, and Julia emits method-redefinition warnings on every run.
- **Root cause**: two paper-local helpers claiming the same global name.
- **Resolution plan**:
  1. Rename to `calderini_print_header` / `gologlu_print_header`, or
  2. Wrap each paper's helpers in a module.

  (Both should in any case delegate to core's `print_banner`.)

### 6. `theorem6_2_sbox` / `theorem6_2_condition` accept invalid parameters

- **Location**: `helpers.jl:214-236` and `:329-345`
- **Symptom**: Theorem 6.2 requires `m` even and `i < m/2` with `gcd(i,m)=1`. The guards exist
  only in `theorem6_2_report` (`theorem6_2.jl:32-34`), not in the builders. With odd `m`,
  `h = m ÷ 2` truncates and produces a meaningless function without error. The same applies to
  `bivariate_carlet_condition` (no `a ∈ {0,1}` check) and `f1_sbox`/`f2_sbox` (no
  `gcd(i,m)=1` check).
- **Root cause**: guards placed at the report layer instead of the construction layer.
- **Resolution plan**: move the parameter guards into the builders in `helpers.jl`.

### 7. Sections 2–3 (the survey half of the paper) are declared out of scope

- **Location**: `helpers.jl:45` — `"[skip] Tables 1-2 (survey content)"`
- **Symptom**: Table 1 (six APN power families) and Table 2 (families F1–F15 with their
  parameter conditions) are the paper's reference lists and are not reproduced. Several are
  already in `VBF` (`gold_apn`, `kasami_apn`, `welch_apn`, `niho_apn`, `inverse_apn`,
  `dobbertin_apn`, `taniguchi_apn`, `bcp_apn`, `bcl_apn`), so a cheap coverage report is
  feasible.
- **Root cause**: scoped out as survey material.
- **Resolution plan**: add `table1.jl`/`table2.jl` instantiating each family at its smallest
  legal parameters, asserting `du == 2`, asserting AB-ness where the paper claims it ("the
  first four cases in Table 1, and for `n` odd all cases in Table 2 are also AB"), and marking
  families with no `VBF` constructor as gaps.

### 8. Section 7's CCZ link to the Edel–Pott function is unverified

- **Location**: `section7_example.jl:97-98`
- **Symptom**: the paper says `F′ = (B, G+f)` is CCZ-equivalent to the Edel–Pott non-quadratic
  APN [39]. The reproduction prints
  `[skip] ... no reference representative available in this repo`. The
  Brinkmann–Leander–Edel–Pott function is written explicitly in the paper (Section 3, the
  `x³ + α¹⁷(x¹⁷+x¹⁸+x²⁰+x²⁴) + …` expression) and would be a valuable `n6_apn.toml` addition.
- **Root cause**: the reference representative was never transcribed.
- **Resolution plan**: transcribe the BLEP function from the LaTeX, verify `du = 2` and
  `deg = 3`, add it to `n6_apn.toml`, then close the CCZ check with `are_ccz_equivalent`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| **Theorem 3.1** (hexanomial APN iff no zero on the unit circle) | Exhaustive over all `(i,c)` at `m=2` (n=4) and `m=3` (n=6): **0 mismatches** between `hexanomial_condition` and `du==2`, matching `theorem3_1_report` |
| **Theorem 4.3** (pentanomial class == hexanomial class) | Same sweep: pentanomial condition ⟺ APN with 0 mismatches; the ortho-derivative EA-class sets of the APN pentanomials and hexanomials are **identical** at `m=2` (1 class) and `m=3` (1 class) |
| **Theorem 4.4** (bivariate Carlet ⊆ hexanomial class) | Bivariate-Carlet APN EA-class set ⊆ hexanomial set at `m=2,3` — in fact **equal** (1 class each). `bivariate_carlet_condition ⟺ du==2` for every `(i,a,b)` tested |
| **Theorem 5.1** (`j` even) | `m=4, i=1, j∈{0,2}`: APN `α` = exactly the 10 non-cubes; `j∈{1,3}`: no APN `α` (see P1) |
| **Theorem 6.2** (new APN family, iff-condition) | **Exhaustive over all 256 `(b,c) ∈ GF(2⁴)²` at `m=4, i=1`: 0 mismatches** between `(cX³+bX²+1)^{2^{m/2}+1}+X^{2^{m/2}+1}` having no zero and `du==2`. Exactly **10** APN pairs: `(1,6),(1,7),(8,4),(8,11),(10,2),(10,14),(12,3),(12,9),(15,5),(15,13)` — matching `theorem6_2_report`'s `apn_count` |
| **Section 6.1.1 new-class claim** | All 10 APN `(b,c)` pairs share **one** ortho-derivative EA-class, distinct from `n8_Gold_x3`, `n8_Gold_x9`, `n8_Kasami_x57`, `n8_Taniguchi2025_ex4_2` — and additionally distinct from all **12** `n=8` Edel–Pott/Weng functions in Budaghyan_202101's Table 1 (i.e. from `[52]`/`[53]`, which the reproduction declares out of scope). This **strengthens** the reproduction's novelty argument |
| **Theorem 7.2** (Göloğlu `F₁`, `F₂`) | `F₁`: `du=2` at `(m,i)=(4,1),(5,1),(5,2),(7,1)` (all `gcd(3i,m)=1`); `du=16` at `(3,1)` where `gcd(3i,m)=3`. `F₂`: `du=2` at `(5,1),(5,2),(7,1)` (`m` odd); `du=32` at `(4,1)` (`m` even); `du=16` at `(3,1)`. Matches the report's probes exactly |
| **Proposition 7.5** | `L(x,y) = (x^{2^{m−i}},y)` applied to `F_KL(m=5,i=3,j=1)` gives an **exact LUT match** with Göloğlu `F₂(m=5,i=2)`; both `du=2` |
| **Section 7 dimension-6 example** | `F=(B,G)`: `du=2`, `deg=2`. `F′=(B,G+f)` with the 27-term `f`: `du=2`, `deg=3`. The `_SECTION7_F_TERMS` transcription is **term-for-term correct** against the LaTeX |
| Theorem 4.3 / 3.1 exact polynomial forms | `hexanomial_sbox` and `pentanomial_sbox` exponent sets match the LaTeX term-for-term |
| Theorem 7.1 / 7.2 / 7.4 biprojective coefficient tuples | `_gologlu_f1 = (1,0,1,1)/(1,1,0,1)`, `_gologlu_f2 = (1,0,1,1)/(0,1,1,0)`, and `kaleyski_li_sbox` `f2 = x^{2^j}y + xy^{2^j}` with `j=1` — all match the LaTeX |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2021/Calderini_202100 test` | **Not run** — `julia` is not installed in the review environment |
| Independent re-derivation of `test_theorem3_1`, `test_theorem4_4` (m=3 parts), `test_theorem5_1`, `test_theorem6_2`, `test_theorem7_2`, `test_section7_example`, Prop. 7.5 | **All pass** |
| `section6_1_n10_sweep`, `section6_1_n12_sweep`, `theorem7_1_report` (`m=3`, 262 144 functions), `theorem5_4_report` | **Unverifiable here** — too expensive to re-derive without Julia |

## Catalog Status

The paper's only new-APN claim is in Section 6, after Theorem 6.2: "for `n=8` the functions
as in Theorem 6.2 can produce a new APN function which is CCZ-inequivalent to the function
given in the tables in [53] and in [52], and in particular which is not included in any of
the known families."

- **`n=8` Theorem 6.2 function**: **present**. Catalog entry `n8_Calderini2021_thm62` in
  `packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml`; its `lut` is **exactly**
  `theorem6_2_sbox(m=4, i=1, b=1, c=6)` under modulus 19 (`x⁴+x+1`), the `(b,c)` pair
  `theorem6_2_report` selects. All 10 APN `(b,c)` pairs at `m=4` fall in this single EA class.
  Novelty evidence: its ortho-derivative fingerprint is distinct from `n8_Gold_x3`,
  `n8_Gold_x9`, `n8_Kasami_x57`, `n8_Taniguchi2025_ex4_2`, and from all 12 `n=8`
  Edel–Pott/Weng entries in Budaghyan Table 1.
  **Full claim reproduced**: formula ✔, APN property ✔, parameter family validated
  exhaustively over `GF(2⁴)²` ✔, novelty checked against Gold/hexanomial/Taniguchi/Zhou-Pott
  *and* against the 12 known `[52]/[53]` `n=8` functions ✔.

- **`n=12` `F₁(b=0, h=2, r=4)` class** (Section 6.1.3, "could be inequivalent to the known
  cases"): **unverifiable** here. The reproduction's `section6_1_n12_sweep` classifies it as
  its own class `:f1_h2r4`, distinct from Gold/hexanomial/Taniguchi/Zhou-Pott/Thm 6.2, but
  this could not be re-derived independently. `n12_apn.toml` currently contains only
  `n12_CalderiniLiVilla2023_F1/F2` (a different, later paper). **Recommendation**: once the
  `n=12` sweep runs under Julia, emit a catalog-gap record for a representative of the
  `f1_h2r4` class — a plausible genuine gap, but not asserted here without evidence.

- **Other constructions in this paper** (hexanomial/pentanomial Thm 3.1/4.3, Zhou–Pott
  Thm 5.1, Taniguchi Thm 5.3, Göloğlu `F₁`/`F₂` Thm 7.2, Kaleyski–Li Thm 7.4) are explicitly
  *known* families, not new-APN claims. No gap records required.

- **Additional gap worth noting** (from Section 3, not a new-APN claim): the
  Brinkmann–Leander–Edel–Pott `n=6` non-quadratic APN function is written explicitly in the
  LaTeX and is the only known APN function CCZ-inequivalent to both quadratic and power
  functions. It is **absent** from `n6_apn.toml` (which has only `n6_Gold_x3`,
  `n6_Kasami_x48`, `n6_Kim`). Adding it would also close issue 8.

## Library-Reuse Note

Correct reuse (no action): `gf_mul`, `gf_pow`, `gf_is_dth_power`, `primitive_polynomial`,
`SBox`, `differential_uniformity`, `algebraic_degree`, `apn_ea_mugshot`, `APNEAMugshot`,
`is_quadratic_apn_rank`, `taniguchi_apn`, `taniguchi_apn_representatives`, `gold_apn`,
`kasami_apn`, `print_banner`/`print_section`/`print_check`/`print_kv`. This reproduction is
the strongest of the 2021 batch at reusing core.

Flags:

| Item | Note |
|------|------|
| `helpers.jl:17` `print_header` | Collides with `papers/2022/Gologlu_202207/helpers.jl:67` — see issue 5. Not a *core* duplication, but a paper-to-paper symbol clash |
| `theorem7_1.jl:47`, `theorem7_2.jl:22`, `proposition7_5.jl:23` | `include` another paper's `helpers.jl` for `biprojective_sbox`. Genuine reuse rather than duplication, but it makes a 2021 reproduction depend on a 2022 one |
| `helpers.jl:58/103/136/189/214/245/278` | Seven near-identical `(x,y) ↦ (xy, G(x,y))` / univariate LUT builders. Internal redundancy only — each corresponds to a distinct paper form, so **not** a core-duplication violation |

Promote-to-core candidates:

- **`biprojective_sbox`** — currently in `papers/2022/Gologlu_202207/helpers.jl:27`, used by
  Calderini_202100 (`theorem7_1`, `theorem7_2`, `proposition7_5`) and Göloğlu_202207.
  Bi-projective polynomials `ax^{q+1}+bx^qy+cxy^q+dy^{q+1}` are a general APN construction
  family; they belong in `packages/VBF/src/constructions/`.
- **`bivariate_sbox(m, f, g)`** — a generic packer for `F(x,y) = (f(x,y), g(x,y))` over
  `GF(2^m)×GF(2^m)` with the `index = x | (y<<m)` convention, hand-rolled seven times in
  `helpers.jl` and again in `theorem5_4.jl:38-53` and `section7_example.jl:57-73`.
- **Zhou–Pott and hexanomial/pentanomial families** — both listed in the paper's Table 2 as
  standard infinite families; they would fit alongside the existing `gold_apn` /
  `taniguchi_apn` / `bcp_apn` / `bcl_apn` constructors.
