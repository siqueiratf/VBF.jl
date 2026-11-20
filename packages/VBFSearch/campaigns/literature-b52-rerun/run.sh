#!/usr/bin/env bash
# Set up and run the literature b6=52 closure rerun with the pinned session-11 code.
#
#   ./run.sh setup   STATE            check inputs, unpack the code, install packages
#   ./run.sh init    STATE            create the empty closure ledger from the roots
#   ./run.sh start   STATE THREADS    start a session in the background
#   ./run.sh stop    STATE            ask the controller to drain and stop
#   ./run.sh status  STATE            print the last progress counters
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
    "$here/controller/config.template.toml" > "$config"
  mkdir -p "$state/tmp" "$state/logs"
  rm -f "$state/STOP"
  cd "$ws"
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 SQLITE_TMPDIR=$state/tmp VBF_CLOSURE_STOP_FILE=$state/STOP \
    nohup julia "${julia_flags[@]}" --threads="$threads",1 --gcthreads=8,1 --heap-size-hint=16G \
      --project="$project" "$here/controller/closure_run.jl" "$config" \
      > "$state/logs/session-$stamp.log" 2>&1 &
  echo $! > "$state/controller.pid"
  echo "start: pid $(cat "$state/controller.pid"), log $state/logs/session-$stamp.log";;
stop)
  touch "$state/STOP"; echo "stop: STOP written; the controller drains its work first";;
status)
  julia "${julia_flags[@]}" --project="$project" -e '
    using VBFSearch; p=VBFSearch.closure_progress(ARGS[1])
    for k in ("state","running","completed_parents","promoted_parents","total_parents",
              "exact_luts","construction_paths","heartbeat_utc")
        println(rpad(k,20), get(p,k,nothing))
    end' "$state/run";;
*) echo "unknown command: $cmd"; exit 2;;
esac
