# APN experiment and reference data

The search uses an immutable, independently rebuilt quadratic (8,8)-APN
reference. This directory holds reference snapshots, experiment runs and archived
research artifacts. Generated run files, reference databases and downloaded inputs
are ignored by git; the small historical class-orbit artifacts remain tracked.
It is not a second editable catalog:
seed LUTs come from `VBFCatalog`, while this snapshot supplies original-source
verification evidence for the comparison baseline.

The default layout is:

- `runs/<experiment>/`: checkpointed search databases, frozen inputs, source
  snapshots, validation evidence and publication exports. Use one directory per
  experiment, for example `bin/vbf search --output data/apn/runs/experiment01`.
- `runs/web/`: saved pair-comparison certificates from the inspector.
- `archive/class-orbit/`: historical commutant/self-equivalence results, candidate
  centers, checkpoints, configurations and reports; see its [README](archive/class-orbit/README.md).
- `reference/comparison.toml`: completed original-source comparison manifest.
- `reference/fresh_union.sqlite`: exact union of recomputed signatures.
- `reference/candidate_comparison.toml`: optional digest-bound historical input
  verification report; other inputs are checked in full.
- `supplement.tsv`: independently checked public supplemental LUTs and signatures.

In this checkout, the prepared union has 3,809,037 signatures and SHA-256
`0eed9fb5d3a70bd24b8c8c9eefa61b0b882b9cd540dd06cda0cd430444f7b603`.
This is a particular reference version, not a claim that all literature is covered.
The supplement is fingerprinted and validated separately. Data ownership is
separate from the implementation in [VBFSearch](../../packages/VBFSearch/README.md).

## Rebuild or restore

The original-source rebuild and public-source survey remain research workflows
under `census/` during the migration. Use the [rebuild instructions](../../census/quadratic_apn8/rebuild_corpus/README.md)
and [literature survey](../../census/quadratic_apn8/reports/literature/LITERATURE.md)
to regenerate their artifacts:

```sh
# Use a fresh directory: old rebuild identities deliberately reject changed code.
for stage in fetch stored raw compare; do
  make -C census/quadratic_apn8/rebuild_corpus "$stage" \
    OUTDIR=/tmp/vbf-apn-reference-rebuild threads=16
done
mkdir -p data/apn/reference
cp /tmp/vbf-apn-reference-rebuild/comparison.toml data/apn/reference/
cp /tmp/vbf-apn-reference-rebuild/fresh_union.sqlite data/apn/reference/
cp census/quadratic_apn8/results/literature_20261009/supplemental_luts.tsv data/apn/supplement.tsv
```

If available, also copy the rebuild's `candidate_comparison.toml`. Alternatively
restore these exact files from an archived experiment's documented inputs.
Keep original raw files and their provenance manifests so another researcher can
repeat the rebuild. Do not manufacture a completion manifest for an old index.

`--reference DIR`, `--supplement FILE`, or the environment variables
`VBF_APN_REFERENCE` and `VBF_APN_SUPPLEMENT` select another prepared snapshot.
The search checks manifest completion, database SHA-256, signature count, the
supplement's LUTs, and Gold coverage. A changed reference refuses resume; start a
new experiment when updating the baseline. Reference paths and digests are
recorded with each run; no historical index is substituted silently.
