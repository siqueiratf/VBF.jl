#!/usr/bin/env python3
"""Checkpoint and backup status of the b52 rerun, for the dashboard.

  python3 backup_status.py STATE OUTPUT [--offsite DIR] [--every SECONDS]

STATE is the campaign state folder (STATE/run, STATE/snapshots,
STATE/config-*.toml). OUTPUT is the status.json to write (atomically); put it
in the folder that the offsite HTTP server publishes. --offsite is that folder
(default /home/jovyan/privado/offsite). --every repeats forever.

Cheap by design: only stat calls and small text files, no hashing.
Standard library only.
"""
import json, os, re, sys, time

MS_STAMP = re.compile(r"^checkpoint-.*-(\d{13})-\d+$")


def utc(seconds):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(seconds)) if seconds else None


def parse_utc(text):
    """Seconds since the epoch from '2026-11-21T10:00:00.123Z' or None."""
    m = re.match(r"(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(\.\d+)?Z?$", text or "")
    if not m:
        return None
    import calendar
    return calendar.timegm(tuple(int(x) for x in m.groups()[:6])) + float(m.group(7) or 0)


def toml_value(path, key):
    """One top-level 'key = value' of a small TOML file (no full parser needed)."""
    try:
        with open(path) as f:
            for line in f:
                if line.startswith("["):
                    break
                m = re.match(rf"\s*{re.escape(key)}\s*=\s*(.+?)\s*$", line)
                if m:
                    value = m.group(1)
                    return value.strip('"') if value.startswith('"') else float(value) if "." in value else int(value)
    except (OSError, ValueError):
        pass
    return None


def tree_bytes(path):
    """Apparent size of a file or folder (os.scandir, no symlink following)."""
    try:
        if not os.path.isdir(path):
            return os.path.getsize(path) if os.path.isfile(path) else 0
        total, stack = 0, [path]
        while stack:
            with os.scandir(stack.pop()) as entries:
                for e in entries:
                    try:
                        if e.is_dir(follow_symlinks=False):
                            stack.append(e.path)
                        elif e.is_file(follow_symlinks=False):
                            total += e.stat(follow_symlinks=False).st_size
                    except OSError:
                        pass  # a file vanished while the export runs
        return total
    except OSError:
        return 0


def last_checkpoint(snapshots):
    found = []
    try:
        for e in os.scandir(snapshots):
            if e.is_dir() and e.name.startswith("checkpoint-") and ".staging-" not in e.name:
                found.append(e)
    except OSError:
        return None
    if not found:
        return None
    def created(e):
        text = toml_value(os.path.join(e.path, "checkpoint-manifest.toml"), "created_utc")
        return parse_utc(text) or e.stat().st_mtime
    e = max(found, key=created)
    return {"name": e.name, "created_utc": utc(created(e)),
            "completed_parents": toml_value(os.path.join(e.path, "progress.toml"), "completed_parents")}


def export_in_progress(snapshots, run):
    try:
        staging = [e for e in os.scandir(snapshots) if e.is_dir() and ".staging-" in e.name]
    except OSError:
        staging = []
    if not staging:
        return None
    e = max(staging, key=lambda e: e.stat().st_mtime)
    st = e.stat()
    m = MS_STAMP.match(e.name.split(".staging-")[0])
    started = int(m.group(1)) / 1000 if m else min(st.st_mtime, st.st_ctime)
    written = tree_bytes(e.path)
    expected = sum(tree_bytes(os.path.join(run, p)) for p in
                   ("closure.sqlite", "closure.sqlite-wal", "cold", "replay", "execution"))
    elapsed = max(time.time() - started, 1.0)
    rate = written / elapsed
    eta = time.time() + (expected - written) / rate if rate > 0 and expected > written else None
    return {"staging": e.name, "started_utc": utc(started), "bytes_written": written,
            "bytes_expected": expected, "percent": round(min(100.0 * written / expected, 100.0), 1) if expected else None,
            "bytes_per_second": round(rate), "eta_utc": utc(eta)}


def newest(paths):
    paths = [p for p in paths if os.path.exists(p)]
    return max(paths, key=os.path.getmtime) if paths else None


def next_export(state, last):
    """Last checkpoint, last skip or session start (whichever is newest) + interval."""
    configs = [os.path.join(state, n) for n in os.listdir(state) if n.startswith("config-") and n.endswith(".toml")]
    config = newest(configs)
    if not config:
        return None
    interval = toml_value(config, "checkpoint_interval_seconds")
    if not interval:
        return {"interval_seconds": interval, "next_utc": None}
    times = [os.path.getmtime(config)]
    if last:
        times.append(parse_utc(last["created_utc"]) or 0)
    evidence = toml_value(config, "evidence")
    if isinstance(evidence, str):
        metrics = os.path.join(state, evidence, "checkpoint-metrics.jsonl")
        try:
            with open(metrics, "rb") as f:
                f.seek(max(0, os.path.getsize(metrics) - 65536))
                for line in f.read().decode(errors="replace").splitlines():
                    try:
                        row = json.loads(line)
                        times.append(parse_utc(row.get("utc")) or 0)
                    except ValueError:
                        pass
        except OSError:
            pass
    return {"interval_seconds": interval, "config": os.path.basename(config), "next_utc": utc(max(times) + interval)}


def offsite_archive(offsite):
    folder = os.path.join(offsite, "checkpoints")
    try:
        names = [n for n in os.listdir(folder) if n.endswith(".tar.zst")]
    except OSError:
        return None
    path = newest([os.path.join(folder, n) for n in names])
    if not path:
        return None
    return {"name": os.path.basename(path), "mtime_utc": utc(os.path.getmtime(path)), "bytes": os.path.getsize(path),
            "sha256_file": os.path.isfile(path[:-len(".tar.zst")] + ".sha256")}


def results_export(offsite):
    try:
        with open(os.path.join(offsite, "export", "latest", "MANIFEST.json")) as f:
            m = json.load(f)
        stamp = m.get("created_utc") or ""
        # export_results.py writes a compact stamp (20261121T155027Z); browsers need ISO 8601.
        if len(stamp) == 16 and stamp[8] == "T":
            stamp = f"{stamp[:4]}-{stamp[4:6]}-{stamp[6:8]}T{stamp[9:11]}:{stamp[11:13]}:{stamp[13:15]}Z"
        return {"created_utc": stamp or None, "class_rows": m.get("class_rows")}
    except (OSError, ValueError):
        return None


def status(state, offsite):
    run, snapshots = os.path.join(state, "run"), os.path.join(state, "snapshots")
    last = last_checkpoint(snapshots)
    return {"schema": "vbf-backup-status-v1", "updated_utc": utc(time.time()),
            "last_checkpoint": last, "export_in_progress": export_in_progress(snapshots, run),
            "next_export": next_export(state, last), "skip_pending": os.path.exists(os.path.join(run, "CHECKPOINT_SKIP")),
            "offsite_archive": offsite_archive(offsite), "results_export": results_export(offsite)}


def write(path, data):
    tmp = f"{path}.tmp-{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, path)


def main(args):
    if len(args) < 2:
        sys.exit(__doc__)
    state, output, rest = args[0], args[1], args[2:]
    options = dict(zip(rest[::2], rest[1::2]))
    offsite = options.get("--offsite", "/home/jovyan/privado/offsite")
    every = float(options.get("--every", 0))
    while True:
        try:
            write(output, status(state, offsite))
        except Exception as e:  # keep the loop alive; the dashboard shows the stale updated_utc
            print(f"backup_status: {e}", file=sys.stderr, flush=True)
            if not every:
                raise
        if not every:
            return 0
        time.sleep(every)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
