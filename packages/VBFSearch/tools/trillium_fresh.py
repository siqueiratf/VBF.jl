"""Run a fresh Slurm CPU pilot in local RAM and publish its single SQLite on scratch.

Only the command's supervisor handles compute-process lifetime. Batch signals
latch a file request, including before that supervisor exists. No SSH, package
installation, checkpoint migration or scheduler submission is performed here.
"""
import argparse
from contextlib import closing
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import sqlite3
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
GRACE_SECONDS = 600
COPY_MARGIN_SECONDS = 300


def remaining_seconds(env):
    """Read the actual allocation end time, including sbatch walltime overrides."""
    if env.get('SLURM_JOB_END_TIME'):
        end = float(env['SLURM_JOB_END_TIME'])
    else:
        result = subprocess.run(['scontrol', 'show', 'job', '-o', env['SLURM_JOB_ID']],
                                check=True, text=True, stdout=subprocess.PIPE, timeout=10)
        match = re.search(r'(?:^|\s)EndTime=(\S+)', result.stdout)
        if not match or match[1] in ('Unknown', 'None', 'N/A', 'Unlimited'):
            raise ValueError('Slurm did not provide a finite job end time')
        end = datetime.datetime.fromisoformat(match[1]).timestamp()
    if not math.isfinite(end):
        raise ValueError('Slurm job end time must be finite')
    return end-time.time()


def plan(args, env, *, remaining=None):
    """Resolve one fresh run and reserve drain/copy time before touching storage."""
    for key in ('SCRATCH', 'SLURM_TMPDIR', 'SLURM_JOB_ID', 'SLURM_CPUS_PER_TASK', 'VBF_DEPOT'):
        if not env.get(key):
            raise ValueError('required environment variable: '+key)
    if not re.fullmatch(r'[0-9]+', env['SLURM_JOB_ID']):
        raise ValueError('invalid SLURM_JOB_ID')
    if int(env['SLURM_CPUS_PER_TASK']) < 1:
        raise ValueError('at least one allocated CPU is required')
    if args.start < 1 or args.end < args.start:
        raise ValueError('seed interval must satisfy 1 <= start <= end')
    if not math.isfinite(args.time) or args.time <= 0:
        raise ValueError('search time must be positive and finite')
    if args.window_size <= 0:
        raise ValueError('window size must be positive')
    if not math.isfinite(args.progress_interval) or args.progress_interval <= 0:
        raise ValueError('progress interval must be positive and finite')
    left = remaining_seconds(env) if remaining is None else remaining
    budget = min(args.time, left-GRACE_SECONDS-COPY_MARGIN_SECONDS)
    if not math.isfinite(budget) or budget <= 0:
        raise ValueError('allocation has insufficient time for search, drain and copy-out')
    workspace = Path(env.get('VBF_WORKSPACE', str(ROOT))).resolve()
    depot = Path(env['VBF_DEPOT']).resolve()
    scratch = Path(env['SCRATCH']).resolve()
    local = Path(env['SLURM_TMPDIR']).resolve() / ('vbfsearch-'+env['SLURM_JOB_ID'])
    output = Path(env.get('VBF_OUTPUT', str(scratch/'vbfsearch'/('pilot-'+env['SLURM_JOB_ID']+'.sqlite')))).absolute()
    if output.suffix.lower() not in ('.sqlite', '.sqlite3', '.db'):
        raise ValueError('VBF_OUTPUT must name a new .sqlite/.sqlite3/.db file')
    if scratch not in output.resolve().parents:
        raise ValueError('persistent VBF_OUTPUT must be beneath SCRATCH')
    for path in (workspace/'Project.toml', workspace/'Manifest.toml', workspace/'bin'/'vbfsearch'):
        if not path.is_file():
            raise ValueError('staged workspace file missing: '+str(path))
    if not depot.is_dir():
        raise ValueError('prepared offline Julia depot is missing: '+str(depot))
    command = [str(workspace/'bin'/'vbfsearch'), '--recursive-closure', '-j',
               '--start='+str(args.start), '--end='+str(args.end),
               '--time='+str(budget), '--output='+str(local/'results.sqlite')]
    if args.campaign:
        command += ['--campaign', str(Path(args.campaign).absolute())]
    if args.heap:
        command += ['--heap', args.heap]
    if args.window_size != 100:
        command += ['--window-size='+str(args.window_size)]
    if args.rolling_windows:
        command += ['--rolling-windows']
    if args.progress_interval != 15:
        command += ['--progress-interval='+str(args.progress_interval)]
    return dict(command=command, workspace=workspace, depot=depot, local=local,
                source=local/'results.sqlite', output=output, budget=budget)


def check_local_ram(path):
    """Refuse placing the live WAL database on a shared filesystem."""
    result = subprocess.run(['stat', '-f', '-c', '%T', str(path)], check=True,
                            text=True, stdout=subprocess.PIPE, timeout=10)
    if result.stdout.strip() not in ('tmpfs', 'ramfs'):
        raise ValueError('SLURM_TMPDIR must be a node-local RAM filesystem')


def inspect_output(path):
    """Check publication metadata and journal state without scanning result rows."""
    path = Path(path).absolute()
    if not path.is_file() or path.is_symlink():
        raise ValueError('finished SQLite output is missing or symlinked: '+str(path))
    if any(Path(str(path)+s).exists() for s in ('-wal', '-shm', '-journal')):
        raise ValueError('finished SQLite still has journal files')
    with closing(sqlite3.connect(path.as_uri()+'?mode=ro', uri=True)) as db:
        if db.execute('PRAGMA journal_mode').fetchone()[0] != 'delete':
            raise ValueError('finished SQLite is not in single-file journal mode')
        manifest = db.execute("SELECT value FROM metadata WHERE key='vbfsearch_output'").fetchone()
        if not manifest or not re.search(r'^schema = "vbfsearch-sqlite-v1"$', manifest[0], re.M):
            raise ValueError('unrecognized single-file search output')
        result = db.execute("SELECT value FROM metadata WHERE key='vbfsearch_result'").fetchone()
        if not result:
            raise ValueError('finished SQLite result metadata is missing')
        db.execute('SELECT path FROM vbfsearch_artifacts LIMIT 1').fetchall()
        return json.loads(result[0])


def sync_directory(path):
    """Make the persistent publication durable before returning job success."""
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def publish(source, output, *, before_publish=lambda: None):
    """Copy a closed output once, hash that stream, then publish without clobbering."""
    source, output = Path(source), Path(output)
    result = inspect_output(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(output):
        raise FileExistsError('persistent output already exists: '+str(output))
    before = source.stat()
    if shutil.disk_usage(output.parent).free < before.st_size+128*1024**2:
        raise OSError('insufficient scratch space for the finished SQLite')
    descriptor, name = tempfile.mkstemp(prefix='.'+output.name+'.', suffix='.partial', dir=output.parent)
    temporary = Path(name)
    digest = hashlib.sha256()
    try:
        with os.fdopen(descriptor, 'wb') as writer, source.open('rb') as reader:
            while True:
                data = reader.read(8*1024**2)
                if not data:
                    break
                writer.write(data);digest.update(data)
            writer.flush();os.fsync(writer.fileno())
        after = source.stat()
        if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
            raise ValueError('source SQLite changed during copy-out')
        if temporary.stat().st_size != before.st_size or inspect_output(temporary) != result:
            raise ValueError('persistent copy differs from finished SQLite')
        before_publish()
        os.link(temporary, output)
        sync_directory(output.parent)
    finally:
        temporary.unlink(missing_ok=True)
    sync_directory(output.parent)
    return dict(output=str(output), bytes=before.st_size, sha256=digest.hexdigest(), result=result)


def run(args, env=None):
    """Latch early scheduler signals, drain the owned search, then copy out once."""
    env = dict(os.environ if env is None else env)
    launch = plan(args, env)
    check_local_ram(Path(env['SLURM_TMPDIR']))
    local = launch['local']
    local.mkdir()
    if os.path.lexists(launch['output']):
        raise FileExistsError('persistent output already exists: '+str(launch['output']))
    request = local/'STOP'
    reason = []

    def stop(signum, _frame):
        if not reason:
            reason.append(signal.Signals(signum).name)
            request.write_text(reason[0]+'\n')

    previous = {s: signal.signal(s, stop) for s in (signal.SIGUSR1, signal.SIGTERM, signal.SIGINT)}
    # Keep the runtime's standard-library caches, while excluding the user depot.
    child_env = dict(env, JULIA_DEPOT_PATH=str(launch['depot'])+os.pathsep,
        JULIA_PKG_OFFLINE='true', JULIA_PKG_PRECOMPILE_AUTO='0', JULIA_NUM_PRECOMPILE_TASKS='1',
        OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1', MKL_NUM_THREADS='1',
        TMPDIR=str(local), SQLITE_TMPDIR=str(local), VBF_SEARCH_STOP_FILE=str(request))
    child_env.pop('VBF_CLOSURE_STOP_FILE', None)
    try:
        print('Pilot command: '+shlex.join(launch['command']), flush=True)
        print('Persistent output: '+str(launch['output']), flush=True)
        process = subprocess.Popen(launch['command'], cwd=launch['workspace'], env=child_env)
        status = process.wait()
        if status != 0:
            raise RuntimeError('search failed with status '+str(status)+'; local working data: '+str(local))
        receipt = publish(launch['source'], launch['output'])
        print('Published SQLite: '+receipt['output']+'; '+str(receipt['bytes'])+
              ' bytes; SHA256 '+receipt['sha256'], flush=True)
        return receipt
    finally:
        for s, handler in previous.items():
            signal.signal(s, handler)


def parser():
    """Expose only the fresh pilot's seed range, duration and existing search knobs."""
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--start', type=int, default=1)
    p.add_argument('--end', type=int, default=100)
    p.add_argument('--time', type=float, default=600, help='search seconds; shortened to preserve drain/copy time')
    p.add_argument('--campaign', help='staged audited campaign, otherwise the command default')
    p.add_argument('--heap', help='optional Julia heap hint, e.g. 64G')
    p.add_argument('--window-size', type=int, default=100, help='parents per scheduling window')
    p.add_argument('--rolling-windows', action='store_true', help='overlap up to two scheduling windows')
    p.add_argument('--progress-interval', type=float, default=15, help='seconds between progress updates')
    return p


if __name__ == '__main__':
    try:
        run(parser().parse_args())
    except Exception as error:
        print('Trillium pilot failed: '+str(error), file=__import__('sys').stderr, flush=True)
        raise SystemExit(1)
