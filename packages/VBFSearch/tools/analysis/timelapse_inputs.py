#!/usr/bin/env python3
"""Write consistent copies of the timelapse inputs of a live run.

    timelapse_inputs.py RUN OUT_DIR [STEP]

OUT_DIR gets classes.sqlite and features.sqlite (SQLite online backups of
RUN/reports, so rows still in the WAL are included) and admitted.json: the
admission time of every STEP-th parent (default 1000) from the ledger, opened
read-only. The search keeps running.
"""
import json, sqlite3, sys
from pathlib import Path


def backup(source, target):
    target.unlink(missing_ok=True)
    src = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    dst = sqlite3.connect(target)
    src.backup(dst, pages=4096)
    dst.close(); src.close()


def main():
    run, out = Path(sys.argv[1]), Path(sys.argv[2])
    step = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
    out.mkdir(parents=True, exist_ok=True)
    for name in ("classes.sqlite", "features.sqlite"):
        backup(run / "reports" / name, out / name)
    db = sqlite3.connect(f"file:{run / 'closure.sqlite'}?mode=ro", uri=True, timeout=60)
    rows = db.execute("SELECT id, admitted_utc FROM parents WHERE id % ? = 1 ORDER BY id", (step,)).fetchall()
    db.close()
    (out / "admitted.json").write_text(json.dumps({"step": step, "ids": [r[0] for r in rows], "utc": [r[1] for r in rows]}))
    print(json.dumps({"classes_bytes": (out / "classes.sqlite").stat().st_size,
                      "features_bytes": (out / "features.sqlite").stat().st_size, "admitted": len(rows)}))


if __name__ == "__main__":
    main()
