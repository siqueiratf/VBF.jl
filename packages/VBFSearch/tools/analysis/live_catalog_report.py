"""Incrementally compare admitted VBF signatures with a pinned published index.

No APN or equivalence algorithm is implemented here. Signature absence is a
certificate relative to the pinned reference; matching signatures stay pending.
Only the separate report cache is writable; the campaign and catalog are read-only.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import math
import sqlite3
import time
import tomllib


def atomic_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, separators=(",", ":")) + "\n")
    temporary.replace(path)


def readonly(path):
    db = sqlite3.connect("file:" + str(path.resolve()) + "?mode=ro", uri=True)
    db.execute("PRAGMA query_only=ON"); db.execute("PRAGMA busy_timeout=5000")
    return db


def cache_state(cache):
    """Read durable incremental counters, reconstructing a legacy cache once."""
    row = cache.execute("SELECT value FROM metadata WHERE key='report_state'").fetchone()
    if row is not None:
        value = json.loads(row[0])
        fields = ("total", "roots", "absent", "last", "root_absent")
        if any(type(value.get(key)) is not int or value[key] < 0 for key in fields):
            raise ValueError("report cache counters are malformed")
        if value["total"] != value["last"] or value["root_absent"] or value["roots"] + value["absent"] > value["total"]:
            raise ValueError("report cache counters disagree")
        maximum = cache.execute("SELECT COALESCE(MAX(id),0) FROM classes").fetchone()[0]
        if maximum != value["last"]:
            raise ValueError("report cache watermark differs from its counters")
        return value
    total, roots, absent, last, root_absent = cache.execute(
        "SELECT COUNT(*),COALESCE(SUM(origin='root'),0),COALESCE(SUM(absent),0),"
        "COALESCE(MAX(id),0),COALESCE(SUM(origin='root' AND absent=1),0) FROM classes"
    ).fetchone()
    if total != last or root_absent:
        raise ValueError("report cache is incomplete or has unpublished roots")
    value = dict(total=total, roots=roots, absent=absent, last=last, root_absent=root_absent)
    with cache:
        cache.execute("INSERT INTO metadata VALUES('report_state',?)", (json.dumps(value),))
    return value


def catch_up(cache, run, signatures, *, batch_size=10000, max_batches=8, after_read=None):
    """Copy bounded ID intervals, releasing every source snapshot before cache work.

    Counters and copied rows commit together. A failed batch leaves the previous
    watermark usable; a later invocation resumes there. The published cutoff is
    fixed for this pass, and may exceed the checked cutoff during a large backlog.
    """
    if isinstance(batch_size, bool) or not isinstance(batch_size, int) or batch_size <= 0:
        raise ValueError("batch_size must be a positive integer")
    if isinstance(max_batches, bool) or not isinstance(max_batches, int) or max_batches <= 0:
        raise ValueError("max_batches must be a positive integer")
    state = cache_state(cache)
    progress = tomllib.loads((Path(run) / "progress.toml").read_text())
    maximum = int(progress["total_parents"])
    expected_roots = int(progress.get("initial_roots", 24294))
    if maximum < state["last"]:
        raise ValueError("campaign was replaced or truncated")
    batches = 0
    for _ in range(max_batches):
        if state["last"] == maximum:
            break
        campaign = readonly(Path(run) / "closure.sqlite")
        try:
            campaign.execute("BEGIN")
            actual = campaign.execute("SELECT COALESCE(MAX(id),0) FROM parents").fetchone()[0]
            if maximum > actual:
                raise ValueError("published parent cutoff exceeds the campaign")
            upper = min(maximum, state["last"] + batch_size)
            rows = campaign.execute(
                "SELECT id,candidate_id,sigma,origin,source FROM parents "
                "WHERE id>? AND id<=? ORDER BY id", (state["last"], upper)
            ).fetchall()
        finally:
            campaign.close()
        if len(rows) != upper - state["last"]:
            raise ValueError("campaign parent interval has a gap")
        if after_read is not None:
            after_read(rows)
        values = [(*row, int(row[2] not in signatures)) for row in rows]
        roots = sum(row[3] == "root" for row in rows)
        root_absent = sum(row[3] == "root" and row[5] for row in values)
        if root_absent:
            raise ValueError("published roots are absent from the pinned reference")
        updated = dict(total=state["total"] + len(rows), roots=state["roots"] + roots,
            absent=state["absent"] + sum(row[5] for row in values), last=upper,
            root_absent=state["root_absent"] + root_absent)
        with cache:
            cache.executemany("INSERT INTO classes VALUES(?,?,?,?,?,?)", values)
            cache.execute("UPDATE metadata SET value=? WHERE key='report_state'", (json.dumps(updated),))
        state = updated
        batches += 1
    if state["last"] >= expected_roots and state["roots"] != expected_roots:
        raise ValueError("published root count differs from campaign metadata")
    return dict(state, target_cutoff=maximum, expected_roots=expected_roots,
                complete=state["last"] == maximum, batches=batches)


def report(run, reference, once=False, *, batch_size=10000, max_batches=8, refresh_seconds=60):
    if not math.isfinite(refresh_seconds) or refresh_seconds <= 0:
        raise ValueError("refresh_seconds must be positive and finite")
    run = Path(run).resolve(); reference = Path(reference).resolve()
    out = run / "reports"; out.mkdir(exist_ok=True)
    manifest = json.loads((reference / "manifest.json").read_text())
    if manifest["n"] != 8 or "legacy20261009_n8" not in manifest["excluded_private_sources"]:
        raise ValueError("reference must be the published eight-bit catalog")
    for name, expected in manifest["artifacts"].items():
        path = reference / name
        if path.stat().st_size != expected["bytes"]:
            raise ValueError("reference artifact size differs: " + name)
        with path.open("rb") as source:
            if hashlib.file_digest(source, "sha256").hexdigest() != expected["sha256"]:
                raise ValueError("reference artifact digest differs: " + name)
    catalog = readonly(reference / "ccz_sigma_index.sqlite")
    signatures = {row[0] for row in catalog.execute("SELECT sigma_hash FROM ccz_sigma_index WHERE n=8")}
    if len(signatures) != manifest["quadratic_classes"]:
        raise ValueError("reference class count differs")
    catalog.close()
    cache = sqlite3.connect(out / "classes.sqlite")
    cache.execute("PRAGMA journal_mode=WAL"); cache.execute("PRAGMA busy_timeout=5000")
    cache.execute("CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
    cache.execute("CREATE TABLE IF NOT EXISTS classes(id INTEGER PRIMARY KEY,sha TEXT NOT NULL,sigma TEXT NOT NULL,origin TEXT NOT NULL,source TEXT NOT NULL,absent INTEGER NOT NULL)")
    binding = dict(run=str(run), reference=str(reference), input_sha256=manifest["original_input_sha256"],
        index_sha256=manifest["artifacts"]["ccz_sigma_index.sqlite"]["sha256"])
    encoded = json.dumps(binding, sort_keys=True)
    prior = cache.execute("SELECT value FROM metadata WHERE key='binding'").fetchone()
    if prior is not None and prior[0] != encoded:
        cache.close()
        raise ValueError("report cache belongs to another run/reference")
    cache.execute("INSERT OR IGNORE INTO metadata VALUES('binding',?)", (encoded,)); cache.commit()
    while True:
        started = time.monotonic()
        state = catch_up(cache, run, signatures, batch_size=batch_size, max_batches=max_batches)
        total, roots, absent, last = (state[key] for key in ("total", "roots", "absent", "last"))
        value = dict(schema="vbfsearch-live-catalog-comparison-v1", generated_utc=datetime.now(timezone.utc).isoformat(),
            current_run=str(run), initial_roots=state["expected_roots"], checked_initial_roots=roots,
            classes_checked=total, parent_cutoff=last,
            confirmed_absent_classes=absent, matching_signature_classes=total-absent,
            reference_classes=len(signatures), catalog_snapshot_validated=True,
            reference=binding, lower_bound=True, refresh_seconds=refresh_seconds,
            target_parent_cutoff=state["target_cutoff"], caught_up=state["complete"],
            backlog_classes=state["target_cutoff"]-last, batches_this_refresh=state["batches"], batch_size=batch_size,
            scope="Admitted quadratic campaign classes with signatures absent from the pinned published catalog; matching signatures are not declared equivalent.",
            seconds=time.monotonic()-started)
        atomic_json(out / "catalog.json", value)
        print(json.dumps(value), flush=True)
        if once:
            break
        time.sleep(refresh_seconds)
    cache.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run"); parser.add_argument("reference")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--batch-size", type=int, default=10000)
    parser.add_argument("--max-batches", type=int, default=8)
    parser.add_argument("--refresh-seconds", type=float, default=60)
    options = parser.parse_args()
    report(options.run, options.reference, once=options.once, batch_size=options.batch_size,
           max_batches=options.max_batches, refresh_seconds=options.refresh_seconds)
