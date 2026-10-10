# Historical APN evidence

`class-orbit/` preserves the former root `search/` experiment.
`census/` preserves the former `census/quadratic_apn8/` data hierarchy: candidate
TSVs, compact samples, downloaded public originals, SQLite reference rebuilds,
checkpoints, figures, scientific reports and execution metadata.

The census relocation preserved 55,003 files, about 13 GB, with SHA-256 checks
before and after each move. The ignored `census/migration.json` records each
original path, destination and digest, with the original implementation commit.
`census/source/` holds an ignored exact snapshot of the original research scripts.
Previously tracked data and READMEs retain their tracked status; bulk generated
data, downloaded sources and source snapshots remain local ignored artifacts.

Historical reports, embedded paths, hashes and source archives describe the
original runs and have not been rewritten. Old command examples in those reports
are historical. Current tools can resolve the retired census prefix when reading
digest-bound input records, but a changed source identity still prevents resume.
The retired code is also available in Git at commit `2f989a9` under `census/`.

Use the [current component review](../../../packages/VBFSearch/CENSUS_REVIEW.md),
[reference tools](../../../packages/VBFCatalog/tools/reference/README.md),
[search commands](../../../packages/VBFSearch/README.md) and
[inspector](../../../apps/apn-inspector/README.md) for supported workflows.
New outputs belong outside this archive, under `data/apn/runs/` or
`data/apn/rebuilds/`. Back up the ignored data separately from the Git repository.
