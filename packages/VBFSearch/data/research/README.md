# Retained APN research evidence

This is the retained APN portion of the former root `data/` directory. It holds
candidate lists, original configurations, sampling evidence, reports and old
checkpoints. It does not supply the default search reference: VBFSearch reads
VBFCatalog's signature index directly, with source coverage and byte digests.

- `archive/census/`: historical discovery, sampling and mathematical studies.
- `archive/class-orbit/`: class-orbit centers, configurations and results.
- `archive/class-orbit/code/` and `archive/census/code/`: the original search code
  (commit `277eca9`), restored byte-exact so that the checkpoints can continue.
- `vault/`: the raw search output that was only on a local disk — the `.hits`
  logs, the B6 = 52 runs, the hyperplane scan and the Beierle 2025 class count —
  as compressed parts with SHA-256 manifests. See [vault](vault/README.md).
- `runs/`: historical VBFSearch runs and inspector certificates.
- `reference/comparison.toml` and `rebuilds/`: retained original-source comparison
  receipts. Their redundant SQLite databases and duplicate downloads were removed
  after confirming every reference signature is present in the catalog.

Unique candidate data and source snapshots remain here, including LUTs whose
signatures match a reference. Such a match alone does not establish equivalence.
Generated data are ignored; previously tracked evidence and READMEs remain tracked.
Original paths in historical manifests describe the experiment as it was run.
The public `crosscheck_raw/raw_only_546.tsv` moved to the canonical catalog input
`../../../VBFCatalog/src/data/luts/langevin_may2025_extra.tsv`; its byte-identical archive copy was removed.

The recovered discoveries are registered as corpus `legacy20261009_n8` in the
main catalog. Their complete validation run, input hashes, inventory and replay
plan are under `../search/legacy20261009/`; the tracked `replay.toml` records the
assessment and executable recipe. The immutable normalized input lives in
`../../../VBFCatalog/src/data/luts/legacy20261009.coeffs.gz`; rebuilds do not need the old run.
Coefficient records reconstruct LUTs through the VBF APIs.

New searches belong under `../search/<experiment>/`. See
[VBFSearch](../../../VBFSearch/README.md) for `bin/vbf discover`, which searches,
validates and registers one representative per new separating signature.
Performance evidence moved to `packages/VBFPaper/bench/data/`, paper-reproduction
results to `packages/VBFRepro/src/results/`, and working-paper evidence to
`packages/VBFPaper/doc/generated/`.
