# Trillium readiness audit

Audited on 2026-10-20 against commit `810cab9` by separate scheduler, storage
and deployment reviews. This is an implementation plan, not an installed
cluster backend. The workstation campaign was left running.

The general operational improvements have since been implemented; see
[campaign operations](OPERATIONS.md) for their APIs, limits and tests. The findings
below describe the audited baseline. Trillium deployment and a multi-node worker
backend remain separate work; no cluster performance is established here.

The recursive search needs migration and shutdown support before a reliable
single-node pilot. Large multi-node execution additionally needs a worker
transport and failure protocol. Increasing the Slurm node count alone will
not distribute this controller.

## Trillium constraints

The official [quickstart](https://docs.alliancecan.ca/wiki/Trillium_Quickstart)
was checked at revision **204255**. Its relevant requirements are:

- CPU jobs receive whole **192-core nodes**; useful utilization of the whole
  allocation is required. Memory requests do not select a smaller node.
- The regular CPU partition permits at most **24 hours**; the debug partition
  permits a one-node, one-hour pilot.
- Compute jobs write to **`$SCRATCH`**. Both `$HOME` and `$PROJECT` are read-only
  there. Dependency installation and package precompilation need suitable paths.
- Compute nodes have no Internet access and cannot submit jobs. Prepare software
  beforehand; submit continuations from the login node.
- The current quickstart describes **VAST** shared storage and a nominal
  **25 TB/user scratch quota**, subject to the applicable policy/group quota.
  Our proposed 60 GB budget is a separate application constraint.

The [storage guide](https://docs.alliancecan.ca/wiki/Data_management_at_Trillium)
states that nodes have no local disks and **`$SLURM_TMPDIR` is RAM-backed**, emptied
after the job. It contains older hardware/filesystem figures that disagree with
the quickstart; do not infer a RAM allowance, current filesystem block size or
purge schedule from those figures. Check the actual allocation and site policy.

## Required changes

| Priority | Repository evidence | Change and completion criterion |
|---|---|---|
| Before migration | [closure.jl](src/closure.jl#L36), [closure_store.jl](src/closure_store.jl#L144) store and verify original absolute input paths. | Add an explicit execution path map, resolved by logical input identity and verified digest. Preserve the scientific identity and record relocation lineage. A copied checkpoint must resume under a different directory prefix with the original paths unavailable; wrong input bytes must still fail. |
| Before migration | [closure_store.jl](src/closure_store.jl#L147) pins sources/environment and exact Julia version; [provenance.jl](src/provenance.jl#L3) fingerprints the root manifest. The current checkpoint pins Julia **1.13.2**. | Bundle the exact Julia runtime/build, frozen sources, both the root and active `docs/inspector` Project/Manifest files, references, inputs and checksums. Instantiate dependencies before batch execution. Do not replace the pinned runtime with a default module without a validated transition. |
| Before pilot | [cli.jl](src/cli.jl#L47) exposes a one-worker closure adapter; [closure_continuous.jl](tools/closure_continuous.jl#L440) is the maintained threaded entry. The existing [validation launcher](tools/analysis/launch_campaign_validation.py#L35) assumes systemd and workstation paths. | Add a tracked Slurm launcher for `closure_continuous.jl CONFIG.toml`, configurable paths and explicit CPU/thread budgets. No systemd dependency inside the batch job. Validate controller concurrency against Julia's default thread pool and the Slurm allocation. |
| Before pilot | [closure_continuous.jl](tools/closure_continuous.jl#L113) polls STOP and an optional deadline, but no Slurm warning wrapper exists. EA attempts can last up to their configured 300-second budget. | Translate an advance Slurm warning into STOP, stop reserving work, drain active packets, close the session and publish a consistent checkpoint. Select the warning/deadline margin using measured startup, drain and export time; a single computation can overrun a slice. |
| Before pilot | [closure_store.jl](src/closure_store.jl#L135) opens WAL with FULL synchronization and a single-writer lease. | Keep the live database and all its readers on the coordinator host with suitable local filesystem semantics. Stage/publish consistent immutable generations on shared storage. Worker nodes and a remote dashboard must not directly open the live WAL database. |
| Before long runs | [closure_continuous.jl](tools/closure_continuous.jl#L119) has no live disk/quota high-water stop. | Add budgets for DB, WAL, reports, telemetry and checkpoint staging. Include quota availability as well as free filesystem space. Stop cooperatively while enough headroom remains for draining and checkpoint publication. |
| Before long runs | [closure_continuous.jl](tools/closure_continuous.jl#L289) appends packet telemetry indefinitely; [live_catalog_report.py](tools/analysis/live_catalog_report.py#L58) holds a source snapshot across its entire unseen backlog. | Rotate/compress bounded telemetry segments; aggregate metrics. Bound reporting source transactions so they do not pin WAL through an arbitrarily large catch-up. Perform graph/global analyses on immutable snapshots. |
| Before multiple nodes | [closure_refill.jl](tools/closure_refill.jl#L52) uses local `Threads.@spawn`; no maintained distributed backend is installed. | Introduce a replaceable transport for DB-free compute packets inside the Slurm allocation. Retain authoritative reservations, ordered application and EA admission at the coordinator initially. Measure transport bytes and coordinator saturation before scaling out. |
| Before multiple nodes | [closure_refill.jl](tools/closure_refill.jl#L98) has no remote heartbeat/assignment timeout; [closure_algorithms.jl](src/closure_algorithms.jl#L355) deliberately rejects stale or already-applied construction packets. | Add assignment/attempt IDs, worker heartbeats, bounded retries and durable result receipts. A repeated delivery must acknowledge the existing receipt without applying the packet twice. Preserve the cursor guards. |
| For a strict bounded disk budget | [closure_store.jl](src/closure_store.jl#L61) retains paths, coverage, candidates and comparisons indefinitely. [closure_upgrade.jl](src/closure_upgrade.jl#L200) can retain the source plus two snapshot copies. | Separate sealed, compressed provenance segments from the hot admission/frontier store, with indexed references and verified replay. Budget staging peaks and avoid unnecessary full copies. Compression alone does not bound an unending search. |

The [SQLite WAL documentation](https://sqlite.org/wal.html) requires same-host
coordination and warns against network filesystems. An application `flock`
does not make a shared live WAL safe across nodes. A move to a client/server
database is an alternative architectural choice, not necessary merely to add
remote compute workers.

Any change to fingerprinted core code needs an explicit, validated implementation
transition as well as relocation; it cannot silently resume under the old source
identity. The launch bundle must **verify** the active inspector Project/Manifest,
which the core fingerprint does not currently cover. Keep login-node preparation
within the site's small-test limits; perform heavy precompilation in an allocated
debug job after dependencies have been staged for offline use.

A tested path-preserving container is another possible migration route:
[Apptainer bind mounts](https://apptainer.org/docs/user/latest/bind_paths_and_mounts.html)
can expose staged files at their original absolute paths without changing input
hashes or the frozen code. Site support and the complete path/runtime mapping
must be verified before choosing this route; no such container was tested here.

## Measured storage and utilization

The following are stat-only observations during this audit, not a database scan.
They grow while the campaign runs:

| Item | Bytes |
|---|---:|
| Live normalized checkpoint | 66,805,579,776 |
| Its WAL | 313,643,272 |
| Catalog classification cache | 699,052,032 |
| Structure feature cache | 415,010,816 |
| Current packet telemetry | 828,824,764 |

The checkpoint alone is **66.81 GB / 62.22 GiB**, exceeding either a strict
60 GB or 60 GiB budget before staging, inputs, dependencies or archives. The
44.04 GiB figure in [STORAGE.md](STORAGE.md) is the earlier migration cutoff.
This does not establish a current workstation free-space emergency; it means
that the proposed cluster budget cannot hold the present full checkpoint.
Separating hot and cold evidence can address a 60 GB **hot-store** target only
with additional capacity for the cold evidence. It cannot keep unlimited total
evidence inside a strict 60 GB budget.

Existing storage reductions and controller optimizations should be retained:
VBFCHN02 lossless coverage packing, binary LUTs, SHA-indexed exact proof-template
interning, shared rank tables, continuous slot refill, bounded FULL-sync batches,
per-application savepoints, the pending-EA partial index and summary baselines.
Hashes are storage indexes; equal signatures are never equivalence proofs.

The controlled two-parent replay in [STORAGE.md](STORAGE.md) improved from
119.19 to 79.99 seconds and from 8.50 to **15.27 average cores**. Scientific
outputs agreed across arms. That small replay does not establish scaling to
192 cores. Whole-node production should follow a scaling measurement, not an
assumption that 192 Julia threads will remain occupied.

## Execution and storage topology

```text
login node: prepare dependencies, submit jobs, arrange continuations
                              |
shared SCRATCH: frozen inputs, immutable checkpoint generations,
                compressed evidence segments, dashboard JSON snapshots
                              |
                     stage / publish / verify
                              |
coordinator node: RAM-backed local working directory on Trillium
  sole live SQLite + WAL; all live SQLite reporting readers
  frontier reservations -> ordered durable application -> EA admission
                              |
                 bounded compute packets / results
                    /          |          \
              worker node  worker node  worker node
              immutable inputs + private scratch; no live DB access
```

This topology is proposed, not implemented. RAM-backed SQLite consumes part of
the allocation's memory and is lost on node failure, even with `synchronous=FULL`.
Periodic [SQLite backups](https://sqlite.org/backup.html), verified manifests,
atomic generation publication and retention are required to bound lost work.
Account for a working DB, backups, report caches, Julia heaps and buffered results
together. If this staging footprint is unsuitable, evaluate a different
persistence backend before production.

Do not copy just `closure.sqlite` while it is live. `_closure_close` requests a
PASSIVE WAL checkpoint, which need not merge every committed page when other
readers remain. Use SQLite's backup API or quiesce all readers and verify a full
checkpoint before packaging. Preserve the previous verified generation until
its successor is fully published. Copies in scratch are not long-term backups;
archival to project/nearline must use a site-supported route with write access.

Separate initial-root partitions do not give disjoint recursive searches:
descendants can converge. Preserve global EA admission. A later admission
partition by signature is mathematically sound because different signatures
separate classes; every candidate with the same signature must reach the same
owner and still receive an EA decision. Keep the existing snapshot revalidation
in [closure_equivalence.jl](src/closure_equivalence.jl#L122) when new targets arrive.

Dagger or Julia Distributed could implement worker scheduling/transport. Neither
supplies our scientific admission rule, receipt protocol, checkpoint publication
or storage budget automatically. Slurm owns the allocation in either case.

## Pilot and acceptance sequence

1. Implement relocation and bundle verification. Test a small checkpoint with
   renamed directories and unavailable originals, corrupt input/archive bytes,
   and a mismatched Julia runtime. Preserve the completed 24,294 published roots
   and `parent_scope="discovered"` when migrating this recursive campaign.
2. Add the Slurm wrapper and storage guard. Start with **one node, one Slurm task**
   on the debug partition. Use all allocated CPUs for the overall profiling
   experiment; short 32/64-slot measurements are scaling diagnostics rather than
   a production allocation policy. Budget compute, GC, coordinator and reporting
   threads together. Use `OPENBLAS_NUM_THREADS=1`.
3. Retain `extension_cosets=65536`, `switching_directions=255`,
   `baseline_policy="summary"`, `indexed_ea_queue=true`, the scientific plan and
   full EA verification. Start with `reservation_horizon=2*concurrency`; increase
   only when buffered-result memory and head-of-line waiting justify it.
4. Test advance-warning STOP/drain/export, restart on another allocated node,
   hard termination, missing WAL, failed transfers and incomplete snapshot
   publication. A failure must preserve the last verified generation. Use
   [Slurm's documented warning signals](https://slurm.schedmd.com/sbatch.html#OPT_signal)
   with a batch-shell trap; a final SIGTERM alone is not a graceful-stop test.
5. Compare paths, coverage streams, kernels and EA partitions against the bounded
   local fixture. Existing [controller](test/closure_controller.jl),
   [refill](test/closure_refill.jl) and [batch](test/closure_batches.jl) tests cover
   useful local invariants; add deployment/failure tests and a smoke test for the
   actual pinned runtime. Current CI exercises Julia 1.12, not this checkpoint's
   1.13.2 environment.
6. Measure committed work/core-hour, construction versus EA busy time, admission
   backlog, coordinator CPU, ready-result waiting, peak buffered bytes, DB/WAL
   growth, bytes transferred and checkpoint/drain latency. Record Slurm job ID,
   hostname and allocated CPUs in the producing processes. The dashboard's local
   PID sampler is insufficient for a controller on another machine.
7. Add remote transport and run the same bounded workload on one then two nodes,
   including killed workers, duplicate results and reordered messages. Compare
   scientific results and useful throughput before requesting larger allocations.

No Trillium account, allocation, job submission, node access or actual cluster
performance was tested during this audit. No new runtime changes were deployed
to the running workstation campaign.
