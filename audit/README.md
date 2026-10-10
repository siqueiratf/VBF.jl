# Audit application and reproduction evidence

The August 2026 YAML files are a frozen investigation. Their current dispositions
are in [resolutions.toml](resolutions.toml), covering all 36 IDs without replacing
historical observations. The application and follow-ups repaired 29 findings, recognized one
existing fix, and partially addressed six research or reproduction boundaries.
Each entry records its implemented change, guarantee, evidence path and remaining work.

A fixed evidence defect does not prove an entire publication. Full finite checks
and exact witnesses justify only their specified inputs and search regions.
Different exact invariants can certify inequivalence; matching invariants cannot
certify equivalence. Reference absence establishes novelty only relative to an
explicit, independently sourced reference set. General CCZ comparisons may still
be needed against nonquadratic representatives of known classes.

## Follow-up of the fifteen partial findings

Seven more findings now have scoped implementation/evidence fixes: F014, F020,
F023, F024, F025, F050 and F064. F063 and F071 gained additional finite evidence
while their literature/equivalence requirements remain unresolved. The eight
partial findings at that stage were F004, F032, F040, F051, F052, F063, F070 and F071.

The [three-reviewer feasibility assessment](partial_feasibility.md) evaluates
these eight requirements without changing their statuses. It identifies a
49,981-case algebraic reduction as a credible route to the finite n=30 claim,
an achievable bounded general code-equivalence API, and stronger theorem-backed
power/reference comparisons. Fresh bounded probe commands and hashes are in
[partial_feasibility_probes.toml](partial_feasibility_probes.toml). Source
ambiguities, unfinished full runs and literature-wide completeness remain explicit.

[followup_runs.toml](followup_runs.toml) binds sixteen run manifests/logs and one
proposal-review snapshot. These include exhaustive counts and traversals, finite
witness replay, and explicitly budget-limited searches. Each record states its
precise scope and input evidence; process success is never treated as exhaustion.
Raw execution artifacts remain ignored under `data/repro/runs/`.

Additional source-faithful evidence includes 26 independently replayed EA
witnesses for the 13 named Edel–Pott n=6 reference representatives with both shift
valences; fresh 17/27/32 Beierle tuple classes; verified commutant-subset pruning
and supported fixed-space seeding; and the complete cited n=8 inverse-swap-family
comparison. Tuple classes and mapping counts are not APN equivalence-class counts.
The n=7 Yu source traversal is exhausted as an invariant-bucket computation;
its attempted exact EA classification remains budget-limited.

## Implemented equivalence, n=30 certification and power coverage

The next three-agent round closed F032 and the finite-instance scope of F070.
The current partial findings are F004, F040, F051, F052, F063 and F071.
Execution and independent-check bindings are in [implementation_runs.toml](implementation_runs.toml).

- `VBF.binary_code_equivalence` accepts arbitrary Boolean generator matrices.
  It searches invertible maps of column multisets, preserving duplicates and
  zero columns. It reuses Kaleyski–Sunde's partial-isomorphism machinery and
  existing wide GF(2) rank APIs. Positive coordinate permutations are independently
  replayed; only exhaustion or an exact separating invariant proves a negative.
  Resource limits return `BudgetHit`. The complete core suite passed 103 items /
  147,156 assertions; all 4,489 pairs of the 67 length-four codes independently
  agree with brute-force codeword/coordinate-permutation classification.
- The specific Bracken n=30 instance now has complete 49,981-case derivative
  and component evidence. Every derivative/polar rank is 28, every augmented
  collision rank is 29. Verified field/coset orders and normalization identities
  cover every original nonzero difference/output mask. An independent Python
  arithmetic implementation recomputed every row. This certifies DU4, permutation
  status and nontrivial Walsh support inclusion `{0, ±65536}`; it does not prove
  an infinite family or APN novelty. The paper suite passed 9,090 assertions.
- All 32 audited paper proposals are excluded from every APN power function
  using complete Gold-domain coverage and Yoshiara's theorem. All 583 current
  catalog comparisons are conclusive: 31 proposals are separated and one is
  represented. Nine prior/proposal positive certificates remain replayed.
  Yu's s₁/s₂ are separated from all 18 current n=9 references and all APN power
  functions. Unlisted non-power constructions and literature completeness
  remain unresolved, so F040/F063 stay partial. Tests passed 172 and 78 assertions.

Gold and matched power controls bind actual formulas, fields, LUTs and
invariants; theorem evidence binds the actual candidate. Changed references,
invariant collisions, missing sources and budget hits fail closed. The source-
rebuilt 3,809,037-signature n=8 baseline was reused, not rebuilt; its sole proposal
already has a positive EA witness to known corpus member 12658. The reproduction
runner suite and docs build also passed; no catalog data changed.

```sh
bin/vbfrepro run Bracken_201205 --target orbit_certificate \
  --param full_search=true --param save_results=true --param timeout_seconds=120 \
  --timeout-seconds 180
make -C packages/VBFRepro/analysis review_catalog_proposals
bin/vbfrepro run Yu_202012 --target table4 --timeout-seconds 120
```

```sh
bin/vbfrepro run Taniguchi_202501 --target theorem3_2 --param n=6 \
  --param modulus=97 --param full_search=true --param timeout_seconds=600 \
  --timeout-seconds 660
bin/vbfrepro run Kaleyski_201911 --target conjecture22 --param 'ns=[7,8]' \
  --param full_search=true --param timeout_seconds=900 --timeout-seconds 960
bin/vbfrepro run Bracken_201103 --target parameter_sweep --param k=5 \
  --param s=13 --param full_search=true --param timeout_seconds=300 \
  --timeout-seconds 360
bin/vbfrepro run Budaghyan_202008 --target section7d
bin/vbfrepro run Zha_201401 --target proposition5 --param save_results=true
make -C packages/VBFRepro/analysis review_catalog_proposals
make -C packages/VBFRepro/analysis test_catalog_proposals
bin/vbfrepro run Beierle_202107 --target corollary1_n6n7n8 \
  --param n=8 --param full_search=true
```

## Reproduce the checks

Use Julia ≥1.12 from the root workspace. Configure the local depot as appropriate.

```sh
julia --project=. -e 'using Pkg; Pkg.test("VBF"); Pkg.test("VBFSearch"); Pkg.test("VBFRepro")'
julia --project=. packages/VBFRepro/analysis/scripts/revalidate_audit_luts.jl

bin/vbfrepro run Canteaut_202205 --target section4_5 \
  --param full_search=true --param check_ortho=true --param save_results=true \
  --param timeout_seconds=600 --timeout-seconds 660

make -C packages/VBFRepro/papers/2025/Beierle_202508 table4_1
make -C packages/VBFRepro/papers/2020/Calderini_202009 table_bounds \
  limit=1 max_nodes=100000 timeout_seconds=10
make -C packages/VBFRepro/papers/2011/Bracken_201103 parameter_sweep \
  k=4 s=11 full_search=true timeout_seconds=60
make -C packages/VBFRepro/papers/2011/Bracken_201103 family_separation
```

`bin/vbfrepro test <paper>` and `bin/vbfrepro run <paper>` record source/input hashes,
parameters, logs, execution status and time under `data/repro/runs/`. Runtime
certificate fixtures participate in source hashes. Named external side stores
also need their own input hashes; the Canteaut driver records both.

Canteaut's optional `results/section4_5.toml` retains every member index, APN check,
full extended Walsh spectrum and full ortho-derivative signature. The two stores
are `yuwangli2014_qam_n8` (8179 members) and `beierleleander2022_n8` (12923 members).
The completed run obtained 21102 distinct exact signatures and no invalid members.
This establishes pairwise inequivalence within that input snapshot, rather than
classification of all eight-variable APNs.

The eight F060 recipes have full finite APN checks and little-endian UInt16 LUT
hashes in [revalidated_luts.toml](revalidated_luts.toml). All five printed LUT arrays
matched the Julia reconstructions. The three Bracken prefixes and legacy hashes
also matched; the historical “FNV-1a” values actually use a nonstandard offset and
word-wise updates, so the new evidence uses an explicit SHA-256 encoding instead.
None of these property checks establishes literature novelty or adds catalog rows.

The bounded Gamma-rank API can be exercised explicitly:

```julia
using VBF
gamma_rank(gold_apn(8); allow_large=true,
           max_memory_bytes=2*1024^3, timeout_seconds=600)
# 11818 in the completed audit run
```

Storage budgets are conservative working-storage estimates, not hard process RSS
limits. Time checks are cooperative. Budget exceptions return no partial rank.
SearchOutcome exhaustion applies only to the declared finite region; sampled or
interrupted searches remain inconclusive. Historical runtime estimates do not
constitute completion certificates.
