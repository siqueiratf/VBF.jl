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
#   ./run.sh graph-now STATE          build one graph snapshot now, then restart the builder
#   ./run.sh ccz     STATE [THREADS]  keep the CCZ-to-permutation watcher running (default 2
#                                     threads, low priority; env CCZ_CPUS: taskset list,
#                                     CCZ_EVERY: poll seconds, default 60). It reads run/
#                                     closure.sqlite read-only and writes run/reports/
#                                     ccz_permutation.{sqlite,json}
#   ./run.sh ccz-stop STATE           stop the watcher after its current class
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
graph-now)
  # Stop the periodic builder first, so that two builds never share run/graph.
  if [ -f "$state/graph.pid" ]; then
    pid=$(cat "$state/graph.pid")
    if kill -0 "$pid" 2>/dev/null; then
      kill -- -"$pid" 2>/dev/null || kill "$pid"
      while kill -0 "$pid" 2>/dev/null; do sleep 1; done
    fi
  fi
  rm -rf "$state"/run/graph/.building-*
  (cd "$ws" && nice -n 10 ionice -c3 julia "${julia_flags[@]}" --project="$project" \
    "$here/../../../../docs/inspector/closure_graph.jl" --run "$state/run" --once) \
    >> "$state/logs/graph.log" 2>&1
  status=$?
  "$0" graph "$state" "${3:-1800}" > /dev/null
  [ $status -eq 0 ] && echo "graph-now: $(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' "$state/run/graph/current.json")"
  exit $status;;
ccz)
  threads=${3:-2}
  if [ -f "$state/ccz.pid" ] && kill -0 "$(cat "$state/ccz.pid")" 2>/dev/null; then
    echo "ccz: watcher already running (pid $(cat "$state/ccz.pid"))"; exit 0
  fi
  mkdir -p "$state/logs" "$state/run/reports"
  stopf=$state/run/reports/ccz_permutation.STOP
  rm -f "$stopf"
  pin=()
  [ -n "${CCZ_CPUS:-}" ] && pin=(taskset -c "$CCZ_CPUS")
  cd "$ws"
  # The wrapper turns SIGTERM into the STOP file: the watcher finishes its class.
  OPENBLAS_NUM_THREADS=1 setsid nohup bash -c \
    'f=$1; shift; trap "touch \"$f\"" TERM INT; "$@" & c=$!; while kill -0 $c 2>/dev/null; do wait $c; done' \
    ccz "$stopf" "${pin[@]}" nice -n 15 ionice -c3 julia "${julia_flags[@]}" --threads="$threads" \
    --project="$project" "$here/../../tools/ccz_permutation_batch.jl" --watch "$state/run" \
    --every "${CCZ_EVERY:-60}" >> "$state/logs/ccz.log" 2>&1 < /dev/null &
  echo $! > "$state/ccz.pid"
  echo "ccz: pid $(cat "$state/ccz.pid"), $threads threads, log $state/logs/ccz.log";;
ccz-stop)
  touch "$state/run/reports/ccz_permutation.STOP"
  echo "ccz-stop: STOP written; the watcher stops after its current class";;
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
