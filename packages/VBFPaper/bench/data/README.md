# Performance evidence storage

Current development runners live under each package's `perf/` directory.
They create local measurements here as `<package>/<UTC-time>_<pid>/`, with
BenchmarkTools JSON, a tab-separated timing summary, a source/configuration/
hardware manifest and resolved environment copies. Raw sampling profiles are
stored under `<package>/profiles/<run>/`. These generated files are ignored;
READMEs remain tracked. Export reviewed summaries/figures through VBFRepro's
performance analysis rather than committing machine-specific raw runs.

The timing protocol is `BenchmarkTools trial summary v1`. Each summary row is
one completed workload's trial, not one independent experiment; `samples`
records its actual sample count. Timing units are nanoseconds. Historical
custom-engine repetitions have a different protocol and must not be pooled
with these summaries. Diagnostic C++ comparisons preserve native BenchmarkTools
trials and separate C++ measurements in `comparison.csv`.

`archive/bench/` contains a byte-for-byte snapshot of the retired local benchmark
engine, calibration, workload definitions and profile support. Its
`inventory.tsv` records every original path, size and SHA-256. Additional
historical analysis/generated artifacts live under `archive/source/` and
`archive/generated/`. Existing local artifacts were preserved before replacing
their runners. These archives are ignored local audit material; README files
are tracked. No git history was rewritten.

Published historical measurement notes and calibration are also retained as
tracked files under `packages/VBFPaper/bench/historical/`. Their commands describe the
old experiments and should be read with their hardware and limitations. Follow
the current package perf READMEs for runnable commands.

Before scientific comparisons, inspect input/source hashes, Julia versions,
thread counts, CPU, parameters, sample counts and validation scope. Collect
runs against fixed source and quiescent input databases. Benchmark evidence
describes cost; mathematical correctness, equivalence and novelty require the
separate package and discovery validation evidence.

The byte-identical retired exporter is preserved in Git at
`a07b06d:data/perf/archive/source/export.jl`. Its duplicate was removed from this
evidence directory; current exporters belong to VBFPaper.
