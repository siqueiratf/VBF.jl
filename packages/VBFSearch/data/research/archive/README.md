# Historical APN evidence

`class-orbit/` preserves the former root `search/` experiment.
`census/` preserves unique candidate TSVs, compact samples, configurations,
scientific reports, checkpoints and source snapshots from the former
`census/quadratic_apn8/` hierarchy. Previously tracked artifacts and READMEs remain
tracked; generated data and source snapshots are local ignored artifacts.

Original paths and source digests in reports and manifests describe their
historical execution. Git contains the retired census code at `2f989a9`; dirty
source snapshots remain when exact recovery from Git has not been established.
Historical command examples are not supported entry points.

The subsequent scan recovered candidate LUTs, verified the public reference's
inclusion in the catalog, and removed redundant reference databases, duplicate
original downloads and byte-identical test input copies. Original public files
belong in `packages/VBFCatalog/data/raw/`. Unique candidates with matching
signatures remain here because their equivalence is unresolved.

Use [VBFSearch](../../../../VBFSearch/README.md), the
[reference tools](../../../tools/README.md), and the
[inspector](../../../../../docs/inspector/README.md) for current workflows.
The [replay recipe](../../search/legacy20261009/replay.toml) records recovered
counts and a bounded successful replay. New outputs belong under
`packages/VBFSearch/data/search/`. Back up ignored evidence separately from Git.
