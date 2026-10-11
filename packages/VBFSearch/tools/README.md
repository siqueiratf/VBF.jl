# Reference and classification tools

These commands consume VBFCatalog data and VBF mathematics. Run in the root Julia
environment; outputs, checkpoints and proof history belong to VBFSearch.

```sh
make classes                 # confirmed curated classes through dimension seven
make classify threads=30 CLASSIFY_ARGS='--n 8 --seconds 1 --nodes 1000000 --algorithm optimized'
make fetch OUTDIR=/path/to/reference
make stored OUTDIR=/path/to/reference
make raw OUTDIR=/path/to/reference
make compare OUTDIR=/path/to/reference
make test
```

`classify` resumes signature-bucket deduplication and bounded equivalence checks;
`--pairs N` limits new attempts, and `--rebuild true` rebinds changed inputs.
Identical signatures alone never merge functions. Positive witnesses are replayed
with VBF; exhausted native searches remain implementation-bound evidence and
budget stops remain inconclusive. Local pair checks survive index rebuilds.

Reference rebuilding compares reconstructed catalog members against pinned raw
originals. It checkpoints complete batches, binds source and implementation
hashes, and refuses completeness claims for partial runs. Its shared raw-format
parsers live with the catalog importers.

The default output is `VBFSearch/data/research/rebuilds/original-source/`.
Classification uses the regenerable catalog signature index;
`VBFSearch/data/equivalence_checks.sqlite` retains pair evidence and
`VBFSearch/data/curated_classes.sqlite` retains derived curated classes.
