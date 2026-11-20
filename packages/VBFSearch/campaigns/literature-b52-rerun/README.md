# Literature b6=52 closure: rerun

This folder holds the minimum that is necessary to run the recursive quadratic
APN closure of the literature b6=52 campaign again on a new machine. The first
campaign (`data/search/literature-b52-closure-20261014`) stopped on 2026-10-21.
Its ledger archive was damaged after the transfer, so the LUTs of its new
classes are lost. This rerun makes a new campaign. It does not reproduce the
old class IDs or counts, because the admission order depends on the machine
(EA comparisons have a 1 s time limit and retry cooldowns).

## Contents

| Path | Content |
|---|---|
| `inputs/` | `campaign.toml`, `published_pool.toml` and the five audited root files in `seed_count/`. `closure_init` checks each digest. |
| `workspace.tar.gz` | The code that ran session 11 (`run-cpu-optimized-20261020/replay/workspace`), with its `Manifest.toml` files. |
| `controller/` | The session-11 controller scripts (unchanged) and `config.template.toml`. |
| `reports/structure-template.json` | The template of the structure report. |
| `SHA256SUMS` | Digests of the files above. |
| `run.sh` | Setup, initialization, start, stop and status. |

The newer search code of `feat/apn-closure-campaign` (branch `search-v2`) has
speed changes that did not run at scale with this controller.

## Run

Julia 1.13 must be installed. Use persistent storage for the depot and the state.

```sh
export JULIA_DEPOT_PATH=/persistent/julia-depot
./run.sh setup  /persistent/b52-rerun
./run.sh init   /persistent/b52-rerun
./run.sh start  /persistent/b52-rerun 32
./run.sh status /persistent/b52-rerun
./run.sh stop   /persistent/b52-rerun
```

A session stops when `STOP` exists, and a new `start` resumes from the ledger.

### Worker processes (optional)

Inside one Julia process more threads do not help (GC and allocation contention).
With `WORKERS`, the construction packets (`prepare_v5`, `v5`, `switching`) run in
separate worker processes, each pinned with `taskset`; the coordinator process
keeps the ledger, EA and the ordered application (`controller/closure_workers.jl`).
The recorded science is identical to the threaded controller.

```sh
# 6 workers x 8 threads on socket 1, coordinator (8 threads) on the other 8 cores
CPUS=104-111 WORKERS="56-63 64-71 72-79 80-87 88-95 96-103" \
  ./run.sh start /persistent/b52-rerun 8
```

`WORKER_THREADS` (8), `WORKER_GC` (threads/2) and `WORKER_HEAP` (8G) set the
defaults per worker; `CPUS:THREADS` sets the threads of one worker, e.g.
`56-63,168-175:16` for 8 cores with their SMT siblings. Without `WORKERS`
nothing changes. If a worker dies the session fails: the applied prefix stays,
unapplied jobs return to `paused`, and the next `start` resumes them.

The state folder must not go into git. Keep a second copy of the ledger
outside the machine, with its SHA-256.
