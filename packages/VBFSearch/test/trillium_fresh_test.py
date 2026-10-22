"""Exercise fresh-job boundaries using synthetic SQLite and an owned fake command."""
import importlib.util
from contextlib import closing
import json
import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
TOOLS = Path(__file__).resolve().parents[1]/'tools'


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS/(name+'.py'))
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


F = load('trillium_fresh')
S = load('closure_supervise')


def fixture(path, state='paused_external'):
    """Make publication metadata only; this fixture makes no mathematical claims."""
    with closing(sqlite3.connect(path)) as db, db:
        db.executescript('CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT);'
                         'CREATE TABLE vbfsearch_artifacts(path TEXT,content BLOB);')
        db.executemany('INSERT INTO metadata VALUES(?,?)', [
            ('vbfsearch_output','schema = "vbfsearch-sqlite-v1"\n'),
            ('vbfsearch_result',json.dumps(dict(state=state,processed_packets=7)))])
        db.execute('INSERT INTO vbfsearch_artifacts VALUES(?,?)', ('fixture',b'\x00\xff'))


class FreshPilotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scratch = self.root/'scratch';self.scratch.mkdir()
        self.local = self.root/'node';self.local.mkdir()
        self.depot = self.root/'depot';self.depot.mkdir()
        self.workspace = self.root/'workspace';(self.workspace/'bin').mkdir(parents=True)
        for name in ('Project.toml','Manifest.toml','bin/vbfsearch'):
            (self.workspace/name).write_text('fixture\n')
        self.env = dict(SCRATCH=str(self.scratch),SLURM_TMPDIR=str(self.local),
            SLURM_JOB_ID='123',SLURM_CPUS_PER_TASK='192',VBF_DEPOT=str(self.depot),
            VBF_WORKSPACE=str(self.workspace),SLURM_JOB_END_TIME=str(time.time()+1800))
        self.args = F.parser().parse_args([])

    def test_budget_reserves_drain_and_copy(self):
        self.args.time=1200
        p=F.plan(self.args,self.env,remaining=1800)
        self.assertEqual(p['budget'],900)
        self.assertIn('-j',p['command'])
        self.assertEqual(p['output'],self.scratch/'vbfsearch'/'pilot-123.sqlite')
        self.assertFalse(p['local'].exists())
        with self.assertRaises(ValueError):F.plan(self.args,self.env,remaining=900)

    def test_scheduling_controls_reach_search_command(self):
        args=F.parser().parse_args(['--window-size=256','--rolling-windows',
                                    '--progress-interval=20'])
        command=F.plan(args,self.env,remaining=1800)['command']
        for flag in ('--window-size=256','--rolling-windows','--progress-interval=20.0'):
            self.assertIn(flag,command)
        for key,values in [('window_size',(0,-1)),
                           ('progress_interval',(0,-1,float('nan'),float('inf')))]:
            for value in values:
                invalid=F.parser().parse_args([])
                setattr(invalid,key,value)
                with self.subTest(key=key,value=value),self.assertRaises(ValueError):
                    F.plan(invalid,self.env,remaining=1800)
        self.assertEqual(list(self.local.iterdir()),[])

    def test_bad_scope_or_resources_fail_before_writes(self):
        for key,value in [('SLURM_CPUS_PER_TASK','1'),('SLURM_JOB_ID','../123'),
                          ('VBF_OUTPUT',str(self.root/'outside.sqlite')),('VBF_OUTPUT',str(self.scratch/'directory'))]:
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):
                F.plan(self.args,dict(self.env,**{key:value}),remaining=1800)
        for value in (0,-1,float('nan'),float('inf')):
            self.args.time=value
            with self.assertRaises(ValueError):F.plan(self.args,self.env,remaining=1800)
        self.assertEqual(list(self.local.iterdir()),[])

    def test_ram_filesystem_is_required(self):
        with patch.object(F.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'nfs\n')):
            with self.assertRaises(ValueError):F.check_local_ram(self.local)
        with patch.object(F.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'tmpfs\n')):
            F.check_local_ram(self.local)

    def test_atomic_copy_preserves_bytes_and_refuses_overwrite(self):
        source=self.local/'source.sqlite';fixture(source)
        before=source.read_bytes();output=self.scratch/'result %?#.sqlite'
        receipt=F.publish(source,output)
        self.assertEqual(output.read_bytes(),before)
        self.assertEqual(source.read_bytes(),before)
        self.assertEqual(receipt['sha256'],F.hashlib.sha256(before).hexdigest())
        self.assertEqual(F.inspect_output(output)['processed_packets'],7)
        with self.assertRaises(FileExistsError):F.publish(source,output)
        self.assertEqual(output.read_bytes(),before)

    def test_copy_failure_retains_source_and_no_false_publication(self):
        source=self.local/'source.sqlite';fixture(source)
        output=self.scratch/'failed.sqlite'
        def fail():raise RuntimeError('injected copy publication failure')
        with self.assertRaises(RuntimeError):F.publish(source,output,before_publish=fail)
        self.assertFalse(output.exists());self.assertTrue(source.exists())
        self.assertEqual(list(self.scratch.iterdir()),[])

    def test_publication_race_does_not_clobber(self):
        source=self.local/'source.sqlite';fixture(source);output=self.scratch/'race.sqlite'
        with self.assertRaises(FileExistsError):
            F.publish(source,output,before_publish=lambda:output.write_text('racing owner'))
        self.assertEqual(output.read_text(),'racing owner')

    def test_active_journal_cannot_be_published(self):
        source=self.local/'source.sqlite';fixture(source)
        Path(str(source)+'-wal').write_bytes(b'active')
        with self.assertRaises(ValueError):F.publish(source,self.scratch/'bad.sqlite')
        self.assertFalse((self.scratch/'bad.sqlite').exists())

    def test_failed_search_is_not_published(self):
        with patch.object(F,'check_local_ram'),patch.object(F.subprocess,'Popen') as popen:
            popen.return_value.wait.return_value=17
            with self.assertRaises(RuntimeError):F.run(self.args,self.env)
        self.assertFalse((self.scratch/'vbfsearch').exists())

    def test_early_signal_is_latched_before_child_start_and_output_is_copied(self):
        original_handler=signal.getsignal(signal.SIGUSR1)
        def start(command,**kw):
            os.kill(os.getpid(),signal.SIGUSR1)
            self.assertEqual(Path(kw['env']['VBF_SEARCH_STOP_FILE']).read_text(),'SIGUSR1\n')
            self.assertEqual(kw['env']['JULIA_PKG_OFFLINE'],'true')
            self.assertEqual(kw['env']['JULIA_DEPOT_PATH'],str(self.depot)+os.pathsep)
            output=Path(next(arg.split('=',1)[1] for arg in command if arg.startswith('--output=')))
            fixture(output)
            return subprocess.CompletedProcess(command,0)
        class Child:
            def wait(self):return 0
        def launch(command,**kw):start(command,**kw);return Child()
        with patch.object(F,'check_local_ram'),patch.object(F.subprocess,'Popen',side_effect=launch):
            result=F.run(self.args,self.env)
        self.assertEqual(Path(result['output']).read_bytes(),(self.local/'vbfsearch-123'/'results.sqlite').read_bytes())
        self.assertEqual(signal.getsignal(signal.SIGUSR1),original_handler)

    def test_supervisor_consumes_request_file_before_worker_initialization(self):
        request=self.root/'request';request.write_text('SIGUSR1\n')
        marker=self.root/'observed'
        code='import os,time,pathlib; time.sleep(0.2); p=pathlib.Path(os.environ["VBF_CLOSURE_STOP_FILE"]); pathlib.Path('+repr(str(marker))+').write_text(p.read_text())'
        result=S.supervise([sys.executable,'-c',code],stop_file=self.root/'unused'/'STOP',
                           request_file=request,grace_seconds=5,poll_seconds=.01)
        self.assertEqual(result,0);self.assertEqual(marker.read_text(),'SIGUSR1\n')


if __name__=='__main__':unittest.main()
