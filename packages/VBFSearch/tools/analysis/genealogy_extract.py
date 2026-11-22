#!/usr/bin/env python3
"""Extract the genealogy of the admitted classes from a live closure ledger.

    genealogy_extract.py RUN/closure.sqlite OUT.sqlite [PAIRS.u32]

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
  produced    paths of this class (as a parent) that reached any class
  spaces      v5 jobs (maximizing 5-spaces) of this class as a parent
  cosets      v5 cosets checked so far
  ea_jobs     EA (deduplicate) jobs that this parent created
  expanded    1 when all its construction jobs (prepare_v5, v5, switching) are done

PAIRS.u32 (optional) gets one (parent, class) pair of little-endian uint32 per
construction path that reached a class, in path order (the order of discovery).

Candidates map to classes through closure_candidates.class_id; a candidate
without a class (not APN, not quadratic, or still waiting for EA) is skipped.
"""
import sqlite3, sys, time
from array import array
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
    spaces = [0] * (n + 1); cosets = [0] * (n + 1); ea = [0] * (n + 1); expanded = bytearray(n + 1)
    for pid, s5, cs, e, open_jobs, construction in db.execute(
            "SELECT parent_id, SUM(kind='v5'), SUM(CASE WHEN kind='v5' AND direction>1 THEN direction-1 ELSE 0 END), "
            "SUM(kind='deduplicate'), SUM(kind IN ('prepare_v5','v5','switching') AND status!='done'), "
            "SUM(kind IN ('prepare_v5','v5','switching')) FROM jobs WHERE parent_id IS NOT NULL GROUP BY parent_id"):
        if 0 < pid <= n:
            spaces[pid], cosets[pid], ea[pid] = s5, cs, e
            expanded[pid] = construction > 0 and open_jobs == 0
    print(f"jobs per parent in {time.time()-t:.0f}s ({sum(expanded)} expanded)", flush=True)
    pairs_path = sys.argv[3] if len(sys.argv) > 3 else None
    pairs = array("I"); pairs_file = open(pairs_path, "wb") if pairs_path else None
    produced = [0] * (n + 1)
    discoverer = [0] * (n + 1); method = bytearray(n + 1); found = [0] * (n + 1)
    finders = {}  # class -> set of parents, only while small; counted at the end
    rows = 0
    for pid, how, child in db.execute("SELECT parent_id, method, child_id FROM paths ORDER BY id"):
        rows += 1
        cls = klass.get(child)
        if cls is None or cls > n:
            continue
        found[cls] += 1
        if 0 < pid <= n:
            produced[pid] += 1
        if pairs_file:
            pairs.append(pid); pairs.append(cls)
            if len(pairs) >= 2_000_000:
                pairs.tofile(pairs_file); pairs = array("I")
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
    if pairs_file:
        pairs.tofile(pairs_file); pairs_file.close()
    print(f"paths {rows} in {time.time()-t:.0f}s", flush=True)
    o = sqlite3.connect(out)
    o.execute("DROP TABLE IF EXISTS genealogy")
    o.execute("CREATE TABLE genealogy(id INTEGER PRIMARY KEY, admitted REAL, seed INTEGER, discoverer INTEGER, "
              "method INTEGER, found INTEGER, finders INTEGER, produced INTEGER, spaces INTEGER, cosets INTEGER, "
              "ea_jobs INTEGER, expanded INTEGER)")
    o.executemany("INSERT INTO genealogy VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                  ((pid, admitted[pid], seed[pid], discoverer[pid], method[pid], found[pid],
                    len(finders.get(pid, ())), produced[pid], spaces[pid], cosets[pid], ea[pid], expanded[pid])
                   for pid, _, _ in parents))
    o.execute("CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY, value TEXT)")
    o.execute("INSERT OR REPLACE INTO metadata VALUES('source', ?), ('paths', ?), ('created', ?)",
              (ledger, str(rows), datetime.utcnow().isoformat() + "Z"))
    o.commit(); o.close()
    print(f"done in {time.time()-t:.0f}s", flush=True)


if __name__ == "__main__":
    main()
