# Retained campaign storage

The current recursive checkpoint is
`data/search/literature-b52-closure-20261014/run-reduced-20261020/closure.sqlite`.
It was stopped for migration; `current.json` records its live controller state.
Its losslessly normalized SQLite at the migration cutoff is
**47,283,838,976 bytes (44.04 GiB)**, preserving all 8,052,863,858 logical coset
records and every scientific table from the pre-reduction source.

The superseded 213.17 GiB source file was removed after conversion and final
checksum verification. The subsequent consolidation reclaimed another
**156.48 GiB**. A further lossless archival reduction reclaimed **26.63 GiB**.
The retained package occupies **57.98 GiB**.

## Retained collections

- The current checkpoint includes replay, identity, inputs, lineage, reports and
  graph. Earlier report databases were moved with WAL/SHM files into
  `run-reduced-20261020/reports/` and passed SQLite checks.
- `run-compact-v15-20261016/closure.normalized.sqlite.zst` preserves the completed
  24,294-root witness ledger: **7,880,146,707 bytes (7.34 GiB)** compressed,
  down from 32.91 GiB. It retains all 1,553,321,163 logical coset records, original
  scientific table columns and class/path IDs. The manifest pins the normalized
  SQLite and archive SHA-256. Replay, original identity and frozen execution remain.
- `data/research/datasets/earlier-discoveries-190638.sqlite` embeds the earlier
  discoveries and six verified original evidence archives in one
  **2,117,996,544-byte (1.97 GiB)** file. See [DATASETS.md](DATASETS.md).

Restore the completed-root ledger for its original frozen code:

```sh
python3 /path/to/run-compact-v15-20261016/storage-tools/archive-v2/restore_checkpoint.py
```

The wrapper verifies the archive and normalized database, then reconstructs the
original schema and V1 coverage frames. Table and ledger digests, integrity and
foreign keys must pass. Allow about 64 GiB temporary space. For compact SQL
inspection, add `--normalized-only --output /path/to/inspection.sqlite`; allow
at least 16 GiB. The original frozen execution needs the default restoration.
Restored scientific records are exact; physical SQLite layout and compressed
frame bytes can differ. Pinned sources, a native restorer and detailed
`RESTORE.md` instructions live alongside the wrapper.

Cold completed-root graph snapshots and old session files are now verified
`tar.zst` archives under `run-compact-v15-20261016/cold/`. Their manifests contain
per-file hashes and restoration commands. The live recursive graph remains
unpacked. Fourteen duplicate frozen input copies now share read-only hardlinks;
canonical source inputs remain independent. These changes saved another
approximately 1.06 GiB. The retained queryable databases have no free pages, so
`VACUUM` offers no material savings. The earlier-discovery SQLite remains directly
queryable with its embedded source archives.

Every completed-root scientific table and coverage block was compared with the
original. All 1,237,894 frozen class representatives and 1,434,339 derivation
references were checked against the rewritten ledger. A real-data restoration
fixture passed the original frozen Julia decoder and corrupt-block rejection.
The compressed archive passed a full decompression SHA-256 comparison before
the superseded archive and temporary databases were removed. Receipts are under
`data/research/analyses/further-storage-20261020/`.

Current source/session evidence retired during cleanup is preserved under
`run-reduced-20261020/lineage/cleanup-20261020/`. Cleanup and relocation receipts
are under `data/research/analyses/cleanup-20261020/`. The lossless conversion proofs
remain in `storage-reduction.toml` and `data/research/analyses/storage-reduction-20261020/`.
Selected paths are recorded in `data/research/datasets/registry.json` and the
campaign's `current.json`. Obsolete launch pointers and other experiment
directories were removed.

## Controller restart policy

The updated continuous controller uses a bounded FIFO of reserved jobs and
refills a free compute slot without waiting for the other slots. Results are
applied in reservation order by the sole database writer. Its default limit is
twice the configured concurrency; an unusually slow first result can still
apply backpressure at that limit. `reservation_horizon` can explicitly raise this bounded
queue; the current restart selects 128 tickets for 32 workers. Scientific
construction limits and coverage cursors retain their existing meaning. In
particular, the checkpoint keeps `extension_cosets = 65536`.

The coordinator groups ready events, job reservations and ordered applications
into one bounded transaction, committing before waiting for more worker results
or publishing reports. Each application has a savepoint: a failed packet is
rolled back while the successful earlier prefix is committed. `synchronous=FULL`
is retained. This amortizes commit overhead without holding a transaction across
worker computation waits. Failed commits roll back their uncommitted batch.

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
resume; source identity, schema and helper binary must match. After every
scientific table and ledger has been verified, `--resume-helper OLD_SHA256` can
explicitly permit a replacement helper for the final database checks. It records
the predecessor and reruns those checks; it cannot resume partially converted
data under a different helper. Integrity checks target `main`, excluding the
attached read-only source. The reserve is a
free-space check and the output budget also sets SQLite's page limit. Source
and target coexist during conversion; budget for both or write the target to a
separate filesystem. Neither success nor failure removes the source.

The verified checkpoint's 47.28 GB SQLite file fits a 60 GB storage budget,
leaving approximately 12.72 GB before dependencies and derived artifacts.
The latest graph payload is reused through hard links to immutable snapshot
files; the structure and catalog JSON snapshots retain their original audit
cutoffs. Mutable report databases are not hard-linked.
The 32-worker continuous campaign was resumed after migration, then restarted
with bounded coordinator transaction batches and a 128-ticket reservation queue.
The campaign's `current.json` points to its frozen controller, service and evidence.
These migration budgets do not cap subsequent
search growth. Workers should receive bounded work packets rather than copies
of the coordinator database.

The optional native integration tests run with
`VBF_CLOSURE_REDUCE_HELPER=/path/to/reduce_closure_store`; ordinary package tests
exercise the Julia codec, SQL views, rollback, constraints and EA proof replay.
