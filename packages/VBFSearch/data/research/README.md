# Retained research data

The consolidation keeps the merged earlier APN discoveries, completed published-root
result and current recursive campaign. Earlier source directories were verified and
embedded in the merged SQLite before removal. Other experimental runs and profiling
checkpoints were removed at the user's request.

- `datasets/`: the self-contained 190,638-representative SQLite, registry, receipts,
  and administrative merge/restore scripts.
- `freezes/published-roots-b52-20261017/`: completed-root results and comparison witnesses.
- `references/published-literature-20261017/`: the pinned published-only reference.
- `analyses/storage-reduction-20261020/`: lossless checkpoint reduction receipts.
- `analyses/further-storage-20261020/`: completed-root archive normalization, restoration
  tests, cold-file archival, input deduplication and final storage inventory.
- `analyses/retention-audit-20261020/`: identification and containment evidence.
- `analyses/cleanup-20261020/`: relocation checks, deletion manifest and cleanup receipt.

The complete root-search ledger and current recursive checkpoint live under
`../search/literature-b52-closure-20261014/`. Paths in older reports record historical
locations; restore earlier-run files with `datasets/extract_archive.py`.

See [DATASETS.md](../../DATASETS.md) and [INVENTORY.md](../../INVENTORY.md).
These are experiment results, not a second curated literature catalog.
