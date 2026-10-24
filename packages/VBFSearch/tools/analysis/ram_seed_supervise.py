"""Supervise one local seed benchmark with explicit resident-memory headroom.

The child receives a cooperative STOP file. Only that child process group is
terminated if it exceeds the hard limit or fails to drain. This supervisor does
not enforce Linux's ineffective RLIMIT_RSS or constrain Julia virtual mappings.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def memory_available():
    for line in Path('/proc/meminfo').read_text().splitlines():
        if line.startswith('MemAvailable:'):
            return int(line.split()[1]) * 1024
    raise RuntimeError('Linux MemAvailable is required for the local benchmark')


def child_rss(pid):
    table = {}
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / 'stat').read_text()
            fields = raw[raw.rfind(')') + 2:].split()
            table[int(entry.name)] = (int(fields[1]), max(0, int(fields[21])))
        except (OSError, ValueError):
            continue
    owned = {pid}
    while True:
        expanded = owned | {p for p, (parent, _) in table.items() if parent in owned}
        if expanded == owned:
            break
        owned = expanded
    return sum(table.get(p, (0, 0))[1] for p in owned) * os.sysconf('SC_PAGE_SIZE')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--soft-gib', type=float, default=6.5)
    parser.add_argument('--hard-gib', type=float, default=8.0)
    parser.add_argument('--available-floor-gib', type=float, default=10.0)
    parser.add_argument('--grace-seconds', type=float, default=180.0)
    parser.add_argument('--max-seconds', type=float, default=21600.0)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or not 0 < args.soft_gib < args.hard_gib:
        parser.error('command and 0 < soft limit < hard limit are required')
    if args.available_floor_gib <= 0 or args.grace_seconds <= 0 or args.max_seconds <= 0:
        parser.error('headroom and time limits must be positive')
    args.directory.mkdir(parents=True, exist_ok=False)
    stop = args.directory.resolve() / 'STOP'
    env = os.environ.copy()
    env['VBF_RAM_STOP_FILE'] = str(stop)
    env['VBF_CLOSURE_STOP_FILE'] = str(stop)
    config = dict(command=command, soft_gib=args.soft_gib, hard_gib=args.hard_gib,
                  available_floor_gib=args.available_floor_gib,
                  max_seconds=args.max_seconds, stop_file=str(stop))
    (args.directory / 'launch.json').write_text(json.dumps(config, indent=2) + '\n')
    if memory_available() < args.available_floor_gib * 2**30:
        raise RuntimeError('Not enough available memory to start with reserved headroom')
    started = time.monotonic()
    peak = 0
    minimum_available = memory_available()
    stop_time = None
    reason = None
    last_progress = 0.0
    terminated = False
    with (args.directory / 'worker.log').open('w') as log:
        child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                 start_new_session=True)
        try:
            while child.poll() is None:
                elapsed = time.monotonic() - started
                rss = child_rss(child.pid)
                available = memory_available()
                peak = max(peak, rss)
                minimum_available = min(minimum_available, available)
                trigger = ('rss_soft_limit' if rss >= args.soft_gib * 2**30 else
                           'available_headroom' if available < args.available_floor_gib * 2**30 else
                           'wall_limit' if elapsed >= args.max_seconds else None)
                if trigger and stop_time is None:
                    reason = trigger
                    stop.write_text(reason + '\n')
                    stop_time = time.monotonic()
                    print('COOPERATIVE_STOP', reason, flush=True)
                if rss >= args.hard_gib * 2**30 or (
                        stop_time is not None and time.monotonic() - stop_time > args.grace_seconds):
                    reason = 'rss_hard_limit' if rss >= args.hard_gib * 2**30 else 'drain_timeout'
                    os.killpg(child.pid, signal.SIGTERM)
                    terminated = True
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                    break
                if elapsed - last_progress >= 30:
                    last_progress = elapsed
                    print(json.dumps(dict(elapsed_seconds=round(elapsed, 1),
                          rss_gib=round(rss / 2**30, 3), peak_rss_gib=round(peak / 2**30, 3),
                          available_gib=round(available / 2**30, 3))), flush=True)
                time.sleep(.25)
            status = child.wait()
        except BaseException:
            if child.poll() is None:
                stop.write_text('supervisor_interrupted\n')
                try:
                    child.wait(timeout=args.grace_seconds)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
            raise
    receipt = dict(exit_code=status, elapsed_seconds=time.monotonic() - started,
                   peak_aggregate_rss_bytes=peak, minimum_available_bytes=minimum_available,
                   stop_reason=reason, force_terminated=terminated)
    (args.directory / 'supervision.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('SUPERVISED_RESULT', json.dumps(receipt), flush=True)
    return status if status >= 0 else 128 - status


if __name__ == '__main__':
    raise SystemExit(main())
