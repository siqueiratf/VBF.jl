#!/usr/bin/env python3
"""Export the results of the closure ledger: the admitted classes, their LUTs and
the first construction path of each, plus the files that the dashboard reads.

  export_results.py RUN OUT

RUN is the run folder (closure.sqlite, progress.toml). The script reads the
ledger read-only in one transaction, so a running controller is not affected.
It writes OUT/<UTC>/ with:
  classes.tsv.zst   id, candidate, sigma, origin, source, admitted_utc, lut_hex,
                    path_parent, path_method, path_cursor, path_witness
  dashboard/        progress.toml, identity.toml and reports/ (if present)
  MANIFEST.json     counts, sizes and SHA-256 of each file
OUT/latest points to the newest export. Older exports are removed (keep 2).
The work state of the search (jobs, queues, evaluations) is not exported.
"""
import hashlib, json, os, shutil, sqlite3, subprocess, sys, time

run, out = map(os.path.abspath, sys.argv[1:3])
stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
dest = os.path.join(out, stamp)
os.makedirs(os.path.join(dest, "dashboard"), exist_ok=True)

db = sqlite3.connect(f"file:{run}/closure.sqlite?mode=ro", uri=True)
db.execute("BEGIN")  # one read snapshot for all queries
query = """
WITH first(child_id, id) AS (SELECT child_id, MIN(id) FROM paths GROUP BY child_id)
SELECT p.id, p.candidate_id, p.sigma, p.origin, p.source, p.admitted_utc,
       c.lut, c.lut_text,
       f.parent_id, f.method, f.cursor, f.witness
FROM parents p
JOIN closure_candidates c ON c.id = p.candidate_id
LEFT JOIN first ON first.child_id = p.candidate_id
LEFT JOIN paths f ON f.id = first.id
ORDER BY p.id
"""
path = os.path.join(dest, "classes.tsv.zst")
rows = 0
with open(path, "wb") as f:
    z = subprocess.Popen(["zstd", "-q", "-T0", "-19", "-c"], stdin=subprocess.PIPE, stdout=f)
    head = ["id", "candidate", "sigma", "origin", "source", "admitted_utc", "lut_hex",
            "path_parent", "path_method", "path_cursor", "path_witness"]
    z.stdin.write(("\t".join(head) + "\n").encode())
    for r in db.execute(query):
        lut = r[6].hex() if r[6] is not None else r[7]
        cells = [r[0], r[1], r[2], r[3], r[4], r[5], lut] + list(r[8:])
        z.stdin.write(("\t".join("" if v is None else str(v).replace("\t", " ").replace("\n", " ")
                                 for v in cells) + "\n").encode())
        rows += 1
    z.stdin.close()
    if z.wait() != 0:
        sys.exit("zstd failed")
counts = {t: db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
          for t in ("parents", "closure_candidates", "paths", "closure_comparisons")}
db.execute("ROLLBACK")

for name in ("progress.toml", "identity.toml"):
    shutil.copy2(os.path.join(run, name), os.path.join(dest, "dashboard", name))
if os.path.isdir(os.path.join(run, "reports")):
    shutil.copytree(os.path.join(run, "reports"), os.path.join(dest, "dashboard", "reports"),
                    ignore=shutil.ignore_patterns("*-wal", "*-shm"))

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 22), b""):
            h.update(b)
    return h.hexdigest()

files = {}
for base, _, names in os.walk(dest):
    for n in names:
        p = os.path.join(base, n)
        files[os.path.relpath(p, dest)] = {"bytes": os.path.getsize(p), "sha256": sha(p)}
manifest = {"schema": "vbfsearch-b52-rerun-export-v1", "created_utc": stamp, "run": run,
            "class_rows": rows, "ledger_counts": counts, "files": files}
with open(os.path.join(dest, "MANIFEST.json"), "w") as f:
    json.dump(manifest, f, indent=1)

link = os.path.join(out, "latest")
tmp = link + ".tmp"
if os.path.lexists(tmp):
    os.remove(tmp)
os.symlink(stamp, tmp)
os.replace(tmp, link)
for old in sorted(d for d in os.listdir(out) if d[:2] == "20" and d != stamp)[:-1]:
    shutil.rmtree(os.path.join(out, old))
print(json.dumps({"export": dest, "class_rows": rows, "ledger_counts": counts,
                  "bytes": sum(v["bytes"] for v in files.values())}))
