# Review — Kuznetsov_202606

Paper: "Quadratic APN Functions in Dimension 8 via Gröbner Basis Search in a
Self-Equivalence Subspace" (Kuznetsov, IEEE Trans. Inf. Theory 2026 / arXiv:2606.11967)

## Summary verdict: Partial
Structurally sound (V_A construction, Algorithm 1, Theorem 4 membership, Table II/III
on 6 representatives all reproduced and tested). But the headline claim — Theorem 6:
CLASS-A..D CCZ-inequivalent to the 3.7M Beierle-2025 + 12921 BBL2021 databases — is
NOT computationally reproduced in-repo (Phase 5 not run; Phase 2 Magma Gröbner step not
reproduced). Repo verifies properties of hand-provided representatives, not the search.

## Tests run
`julia --project=. packages/VBFRepro/papers/Kuznetsov_202606/test/runtests.jl` -> ALL PASS
(section4 9/9, algorithm1 8/8, theorem4 28/28, table2 15/15, table3 7/7).

## Reproduced
- Sec IV.A automorphism A = block_diag(C(q),C(q)); A^5=I, A^k!=I (k=1..4).
- Sec IV.B-C M_A/RREF/fc22+sol22: rank(M_A)=184, dim(V_A)=40; samples land in V_A.
- Algorithm 1 (Phase 1) structurally (bounded budget).
- Theorem 4 / Table III membership on 6 reps: A,E,F in V_A; B,C,D outside.
- Property checks: all 6 reps APN (delta=2), degree 2, non-permutation.
- Table II sigma: 6 pairwise-distinct sigmas; sigma(E)=Gold x^3, sigma(F)=Gold x^9.

## Missing / not reproduced
- Phase 2 Gröbner basis slice (Magma) — the step that discovers CLASS-B/C/D.
- Theorem 6 / Table V database NO_MATCH vs Beierle 2025 (3.7M) + BBL2021 (12921).
- Theorem 5 / Table IV comparative experiments (Exp B/C).
- Table II/VI sigma-hash strings (SHA-256 of sigma never computed in repo).
- APN density ~1e-4 (Sec IV.D) not verified at bounded budget.
- E/F=Gold identification uses sigma-equality only, not exact CCZ test.

## Incorrect / suspicious
- Table VII mismatch + paper internal inconsistency (IMPORTANT): repo's 6 reps come
  from the author's artifact ccz_verify_representatives.m, NOT paper Table VII (LUTs
  differ, e.g. CLASS-A Table VII starts 0,0,0,63,... vs repo 0,0,0,50,...). Direct
  check of paper Table VII LUTs: all APN deg 2, BUT contradict Theorem 4/Table III:
  Table VII CLASS-A NOT in V_A (paper says in), Table VII CLASS-B IS in V_A (paper
  says outside); sigma(TableVII A/B/C) != sigma(repo A/B/C); only D matches. Paper's
  printed Table VII appears to have transcription errors. Repo used self-consistent
  artifact instead — defensible but should be documented.
- theorem4.jl non-permutation assertion "!res.perm == !expected_perm[...]" is obfuscated
  (works only because all expected are false).

## Catalog status — WITHDRAWN 2026-08-19

**The four catalog-gap records below are withdrawn. Do not write them.** They are
superseded by `FINDINGS.md` in this same directory, which refutes the paper's central
novelty claim, and by a direct re-check against the current catalog.

The original records were not wrong when written; they went stale. They were written
when `n8_apn.toml` held only `n8_Gold_x3`, `n8_Gold_x9` and `n8_Kasami_x57`, so
"no sigma match to any n=8 catalog entry" was a statement about three functions. The
catalog has since gained the `APN-rep`, `CCZ-rep-GF4`, `known-family` and
`known-sporadic` populations, and every one of the six representatives now matches:

| representative | `classify_ccz` verdict | matches |
|---|---|---|
| CLASS-A | `(:sigma_match, "functions", 566)` | `reprs8_17` (`APN-rep`) |
| CLASS-B | `(:sigma_match, "functions", 553)` | `reprs8_4` (`APN-rep`) |
| CLASS-C | `(:sigma_match, "functions", 586)` | `SimonBerg_GF4_n8_class_5` (`CCZ-rep-GF4`) |
| CLASS-D | `(:sigma_match, "functions", 585)` | `SimonBerg_GF4_n8_class_4` (`CCZ-rep-GF4`) |
| CLASS-E | `(:sigma_match, "functions", 41)` | `n8_Gold_x3` |
| CLASS-F | `(:sigma_match, "functions", 42)` | `n8_Gold_x9` |

Reproduce with `classify_ccz(F)` on `representative_sboxes()` from `helpers.jl`; all six
are `du = 2`, `deg = 2`. No representative returns `:new`. A sigma match is a necessary
condition for CCZ-equivalence and not a decision, so this refutes novelty without
identifying the class; `FINDINGS.md` identifies it, mapping CLASS-A/B/C/D to Edel-Pott
(2009) Table 9 functions 2.1, 1.3, 1.2 and 1.11 by the paper's own published sigma-hashes.

Two further reasons the records must not be written as they stand:

- `bib_key="Kuznetsov_202606"` does not exist. `data-raw/bibliography.bib` has
  `Kuznetsov_202600`. The catalog gate rejects a `bib_key` with no bibliography row.
- The catalog admits a CCZ-duplicate only under a name that does not assert novelty.
  These four would have entered as new classes.

The withdrawn records, kept for the audit trail:

```
Catalog-gap records (LUTs = repo helpers.jl class_a..d; n=8,m=8,is_permutation=false;
bib_key="Kuznetsov_202606"; target packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml):
- n8_Kuznetsov2026_classA  sigma-hash 9d95d9c4a5e2dfdd  (in V_A)
- n8_Kuznetsov2026_classB  sigma-hash c5f52f5659346f9f  (outside V_A)
- n8_Kuznetsov2026_classC  sigma-hash 74a30c1a17d45761  (outside V_A)
- n8_Kuznetsov2026_classD  sigma-hash 024ba500f4bac35b  (outside V_A)
```

## Library-reuse audit
Duplicates of VBF core (flag):
- rref_f2! (helpers.jl:121) duplicates gauss_jordan! (packages/VBF/src/linalg/f2_arith.jl:53)
  and kernel_f2 (packages/VBF/src/linalg/linear_system.jl:239). Strongest flag.
- apply_matrix (helpers.jl:45), matmul_f2 (helpers.jl:59), build_A_lut (helpers.jl:68)
  duplicate F2LinearMap (packages/VBF/src/representations/f2_linear_map.jl:37) + compose.
Legitimately paper-specific (do not flag): pair_index/row_idx/col_idx, build_M_A,
fc22_sol22, apply_fc22_sol22, in_va, quadratic_lut (F2-component ANF, not GF-univariate;
NOT a clean decode_quadratic_lut duplicate).
Promote-to-core: none needed.

## Open questions
1. Reconcile repo reps vs paper Table VII, or document Table VII inconsistency.
2. ~~Do maintainers want CLASS-A..D as individual catalog entries?~~ ANSWERED: no.
   All four match functions already in the catalog; see the withdrawal above.
3. Is reproducing Theorem 6 (3.7M dataset comparison) in scope? -> now being done.
