#!/usr/bin/env python3
"""Test backup_status.py on a fake STATE tree: python3 test_backup_status.py"""
import json, os, sys, tempfile, time, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backup_status as bs


def put(path, size=0, text=None, mtime=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w" if text is not None else "wb") as f:
        f.write(text) if text is not None else f.write(b"\0" * size)
    if mtime:
        os.utime(path, (mtime, mtime))


class BackupStatus(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        s = self.state = os.path.join(self.tmp.name, "state")
        self.offsite = os.path.join(self.tmp.name, "offsite")
        now = time.time()
        put(f"{s}/config-20261121T100000Z.toml", text='run = "run"\nevidence = "evidence-x"\ncheckpoint_interval_seconds = 28800.0\n[[worker_processes]]\n', mtime=now - 7200)
        put(f"{s}/run/closure.sqlite", 6000)
        put(f"{s}/run/closure.sqlite-wal", 1000)
        put(f"{s}/run/cold/a.seg", 2000)
        put(f"{s}/run/replay/r", 500)
        put(f"{s}/run/execution/e", 500)
        old = f"{s}/snapshots/checkpoint-7-1763700000000-1"
        put(f"{old}/checkpoint-manifest.toml", text='schema = "x"\ncreated_utc = "2026-11-21T08:00:00.000Z"\n')
        put(f"{old}/progress.toml", text="completed_parents = 1234\n")
        staging = f"{s}/snapshots/checkpoint-7-{int((now - 100) * 1000)}-2.staging-AbCd"
        put(f"{staging}/closure.sqlite", 2500)
        put(f"{staging}/cold/a.seg", 500)
        put(f"{self.offsite}/checkpoints/checkpoint-7-1763700000000-1.tar.zst", 4321, mtime=now - 60)
        put(f"{self.offsite}/checkpoints/checkpoint-7-1763700000000-1.sha256", text="x")
        put(f"{self.offsite}/checkpoints/older.tar.zst", 10, mtime=now - 9999)
        put(f"{self.offsite}/export/latest/MANIFEST.json", text=json.dumps({"created_utc": "2026-11-21T09:00:00Z", "class_rows": 99}))

    def tearDown(self):
        self.tmp.cleanup()

    def test_status(self):
        out = os.path.join(self.tmp.name, "status.json")
        bs.main([self.state, out, "--offsite", self.offsite])
        st = json.load(open(out))
        self.assertEqual(st["last_checkpoint"], {"name": "checkpoint-7-1763700000000-1",
                         "created_utc": "2026-11-21T08:00:00Z", "completed_parents": 1234})
        e = st["export_in_progress"]
        self.assertTrue(e["staging"].endswith(".staging-AbCd"))
        self.assertEqual((e["bytes_written"], e["bytes_expected"], e["percent"]), (3000, 10000, 30.0))
        self.assertAlmostEqual(bs.parse_utc(e["eta_utc"]) - time.time(), 233, delta=5)  # 7000 B at 30 B/s
        self.assertEqual(st["next_export"]["interval_seconds"], 28800.0)
        # The session started (config mtime) after the last checkpoint: start + 8 h.
        self.assertAlmostEqual(bs.parse_utc(st["next_export"]["next_utc"]) - time.time(), 28800 - 7200, delta=5)
        self.assertFalse(st["skip_pending"])
        a = st["offsite_archive"]
        self.assertEqual((a["name"], a["bytes"], a["sha256_file"]), ("checkpoint-7-1763700000000-1.tar.zst", 4321, True))
        self.assertEqual(st["results_export"], {"created_utc": "2026-11-21T09:00:00Z", "class_rows": 99})

    def test_idle_skip_and_empty(self):
        for root, dirs, _ in os.walk(os.path.join(self.state, "snapshots")):
            for d in dirs:
                if ".staging-" in d:
                    import shutil
                    shutil.rmtree(os.path.join(root, d))
        put(f"{self.state}/run/CHECKPOINT_SKIP", text="")
        put(f"{self.state}/evidence-x/checkpoint-metrics.jsonl", text=json.dumps({"utc": "2026-11-21T11:30:00.0Z", "skipped": True}) + "\n")
        st = bs.status(self.state, os.path.join(self.tmp.name, "absent"))
        self.assertIsNone(st["export_in_progress"])
        self.assertTrue(st["skip_pending"])
        self.assertIsNone(st["offsite_archive"])
        self.assertIsNone(st["results_export"])
        # The newest of checkpoint, skip and session start counts.
        start = os.path.getmtime(f"{self.state}/config-20261121T100000Z.toml")
        expected = max(start, bs.parse_utc("2026-11-21T11:30:00Z")) + 28800
        self.assertEqual(st["next_export"]["next_utc"], bs.utc(expected))


if __name__ == "__main__":
    unittest.main()
