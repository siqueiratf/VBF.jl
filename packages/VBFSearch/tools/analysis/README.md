# APN analysis and bounded prototypes

These tools record structural audits, exact reuse experiments, and performance
investigations for VBFSearch. Generated measurements and research artifacts
belong under `packages/VBFSearch/data/research/analyses/` and remain outside Git.
Published corpora remain in VBFCatalog.

The package test suite exercises the admission, frontier-incidence, symmetry,
restriction, and reuse audits that it includes explicitly. Other files are
opt-in prototypes and benchmarks; they do not change the running controller.
Their corresponding tests run in fresh Julia processes, for example:

```sh
julia --startup-file=no --threads=1,1 --gcthreads=1,0 --project=docs/inspector packages/VBFSearch/test/v6_completion_reuse_du7_bitsets.jl
```

Several experiments instrument a source-bound copy of an earlier completion
kernel. Its original source is preserved under `test/fixtures/`, with exact
SHA-256 pins and a purpose manifest. The fixture loader verifies the source
before making an in-memory transformation. Strict anchors reject source drift;
the tests also compare mathematical outputs and coverage cursors with the
current native kernel. Work counters can differ when pruning changes the work.
The fixtures retain the original benchmark baseline; they are not production
implementations or new performance measurements.

The 19 October 2026 maintenance verified all sixteen opt-in prototype tests
after making their baseline choices explicit. Earlier measurement files were
preserved. Re-run the relevant parity tests when changing a source pin or a
transformation anchor, and collect new measurements before making a performance
claim about the changed code.
