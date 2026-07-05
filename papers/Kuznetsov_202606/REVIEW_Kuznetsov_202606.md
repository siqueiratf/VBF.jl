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
`julia --project=. papers/Kuznetsov_202606/test/runtests.jl` -> ALL PASS
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

## Catalog status (n8_apn.toml has only Gold_x3, Gold_x9, Kasami_x57)
- CLASS-E -> present (sigma matches n8_Gold_x3)
- CLASS-F -> present (sigma matches n8_Gold_x9)
- CLASS-A/B/C/D -> missing (no sigma match to any n=8 catalog entry; Kasami x57 is deg 4)
Note: catalog is tiny, so "missing" only proves inequivalence to Gold/Kasami; novelty
vs 3.7M Beierle-2025 was NOT re-verified in-repo (this is the follow-up task).

Catalog-gap records (LUTs = repo helpers.jl class_a..d; n=8,m=8,is_permutation=false;
bib_key="Kuznetsov_202606"; target packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml):
- n8_Kuznetsov2026_classA  sigma-hash 9d95d9c4a5e2dfdd  (in V_A)
- n8_Kuznetsov2026_classB  sigma-hash c5f52f5659346f9f  (outside V_A)
- n8_Kuznetsov2026_classC  sigma-hash 74a30c1a17d45761  (outside V_A)
- n8_Kuznetsov2026_classD  sigma-hash 024ba500f4bac35b  (outside V_A)

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
2. Do maintainers want CLASS-A..D as individual catalog entries?
3. Is reproducing Theorem 6 (3.7M dataset comparison) in scope? -> now being done.
