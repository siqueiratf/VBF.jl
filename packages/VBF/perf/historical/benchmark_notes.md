# Historical benchmark evidence

The original benchmark tables, provenance and command descriptions are preserved
verbatim in [the archived benchmark README](../../../../data/perf/archive/bench/README.md).
Current commands and the BenchmarkTools measurement protocol are documented in
[the active perf README](../README.md).

The historical calibration remains [calibration.toml](calibration.toml).
Core workloads now live in VBF/perf/suites; catalog reads in VBFCatalog/perf;
durable discovery operations in VBFSearch/perf; paper workloads in VBFRepro/perf.
The old custom timer/persistence engine is retired and preserved locally under
`data/perf/archive/bench/` with a SHA-256 inventory.
