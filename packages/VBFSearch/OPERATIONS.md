# Long-running recursive campaigns

The threaded controller has scheduler-independent launch, storage limits,
bounded telemetry, process-owned performance metrics, portable checkpoints and
optional cold coverage segments. These controls preserve the construction plan,
coverage and verified EA admission rules. They do not implement multi-node workers.

Existing campaigns use frozen sources. Developing these changes does not deploy
them to an already running process. Stop and use a verified execution upgrade
before adopting changed core sources; never overwrite a live replay workspace.

## Launch and stop

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
window_size = 100
parent_scope = "discovered"         # retain completed published-root provenance
baseline_policy = "summary"
indexed_ea_queue = true

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

Controller retention applies only to its published generation names and the same
identity, survives restarts and excludes the active source. Unrelated, malformed
or staging directories are not deleted. A newly verified generation is protected
even when an older manifest has an incorrect future timestamp. Retention failures
pause further work with a diagnostic; they do not remove the new valid snapshot.

An evolving working copy no longer matches its old sealed-generation manifest.
Use complete bundle verification on published generations, not on a database that
has resumed and acquired new sessions. Ordinary resume still verifies its source,
inputs, environment, coverage and evidence references.

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
