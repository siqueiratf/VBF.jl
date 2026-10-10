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
`julia --project=. packages/VBFRepro/src/202606-kuznetsov-groebner-search/test/runtests.jl` -> ALL PASS
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

## Catalog status — withdrawn and superseded

The four former catalog-gap proposals have been removed. Absence from the small
catalog used by the original review never proved literature novelty; a later
signature match only located reference candidates.

The current evidence is stronger: `theorem6_exact.jl` independently replays an
explicit EA graph map for each artifact representative against the tracked
Edel–Pott 2009 corpus. The pairings are A→18, B→5, C→3, D→4. Saved witnesses bind
both exact LUTs and provide 16 ambient columns and an affine constant; the
stdlib-only verifier checks rank, EA block structure, input/output bijections,
and the identity on all 256 points. Bounded native recovery is also tested.
These positive witnesses establish EA-equivalence and therefore CCZ-equivalence.
No new equivalence class should be added for these four representatives.

The older test counts and missing-feature discussion above are historical.
Current scope and commands appear in the paper README. In particular, named
signature sources that are missing or incompletely indexed are **inconclusive**,
not evidence that Theorem6's literal inequivalences all hold.

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
