# Long-running recursive campaigns

The threaded controller has scheduler-independent launch, storage limits,
bounded telemetry, process-owned performance metrics, portable checkpoints and
optional cold coverage segments. These controls preserve the construction plan,
coverage and verified EA admission rules. They do not implement multi-node workers.

Existing campaigns use frozen sources. Developing these changes does not deploy
them to an already running process. Stop and use a verified execution upgrade
before adopting changed core sources; never overwrite a live replay workspace.

## Launch and stop

Start a new recursive CPU search with one command:

```sh
bin/vbfsearch --recursive-closure -j 8 --start=1 --end=100 --time=1h --output=results.sqlite
```

Add this checkout's `bin/` directory to `PATH` to invoke it as `vbfsearch` from
any working directory. `bin/vbfsearch --help` lists the supported options.

No launch TOML is required. `--start` and `--end` are inclusive, one-based rows
in the audited published-root list, not internal checkpoint parent IDs. Reached
quadratic descendants are unrestricted by that interval. Each invocation creates
a fresh output; existing output is refused. Resume is not part of this command.
By default, output is a single timestamped `.sqlite` file under `data/search/`.
An explicit `.sqlite`, `.sqlite3` or `.db` filename selects the same format.
The finished database contains scientific tables, LUTs, construction witnesses,
coverage and comparisons. Configuration, reports, telemetry and frozen source/input
evidence are embedded in `vbfsearch_artifacts(path, sha256, bytes, content)`.
The `metadata` table holds `vbfsearch_command`, `vbfsearch_result` and the
`vbfsearch_output` archive manifest. Ordinary SQLite clients can query the file
without its former working directory or original input files.

During the search, commits go to an adjacent hidden workspace, for example
`.results.sqlite.work/`, with SQLite journals as needed. On a clean stop, the
command embeds and verifies the evidence, checkpoints the WAL, closes the database
and publishes it under the requested filename. Publication uses a hard link on
the same filesystem, avoiding a full database copy, then removes the workspace.
Packaging reads the evidence files, not every scientific result row. A failure
before publication keeps the workspace for inspection; a hard kill can also leave
working files. Do not delete those while the command is active. A path without
one of the database suffixes retains directory output with `command.toml`,
`state/` and `session/` for advanced use.

Add `--dry-run` to inspect the seed range, thread pools, time limit, input plan and
output path without creating files or loading the search engine. Omit `--time`
to run until stopped. The time budget includes worker startup and input checks;
dispatched work drains afterward. Ctrl-C, TERM and USR1 use the existing
cooperative supervisor, with a 600-second drain grace.

Use `-j 1` for one compute thread. Bare `-j` selects all local compute threads or
automatically budgets compute, interactive and GC pools within
`SLURM_CPUS_PER_TASK`. An explicit count is validated against that allocation;
the maintained validator requires at least two allocated CPUs for one compute
thread plus serial GC. Local one-thread checks do not require a Slurm allocation.
BLAS/OMP threads are fixed to one. `--heap=16G` overrides the heap hint.

`--gcthreads=8,0` selects eight GC collectors and disables concurrent page
sweeping. The second value defaults to zero; `--gcthreads=16` is equivalent to
`16,0`. Bare `-j` includes these pools in its Slurm CPU budget. For example,
192 allocated CPUs with `--gcthreads=8,0` select 183 compute threads, one
interactive thread and eight collectors; `16,0` selects 175 compute threads.
An explicit pool configuration that exceeds the allocation is refused.

Concurrent sweeping defaults off because Julia 1.13.0 has a
[page-pool race](https://github.com/JuliaLang/julia/pull/62162) in that path.
This launch setting avoids the affected path while retaining parallel GC
collectors; it requires no modification of the Julia runtime. The historical
measurements below used `8,1` before that diagnosis. An explicit `8,1` remains
available for comparisons on a runtime containing the upstream correction.

The one-command worker batches up to 64 switching directions per packet and
65,536 V5 cosets. These limits amortize preparation and are frozen in the search
identity. Switching retains its 256-candidate evaluation cap and checks stop/time
limits within a batch. Local matched tests found that 64 directions shortened
the serial switching tail; performance on other seed ranges can differ.

The default seed plan is the installed
`data/search/literature-b52-closure-20261014/campaign.toml` beneath
`VBF_SEARCH_DATA_DIR` (normally this package's `data/`). Use `--campaign FILE` or
`VBF_SEARCH_CAMPAIGN` for an audited copy elsewhere. Dependencies and its audited
seed files must already be installed; initialization verifies the existing
qualification/equivalence evidence before construction. This command neither
downloads data nor connects to a cluster.

The equivalent Julia invocation is:

```sh
julia --project=. packages/VBFSearch/tools/vbfsearch.jl --recursive-closure -j 8 --start=1 --end=100 --time=1h --output=results.sqlite
```

The configuration-based entry point remains available for advanced operational
policies:

Instantiate dependencies beforehand, then start a fresh evidence directory:

```sh
julia --startup-file=no --project=docs/inspector \
  --threads=8,1 --gcthreads=1,0 \
  packages/VBFSearch/tools/closure_run.jl campaign.toml
```

Alternatively set `JULIA_NUM_THREADS` and use
`bin/vbf closure continuous campaign.toml`. The existing `closure run/resume`
adapter retains its serial behavior. Paths in the TOML configuration resolve
relative to that file. No systemd service or machine-specific directory is required.

The launcher validates compute slots before loading the controller. An explicit
`cpu_allocation` and, when present, `SLURM_CPUS_PER_TASK` both constrain the total
default, interactive and GC thread pools. The smaller applicable allocation wins.
Without an explicit/scheduler allocation, compute slots still cannot exceed
Julia's default pool. BLAS threads should be configured separately, usually to 1.
When `concurrency` is omitted it now uses the whole default pool; an explicit
value still takes precedence. The launcher reports the V5 buffer lower bound
(about 49.5 MiB per fully initialized eight-bit slot, plus the shared rank table)
and warns when the heap hint leaves little room beyond it. A heap hint controls GC
heuristics, rather than limiting all process memory. Budget EA state, buffered
results, SQLite, reporting and RAM-backed checkpoint storage separately.
Each slot reuses its histogram and bitmap instead of allocating them for every
V5 packet. Component-subspace membership tables are shared read-only across
workers; the usual eight-bit preparation table occupies about 3 MiB.
DU7 matrices also reuse private capacity, retaining at most 8 MiB of array
payload per slot. Larger requests use fresh temporary arrays. Budget this
capacity separately from the reported V5 lower bound; replacing old arrays can
briefly retain both allocations until GC. These caches reduce allocation churn;
garbage collection remains enabled.

The launcher replaces itself with a small Python 3 supervisor on POSIX systems.
`USR1`, `TERM`, `INT` and an optional supervisor deadline create cooperative STOP
requests. A private control file handles signals arriving before the controller
creates its evidence directory. The supervisor waits for drain and only kills its
owned child process group after `shutdown_grace_seconds`; a timeout returns 124.
Set the grace to cover startup, indivisible work, drain and any final export.

## Operational configuration

```toml
run = "working-checkpoint"
evidence = "sessions/run-001"       # must be new for every invocation
concurrency = 8
reservation_horizon = 16
reservation_refill_batch = 1        # opt-in query batching; between 1 and the horizon
window_size = 100
parent_scope = "discovered"         # retain completed published-root provenance
baseline_policy = "summary"
indexed_ea_queue = true
report_interval_seconds = 15.0
global_count_interval_seconds = 60.0 # 0 recounts on every publication
cached_global_counts = false        # opt-in transactional session-local counters
rolling_windows = false             # opt-in overlap of at most two parent windows
shared_property_cache_entries = 8192 # exact LUT keys; 0 keeps separate slot caches
max_apply_per_step = 8               # defaults to concurrency; refill runs between applications

min_free_bytes = 2147483648          # 2 GiB, default
storage_reserve_bytes = 1073741824   # 1 GiB drain allowance, default
storage_max_bytes = 0               # uncapped total size; set an explicit ceiling
storage_check_seconds = 15.0
telemetry_segment_bytes = 16777216
telemetry_keep_segments = 4
measure_result_bytes = false        # enable if measuring buffered-result memory
shutdown_grace_seconds = 600.0

# Optional: includes startup in the external wall-clock deadline.
# supervisor_duration_seconds = 3600.0

# Optional verified exports; allow working + retained + one staging generation.
# checkpoint_directory = "snapshots"
# checkpoint_interval_seconds = 3600.0
# checkpoint_keep = 2
# checkpoint_on_stop = true

# Optional compressed evidence outside the active SQLite database.
# evidence_segment_directory = "cold-evidence"
# evidence_segment_interval_seconds = 60.0
# evidence_segment_rows = 256
# evidence_segment_bytes = 16777216
```

Storage accounting includes the run, current evidence, configured checkpoint
directory, configured/already-bound cold evidence and additional `storage_paths`.
Overlapping roots and hard links count once; symlinks are not followed. Checks
use file metadata rather than scanning SQLite rows. A ceiling includes the drain
reserve; free-space checks also preserve `min_free_bytes`. These are conservative
operational allowances, not a mathematical upper bound on packet output sizes.

The controller checks while waiting for workers as well as between completed
packets. A limit latches STOP, drains dispatched successful work, commits cursors
and finishes as `paused_storage`. A final export is skipped if it cannot fit.
Optional maintenance does not start after an external stop or deadline.

Filesystem free space does not report every user/project quota. An optional
`quota_status_file` adapter must atomically publish JSON with `available_bytes`
and `updated_epoch`; readings older than `quota_max_age_seconds` (default 300)
stop work. Checkpoint staging is included in both quota and total-size preflight.
The adapter itself is site-specific; no quota command is assumed by the controller.

## Metrics and reports

`progress.toml`, the evidence directory's `progress.json` and final `result.json`
contain storage policy and runtime diagnostics. They identify the producing host,
PID, job ID and actual Julia pools. Linux CPU time uses that process and the
runtime clock-tick frequency, rather than interpreting a remote PID locally.

Metrics separate construction/EA compute durations, application time, ordered
result waiting, queue preparation/reservation, GC, reporting and checkpoint time.
Packet totals cover the controller run; scheduler counters describe the current
or latest refill pool. Compute durations overlap across slots and are not CPU
time. Buffered-result size measurement is opt-in because traversing results has
a cost. This is diagnostic instrumentation, not a claim of improved CPU scaling.

The scheduler also integrates active-slot, queued-ticket, completed-ticket,
underfilled and horizon-backpressure time. `average_active_slots` includes
dispatch-to-receipt delay; `compute_slot_seconds` sums overlapping task wall
durations. Neither measures actual CPU use. Compare process CPU time and
committed work per second when tuning `reservation_horizon` and concurrency.

`ordered_head_wait_seconds` and `horizon_wait_seconds` count actual event waits,
excluding coordinator application, reservation and maintenance. The broader
`horizon_backpressure_seconds` also includes coordinator activity while the
horizon is full. A full result buffer alone does not establish idle CPU time.

Slots share a bounded cache of freshly verified exact-LUT properties, allowing
construction results and later EA tasks to reuse verification across slots.
Miss calculations and boundary copies run outside its lock; callers receive
independent results and every packet still checks its exact byte identity.
`property_cache` metrics report capacity, retained entries, hits and misses.
The cache lasts for one controller invocation and is never populated from
transported property claims or unverified database metadata.

Global report counts refresh at `global_count_interval_seconds`, with freshness
and age recorded in each report. Window folds, final reports and checkpoints
force a fresh count. Worker completions are harvested between bounded apply and
prepare steps, so ready slots can refill while the coordinator drains a result
backlog. `reservation_refill_batch` waits for that many ticket positions to become
available before refilling all available positions in one reservation call. The
threshold follows the ordered applied prefix, independent of worker completion
order. Larger batches can change admission order across configurations; measure
committed throughput and `reservation_calls` when tuning. Ordered application,
authoritative EA admission and memory limits remain in force. `rolling_windows=true` admits a second bounded parent cohort before the
first drains; `max_windows` still caps the number admitted, including on STOP.

`cached_global_counts=true` replaces subsequent global count scans with one
connection-local TEMP row. Triggers track candidate and parent changes in the
same transactions and savepoints as scientific writes. An invocation starts
with exact counts; a resumed invocation rebuilds its counters. No counter state
enters a checkpoint. Completed published-root summaries can also be cached after
a committed, identity-matched terminal observation; partial summaries refresh.

Counters trade extra mutation work for cheaper reports. A synthetic one-million
candidate experiment added about 0.21 seconds per 50,000 candidate cycles without
reports, but saved 0.71 seconds when ten exact count refreshes were required.
That experiment excludes mathematics, proofs and durable commits. Use the
recorded production cardinality and refresh timings to evaluate this option;
small checkpoints should retain the default. The bounded experiment tool is
`tools/analysis/closure_report_counter_bench.jl`.

Each JSONL telemetry stream retains one active file and a bounded number of
compressed segments. Rolling/lifetime aggregate metrics remain available after
old samples expire. A telemetry error disables cosmetic logging and records a
best-effort diagnostic; it does not discard scientific evidence or abort a
successfully applied packet.

Resume drains pending EA comparisons even when no construction parents remain.
Reports distinguish construction, equivalence and idle windows; an EA-only window
does not count as a completed seed or dispatch excluded published-root jobs.

The published-catalog reporter now releases the source snapshot after each bounded
ID interval, before committing its own cache. Rows and incremental counters commit
together. `--batch-size`, `--max-batches` and `--refresh-seconds` bound catch-up;
reports explicitly expose the checked cutoff, target cutoff and backlog. A partial
catch-up is not presented as a complete current comparison.

## Portable checkpoint generations

```sh
bin/vbf closure export working-checkpoint --output snapshots/generation-001
bin/vbf closure verify-bundle snapshots/generation-001
bin/vbf closure relocate copied-working-checkpoint
```

Directory export requires an exclusive writer lease. Periodic exports use the
owning coordinator between transactions. SQLite backup includes committed WAL
pages; a live main-file copy is not an export. A generation is staged, verified,
synced and atomically published, with per-file hashes and runtime/environment
pins. Cold segments and archived operational code/configuration are included
automatically. Failed publication preserves the preceding verified generation.

Keep published generations immutable. Verify one, make a working copy, then
launch with its frozen project and archived controller. For the usual inspector
environment the project is `WORKING/replay/workspace/docs/inspector`. Controller
sources and per-session configurations are under `WORKING/execution/`; create a
new configuration pointing `run` and `evidence` at their new execution locations.
Instantiating a frozen environment must not resolve different package versions.

Input relocation uses digest-checked archived inputs and a separate execution
path map. Original absolute input paths can disappear. Scientific identity remains
unchanged; exact source, Julia build and active Project/Manifest checks remain.
Execution upgrades preserve bindings and lineage under the new implementation.
Unsupported legacy compaction/reduction paths reject relocated or sealed inputs
instead of creating an incomplete copy.

CPU changes to VBF, property verification or storage require an explicit
performance transition, rather than resuming under a changed source identity:

```sh
bin/vbf closure upgrade stopped-working-checkpoint --output upgraded-checkpoint \
  --switching-directions 255 --performance-evidence performance-validation.json
```

The validation JSON binds the complete old/new implementation fingerprints,
Julia version, identical fixture digest and completed replay digests for paths,
classes, switching kernels and coverage. Only the listed CPU implementation
files may change; dependencies, catalog inputs and unrelated mathematics remain
pinned. This is bounded computational evidence. The upgrade archives it, retains
the predecessor and copies referenced cold segments into both generations. The
original checkpoint is never rewritten. Ordinary upgrades keep their narrower
controller-only policy. Use a new evidence directory and a frozen upgraded
project when launching; an older Julia process cannot adopt these changes.

`tools/analysis/closure_cpu_replay.jl CONFIG.json` records those replay fields,
allocation/GC/process CPU measurements and scientific digests from an isolated
fixture. Initialize each arm in a fresh directory and process. The fixture has
`roots` and `reference_parents` tables; this tool never opens a production
checkpoint. Compare old sources through their frozen project, then current
sources with the same inputs. Keep all other test/search processes idle during
timing. The resulting summaries form the `before` and `after` objects of a
`vbfsearch-cpu-performance-validation-v1` document.

Set `warm_controller=true` in the replay JSON to measure steady-state work after
one complete identical controller replay in the same process. The measured run
gets a new checkpoint and new worker/property caches; the compiler remains warm.
Both runs must finish their finite plans and agree on all four scientific
digests. Cold-run timing is retained separately. `peak_rss_bytes` is the process
lifetime high-water mark, including initialization and the cold prepass.
Linux summaries also separate coordinator and other OS-thread CPU consumption
from inclusive scheduler wall timers and record process I/O deltas.

The four scientific digests do not compare source-bound EA proof text. The
separate admission/job audit records unresolved work and comparison outcomes;
when checking exact solver-path parity, compare the retained witness, node and
RNG slots as well. Timed runs should remain isolated from tests and reporting
services.

The first completed 20 October 2026 CPU comparisons use two retained campaign parents and a
frozen reference fixture on 16 physical / 32 logical CPUs with Julia 1.13.2 and
single-thread BLAS. Each completed main-fixture arm produced 23,850 packets,
41,352 paths, 34,110 candidate-to-class rows, 510 switching-kernel rows and 178
coverage blocks covering 2,750,238 logical cosets.

| Implementation and controller state | Seconds | Cumulative allocated GiB | Average logical CPUs |
|---|---:|---:|---:|
| Frozen original, cold controller | 83.06 | 271.11 | 14.59 |
| Frozen original, warmed controller | 74.76 | 269.34 | 16.17 |
| Optimized, cold controller, mean of two runs | 36.83 | 60.82 | 18.33 |
| Optimized, warmed controller, mean of two runs | 28.13 | 58.73 | 23.53 |

That pass's final warmed repeats took 28.16 and 28.09 seconds, about 2.66 times the
original throughput. Cumulative allocations fell about 78.2%; this is allocation
traffic, not peak resident memory. Warmed GC time fell from 15.31 to 3.46 seconds.
The original settings were 32 slots, a 64-ticket horizon, a 4 GiB heap hint and
`--gcthreads=4,0`; the optimized settings use 32 slots, 1,024 tickets, refill batch
16, a 16 GiB hint and `--gcthreads=8,1`. Both use `--threads=32,1` and single-thread
BLAS. Process CPU measurements include GC and helper threads; these workstation
settings do not represent a total 32-thread allocation. The Slurm pilot budgets
all runtime pools explicitly.

Earlier tuning arms showed several GiB of allocation-count variation despite
matching solver paths. This runtime charges allocator usable chunk sizes, which
can depend on allocator state; that mechanism was checked, but the variation's
full magnitude was not apportioned. Avoid precise claims from small allocation
differences between arms. Peak RSS is the process-lifetime high-water mark,
including the excluded cold replay and initialization.

Cold-controller timing includes controller compilation and rank-table setup,
after a mathematical warmup. Warmed timing follows a complete identical replay
in the same process, with a new checkpoint and caches. Fixture initialization
is excluded from both. A broader six-parent fixture, including four parents
selected for high retained construction/EA task time, completed 25,273 packets
in 43.07 seconds cold and 34.59 seconds warm, with matching digests for 44,460
paths, 36,964 class rows, 1,530 kernels and 297 coverage blocks. This broader
fixture's earlier first-pass implementation took 71.32 seconds cold.

The accepted changes remove dense spectrum intermediates, use stable scratch
radix sorting and compact native partition orders, reuse private per-query DFS
partition buffers, run checked Int32 incidence sums with wider SIMD, fuse the
first three serial Int32 FWHT stages, prepare immutable proofs on workers, and
reduce repeated SQL preparation and reservation-query construction. Scientific evidence admission
and durable SQLite synchronization remain part of the measured work.

| Deferred control or idea | Local finding and decision |
|---|---|
| GC marking/sweeping | Eight mark threads plus one sweep thread performed best among the tested conservative settings; sixteen marking threads added no material gain. |
| CPU placement and SMT | 32 unbound workers beat 16-worker arms, including the post-SIMD repeat (34.84 seconds at 16 workers). Exclusive placement added no gain. Keep the local launcher unbound. NUMA was not testable on this single-domain host. |
| Shared property cache | 32,768 entries almost halved misses but did not improve throughput and used more memory. Keep 8,192. |
| Reservation horizon and refill batching | Before the math changes, batching cut query calls without a material throughput gain. Retesting after SIMD showed horizon 1,024 / batch 16 improved throughput and occupancy, with unchanged fixture RSS. Use those explicit local settings; generic defaults remain unchanged. |
| Rolling windows and application steps | Rolling overlap and a four-result application step did not improve this fixture. Keep rolling off and the application-step bound equal to concurrency. |
| Rank representation | Packed and byte tables performed similarly, but use 64 versus 256 MiB. Packed setup cost about 0.28 seconds; disabling it did not improve throughput. Keep the packed precomputed table. |
| Global count counters | Transactional TEMP counters trade per-mutation overhead for fewer large scans. Keep the generic default off; evaluate the opt-in against actual cardinality and refresh cadence. |
| Persistent partition pools, final-child ownership transfer | Incremental savings were small or inconsistent; the prototypes were rejected. Keep fresh per-query buffers. |
| Direct-score/FWHT crossover | Retesting real positive queries after both kernel improvements preserved all 96 witness/node/RNG and budget checks. A lower threshold was slower; a higher threshold gave inconsistent concurrent results. Keep 4,096. |
| Geometry caching and trim rewrites | Final CPU profiles attributed little time to these paths. Additional cache memory and ownership complexity lack a measured throughput justification. |
| SQLite export-verification cache | Larger caches did not improve warm foreign-key-check prefixes. Keep the default; these bounded prefixes did not fully verify the export. |

On the unchanged original checkpoint with 11,066,907 candidates, the seven
current global-count SELECTs took 3.13 seconds on the first read-only pass and
1.01 seconds on the second. Python's linked SQLite 3.54.0 differs from Julia's
3.53.4, so this is query-cost evidence rather than native controller timing.
Combined with the synthetic mutation-cost test, it supports an opt-in counter
trial in the prepared large-checkpoint configuration. The expected saving
depends on actual mutations per packet and refresh frequency; the finite replay
keeps counters off and does not establish resumed campaign throughput.

That pass's final diagnostic profile recorded zero actual horizon waiting in 28.47
seconds and averaged 29.80 active slots out of 32. Its coordinator used 19.04 CPU
seconds (0.67 cores), while the process used 657.98 CPU seconds; inclusive prepare/apply/reserve wall timers must
not be added as serial CPU costs. The dominant remaining CPU work is the already optimized EA
incidence scoring. The remaining property-transform path has only a small
estimated CPU ceiling; trim, copy and geometry-cache proposals lack a material
local timing case. Finite fixtures do not establish throughput for the complete
11-million-candidate campaign or scaling to a 192-core Trillium node.

That pass's cross-source audits compare 11 main-fixture arms, including the original
and final sources, and match all 23,668 EA candidate/target/status rows, witness
columns/constants, node counts and RNG seeds (1,289,512 total nodes). The three
broader-fixture arms match all 24,964 comparisons and 1,439,944 nodes. Earlier
26-arm controls also matched. Sequential versus rolling windows changed numeric
job bindings in 167 compressed coverage blocks; decoding all 178 blocks verified
every other payload byte matched across 2,750,238 cosets. Their EA rows matched
too. An opaque physical coverage hash is not canonical across job schedules.

Read-only indexed counts found all 4,151,043 original parent signature buckets
had cardinality one. Every fixture/executed bucket matched, so the larger queue's
target-list cardinality represents this checkpoint cutoff. The 1,024-ticket
control peaked at about 4.2 GiB lifetime RSS. Future frontiers and cluster memory
limits still need measurement. That pass's mathematical validation passed 17,469
assertions, including full-width fallbacks, integer wrapping, threaded scratch
reuse, witnesses, node/RNG paths and legacy constructors.
The full VBFSearch suite passed another 11,271 assertions across 147 test sets.
The performance-transition gate accepted all 20 changed implementation paths
against the original checkpoint identity and matching replay evidence. This
check did not migrate the checkpoint or start a search.

Raw summaries, commands, immutable source snapshots, scientific digests, profiles,
rejected-prototype evidence and the prepared configuration/launch bundle live in
`data/research/analyses/cpu-utilization-phase2-20261020/`. The first-pass results
remain in `data/research/analyses/cpu-utilization-fixes-20261020/`. The original
campaign remains stopped and frozen. Its final scientific session committed
before interruption of an optional export verifier; the retained staging export
is unpublished and unverified, and must not be used as a verified generation.

A further CPU review retained one additional change: checked native incidence
scoring processes adjacent output pairs, reuses their input loads, and computes
each signature as the total weight minus twice its odd-parity subset sum.
The existing Int32 weight and absolute-sum checks bound every subset; the final
adjustment widens before doubling. Scalar tails, full-width fallbacks, tracing,
plane signs and result order retain their earlier behavior.

Against a fresh 28.20-second replay of the preceding optimized source, paired
scoring took 25.90 and 26.06 seconds: a 25.98-second mean, or 7.85% less wall time.
This is about 2.88 times the frozen original's warmed throughput. Its cumulative
allocation traffic remains about 58.73 GiB; the improvement reduces arithmetic
work. The broader fixture improved from 34.59 to 32.72 seconds warm, and from
43.07 to 41.78 seconds cold. All four scientific digests match, and separate
audits match all 23,668 main and 24,964 broader EA comparisons, including their
witnesses, node counts and RNG seeds. Final math validation passed 17,961
assertions, including the 106 new paired-kernel assertions. The source-bound
performance gate passed for all 20 changed implementation paths. The final
VBFSearch suite passed 11,286 assertions across 147 test sets; both suites
verified that their source files remained unchanged throughout execution.

| Additional review control | Finding and decision |
|---|---|
| Four-output scoring | Exact arithmetic checks passed, but gains over pairs were inconsistent across real inputs and 32-task repeats. Keep pairs. |
| Direct-score/FWHT crossover after pairing | Another 69 exact checks passed; 8,192 lacked a consistent material benefit. Keep 4,096. |
| Native buffers for radix and comparison sorts | The integrated candidate passed 1,428 checks. Its full replay took 25.78 seconds versus the paired mean of 25.98, an apparent 0.76% gain. A material throughput improvement was not established, so retain the simpler existing ownership path. |
| Split-boundary reuse and binary-score sorting | Source-shaped microbenchmarks were flat or slower. Reject both. |
| Native coset-form access | The compiler already eliminates the apparent coordinator copies. The measured worker-ledger saving projects to about 0.85 CPU seconds per main replay, too little to justify the additional code here. |

The additional source copies, commands, exact checks, rejected prototypes,
updated performance proof and prepared launch bundle are retained under
`data/research/analyses/cpu-utilization-round3-20261020/`. Those reviews did not
measure Trillium scaling. The full workstation checkpoint was subsequently
upgraded and resumed on 2026-10-21; its first three-minute sample averaged 23.1
CPU cores and 134 packets/s with 32 workers.

The default one-node pilot in `tools/trillium_cpu.sbatch` runs the fresh
`bin/vbfsearch` command with automatic Slurm CPU-pool budgeting and offline
dependencies. It keeps the live SQLite/WAL on RAM-backed `$SLURM_TMPDIR`, latches
Slurm warnings even before the signal supervisor starts, and atomically copies
the finished single SQLite to scratch. The 30-minute debug allocation defaults
to a ten-minute search, preserving drain and copy time. See
[the operator commands](CLUSTER.md#prepared-operator-commands) for staging,
the one-CPU login check and pilot options. The earlier sealed-checkpoint pilot
is retained as `tools/trillium_checkpoint.sbatch`; it has distinct runtime,
checkpoint and launcher requirements. No job is submitted by preparing or
testing these tools.

Controller retention applies only to its published generation names and the same
identity, survives restarts and excludes the active source. Unrelated, malformed
or staging directories are not deleted. A newly verified generation is protected
even when an older manifest has an incorrect future timestamp. Retention failures
pause further work with a diagnostic; they do not remove the new valid snapshot.

An evolving working copy no longer matches its old sealed-generation manifest.
Use complete bundle verification on published generations, not on a database that
has resumed and acquired new sessions. Ordinary resume still verifies its source,
inputs, environment, coverage and evidence references.

## Storage and production utilization measurements

The 2026-10-21 comparison under
`data/research/analyses/sqlite-disk-vs-ram-20261021/` replayed 6,144 recent
positive EA admission jobs against their complete signature buckets. Three
interleaved trials per storage arm produced identical job, class, witness and
RNG-seed digests. Median processing times were 4.432 s with disk SQLite,
4.342 s with RAM-backed SQLite and 4.193 s with native Julia dictionaries.
The dictionary experiment uses the same VBF mathematics and witness replay,
retains native packets and evidence, and saves results after processing. It
does not implement the full recursive search backend or establish Trillium
scaling. SQLite uses WAL/FULL; RAM and dictionary state need final saving.

Production telemetry identifies an output-heavy window, parents
111378–111477, that processed 296,009 packets in 586.6 s. During one 86.9 s
interval, serial application of 736 V5 results consumed 57.8 s; their completed
worker results waited a median 47.4 s before application. The small
positive-admission storage comparison does not exercise this bottleneck.

Seed-completion polling is another measured bottleneck. `record_completed!`
repeatedly counts construction paths joined to candidate admission state on the
coordinator. Its time is outside `runtime.reporting_seconds`. A controlled
off/on/on/off replay of the same 6,144 admissions, with completion scans against
the read-only production DB for the 36 historically unfinished parents, increased
median elapsed time from 4.377 to 7.658 s and reduced mean CPU use from 24.56
to 14.52 cores. Class digests matched. This isolates scan cost on final production
rows; it does not reconstruct the historical candidate states exactly.

Active-slot occupancy includes completed tasks whose events have not yet been
collected, so it can remain high while coordinator polling leaves CPUs idle.
Use process CPU deltas alongside those counters. The controller now uses
connection-local transactional completion counters: selected cohorts are backfilled
once, shared-child admission updates every dependent parent, and completed cohorts
release their dependency rows. Counters follow packet savepoint and transaction
rollback. They add no checkpoint schema or resume state. SQLite's TEMP storage
policy still applies; runtime metrics report its allocation and policy.

V5 workers prepare immutable candidate and witness encodings. Application reuses
those encodings, admits each exact child once per packet, and batches path and
EA-job inserts in their original order. Transported dictionaries retain ordinary
validation and encoding. On eight real production jobs with 9,774 paths, median
application time fell from 0.736 s to 0.296 s, or 0.377 s with completion tracking
included; native application allocations fell from 278 to 84 MB. Those writer
measurements exclude worker preparation and do not establish end-to-end scaling.
A matched warm 32-worker replay of three complete output-heavy parents processed
49,717 packets with identical scientific and EA-audit digests: elapsed time fell
from 50.41 to 47.50 s, average CPU use rose from 21.53 to 22.90 cores, and median
V5 completed-result wait fell from 4.68 to 1.95 s. Total allocations were nearly
unchanged because preparation moves work to workers and completion triggers add
EA application cost. This single pair has only three parents and does not measure
the original 36-parent polling burden or Trillium scaling.

Separate scheduler counters expose computing calls, scheduled tasks and completed
results awaiting collection. Timers cover completion checks, coordinator steps,
nested transaction control, callbacks and maintenance. Computing calls can still
block or pause for GC; process CPU deltas remain the utilization measure. Event
collection and ordered-result wait totals overlap across tasks and can exceed wall
time. The retained telemetry and original diagnosis are in the storage experiment's
`analysis.md`; fixed-work before/after evidence is under
`data/research/analyses/production-collapse-fixes-20261021/`.

Further coordinator work is recorded under
`data/research/analyses/cpu-coordinator-next-20261021/`. Parent target snapshots
cache only immutable identity/LUT rows, with bounded retention and
transaction-safe identity invalidation. Saved EA decisions and final admission
checks remain live. Prepared statements use bounded FIFO eviction: the earlier
policy kept its first 128 SQL strings forever and could repeatedly compile later
hot writes after setup filled the cache. Runtime metrics expose statement hits,
preparations, evictions and peak entries, alongside parent-target cache counters.
Native V5 worker constructors also validate immutable records against their exact
packet before coordinator reuse; transported records retain ordinary validation.
In fresh matched 32-worker controls, the previous implementation took 50.52 s
and the combined version 50.10 s, with identical scientific and EA-audit digests.
This difference does not establish a reliable whole-search speedup. Application
batch sizes 16/32/64 took 50.47/50.10/49.91 s; a 24 GiB heap hint took 50.12 s.
These checks retain the 32-result batch, 16 GiB workstation heap hint and GC
setting `8,1`. They do not establish full CPU occupancy or larger-node scaling.

A separate native Julia dictionary experiment applied eight output-heavy V5
packets with 9,774 paths in 0.0683 s versus 0.2885 s for optimized SQLite without
completion tracking. Setup plus application plus a final fsynced save took
0.2465 s. All logical fingerprints, final proofs, path order and saved-state
checks matched. This bounded prototype copies accumulated indexes per packet,
allocates more during application and lacks recursive scheduling, EA admission
and completion maintenance. It establishes application headroom, not a scalable
replacement for the full campaign or a Trillium speedup.

## Cold coverage evidence

```sh
bin/vbf closure seal stopped-working-checkpoint --cold-directory cold-evidence
bin/vbf closure rehydrate stopped-working-checkpoint
```

Each seal call is bounded and moves only completed V5 coverage payloads into
immutable SHA-addressed zstd segments. SQLite retains every indexed coverage
envelope; paths, candidate/class identities and EA decisions remain in the active
store. Publication and verification precede transactional payload replacement.
A failed transaction can leave a harmless unreferenced segment, reused on retry.

Logical iteration resolves external evidence transparently and verifies content
and coverage bindings. Raw SQL consumers of `chunks.evidence` see an explicitly
tagged reference; rehydrate before passing such a database to older/raw consumers.
Rehydration restores exact TEXT/BLOB payloads. Preserve referenced cold files;
never garbage-collect them by age alone. Legacy Julia and native migration tools
reject sealed checkpoints until they are rehydrated.

Sealing frees SQLite pages for reuse; it does **not** immediately shrink the
physical database file. Offline compaction needs its own staging space and
verification. Cold evidence still needs storage: neither this separation nor
compression fits unlimited total provenance inside a fixed 60 GB budget.
