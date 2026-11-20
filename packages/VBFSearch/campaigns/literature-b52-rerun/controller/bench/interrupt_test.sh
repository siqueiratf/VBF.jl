#!/usr/bin/env bash
# Interrupt a worker-process window, check the ledger, resume, compare.
#
#   interrupt_test.sh BASE PROJECT REFERENCE.sqlite MODE
#   MODE = kill  (SIGKILL one worker after 800 packets: the session must fail)
#        | stop  (write run/STOP after 800 packets: the session must pause)
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
base=$1; project=$2; reference=$3; mode=$4
label=interrupt-$mode; folder=$base/$label
workers="56-63 64-71 72-79"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
run_bench() {
  taskset -c 104-111 julia --startup-file=no --threads=8,1 --gcthreads=8,1 --heap-size-hint=16G \
    --project="$project" "$here/bench_window.jl" "$base" "$label" "$workers"
}
run_bench > "$base/$label-1.log" 2>&1 &
bench=$!
until [ "$(cat "$folder"/evidence/packet-metrics.jsonl 2>/dev/null | wc -l)" -ge 800 ]; do
  kill -0 $bench 2>/dev/null || break; sleep 0.2
done
if [ "$mode" = kill ]; then
  victim=$(sed -n 's/.*ready: pid \([0-9]*\).*/\1/p' "$folder"/evidence/workers/worker-2.log)
  echo "killing worker 2 (pid $victim) at $(wc -l < "$folder"/evidence/packet-metrics.jsonl) packets"
  kill -9 "$victim"
else
  echo "STOP at $(wc -l < "$folder"/evidence/packet-metrics.jsonl) packets"
  touch "$folder/run/STOP"
fi
wait $bench; echo "first session exit status $?"
grep -E "^(RESULT|RUN_FAILED)" "$base/$label-1.log" | cut -c1-600
sleep 2
echo "worker processes left: $(pgrep -f -c "closure_workers.jl --serve" || true)"
python3 - "$folder/run/closure.sqlite" <<'EOF'
import sqlite3, sys
db = sqlite3.connect('file:'+sys.argv[1]+'?mode=ro', uri=True)
print('sessions', db.execute('select id,state,jobs,finished!="" from sessions').fetchall())
print('jobs', db.execute('select kind,status,count(*) from jobs group by 1,2').fetchall())
print('running jobs', db.execute("select count(*) from jobs where status='running'").fetchone()[0])
EOF
rm -f "$folder/run/STOP"
RESUME=1 run_bench > "$base/$label-2.log" 2>&1; echo "resume exit status $?"
grep -E "^(RESULT|RUN_FAILED)" "$base/$label-2.log" | cut -c1-600
python3 "$here/compare_science.py" "$reference" "$folder/run/closure.sqlite" --ids | grep -vE "^ {5}"
