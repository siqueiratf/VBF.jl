The catalog build environment imports original datasets and builds the curated
SQLite catalog. Run `make catalog`, then `make check`; supply the local dataset
paths documented in the Makefile. Importers are build tools, not package APIs.
The full build defaults to `CATALOG_ARGS='--max-n 11'`, matching the committed
constructor-family scope. Increasing that limit is a catalog content change.

For a source-only rebuild with an existing independently audited Beierle store,
set `BFA_REUSE_CORPUS_AUDIT` to the source-rebuild audit directory and still set
`BFA_BEIERLE2025_PATH` to the original `new_apns.txt` directory. The build checks
the original digest and record count; the store digest, integrity, schema,
encoding size and count; and the complete raw/stored audit and comparison
records. Failed checks abort. The descriptor records the audit digests used.
This reuses previous verification evidence; it does not recompute the APN
checks. Leave the option unset for a fresh import from every original LUT.

For example, this rebuild keeps the existing constructor scope and reuses the
independently verified Beierle store:

```sh
BFA_SBOXU_PATH=/path/to/pinned/sboxU \
BFA_THESIS_PATH=/path/to/thesis/files \
BFA_BEIERLE2025_PATH=/path/to/originals \
BFA_REUSE_CORPUS_AUDIT=/path/to/source-rebuild-audit \
make -C packages/VBFCatalog/data-build catalog CATALOG_ARGS='--max-n 11'
make -C packages/VBFCatalog/data-build check
```

The originals directory must contain `new_apns.txt`. The audit directory must
contain `raw_beierle2025_n8.toml`, `stored_beierle2025_n8.toml`, and
`comparison.toml` from the complete independent source/store comparison.
The content-addressed store must match both the catalog descriptor and audit.

`make check-reuse` runs isolated corruption and coverage tests for this path.
