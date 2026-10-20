"""Bounded reporting must release source snapshots and resume failed batches."""
import importlib.util
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("live_catalog_report", Path(__file__).parents[1] / "tools/analysis/live_catalog_report.py")
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


class CatalogReportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.run = Path(self.temporary.name)
        db = sqlite3.connect(self.run / "closure.sqlite")
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT,sigma TEXT,origin TEXT,source TEXT)")
        db.executemany("INSERT INTO parents VALUES(?,?,?,?,?)", [(i, str(i), "known" if i <= 2 else "new", "root" if i <= 2 else "discovered", "fixture") for i in range(1, 8)])
        db.commit(); db.close()
        (self.run / "progress.toml").write_text("total_parents = 7\ninitial_roots = 2\n")
        self.cache_path = self.run / "cache.sqlite"
        self.cache = sqlite3.connect(self.cache_path)
        self.cache.execute("CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
        self.cache.execute("CREATE TABLE classes(id INTEGER PRIMARY KEY,sha TEXT,sigma TEXT,origin TEXT,source TEXT,absent INTEGER)")

    def tearDown(self):
        self.cache.close()
        self.temporary.cleanup()

    def test_bounded_catchup_closes_snapshot_before_cache_work(self):
        sizes = []
        def after_read(rows):
            sizes.append(len(rows))
            writer = sqlite3.connect(self.run / "closure.sqlite", timeout=0.1)
            try:
                writer.execute("UPDATE parents SET source=source WHERE id=7"); writer.commit()
                self.assertEqual(writer.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()[0], 0)
            finally:
                writer.close()
        value = REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=2, max_batches=2, after_read=after_read)
        self.assertEqual((value["last"], value["absent"], value["roots"], value["complete"]), (4, 2, 2, False))
        self.assertEqual(sizes, [2, 2])
        self.cache.close(); self.cache = sqlite3.connect(self.cache_path)
        statements = []
        self.cache.set_trace_callback(statements.append)
        value = REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=2, max_batches=2)
        self.assertEqual((value["last"], value["total"], value["absent"], value["complete"]), (7, 7, 5, True))
        self.assertFalse(any("COUNT(*)" in sql for sql in statements))

    def test_failed_batch_rolls_back_rows_and_counters_then_resumes(self):
        REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=2, max_batches=1)
        self.cache.execute("CREATE TRIGGER fail_batch BEFORE INSERT ON classes WHEN NEW.id=4 BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        self.cache.commit()
        with self.assertRaises(sqlite3.IntegrityError):
            REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=2, max_batches=1)
        self.assertEqual(self.cache.execute("SELECT COUNT(*) FROM classes").fetchone()[0], 2)
        self.assertEqual(REPORT.cache_state(self.cache)["last"], 2)
        self.cache.execute("DROP TRIGGER fail_batch"); self.cache.commit()
        value = REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=3, max_batches=2)
        self.assertEqual((value["total"], value["absent"], value["complete"]), (7, 5, True))

    def test_source_gap_and_replaced_cutoff_fail_closed(self):
        REPORT.catch_up(self.cache, self.run, {"known"}, batch_size=2, max_batches=1)
        (self.run / "progress.toml").write_text("total_parents=1\ninitial_roots=2\n")
        with self.assertRaisesRegex(ValueError, "truncated"):
            REPORT.catch_up(self.cache, self.run, {"known"})
        (self.run / "progress.toml").write_text("total_parents=7\ninitial_roots=2\n")
        db = sqlite3.connect(self.run / "closure.sqlite")
        db.execute("DELETE FROM parents WHERE id=4"); db.commit(); db.close()
        with self.assertRaisesRegex(ValueError, "gap"):
            REPORT.catch_up(self.cache, self.run, {"known"})
        self.assertEqual(REPORT.cache_state(self.cache)["last"], 2)

    def test_invalid_bounds_and_unpublished_roots(self):
        for options in ({"batch_size": 0}, {"max_batches": -1}, {"batch_size": True}):
            with self.assertRaises(ValueError):
                REPORT.catch_up(self.cache, self.run, {"known"}, **options)
        with self.assertRaisesRegex(ValueError, "roots are absent"):
            REPORT.catch_up(self.cache, self.run, set())
        self.assertEqual(REPORT.cache_state(self.cache)["last"], 0)

    def test_report_retains_reference_binding_with_partial_coverage(self):
        reference = self.run / "reference"; reference.mkdir()
        index = reference / "ccz_sigma_index.sqlite"
        db = sqlite3.connect(index)
        db.execute("CREATE TABLE ccz_sigma_index(n INTEGER,sigma_hash TEXT)")
        db.execute("INSERT INTO ccz_sigma_index VALUES(8,'known')"); db.commit(); db.close()
        manifest = dict(n=8, excluded_private_sources=["legacy20261009_n8"], quadratic_classes=1,
            original_input_sha256="fixed-input", artifacts={index.name: dict(bytes=index.stat().st_size,
                sha256=hashlib.sha256(index.read_bytes()).hexdigest())})
        (reference / "manifest.json").write_text(json.dumps(manifest))
        with redirect_stdout(io.StringIO()):
            REPORT.report(self.run, reference, once=True, batch_size=2, max_batches=1)
        value = json.loads((self.run / "reports/catalog.json").read_text())
        self.assertEqual((value["classes_checked"], value["initial_roots"], value["parent_cutoff"]), (2, 2, 2))
        self.assertFalse(value["caught_up"])
        self.assertEqual(value["backlog_classes"], 5)
        manifest["original_input_sha256"] = "replaced-input"
        (reference / "manifest.json").write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "another run/reference"):
            REPORT.report(self.run, reference, once=True)


if __name__ == "__main__":
    unittest.main()
