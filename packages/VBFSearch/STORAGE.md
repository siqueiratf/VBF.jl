# Recursive campaign storage

The recursive campaign was stopped at the user's request on 19 October 2026.
The current checkpoint remains uncompressed at
`data/search/literature-b52-closure-20261014/run-validation-20261018T232756Z/closure.sqlite`.
Its STOP marker remains present. The dashboard remains available to inspect the
retained reports; the search and report-generation services remain stopped.

The current SQLite file is approximately 213 GiB and has no freelist pages.
`VACUUM` therefore offers little space recovery. The disk audit and maintenance
receipts are under `data/research/analyses/campaign-maintenance-20261019/`.

## Historical artifacts

Under `data/search/literature-b52-closure-20261014/`, the stopped checkpoints
`run-fresh-20261017/closure.sqlite` and
`run-compact-v15-20261016/closure.sqlite` are now `.sqlite.zst` archives.
Each archive was decompressed to a SHA-256 stream and checked against the
original before removing the uncompressed file. The adjacent
`.zst.manifest.json` records both hashes and the exact restore command.
Restore a checkpoint before using a tool that expects SQLite:

```sh
zstd -d /path/to/closure.sqlite.zst -o /path/to/closure.sqlite
```

The former `code-20261017-36f1485/` and `code-20261018-08d5fee/` source trees
are preserved under `archive/source-snapshots/` as `.tar.zst` files. Their
manifests verify every file and symlink. They include the original copied
README files and source changes. To restore one at its original path:

```sh
tar --zstd -xf /path/to/archive/source-snapshots/code-20261018-08d5fee.tar.zst -C /path/to/literature-b52-closure-20261014
```

The live checkpoint's `replay/workspace/` remains in place. Published catalog
inputs, earlier discoveries, direct published-root results, and the current
recursive results retain their separate dataset scopes in [DATASETS.md](DATASETS.md).

## Controller restart policy

The updated continuous controller uses a bounded FIFO of reserved jobs and
refills a free compute slot without waiting for the other slots. Results are
applied in reservation order by the sole database writer. Its default limit is
twice the configured concurrency; an unusually slow first result can still
apply backpressure at that limit. Scientific construction limits and coverage
cursors retain their existing meaning.

`baseline_policy = "summary"` is the default for continuous runs. It saves a
small TOML record of checkpoint identity, cached-counter freshness, indexed row
watermarks, and the latest session. Derivation witnesses remain in the checkpoint.
This summary is not a rollback copy. The earlier full classification projection
is available with `baseline_policy = "full"`; a disk-space preflight must pass
before copying it. Other controllers keep their existing full-baseline behavior.

Stopping a run commits its paused session and job states before refreshing
reports. The shutdown path avoids the global temporary DISTINCT-child sort
that failed during this campaign's final statistics update. A report failure is
recorded separately and preserves the primary compute or checkpoint error.

Deploying the changed controller requires a fresh evidence directory and a
new frozen source snapshot. Preserve the stopped checkpoint's original source
identity. This maintenance does not restart the campaign.

## Lossless normalized storage

New public `closure_init` checkpoints use normalized storage by default
(`compact_storage=false` retains the legacy layout for compatibility). Existing
checkpoints remain readable. The mathematical search, candidate hashes, class
assignments, paths and coverage cursors have the same meaning in both layouts.

The reduction has three parts:

- `VBFCHN02` coverage blocks factor out the job, forms and interval context,
  intern equal five-integer outcome tuples, and encode signed differences of
  successive coset representatives. Every logical coset is retained. The
  envelope retains the **original V1 logical-stream length and SHA-256**;
  decoding reconstructs that stream and verifies its digest. TEXT and
  `VBFCHN01` blocks remain readable. Unrecognized proof schemas use V1.
- `closure_candidates` stores binary LUTs and ortho-derivatives once, with
  SHA-256-indexed templates for their repeated property text. The `candidates`
  SQL view reconstructs the original columns and exact TOML bytes.
- `closure_comparisons` references the existing candidate and target parent,
  stores variable proof values separately, and shares the remaining proof
  text. The `comparisons` SQL view restores the complete original evidence,
  including both LUTs, without a SQLite extension. Positive EA witnesses are
  still available to `verify_comparison`.

Coverage packing follows computation packets. Long campaigns should select an
explicit batch size such as `--extension-cosets 65536` at initialization, as the
current campaign does. The one-coset default is useful for bounded experiments
but retains one TEXT row per packet and does not provide the same ledger savings.

Template hash lookups compare the complete bodies before reuse. Hashes are
storage indexes, never mathematical equivalence certificates. Unknown schemas
and literal template markers have opaque, byte-preserving fallbacks. Views use
only built-in SQLite functions. Candidate class/state updates and legacy SQL
inserts remain supported; candidate evidence is immutable. The hidden `rowid`
is a physical-table property: use `closure_candidates.rowid` or
`closure_comparisons.rowid` when collecting physical watermarks.

Build and run the resumable migrator from the root environment:

```sh
c++ -O3 -std=c++17 packages/VBFSearch/tools/reduce_closure_store.cpp \
    -lsqlite3 -lzstd -lcrypto -pthread -o /tmp/reduce_closure_store
bin/vbf closure reduce /path/to/stopped-run --output /path/to/reduced-run \
    --helper /tmp/reduce_closure_store --threads 8 --reserve-gib 12 --max-gib 55
```

The source must have a STOP marker and no active session, job or journal. The
Julia wrapper takes its exclusive application lease and checks the original
archived code, inputs and environment. The native helper opens the source
read-only and keeps bounded batches and a bounded worker queue. Secondary
indexes are built after the bulk copy to avoid rewriting them for each row. It verifies
all logical table columns with independent streaming hashes, reconstructs and
checks every ledger block, then runs SQLite integrity and foreign-key checks.
The wrapper pins a new implementation archive, records the original database
SHA-256 and session cutoff, and validates the saved coverage cursors before
publishing the stopped output directory. It never dispatches search work.

Failure retains `OUTPUT.reducing` for recovery. Repeat the same command to
resume; source identity, schema and helper binary must match. The reserve is a
free-space check and the output budget also sets SQLite's page limit. Source
and target coexist during conversion; budget for both or write the target to a
separate filesystem. Neither success nor failure removes the source.

The complete campaign conversion is being recorded under
`data/research/analyses/storage-reduction-20261020/`, with a target of
`data/search/literature-b52-closure-20261014/run-reduced-20261020/`.
The original checkpoint remains stopped and preserved until verification.
Sample savings are estimates; the final database size determines whether a
60 GB node has enough headroom. These migration budgets do not cap subsequent
search growth. Workers should receive bounded work packets rather than copies
of the coordinator database.

The optional native integration tests run with
`VBF_CLOSURE_REDUCE_HELPER=/path/to/reduce_closure_store`; ordinary package tests
exercise the Julia codec, SQL views, rollback, constraints and EA proof replay.
