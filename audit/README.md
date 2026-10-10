# Audit application and reproduction evidence

The August 2026 YAML files are a frozen investigation. Their current dispositions
are in [resolutions.toml](resolutions.toml), covering all 36 IDs without replacing
historical observations. The application repaired 20 findings, recognized one
existing fix, and partially addressed 15 research or reproduction boundaries.
Each entry records its implemented change, guarantee, evidence path and remaining work.

A fixed evidence defect does not prove an entire publication. Full finite checks
and exact witnesses justify only their specified inputs and search regions.
Different exact invariants can certify inequivalence; matching invariants cannot
certify equivalence. Reference absence establishes novelty only relative to an
explicit, independently sourced reference set. General CCZ comparisons may still
be needed against nonquadratic representatives of known classes.

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
