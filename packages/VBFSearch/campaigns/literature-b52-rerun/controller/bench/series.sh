#!/usr/bin/env bash
# Run fixed-window benchmarks one after another and compare each ledger with
# the first (reference) run.
#
#   series.sh BASE STATE_WORKSPACE_PROJECT RUN...
#   RUN = LABEL|COORD_CPUS|COORD_THREADS|WORKERS     (WORKERS empty = threaded)
#
# Env: GC (coordinator GC threads, 8), HEAP (coordinator heap hint, 16G),
# WORKER_GC, WORKER_HEAP (per worker). Results: BASE/LABEL, BASE/series.log.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
base=${1:?BASE}; project=${2:?PROJECT}; shift 2
reference=""
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
for spec in "$@"; do
  IFS='|' read -r label cpus threads workers <<< "$spec"
  log=$base/$label.log
  echo "== $label coordinator=$cpus threads=$threads workers='$workers' $(date -u +%FT%TZ)" >> "$base/series.log"
  before=$(mktemp); cp /proc/stat "$before"
  taskset -c "$cpus" julia --startup-file=no --threads="$threads",1 --gcthreads="${GC:-8}",1 \
    --heap-size-hint="${HEAP:-16G}" --project="$project" "$here/bench_window.jl" "$base" "$label" "$workers" > "$log" 2>&1
  # Busy CPU-seconds of socket 1 (56-111, 168-223) during the run, all tenants.
  python3 - "$before" >> "$log" <<'EOF'
import os, sys
def snap(path):
    d = {}
    for line in open(path):
        f = line.split()
        if f[0].startswith('cpu') and f[0][3:].isdigit():
            v = list(map(int, f[1:9])); d[int(f[0][3:])] = (sum(v), v[3] + v[4])
    return d
a, b = snap(sys.argv[1]), snap('/proc/stat'); hz = os.sysconf('SC_CLK_TCK')
cpus = list(range(56, 112)) + list(range(168, 224))
busy = sum((b[c][0] - a[c][0]) - (b[c][1] - a[c][1]) for c in cpus) / hz
print(f"SOCKET1 busy_cpu_seconds={busy:.1f}")
EOF
  rm -f "$before"
  grep -E "^RESULT" "$log" | sed "s/\$/ $(grep -oE 'busy_cpu_seconds=[0-9.]+' "$log")/" >> "$base/series.log" || { echo "FAILED $label" >> "$base/series.log"; tail -30 "$log" >> "$base/series.log"; continue; }
  if [ -z "$reference" ]; then
    reference=$base/$label/run/closure.sqlite
  else
    python3 "$here/compare_science.py" "$reference" "$base/$label/run/closure.sqlite" --ids > "$base/$label.compare" 2>&1
    echo "compare $label: $(grep '^SCIENCE' "$base/$label.compare")" >> "$base/series.log"
  fi
done
echo "== done $(date -u +%FT%TZ)" >> "$base/series.log"
