# APN research consumers

These scripts orchestrate mathematical experiments using the packages. They do
not supply another implementation of coefficient arithmetic, APN extension
counting, profiles or hyperplane restrictions. Use `bin/vbf search` for supported
checkpointed discovery; these research drivers have separate, limited purposes.

| Directory | Purpose | Data |
|---|---|---|
| `census/` | Reproduce Knuth coefficient-tree samples, compact TSVs and historical mass diagnostics | Inputs: `data/apn/archive/census/data/`; new output: `data/apn/runs/census/` |
| `hyperplanes/` | Count extensions, compare admissible selections, inspect signature-neighbour graphs | Historical input: `data/apn/archive/census/theory/`; new output: `data/apn/runs/hyperplanes/` |
| `power_ccz/` | Export power-function controls and inspect Walsh-zero subspaces | `data/apn/runs/power-ccz/` |
| `controls/` | Export explicit candidate/control LUTs | `data/apn/runs/controls/` |

Run from the instantiated repository project:

```sh
julia --project=. packages/VBFSearch/experiments/census/test/runtests.jl
julia --project=. -t 4 -e 'include("packages/VBFSearch/experiments/census/sampler.jl"); run_sampling(outdir="data/apn/runs/census/sample01", first_seed=1, nchunks=1, samples=1000, n=6, m=6, threads=4, streams=4)'
julia --project=. -e 'include("packages/VBFSearch/experiments/hyperplanes/check_uniqueness.jl"); check_uniqueness(n=4, samples=10, hpf=3, exhaustive=false)'
```

Sampler reproducibility requires the same stream count, seed and sample count;
the physical thread count may differ. Dead ends retain zero weights in the
denominator. Mathematical counting belongs to `VBF.QuadraticAPNTree`; a node
budget stop raises an error and supplies no exact count. Experiments may select
explicit budgets through the underlying API. Their outputs are not the
checkpoint format used by the production search application.

Knuth weights estimate numbers of coefficient tuples. Orbit-mass diagnostics
depend on the stated group action and stabilizers; mass is not a class count.
Historical coverage-to-class estimates retain their historical reference
assumptions and are exploratory diagnostics. A neighbour graph labeled only by
signatures is a graph of signature buckets, with possible collisions, unless
equivalence and reference completeness are established separately.

The [consolidation review](../CENSUS_REVIEW.md) lists retired runners and the
[research assessment](../AUDIT.md) distinguishes established results from open claims.
