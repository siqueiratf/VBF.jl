# VBFSearch inventory after consolidation

Updated 2026-10-20T03:30:25.622527+00:00. The authorized cleanup merged earlier discoveries
and removed the other experiments except the completed 24,294-root search and
current recursive campaign, with shared inputs and provenance.
The package occupies **84.61 GiB**, down from about **239 GiB**.
The cleanup reclaimed **156.48 GiB**.

| Retained collection | Path relative to VBFSearch | Allocated GiB |
| --- | --- | --- |
| Merged earlier discoveries | data/research/datasets/earlier-discoveries-190638.sqlite | 1.97 |
| Completed-root results and comparisons | data/research/freezes/published-roots-b52-20261017 | 1.00 |
| Completed-root ledger, replay and graph | data/search/literature-b52-closure-20261014/run-compact-v15-20261016 | 34.19 |
| Current recursive checkpoint and evidence | data/search/literature-b52-closure-20261014/run-reduced-20261020 | 45.98 |
| Pinned published reference | data/research/references/published-literature-20261017 | 1.11 |

The earlier SQLite has **190,638 representatives**, **645,851 exact LUTs** and
**676,241 source observations**. Six embedded archives preserve original run
files, audits, source snapshots and alternatives. Its original 190,454-class
prefix remains exact at the row level for existing comparison witnesses.

Only `data/search/literature-b52-closure-20261014/` remains under `data/search/`.
It contains:

- `run-reduced-20261020/`: current stopped recursive checkpoint, reports and graph.
- `run-compact-v15-20261016/`: completed-root ledger and replay. Its original
  construction/admission witnesses remain; predecessor DBs and full baselines removed.
- `seed_count/`: published-root qualification and EA certificates.
- `diagrams/`: retained figures, including the dashboard SVG.
- `restart-controller-20261020-reduced/`: prepared restart, not started.

Canonical inputs and preparation evidence remain at their pinned paths.
`current.json` identifies selected collections. Source, GPU kernels, controllers,
analysis tools, tests and benchmarks outside `data/` remain in place. Historical
restored source under `data/` is inside the merged evidence archives.

The former 47-directory campaign mixture, independent discovery runs, profiling
checkpoints, redundant projections, old graph caches, exports and vault copies
were removed. Current report databases and session evidence were relocated or
archived before removal. The dashboard, graph and structure pages passed checks;
the search remains stopped.

The pre-cleanup file inventory is
`data/research/analyses/cleanup-20261020/before-inventory.json.zst`. That directory
also holds the exact deletion manifest, receipt, relocations and verification.
[DATASETS.md](DATASETS.md) records scientific scopes; [STORAGE.md](STORAGE.md)
describes restoration. No data was pushed.
