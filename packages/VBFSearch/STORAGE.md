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
