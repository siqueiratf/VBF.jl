# Region steering (optional)

Region steering is an optional scheduler for the closure controller. It changes
the order in which the controller expands the admitted classes. It is off by
default. With the default settings, the controller is the session-11 FIFO
controller.

## Motivation

Each admitted class has a lattice point `(two, three)`. `two` is the number of
2-dimensional subspaces in its nonbent component set. `three` is the number of
3-dimensional subspaces. Both come from VBF `nonbent_signature` (entries 2 and
3), as in `tools/analysis/live_structure_report.jl`. Both are EA invariants.

The FIFO controller expands the parents in admission order. A region with many
classes fills the frontier. Classes in a region with few classes wait behind
them. Thus FIFO can reach some regions of the lattice late. Steering moves some
places of each window to the regions that have the lowest coverage.

## Rule

Settings (in the config, or with `run.sh` environment variables):

| Key | Values | Default | `run.sh` variable |
|---|---|---|---|
| `steering` | `"none"`, `"region"` | `"none"` | `STEERING` |
| `steering_fifo_share` | real number in (0, 1] | `0.5` | `STEERING_FIFO_SHARE` |
| `steering_score` | `"ratio"`, `"expanded"` | `"ratio"` | `STEERING_SCORE` |
| `steering_measure_batch` | positive integer | `4096` | (none) |

The controller uses the rule only for construction windows. Each window comes
from one origin, as before: the published roots first, then the discovered
classes. EA-only and idle windows do not change.

Definitions, for one window of size `W`:

- The frontier is the set of parents of the origin that have an unfinished
  construction job and that no active window holds. It is sorted by id.
- For each lattice point `p`, `A(p)` is the number of admitted parents at `p`
  (all origins).
- `available(p)` is the number of parents at `p` that a window can still take
  (unfinished and not held, all origins).
- `claimed(p) = A(p) - available(p)`. This is the number of parents at `p` that
  are expanded or that an active window holds.

Steps:

1. FIFO part. Take the `F = max(1, ceil(steering_fifo_share * W))` lowest ids
   of the frontier. Add 1 to `claimed` of their points.
2. Steered part. Fill each of the other `W - F` places as follows. Find the
   lattice point with the lowest key. Take its lowest remaining frontier id. Add
   1 to its `claimed`.
   - Score `ratio`: key = (`claimed/A`, `claimed`, lowest id of the point).
   - Score `expanded`: key = (`claimed`, `claimed/A`, lowest id of the point).
   The fraction is an exact rational number. The last entry is the admission
   id, so there are no ties.
3. If the frontier has fewer than `W` parents, the window takes all of them.

Because each pick adds 1 to `claimed`, the steered places spread over the
under-covered points. They do not all go to one point. When all candidate
points have the same key (for example all have `claimed = 0`), the rule takes
the lowest id. Then the window is the same as the FIFO window, except that it
skips parents whose point is already claimed.

`steering_fifo_share = 1` gives exactly the FIFO window.

The code is in `controller/closure_steering.jl`. `select_parents` in
`controller/closure_continuous.jl` calls it only when `steering = "region"`.

## Invariants at selection time

The controller measures the lattice point of each parent once. It writes the
result to a new ledger table:

```sql
CREATE TABLE steering_regions(parent_id INTEGER PRIMARY KEY REFERENCES parents(id),
  candidate_id TEXT NOT NULL, two INTEGER NOT NULL, three INTEGER NOT NULL)
```

No existing table changes. The table is made only when steering is on. Before
each steered selection, the controller measures all parents that have no row,
in id order, in batches of `steering_measure_batch`, with all threads. Then it
checks that the table has one row for each parent.

Why lazily at selection, not at admission: admission is in the pinned
VBFSearch package. A change there would change the package code of the
campaign. The selection is in the controller, which another branch
(`multiproc`) also changes. A lazy measurement keeps the change small and in
one place. A resumed ledger that ran without steering gets its table at the
first steered selection.

Cost (measured on this machine, Julia 1.13, pinned code, a ledger with 2,388
parents): 1.5 ms per class with 1 thread, 1.1 ms per class (wall) with 2
threads. This includes the LUT read and the insert. The expansion of one parent
took about 10 CPU seconds in the same test. So the measurement adds about 0.02 %
to the work. A first steered selection on a ledger with 1,000,000 parents takes
about 25 minutes on 1 thread. With more threads it is faster, but the
LUT read and the insert are serial, so expect several minutes. After that, each
window measures only the classes admitted since the last window.

The selection also reads the full frontier (one indexed query) each window.
This is a small cost compared with a window of 100 parents.

## Determinism

The selection is a pure function of:

- the ledger rows `parents`, `jobs` (status) and the LUTs of the parents;
- the ids that active windows hold (the same input as in FIFO mode).

The lattice point is a function of the LUT. The table only caches it. So the
selection does not depend on when a class was measured. The rule does not use
the clock, random numbers or the state of the workers. Ties are broken by id.
The unit tests check that two calls on the same ledger give the same window.

As in FIFO mode, the content of the ledger itself depends on the machine (EA
comparisons have a time limit). So two runs on two machines can still differ.

## Progress guarantee

Claim: with `steering_fifo_share > 0`, every admitted parent is expanded
eventually (if the run continues).

Proof. `F >= 1`, so each window takes the lowest id of the frontier. Take a
parent `x`. Let `c` be the number of unfinished parents with an id lower than
`x` when `x` is admitted. A new parent always gets a higher id than `x`. So no
new parent can come before `x` in the FIFO part. A construction window ends
only when all its parents are expanded (as in FIFO mode). Each window either
contains `x` or takes `min(F, c')` parents with ids lower than `x`, where `c'`
is the current number of them. Thus `x` is in a window after at most
`ceil(c / F) + 1` windows. With rolling windows, a lower parent can also be in
an active window; it ends, so the bound holds with the same argument. QED.

With `steering_fifo_share = 0`, there is no such bound: a crowded region could
wait as long as new classes come to other regions. Thus the config rejects 0.

The unit test `progress` simulates 3,000 admissions (80 % in one region) and
checks that every parent is expanded and the bound above.

## What changes scientifically

- The closure limit does not change. The controller expands every admitted
  class with the same operations and the same admission and EA rules. When the
  frontier is empty, the closure is the same set of classes (up to the
  machine-dependent EA time limits, as in FIFO mode).
- The order of the expansion changes. Thus the set of classes found by a given
  cutoff (time, number of parents or a stopped run) changes. Admission ids and
  class ids change too.
- A partial run is a biased sample of the closure, in FIFO mode and in steered
  mode. The bias is different. Statistics of a partial run (for example the
  distribution of `(two, three)`) depend on the scheduler.

## How a paper must describe it

- Say that the run used region steering, with `steering_fifo_share` and
  `steering_score`, and give the controller commit.
- Say that steering changes only the expansion order, not the operations or
  the admission rule.
- If the run did not finish the closure, say that the classes found are a
  partial result whose composition depends on the scheduler. Do not compare
  counts per region with a FIFO run as if they were samples of the same
  distribution.
- Give the session budgets: each session records `"steering"` (mode, share,
  score) in `sessions.budgets`.

## How to compare a steered and a FIFO run

Use `controller/steering_compare.jl`. It copies each ledger (read-only for the
original), measures the lattice points on the copy, and reads the completion
order from the `seed_completed` events in the session logs. It prints, per run:

- `points_reached_per_1000_expanded`: the number of distinct lattice points
  among the first 1,000, 2,000, ... expanded parents;
- `points_expanded`, `points_not_expanded`, `lattice_points`;
- `coverage_E_over_A_quantiles`: the 10 %, 50 % and 90 % quantiles of
  expanded/admitted over the lattice points;
- `new_classes_per_hour`: discovered classes admitted per hour, from the first
  dispatch to the last completion (use one continuous session for each run);
- `parents`, `discovered`, `expanded`, `hours`.

Compare the runs at the same number of expanded parents and at the same time.
Steering is useful if it reaches more lattice points per 1,000 parents without
a large loss of new classes per hour.

## Risks

- Throughput: regions with few classes may give fewer children per parent.
  Then steering can find fewer new classes per hour.
- Parents with expensive expansions can cluster in some regions. Then window
  times change. Check `batch_completion_seconds`.
- The rule uses only `(two, three)`. Other invariants are not steered.
- A paper must state the scheduler (see above). Results of a steered partial
  run are not comparable with FIFO counts without care.
- Memory and time: each window reads the full frontier. With millions of
  frontier parents, this takes seconds. Check the `seconds` field of the
  `steering_window` log events.
- The first steered selection on a large ledger measures all parents (see the
  cost above).

## Local tests (done)

- `controller/test/steering.jl` (unit tests): options, the rule (determinism,
  FIFO share, share 1 = FIFO, both scores), the progress bound (simulation) and
  the ledger table (synthetic ledger with real root LUTs; only the table
  `steering_regions` is added). Run:
  `julia --project=STATE/workspace/docs/inspector controller/test/steering.jl`.
- End to end, pinned code, roots 1 to 16, window 8, 2 threads, 2 windows per
  session, 2 sessions per mode. Both modes finished. Both ledgers passed
  `PRAGMA integrity_check` and `PRAGMA foreign_key_check`. The steered first
  window was parents 1-7 and 9 (FIFO: 1-8): parent 8 has the same lattice point
  as a parent that the FIFO part took. The second session (discovered
  parents) gave the same windows as FIFO, because all next parents were at
  lattice points with no claim yet. After 32 expanded parents, both ledgers had
  the same number of parents (2,388). Two calls of the selection on the same ledger gave
  the same window.

## VLab test plan (not run yet)

Two runs at the same time on socket 1 (CPUs 56-111), 28 CPUs each, from fresh
state folders. Use the same code and depot.

```sh
export JULIA_DEPOT_PATH=/home/jovyan/privado/julia-depot
B=/path/to/VBF.jl/packages/VBFSearch/campaigns/literature-b52-rerun   # branch steering
R=/home/jovyan/privado/steer-bench
for m in fifo region; do
  $B/run.sh setup $R/$m
  $B/run.sh init  $R/$m
done
CPUS=56-83  HEAP=16G GC_THREADS=4 STEERING=none   $B/run.sh start $R/fifo   28
CPUS=84-111 HEAP=16G GC_THREADS=4 STEERING=region STEERING_FIFO_SHARE=0.5 \
  STEERING_SCORE=ratio $B/run.sh start $R/region 28
```

- Check after 10 minutes: `$B/run.sh status $R/region`, and
  `grep steering_window $R/region/logs/session-*.log | tail -n 3` (the
  `seconds` and `measured` fields). The first steered window measures the
  24,294 roots (well under 1 minute).
- Duration: 24 hours. The 24,294 roots come first in both runs, so a shorter
  test compares only the root order. After about 24 hours the runs are in the
  discovered classes. Then stop both: `$B/run.sh stop $R/fifo`,
  `$B/run.sh stop $R/region`, and wait until both controllers exit.
- Compare (after the stop, or at any time on a live run, because the tool uses
  a copy):

```sh
cd $R/fifo/workspace
julia --threads=8 --project=docs/inspector $B/controller/steering_compare.jl $R/fifo $R/region
```

- Metrics: `points_reached_per_1000_expanded` (main metric), `points_expanded`,
  `coverage_E_over_A_quantiles`, `new_classes_per_hour`, `expanded` per hour,
  and the `seconds` of the `steering_window` events (overhead).
- Optional second pair: `STEERING_FIFO_SHARE=0.25` or `STEERING_SCORE=expanded`
  against the same FIFO run.
- Each state folder needs space for its ledger. Delete the folders after the
  test; they are not campaign data.
