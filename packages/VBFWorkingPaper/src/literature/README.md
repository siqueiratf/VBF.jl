# Finite construction coverage

`family_coverage.jl` enumerates the declared n=8 parameter domains from
`family_coverage.toml`. It reuses VBF mathematics, reproduction formula evaluators
and VBFSearch evidence. The ledger pins formula sources and records uncovered or
unavailable constructions. It does not assert literature completeness.

```sh
julia --project=packages/VBFWorkingPaper \
  packages/VBFWorkingPaper/src/literature/family_coverage.jl \
  data/working-paper/literature/survey01 data/apn/reference
```

Provide the ledger's pinned source PDFs under the archived literature input path;
these inputs remain optional and outside Git. Reports retain parameter accounting,
LUTs, rejection witnesses, source hashes and reference scope. Use a new output
folder. The finite enumerator has no resumable checkpoint; its completed report
is written only after the whole declared domain and source identities agree.

Historical source-fetch/parsing scripts and separate evidence reimplementations
were retired. Original corpus ingestion belongs to VBFCatalog, whose layout will
be consolidated separately. Package tests cover formula domains without downloads.
