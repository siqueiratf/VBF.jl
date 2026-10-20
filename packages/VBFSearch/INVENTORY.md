# VBFSearch inventory

Snapshot: **2026-10-20T02:54:00.695514+00:00** (19 October 2026, São Paulo). Paths below are relative to `packages/VBFSearch/`.

VBFSearch occupies **238.88 GiB** in **93,841 files** and 5,096 directories. At the snapshot, 567 files were tracked and 93,274 were ignored generated/history artifacts. This inventory does not move, remove, reclassify or restart any experiment.

The current stopped checkpoint is `data/search/literature-b52-closure-20261014/run-reduced-20261020/closure.sqlite`. Its dashboard is [live](http://100.71.191.42:8766/); the search service has no process. The compact database is 44.04 GiB; its complete run directory, including replay, reports and graph payloads, is 44.88 GiB.

## Measurement and evidence

Sizes are allocated filesystem bytes, using file metadata only. Each inode is counted once per subtree; symlink targets are not followed. The scan found 1,740 hard-link groups, 3 symlinks (all valid), and 0 traversal errors. Sibling directory sizes can overlap through hard links. Identical sizes are not evidence of identical contents.

The detailed local manifest is `data/research/analyses/vbfsearch-inventory-20261020/inventory.json.zst`; `classification.json` records role assignments and protected input paths. The file list precedes writing these inventory outputs, so their own bytes and this document are excluded. Database tables and compressed archives were not rescanned or decompressed; verification receipts cited below predate this filesystem inventory.

## Disk use by role

These file-allocation categories are exclusive: a multiply linked inode is assigned once, prioritizing the current checkpoint. Directory blocks are separate.

| Role | GiB |
| --- | --- |
| Current checkpoint and its replay/reports/graph | 44.88 |
| Archived closure checkpoints | 96.66 |
| Historical classification baselines | 53.20 |
| Earlier finite-search campaigns | 19.01 |
| Profiling and miniature campaigns | 8.78 |
| Published reference and frozen class datasets | 2.49 |
| Historical source and evidence archive | 0.76 |
| Exports and shared vault | 1.28 |
| Other campaign and analysis evidence | 11.79 |
| Source, tools, tests and package documentation | <0.01 |
| Directory blocks | 0.02 |

## Package layout

| Path | Tracked files | Allocated MiB | Responsibility |
| --- | --- | --- | --- |
| src | 34 | 0.38 | Production search, evidence, equivalence and normalized storage |
| tools | 98 | 1.05 | Controllers, migration tools, dataset operations and analysis prototypes |
| test | 56 | 0.44 | Package tests, opt-in prototype tests and source-pinned fixtures |
| gpu | 17 | 0.19 | Standalone GPU search kernels and census orchestration |
| perf | 7 | 0.05 | Optional benchmark environment and workloads |

Almost all disk space belongs to data. Restored historical code under `data/research/archive/` is deliberately tracked. Tests include controller and analysis scripts by relative path, so moving those scripts requires coordinated include-path changes. Frozen replay workspaces retain recorded identities.

## Ten search experiment roots

| Directory under data/search/ | GiB | Files | Purpose / recommendation |
| --- | --- | --- | --- |
| b50-pilot-20261014 | 0.05 | 178 | B6=50 pilot, controls and audits. Retain pilot result and witnesses; archive logs/source with it. |
| b52-20261014-9h-30t | 3.46 | 167 | Initial B6=52 finite search, exported results and reviews. Retain historical evidence until containment in a freeze is verified. |
| b52-20261014-split-24-12 | 14.79 | 1,103 | Local/Hypatia split search, partitions, merged result and implementation snapshots. Retain shard/partition provenance; different scope from the initial run. |
| b52-catalog-smoke | <0.01 | 164 | Catalog-input smoke test. Small reproducible test run; archive as a test artifact. |
| b52-corpus-smoke | <0.01 | 163 | Corpus-input smoke test. Small reproducible test run; archive as a test artifact. |
| b52-pilot-20261014 | 0.05 | 154 | B6=52 pilot. Retain pilot evidence. |
| b52-replay-pilot | <0.01 | 166 | Bounded replay of a recovered historical parent. Keep comparison and original replay evidence. |
| legacy20261009 | 0.66 | 33 | Recovered historical search, validation and deterministic parent plan. Protect tracked inputs, replay recipe and validation evidence. |
| literature-b52-closure-20261014 | 195.67 | 27,046 | Published-root and recursive campaign across multiple implementation generations. Protect current checkpoint and canonical seed inputs; organize historical material by role. |
| mini-campaign-20261017 | 1.99 | 3,395 | Fixed-packet, recursive and writer benchmark experiments. Archive benchmark evidence; outside the current frontier. |

## Recursive campaign: all 47 subdirectories

These rows are descriptive, not a declaration that every run completed. Archived generations can have distinct classifications or coverage. Directory sizes overlap where lineage archives are hard-linked.

| Directory under data/search/literature-b52-closure-20261014/ | GiB | Files | Role / recommendation |
| --- | --- | --- | --- |
| archive | 0.70 | 4 | Verified compressed source snapshots and manifests; Retain source identity and restoration paths. |
| catalog-audit-20261016T115652Z | 1.09 | 54 | Earlier published-reference comparison and snapshot; Retain historical scope receipts and comparison evidence. |
| cluster-code | <0.01 | 156 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v2 | <0.01 | 155 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v3 | <0.01 | 155 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v4 | <0.01 | 162 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v5 | <0.01 | 160 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v6 | <0.01 | 165 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v7 | <0.01 | 177 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| cluster-code-v9 | <0.01 | 173 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| compact-code-v15 | <0.01 | 178 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| compact-code-v16 | <0.01 | 178 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| continuous-controller-compact-v15-20261016 | 0.01 | 11 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| continuous-controller-v1-20261015 | <0.01 | 8 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| controller-fresh-20261017 | 0.02 | 4 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| diagrams | 0.01 | 93 | Pipeline figures and slide assets; PROTECT gallery/slide_pipeline.svg: the live dashboard serves it. |
| ea-only-controller-v1-20261015 | <0.01 | 5 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| finish-next100-controller-v1-20261015 | <0.01 | 7 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| finish-seed1-controller-v1-20261015 | <0.01 | 7 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| graph-dashboard-evidence-20261016 | <0.01 | 12 | Graph dashboard deployment evidence; Retain small deployment receipts. |
| history | <0.01 | 4 | Original campaign and qualification plans; Retain provenance. |
| monitor-cached-v8-code | <0.01 | 185 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-catalog-v18-code | <0.01 | 166 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-completion-v13-code | <0.01 | 163 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-continuous-v14-code | <0.01 | 163 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-graph-v17-code | <0.01 | 166 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-local32-code | <0.01 | 157 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| monitor-profile32-v9-code | <0.01 | 168 | Frozen deployment or dashboard source snapshot; Historical source identity; small, consolidate through verified archives. |
| prepared-v10-20261015 | 0.07 | 170 | Historical prepared deployment bundle; Superseded; preserve manifest and pinned inputs before consolidation. |
| prepared-v11-20261015 | 0.07 | 178 | Historical prepared deployment bundle; Superseded; preserve manifest and pinned inputs before consolidation. |
| prepared-v12-20261015 | 0.07 | 183 | Historical prepared deployment bundle; Superseded; preserve manifest and pinned inputs before consolidation. |
| prepared-v13-20261015 | 0.07 | 174 | Historical prepared deployment bundle; Superseded; preserve manifest and pinned inputs before consolidation. |
| profiling-evidence-v9 | 6.80 | 7,016 | Performance, storage and UI experiments; Keep conclusions and fixtures; benchmark SQLite files are cold evidence. |
| recursive-20261018T235746Z | 9.50 | 65 | Most recent stopped recursive controller evidence; Retain metrics and controller history; compress the historical classification baseline. |
| restart-controller-20261019T2100Z | <0.01 | 7 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| restart-controller-20261020-reduced | <0.01 | 6 | CURRENT: prepared restart controller; Keep; prepared only, not started. |
| resume-20261016T172118Z | 0.01 | 16 | Historical controller/configuration/launch evidence; Superseded; archive under controller history, preserve recorded paths. |
| run | 0.15 | 157 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-compact-v15-20261016 | 62.76 | 2,253 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-first-half | 0.11 | 160 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-fresh-20261017 | 35.53 | 2,122 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-local32-v7 | 8.27 | 862 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-profile32-v9-20261015 | 40.17 | 1,108 | Historical checkpoint / partial campaign generation; Retain scientific evidence; archived SQLite needs restoration before inspection or resume. |
| run-reduced-20261020 | 44.88 | 1,927 | CURRENT: stopped compact checkpoint; Keep online; dashboard and prepared restart use this run. |
| run-validation-20261018T232756Z | 3.39 | 5,531 | Retired database; retained reports, graphs, replay and provenance; Keep retirement receipt and evidence; the 213 GiB SQLite is already removed. |
| scope-reconciliation-20261017T024857Z | 0.53 | 51 | Published-root vs literature/historical comparison; Keep comparison evidence; three valid symlinks point to canonical freezes. |
| seed_count | 0.20 | 1,983 | Root qualification, 24,294 seeds and EA certificates; PROTECT: current identity binds files at these absolute paths. |

The campaign root additionally has 41 files: campaign and root-pool definitions, preparation/trace scripts, cluster configurations, old launch pointers and logs. These are individually indexed in the compressed manifest.

## Research categories

| Directory under data/research/ | GiB | Files | Purpose |
| --- | --- | --- | --- |
| analyses | 17.51 | 5,084 | Thirty dated analysis directories, including validation baselines. |
| archive | 0.77 | 55,165 | Historical census and class-orbit evidence plus restored source. |
| datasets | <0.01 | 1 | Registry selecting canonical dataset roles. |
| exports | 0.93 | 37 | Shareable derived datasets and receipts. |
| freezes | 1.37 | 28 | Earlier 190,454-class dataset and direct published-root dataset with comparisons. |
| reference | <0.01 | 2 | Small original-source comparison receipts. |
| references | 1.11 | 6 | Pinned published-only reference snapshot. |
| runs | 0.01 | 695 | Older search runs and inspector certificate evidence. |
| vault | 0.34 | 12 | Tracked compressed shared datasets and original raw search evidence. |

The older census archive contains **55,020 files in 0.75 GiB**. It explains much of the file-count clutter but contributes little to disk use. Its original code and raw inputs need provenance-preserving archiving.

## All 30 pre-existing analysis directories

| Directory under data/research/analyses/ | GiB | Files | Purpose |
| --- | --- | --- | --- |
| algebraic-core-reuse-20261018 | 0.01 | 45 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| campaign-maintenance-20261019 | <0.01 | 29 | Storage or maintenance receipts and tests; preserve migration/retirement evidence. |
| campaign-validation-20261018T232756Z | 8.19 | 31 | Checkpoint validation / fork evidence; dominated by a full classification-before.sqlite copy. |
| campaign-validation-index-20261018T234415Z | 8.24 | 46 | Checkpoint validation / fork evidence; dominated by a full classification-before.sqlite copy. |
| closure-class-graph-20261016T044350Z | 0.09 | 10 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| closure-optimization-20261018b | <0.01 | 23 | Scheduler, admission, kernel or storage optimization measurements. |
| closure-optimization-20261018c | <0.01 | 344 | Scheduler, admission, kernel or storage optimization measurements. |
| closure-optimization-20261018d | 0.01 | 673 | Scheduler, admission, kernel or storage optimization measurements. |
| closure-proof-views-20261018 | 0.01 | 669 | Scheduler, admission, kernel or storage optimization measurements. |
| closure-structure-20261016T020429Z | 0.09 | 18 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| combined-20261014-full-structure | 0.09 | 31 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| combined-20261014-structure | 0.06 | 15 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| coordinator-apply-20261019 | <0.01 | 164 | Scheduler, admission, kernel or storage optimization measurements. |
| coordinator-apply-20261019b | <0.01 | 167 | Scheduler, admission, kernel or storage optimization measurements. |
| coordinator-apply-barrier-20261019 | <0.01 | 167 | Scheduler, admission, kernel or storage optimization measurements. |
| ea-admission-20261018 | <0.01 | 18 | Scheduler, admission, kernel or storage optimization measurements. |
| historical-intersection-20261016T113319Z | 0.07 | 13 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| historical-rediscovery-20261016T042454Z | 0.07 | 21 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| odd-flat-circuits-20261018 | 0.01 | 36 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| packed-rank-20261019 | <0.01 | 15 | Scheduler, admission, kernel or storage optimization measurements. |
| published-roots-structure-20261018 | 0.12 | 19 | Dataset membership, structure or graph analysis at a recorded historical cutoff. |
| simultaneous-completion-20261018 | <0.01 | 39 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| storage-diagnosis-20261019 | <0.01 | 29 | Storage or maintenance receipts and tests; preserve migration/retirement evidence. |
| storage-reduction-20261020 | <0.01 | 36 | Storage or maintenance receipts and tests; preserve migration/retirement evidence. |
| u6-obstructions-20261018 | <0.01 | 2 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| v5-connectivity-draft-20261019 | 0.03 | 616 | Mathematical draft support and experiments; retain claim scope and evidence. |
| v5-native-hotspots-20261019 | <0.01 | 11 | Scheduler, admission, kernel or storage optimization measurements. |
| v5-redundancy-20261018 | 0.39 | 227 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| v6-frontier-incidence-20261018 | <0.01 | 14 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |
| v6-reuse-20261018 | 0.02 | 1,543 | Bounded mathematical reuse, obstruction, incidence or completion investigation. |

## Largest individual files

Hard-linked paths can appear twice; these rows are not additive.

| File | Allocated GiB | Hard links |
| --- | --- | --- |
| data/search/literature-b52-closure-20261014/run-reduced-20261020/closure.sqlite | 44.04 | 1 |
| data/search/literature-b52-closure-20261014/run-fresh-20261017/closure.sqlite.zst | 34.19 | 1 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/closure.sqlite.zst | 32.91 | 1 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/lineage/previous/closure.sqlite.zst | 15.90 | 2 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/closure.sqlite.zst | 15.90 | 2 |
| data/search/literature-b52-closure-20261014/recursive-20261018T235746Z/live/classification-before.sqlite | 8.33 | 1 |
| data/research/analyses/campaign-validation-index-20261018T234415Z/live/classification-before.sqlite | 8.23 | 1 |
| data/research/analyses/campaign-validation-20261018T232756Z/live/classification-before.sqlite | 8.19 | 1 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/continuous_passes/20261016T172118Z-until-stop/classification-before.sqlite | 7.56 | 1 |
| data/search/literature-b52-closure-20261014/run-local32-v7/closure.sqlite.zst | 5.74 | 1 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/lineage/previous/closure.sqlite.zst | 5.74 | 1 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/continuous_passes/20261016-until-stop/classification-before.sqlite | 5.10 | 1 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/continuous_passes/20261015-until-stop/classification-before.sqlite | 4.11 | 1 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/root_passes/20261015-seeds2-101/classification-before.sqlite | 4.09 | 1 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/parent_passes/20261015-seed1/classification-before.sqlite | 4.09 | 1 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/ea_passes/20261015T213534Z/classification-before.sqlite | 3.43 | 1 |
| data/search/b52-20261014-split-24-12/combined/run.sqlite | 3.24 | 1 |
| data/search/b52-20261014-split-24-12/hypatia12/run.sqlite | 2.78 | 1 |
| data/search/b52-20261014-split-24-12/local24/run.sqlite | 2.32 | 1 |
| data/search/b52-20261014-split-24-12/hypatia12/implementation_history/20261014-progress-v1/run.sqlite | 2.29 | 1 |
| data/search/b52-20261014-split-24-12/local24/implementation_history/20261014-progress-v1/run.sqlite | 2.19 | 1 |
| data/search/b52-20261014-9h-30t/run.sqlite | 1.90 | 1 |
| data/search/b52-20261014-split-24-12/original_snapshot.sqlite | 1.90 | 1 |
| data/search/literature-b52-closure-20261014/profiling-evidence-v9/sustained-forwarding-pipeline/results/gc8-long/closure.sqlite | 1.41 | 1 |
| data/search/b52-20261014-9h-30t/publication/snapshot.json | 1.15 | 1 |

## Historical classification copies

There are **30 `classification-before.sqlite` files totaling 53.20 GiB**. Ten substantial copies account for almost all of this; twenty miniature benchmark copies are small. `tools/closure_baseline.jl` defines their scope: metadata, candidates, parents, jobs, comparisons and sessions at an earlier point. They omit construction path/kernel/chunk tables; these are historical projections, not complete campaign checkpoints.

| File | GiB |
| --- | --- |
| data/search/literature-b52-closure-20261014/recursive-20261018T235746Z/live/classification-before.sqlite | 8.33 |
| data/research/analyses/campaign-validation-index-20261018T234415Z/live/classification-before.sqlite | 8.23 |
| data/research/analyses/campaign-validation-20261018T232756Z/live/classification-before.sqlite | 8.19 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/continuous_passes/20261016T172118Z-until-stop/classification-before.sqlite | 7.56 |
| data/search/literature-b52-closure-20261014/run-compact-v15-20261016/continuous_passes/20261016-until-stop/classification-before.sqlite | 5.10 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/continuous_passes/20261015-until-stop/classification-before.sqlite | 4.11 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/root_passes/20261015-seeds2-101/classification-before.sqlite | 4.09 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/parent_passes/20261015-seed1/classification-before.sqlite | 4.09 |
| data/search/literature-b52-closure-20261014/run-profile32-v9-20261015/ea_passes/20261015T213534Z/classification-before.sqlite | 3.43 |
| data/search/literature-b52-closure-20261014/run-fresh-20261017/continuous_passes/20261018T002004Z-until-stop/classification-before.sqlite | 0.06 |

The continuous controller uses `baseline_policy = "summary"` by default. Existing full copies still document earlier classifications and cursors. Lossless compression with hashes and restore receipts can reduce their footprint. Deleting them requires a separate retention decision or evidence that their historical information is reproduced elsewhere.

## Current paths to protect

The registry `data/research/datasets/registry.json` selects these distinct scopes:

| Registry role | Path relative to package |
| --- | --- |
| published_reference | data/research/references/published-literature-20261017 |
| historical | data/research/freezes/apn-20261014-190454/classes.sqlite |
| published_root_results | data/research/freezes/published-roots-b52-20261017/classes.sqlite |
| comparison_evidence | data/research/freezes/published-roots-b52-20261017/comparisons.sqlite |
| recursive_campaign_archive | data/search/literature-b52-closure-20261014/run-compact-v15-20261016/closure.sqlite.zst |
| current_recursive_checkpoint | data/search/literature-b52-closure-20261014/run-reduced-20261020/closure.sqlite |

The current checkpoint identity pins these canonical input paths:

- `data/search/literature-b52-closure-20261014/campaign.toml`
- `data/search/literature-b52-closure-20261014/published_pool.toml`
- `data/search/literature-b52-closure-20261014/seed_count/EA_certificates.tsv`
- `data/search/literature-b52-closure-20261014/seed_count/equivalence_result.toml`
- `data/search/literature-b52-closure-20261014/seed_count/result.toml`
- `data/search/literature-b52-closure-20261014/seed_count/selected_roots.tsv`
- `data/search/literature-b52-closure-20261014/seed_count/verified_roots.tsv`

Keep the current checkpoint replay, identity, migration receipt, lineage, reports and graph snapshot. The prepared restart is `data/search/literature-b52-closure-20261014/restart-controller-20261020-reduced/`; it has not started. The live dashboard serves `data/search/literature-b52-closure-20261014/diagrams/gallery/slide_pipeline.svg`.

The superseded 213.17 GiB original SQLite is already removed. Its retained run directory contains retirement receipts, reports, replay and graphs; removing that directory wholesale would discard different evidence. The current graph shares immutable payloads through hard links.

## Organization issues

1. Seven `active-*.json` files at the campaign root describe older generations. `current-recursive-plan.json` still names the retired pre-reduction database. They are historical evidence, not authoritative current-state pointers. The registry and actual dashboard arguments select the reduced checkpoint. Preserve old metadata as history, then introduce one documented operational pointer.

2. The recursive campaign mixes checkpoints, controller generations, frozen source bundles, profiling runs, figures and comparison studies. Many small code directories create clutter but use little space.

3. Checkpoint lineage uses hard links: deleting one apparent duplicate name may reclaim no data blocks.

4. Two archives have the same compressed length, 6,162,330,494 bytes, but different recorded SHA-256 values: `run-local32-v7/closure.sqlite.zst` and `run-profile32-v9-20261015/lineage/previous/closure.sqlite.zst`. Their original database hashes also differ. Do not merge them by name or size.

5. Older package/research README history still describes private legacy discoveries as being in the default catalog. [DATASETS.md](DATASETS.md) documents the current published-only policy. Those older examples need a separate documentation pass before being treated as current recipes.

6. The scan found 157 non-symlink `.sqlite` paths and 17 `.sqlite.zst` paths, across experiments and fixtures. File presence does not establish database health or scientific equivalence.

## Proposed cleanup sequence

1. Use this index, [DATASETS.md](DATASETS.md) for dataset meaning and [STORAGE.md](STORAGE.md) for restoration. Classify each path by role before changing it.

2. Compress the 53.20 GiB of historical classification projections and large stopped logs with hashes and restore instructions. This preserves earlier states. That is input size, not a promised saving; measure actual compression.

3. Treat the **96.66 GiB of unique archived closure-checkpoint allocations** as cold scientific evidence. If local space is the priority, move verified copies to external storage while maintaining manifests and restoration paths. Do not assume every old checkpoint is a scientifically redundant subset.

4. Consolidate superseded source/controller/profiling directories into verified archives, leaving manifests or compatibility paths where identities and restore scripts expect the old layout. Keep production tools and source-pinned fixtures in their tested locations.

5. Give future campaigns a predictable structure for checkpoints, controller sessions, measurements and figures. Use the dataset registry for canonical dataset roles and one operational pointer for the selected run.

6. For a 60 GB cluster node, prepare an explicit runtime manifest with the compact checkpoint, pinned code and inputs, and required references. The full 238.88 GiB package data tree will not fit. SQLite alone is not a complete resumable campaign.

No experiment deletion or relocation was performed during this inventory.
