#!/usr/bin/env python3
"""Write a small health summary of the search for off-site watchers.

    health.py STATE OUTPUT_JSON [SECONDS]

Every SECONDS (default 300) it writes OUTPUT_JSON atomically: the processes of
the search (controller, keepalive, catalog and structure reports, graph
builder), the progress counters, the parent rate over the last 30 minutes, the
catalog comparison, the free space and recent error lines of the session log.
It reads files only; it never opens the ledger.
"""
import json, os, re, subprocess, sys, time, tomllib
from collections import deque
from datetime import datetime, timezone
from pathlib import Path


def alive_pid(path):
    try:
        os.kill(int(Path(path).read_text().strip()), 0)
        return True
    except (OSError, ValueError):
        return False


def running(pattern):
    return subprocess.run(["pgrep", "-f", pattern], capture_output=True).returncode == 0


def age(utc):
    try:
        return time.time() - datetime.fromisoformat(utc.replace("Z", "+00:00")).timestamp()
    except (AttributeError, ValueError):
        return None


def summary(state, history):
    run = state / "run"
    out = {"utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
           "controller_running": running(r"julia.*closure_run\.jl"),
           "keepalive_running": running(r"keepalive\.sh"),
           "keepalive_off": (state / "KEEPALIVE_OFF").exists() or (run / "STOP").exists(),
           "catalog_report_running": alive_pid(state / "catalog-report.pid"),
           "structure_report_running": alive_pid(state / "structure-report.pid"),
           "graph_running": alive_pid(state / "graph.pid")}
    try:
        progress = tomllib.loads((run / "progress.toml").read_text())
        out.update(state=progress.get("state"), completed_parents=progress.get("completed_parents"),
                   total_parents=progress.get("total_parents"),
                   unresolved_equivalence=progress.get("unresolved_equivalence"),
                   progress_age_seconds=age(progress.get("updated_utc")),
                   deferred_heavy_parents=progress.get("continuous_search", {}).get("deferred_heavy_parents"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        out["progress_error"] = str(error)
    now = time.time()
    if isinstance(out.get("completed_parents"), int):
        history.append((now, out["completed_parents"]))
    while history and now - history[0][0] > 1800:
        history.popleft()
    if len(history) >= 2 and history[-1][0] - history[0][0] >= 600:
        (t0, c0), (t1, c1) = history[0], history[-1]
        out["parents_per_minute_30min"] = round((c1 - c0) / ((t1 - t0) / 60), 1)
    try:
        catalog = json.loads((run / "reports" / "catalog.json").read_text())
        out.update(catalog_age_seconds=age(catalog.get("generated_utc")),
                   new_classes=catalog.get("confirmed_absent_classes"),
                   unaudited_classes=catalog.get("unaudited_classes"))
    except (OSError, ValueError) as error:
        out["catalog_error"] = str(error)
    stat = os.statvfs(state)
    out["free_gb"] = round(stat.f_bavail * stat.f_frsize / 1024**3, 1)
    logs = sorted((state / "logs").glob("session-*.log"), key=lambda p: p.stat().st_mtime)
    if logs:
        with open(logs[-1], "rb") as handle:
            handle.seek(max(0, logs[-1].stat().st_size - 2_000_000))
            tail = handle.read().decode(errors="replace").splitlines()
        errors = [l for l in tail if re.search(r"^ERROR|Exception|error:|checkpoint_skipped|Checkpoint export failed", l)]
        out["session_log"] = logs[-1].name
        out["recent_error_lines"] = [l[:300] for l in errors[-3:]]
    return out


def main():
    state, output = Path(sys.argv[1]), Path(sys.argv[2])
    every = float(sys.argv[3]) if len(sys.argv) > 3 else 300.0
    history = deque()
    while True:
        try:
            data = summary(state, history)
        except Exception as error:  # keep the loop alive; report the failure itself
            data = {"utc": datetime.now(timezone.utc).isoformat(timespec="seconds"), "health_error": repr(error)}
        temporary = output.with_suffix(".tmp")
        temporary.write_text(json.dumps(data, indent=1))
        temporary.replace(output)
        time.sleep(every)


if __name__ == "__main__":
    main()
