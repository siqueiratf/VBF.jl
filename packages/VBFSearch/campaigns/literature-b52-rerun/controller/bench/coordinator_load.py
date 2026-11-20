"""Coordinator load of fixed-window runs: busy time of the serial loop.

The single coordinator task reserves, prepares, applies and reports; it waits
for worker events otherwise. busy = pool wall - event wait. Its inverse bounds
the parent rate: max parents/min = 60 * parents / busy.

    python3 coordinator_load.py BASE LABEL...
"""
import json, pathlib, sys

base = pathlib.Path(sys.argv[1])
print(f"{'label':<10} {'pool_s':>7} {'wait_s':>7} {'busy_s':>7} {'apply':>6} {'prep':>5} {'resv':>5} {'report':>6} {'occ':>5} {'busy%':>6} {'max_par/min':>11}")
for label in sys.argv[2:]:
    ev = base/label/'evidence'
    pools = [json.loads(l) for l in open(ev/'scheduler-metrics.jsonl') if l.strip()]
    wall = sum(p['pool_wall_seconds'] for p in pools)
    wait = sum(p['event_wait_seconds'] for p in pools)
    apply = sum(p['apply_seconds'] for p in pools)
    prep = sum(p['prepare_seconds'] for p in pools)
    resv = sum(p['reserve_seconds'] for p in pools)
    report = 0.0
    if (ev/'publish-metrics.jsonl').exists():
        report = sum(json.loads(l)['seconds'].get('total', 0.0) for l in open(ev/'publish-metrics.jsonl') if l.strip())
    occ = pools[-1]['slot_occupancy']
    busy = wall - wait
    print(f"{label:<10} {wall:7.2f} {wait:7.2f} {busy:7.2f} {apply:6.2f} {prep:5.2f} {resv:5.2f} {report:6.2f} {occ:5.3f} {100*busy/wall:6.1f} {60*64/busy:11.1f}")
