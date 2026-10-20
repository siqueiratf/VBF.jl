"""Signal/deadline integration tests use disposable child processes only."""
import importlib.util
from pathlib import Path
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "tools/closure_supervise.py"
SPEC = importlib.util.spec_from_file_location("closure_supervise", SCRIPT)
SUPERVISOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SUPERVISOR)


class SupervisorTests(unittest.TestCase):
    def test_signal_before_dispatch_and_zero_deadline_skip_child(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "started"
            command = [sys.executable, "-c", "from pathlib import Path; import sys; Path(sys.argv[1]).touch()", str(marker)]
            request = SUPERVISOR.StopRequest(); request.request(signal.SIGTERM)
            self.assertEqual(SUPERVISOR.supervise(command, stop_file=marker.parent / "STOP", request=request), 0)
            self.assertEqual(SUPERVISOR.supervise(command, stop_file=marker.parent / "STOP", duration_seconds=0), 0)
            self.assertFalse(marker.exists())

    def test_shutdown_signals_drain_using_private_stop_without_creating_evidence(self):
        for signum in (signal.SIGUSR1, signal.SIGTERM, signal.SIGINT):
            with self.subTest(signum=signum), tempfile.TemporaryDirectory() as temporary:
                self.check_signal_drain(signum, temporary)

    def check_signal_drain(self, signum, temporary):
        ready = Path(temporary) / "ready"
        evidence = Path(temporary) / "fresh-evidence"
        code = "import os,time,sys; from pathlib import Path; Path(sys.argv[1]).touch(); p=Path(os.environ['VBF_CLOSURE_STOP_FILE']);\nwhile not p.exists(): time.sleep(.01)\n"
        process = subprocess.Popen([sys.executable, str(SCRIPT), "--stop-file", str(evidence / "STOP"), "--grace-seconds", "2", "--", sys.executable, "-c", code, str(ready)])
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(ready.exists())
            os.kill(process.pid, signum)
            self.assertEqual(process.wait(timeout=4), 0)
            self.assertFalse(evidence.exists())
        finally:
            if process.poll() is None:
                process.kill(); process.wait()

    def test_supervisor_io_failure_still_drains_owned_child(self):
        with tempfile.TemporaryDirectory() as temporary:
            pid_file = Path(temporary) / "pid"
            stop = Path(temporary) / "STOP"
            code = "import os,time,sys; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); p=Path(os.environ['VBF_CLOSURE_STOP_FILE']);\nwhile not p.exists(): time.sleep(.01)\n"
            write_text = Path.write_text
            def fail_only_evidence(path, *args, **kwargs):
                if path == stop:
                    raise PermissionError("injected report filesystem failure")
                return write_text(path, *args, **kwargs)
            with patch.object(Path, "write_text", fail_only_evidence):
                with self.assertRaisesRegex(PermissionError, "injected"):
                    SUPERVISOR.supervise([sys.executable, "-c", code, str(pid_file)],
                        stop_file=stop, duration_seconds=.1, grace_seconds=2, poll_seconds=.01)
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pid_file.read_text()), 0)

    def test_deadline_escalation_and_exit_status_and_handlers(self):
        with tempfile.TemporaryDirectory() as temporary:
            before = signal.getsignal(signal.SIGTERM)
            status = SUPERVISOR.supervise([sys.executable, "-c", "import time; time.sleep(10)"],
                stop_file=Path(temporary) / "STOP", duration_seconds=.05, grace_seconds=.1, poll_seconds=.01)
            self.assertEqual(status, 124)
            self.assertEqual(signal.getsignal(signal.SIGTERM), before)
            self.assertEqual(SUPERVISOR.supervise([sys.executable, "-c", "raise SystemExit(7)"], stop_file=Path(temporary) / "STOP"), 7)

    def test_invalid_budgets_fail_before_dispatch(self):
        for options in ({"grace_seconds": 0}, {"grace_seconds": float("nan")}, {"duration_seconds": -1}):
            with self.assertRaises(ValueError):
                SUPERVISOR.supervise([sys.executable], stop_file="unused", **options)


if __name__ == "__main__":
    unittest.main()
