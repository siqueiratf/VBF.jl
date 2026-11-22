#!/usr/bin/env python3
"""Extract the genealogy of the admitted classes from a live closure ledger.

    genealogy_extract.py RUN/closure.sqlite OUT.sqlite

The ledger is opened read-only; run it with nice/ionice next to the search.
OUT.sqlite gets one row per admitted class (parents.id, admission order):

  id          class id (parents.id)
  admitted    admission time, seconds since the Unix epoch
  seed        1 for a published root
  discoverer  parent whose construction path first reached a candidate of
              this class (lowest paths.id), 0 for a seed or when no path exists
  method      0 seed or none, 1 v5, 2 switching (of that first path)
  found       number of construction paths that reached any candidate of
              this class (rediscoveries included)
  finders     number of distinct parents among those paths

Candidates map to classes through closure_candidates.class_id; a candidate
without a class (not APN, not quadratic, or still waiting for EA) is skipped.
"""
import sqlite3, sys, time
from datetime import datetime

METHOD = {"v5": 1, "switching": 2}


def main():
    ledger, out = sys.argv[1], sys.argv[2]
    db = sqlite3.connect(f"file:{ledger}?mode=ro", uri=True, timeout=120)
    t = time.time()
    epoch = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    parents = db.execute("SELECT id, origin, admitted_utc FROM parents ORDER BY id").fetchall()
    n = parents[-1][0]
    admitted = [0.0] * (n + 1); seed = bytearray(n + 1)
    for pid, origin, utc in parents:
        admitted[pid] = epoch(utc); seed[pid] = origin == "root"
    print(f"parents {len(parents)} in {time.time()-t:.0f}s", flush=True)
    klass = {}
    for cid, cls in db.execute("SELECT id, class_id FROM closure_candidates WHERE class_id IS NOT NULL"):
        klass[cid] = cls
    print(f"candidates with a class {len(klass)} in {time.time()-t:.0f}s", flush=True)
    discoverer = [0] * (n + 1); method = bytearray(n + 1); found = [0] * (n + 1)
    finders = {}  # class -> set of parents, only while small; counted at the end
    rows = 0
    for pid, how, child in db.execute("SELECT parent_id, method, child_id FROM paths ORDER BY id"):
        rows += 1
        cls = klass.get(child)
        if cls is None or cls > n:
            continue
        found[cls] += 1
        if discoverer[cls] == 0 and not seed[cls]:
            discoverer[cls] = pid; method[cls] = METHOD.get(how, 0)
        s = finders.get(cls)
        if s is None:
            finders[cls] = {pid}
        elif len(s) < 255:
            s.add(pid)
        if rows % 5_000_000 == 0:
            print(f"paths {rows} in {time.time()-t:.0f}s", flush=True)
    db.close()
    print(f"paths {rows} in {time.time()-t:.0f}s", flush=True)
    o = sqlite3.connect(out)
    o.execute("DROP TABLE IF EXISTS genealogy")
    o.execute("CREATE TABLE genealogy(id INTEGER PRIMARY KEY, admitted REAL, seed INTEGER, discoverer INTEGER, "
              "method INTEGER, found INTEGER, finders INTEGER)")
    o.executemany("INSERT INTO genealogy VALUES(?,?,?,?,?,?,?)",
                  ((pid, admitted[pid], seed[pid], discoverer[pid], method[pid], found[pid],
                    len(finders.get(pid, ()))) for pid, _, _ in parents))
    o.execute("CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY, value TEXT)")
    o.execute("INSERT OR REPLACE INTO metadata VALUES('source', ?), ('paths', ?), ('created', ?)",
              (ledger, str(rows), datetime.utcnow().isoformat() + "Z"))
    o.commit(); o.close()
    print(f"done in {time.time()-t:.0f}s", flush=True)


if __name__ == "__main__":
    main()
