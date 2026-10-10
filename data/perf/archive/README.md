# Historical performance archive

`bench/inventory.tsv` records SHA-256 hashes and sizes captured before retiring
the old benchmark runners. Files under `bench/` preserve the original bytes,
including the historical measured tables and calibration. `source/` and
`generated/` preserve older analysis/export evidence moved by the analysis
migration. Archives are local ignored evidence, except README files, which
remain tracked. Active BenchmarkTools runners live in each package's `perf/`.
