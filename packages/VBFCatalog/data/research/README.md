# Retained APN research evidence

This is the retained APN portion of the former root `data/` directory. It holds
candidate lists, original configurations, sampling evidence, reports and old
checkpoints. It does not supply the default search reference: VBFSearch reads
VBFCatalog's signature index directly, with source coverage and byte digests.

- `archive/census/`: historical discovery, sampling and mathematical studies.
- `archive/class-orbit/`: class-orbit centers, configurations and results.
- `runs/`: historical VBFSearch runs and inspector certificates.
- `reference/comparison.toml` and `rebuilds/`: retained original-source comparison
  receipts. Their redundant SQLite databases and duplicate downloads were removed
  after confirming every reference signature is present in the catalog.

Unique candidate data and source snapshots remain here, including LUTs whose
signatures match a reference. Such a match alone does not establish equivalence.
Generated data are ignored; previously tracked evidence and READMEs remain tracked.
Original paths in historical manifests describe the experiment as it was run.
The public `crosscheck_raw/raw_only_546.tsv` moved to the canonical catalog input
`../luts/langevin_may2025_extra.tsv`; its byte-identical archive copy was removed.

The recovered discoveries are registered as corpus `legacy20261009_n8` in the
main catalog. Their complete validation run, input hashes, inventory and replay
plan are under `../search/legacy20261009/`; the tracked `replay.toml` records the
assessment and executable recipe. Compact catalog members regenerate their
intermediate TSV when rebuilding from a clean checkout.

New searches belong under `../search/<experiment>/`. See
[VBFSearch](../../../VBFSearch/README.md) for `bin/vbf discover`, which searches,
validates and registers one representative per new separating signature.
Performance evidence moved to `packages/VBF/perf/data/`, paper-reproduction
results to `packages/VBFRepro/src/results/`, and working-paper evidence to
`packages/VBFWorkingPaper/doc/generated/`.
