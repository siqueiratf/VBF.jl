# Quadratic APN census study

These consumers estimate coefficient-tree mass using VBF.QuadraticAPNTree and
inspect the documented catalog reference. Mass is a sum of inverse stabilizer
orders; converting it to a class count needs additional assumptions. The known
mass and class constants describe the cited Beierle 2025 study, not a continuously
updated census of the entire literature.

Run in the VBFPaper environment, with explicit seed, stream count and limits:

```sh
julia --project=packages/VBFPaper -t 4 -e '
include("packages/VBFPaper/src/census/sampler.jl")
run_sampling(outdir="packages/VBFPaper/doc/generated/census/sample01",first_seed=1,nchunks=1,
             samples=1000,n=6,m=6,threads=4,streams=4)'
```

Sampling resumes from digest-bound completed chunks in `sampling.toml`. A changed
configuration, implementation, Julia version or completed chunk is rejected.
Changing physical thread count is allowed when stream count remains fixed.
A crash before committing a chunk digest repeats that chunk. This sampler has
chunk checkpoints; production construction searches use VBFSearch's SQLite ledger.
Dead ends retain zero weights in the denominator. Historical controls and
archived-run reconstruction helpers have been retired; Git preserves them.

Tests under `test/census/` use generated fixtures and run in the package suite.
