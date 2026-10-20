"""Supervise one search process, translating shutdown signals into cooperative STOP.

The supervisor never opens a checkpoint. It waits for the child to drain after
USR1, TERM, INT or a deadline, and kills its owned process group only if the
explicit shutdown grace expires. Signals delivered before dispatch prevent it.
"""
import argparse
from pathlib import Path
import math
import os
import signal
import subprocess
import tempfile
import time


class StopRequest:
    def __init__(self):
        self.reason = None
    def request(self, signum, _frame=None):
        if self.reason is None:
            self.reason = signal.Signals(signum).name


def supervise(command, *, stop_file, grace_seconds=600.0, duration_seconds=None,
              request=None, poll_seconds=0.05, environment=None):
    """Return the child status, 124 on a drain timeout, or zero before dispatch."""
    if not command or not math.isfinite(grace_seconds) or grace_seconds <= 0 or not math.isfinite(poll_seconds) or poll_seconds <= 0:
        raise ValueError("command and positive shutdown/poll intervals required")
    if duration_seconds is not None and (not math.isfinite(duration_seconds) or duration_seconds < 0):
        raise ValueError("duration_seconds must be nonnegative")
    request = StopRequest() if request is None else request
    previous = {}
    for signum in (signal.SIGUSR1, signal.SIGTERM, signal.SIGINT):
        previous[signum] = signal.signal(signum, request.request)
    try:
        if request.reason is not None or duration_seconds == 0:
            return 0
        with tempfile.TemporaryDirectory(prefix="vbf-closure-control-") as temporary:
            private_stop = Path(temporary) / "STOP"
            child_env = dict(os.environ if environment is None else environment)
            child_env["VBF_CLOSURE_STOP_FILE"] = str(private_stop)
            if request.reason is not None:
                return 0
            process = subprocess.Popen(command, env=child_env, start_new_session=True)
            started = time.monotonic(); requested_at = None
            try:
                while process.poll() is None:
                    now = time.monotonic()
                    if duration_seconds is not None and now - started >= duration_seconds and request.reason is None:
                        request.reason = "deadline"
                    if request.reason is not None:
                        if requested_at is None:
                            requested_at = now
                            private_stop.write_text(request.reason + "\n")
                        target = Path(stop_file)
                        # The controller owns creation of its fresh evidence directory.
                        if target.parent.is_dir() and not target.exists():
                            target.write_text(request.reason + "\n")
                        if now - requested_at >= grace_seconds:
                            try:
                                os.killpg(process.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                            process.wait()
                            return 124
                    time.sleep(poll_seconds)
                status = process.wait()
                return status if status >= 0 else 128 - status
            except BaseException:
                # Even supervisor I/O errors must not orphan an owned compute job.
                try:
                    private_stop.write_text("supervisor_failure\n")
                    process.wait(timeout=grace_seconds)
                except (OSError, subprocess.TimeoutExpired):
                    if process.poll() is None:
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        process.wait()
                raise
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stop-file", required=True)
    parser.add_argument("--grace-seconds", type=float, default=600)
    parser.add_argument("--duration-seconds", type=float)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    options = parser.parse_args(arguments)
    command = options.command[1:] if options.command[:1] == ["--"] else options.command
    return supervise(command, stop_file=options.stop_file, grace_seconds=options.grace_seconds,
                     duration_seconds=options.duration_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
