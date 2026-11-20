#!/usr/bin/env bash
# Set up and run the literature b6=52 closure rerun with the pinned session-11 code.
#
#   ./run.sh setup   STATE            check inputs, unpack the code, install packages
#   ./run.sh init    STATE            create the empty closure ledger from the roots
#   ./run.sh start   STATE THREADS    start a session in the background
#                                     env: HEAP (16G), GC_THREADS (8), CPUS (taskset list,
#                                     e.g. 0-55; default all), ROLLING (false), WINDOW (100)
#   ./run.sh stop    STATE            ask the controller to drain and stop
#   ./run.sh status  STATE            print the last progress counters
#   ./run.sh graph   STATE [SECONDS]  keep a graph builder running: a new snapshot of
#                                     run/graph every SECONDS (default 1800), low priority
#
# STATE holds the code, ledger, evidence and logs. Put it on persistent storage
# with at least 200 GB free. JULIA_DEPOT_PATH must be set (persistent too).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cmd=${1:?command}; state=$(mkdir -p "${2:?STATE directory}" && cd "$2" && pwd)
ws=$state/workspace
project=$ws/docs/inspector
julia_flags=(--startup-file=no --compiled-modules=existing)

case $cmd in
setup)
  (cd "$here" && sha256sum -c --quiet SHA256SUMS)
  [ -d "$ws" ] || tar -C "$state" -xzf "$here/workspace.tar.gz"
  julia "${julia_flags[@]}" --project="$project" -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
  echo "setup: OK ($ws)";;
init)
  [ -e "$state/run" ] && { echo "init: $state/run exists"; exit 1; }
  julia "${julia_flags[@]}" --project="$project" -e '
    using VBFSearch
    println(VBFSearch.closure_init(ARGS[1]; output=ARGS[2], execution_backend=:serial,
        extension_cosets=65536, switching_directions=255, compact_storage=true))' \
    "$here/inputs/campaign.toml" "$state/run";;
start)
  threads=${3:?THREADS}
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  config=$state/config-$stamp.toml
  sed -e "s|@EVIDENCE@|evidence-$stamp|" -e "s|@THREADS@|$threads|" \
    -e "s|^rolling_windows = .*|rolling_windows = ${ROLLING:-false}|" \
    -e "s|^window_size = .*|window_size = ${WINDOW:-100}|" \
    "$here/controller/config.template.toml" > "$config"
  pin=()
  [ -n "${CPUS:-}" ] && pin=(taskset -c "$CPUS")
  mkdir -p "$state/tmp" "$state/logs"
  rm -f "$state/run/STOP"
  cd "$ws"
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 SQLITE_TMPDIR=$state/tmp \
    setsid nohup "${pin[@]}" julia "${julia_flags[@]}" --threads="$threads",1 --gcthreads="${GC_THREADS:-8}",1 --heap-size-hint="${HEAP:-16G}" \
      --project="$project" "$here/controller/closure_run.jl" "$config" \
      > "$state/logs/session-$stamp.log" 2>&1 < /dev/null &
  echo $! > "$state/controller.pid"
  echo "start: pid $(cat "$state/controller.pid"), log $state/logs/session-$stamp.log";;
graph)
  every=${3:-1800}
  if [ -f "$state/graph.pid" ] && kill -0 "$(cat "$state/graph.pid")" 2>/dev/null; then
    echo "graph: builder already running (pid $(cat "$state/graph.pid"))"; exit 0
  fi
  mkdir -p "$state/logs"
  cd "$ws"
  setsid nohup nice -n 10 ionice -c3 julia "${julia_flags[@]}" --project="$project" \
    "$here/../../../../docs/inspector/closure_graph.jl" --run "$state/run" \
    --every-seeds 1 --min-seconds "$every" >> "$state/logs/graph.log" 2>&1 < /dev/null &
  echo $! > "$state/graph.pid"
  echo "graph: pid $(cat "$state/graph.pid"), every $every s, log $state/logs/graph.log";;
stop)
  # The controller polls RUN/STOP (and EVIDENCE/STOP), not STATE/STOP.
  touch "$state/run/STOP"; echo "stop: run/STOP written; the controller drains its work first";;
status)
  julia "${julia_flags[@]}" --project="$project" -e '
    using VBFSearch; p=VBFSearch.closure_progress(ARGS[1])
    for k in ("state","running","completed_parents","promoted_parents","total_parents",
              "exact_luts","construction_paths","heartbeat_utc")
        println(rpad(k,20), get(p,k,nothing))
    end' "$state/run";;
*) echo "unknown command: $cmd"; exit 2;;
esac
