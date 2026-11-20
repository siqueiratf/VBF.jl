"""Compare the complete recorded science of two closure ledgers.

Adapted from data/research/analyses/recursive-frontier-20261022/bench/normalize.py
and cpu-hotspots-20261023/switching/normalize.py. Row IDs, sessions and
timestamps are replaced by LUT identities: a job is (parent LUT, kind, payload),
a parent is its LUT, an EA class is the LUT of its parent. VBFCHN02 coverage
blobs are compared as their decompressed payload with the leading job ID zeroed.
Completed switching jobs store the last packet's evaluation count; that field
is replaced by the exact count of evaluation rows (as in the earlier work).
EA comparison evidence is compared with its timing fields removed and listed
separately, because the 1 s EA budget is wall-clock dependent.

    python3 compare_science.py A/closure.sqlite B/closure.sqlite [--ids]

Exit status 0 when every section is equal. --ids also compares raw row IDs.
"""
from __future__ import annotations
import ctypes, ctypes.util, hashlib, json, pathlib, sqlite3, struct, sys, tomllib

_zstd = ctypes.CDLL(ctypes.util.find_library('zstd') or 'libzstd.so.1')
_zstd.ZSTD_getFrameContentSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
_zstd.ZSTD_getFrameContentSize.restype = ctypes.c_ulonglong
_zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
_zstd.ZSTD_decompress.restype = ctypes.c_size_t
_zstd.ZSTD_isError.argtypes = [ctypes.c_size_t]
_zstd.ZSTD_isError.restype = ctypes.c_uint

_buffer = [None, 0]
def decompress(src):
    n = _zstd.ZSTD_getFrameContentSize(src, len(src))
    if n >= 2**64-2:
        n = 256*1024**2
    if _buffer[1] < n:
        _buffer[0], _buffer[1] = ctypes.create_string_buffer(n), n
    got = _zstd.ZSTD_decompress(_buffer[0], _buffer[1], src, len(src))
    if _zstd.ZSTD_isError(got):
        raise ValueError('invalid Zstandard coverage payload')
    return ctypes.string_at(_buffer[0], got)

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)

def coverage(row):
    evidence = row['evidence']
    if isinstance(evidence, str):
        return ('text', evidence)
    if evidence[:8] != b'VBFCHN02':
        raise ValueError('unsupported coverage encoding '+repr(evidence[:8]))
    data = decompress(evidence[48:])
    job, first, total = struct.unpack_from('<QQQ', data)
    count, templates = struct.unpack_from('<II', data, 44)
    assert job == row['job_id'] and first == row['first_x'] and total == row['total_x']
    assert first+count == row['next_x'] and 1 <= templates <= count <= 65536
    return ('VBFCHN02', hashlib.sha256(b'\0'*8+data[8:]).hexdigest())

# timeout_seconds is the remaining wall-clock EA budget when the comparison started.
TIMING_KEYS = {'seconds', 'elapsed_seconds', 'wall_seconds', 'time_seconds', 'elapsed', 'timeout_seconds'}

def strip_timing(value):
    if isinstance(value, dict):
        return {k: strip_timing(v) for k, v in value.items() if k not in TIMING_KEYS}
    if isinstance(value, list):
        return [strip_timing(v) for v in value]
    return value

def parse_toml(text):
    try:
        return tomllib.loads(text)
    except Exception:
        return {'unparsed': text}

def summarize(path):
    db = sqlite3.connect('file:'+str(pathlib.Path(path).resolve())+'?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    assert db.execute('pragma quick_check').fetchone()[0] == 'ok'
    assert not db.execute('pragma foreign_key_check').fetchall()
    parents = {r['id']: r['candidate_id'] for r in db.execute('select id,candidate_id from parents')}
    jobs = {r['id']: r for r in db.execute('select * from jobs')}
    def key(job_id):
        r = jobs[job_id]
        return (parents.get(r['parent_id']), r['kind'], r['payload'])
    out = {}
    raw = {}
    out['parents'] = [(r['candidate_id'], r['sigma'], r['origin'], r['source']) for r in db.execute('select * from parents')]
    raw['parents'] = [(r['id'], r['candidate_id']) for r in db.execute('select id,candidate_id from parents')]
    cands = []
    for r in db.execute('select id,lut_hex,sigma,apn,degree,class_id,state from candidates'):
        assert hashlib.sha256(bytes.fromhex(r['lut_hex'])).hexdigest() == r['id']
        cands.append((r['id'], r['lut_hex'], r['sigma'], r['apn'], r['degree'],
                      None if r['class_id'] is None else parents[r['class_id']], r['state']))
    out['candidates'] = cands
    out['paths'] = [(parents[r['parent_id']], key(r['job_id']), r['method'], r['cursor'], r['child_id'], r['witness'])
                    for r in db.execute('select * from paths')]
    out['evaluations'] = [(key(r['job_id']), r['direction'], r['combination'], r['candidate_id'], r['apn'])
                          for r in db.execute('select * from evaluations')]
    out['kernels'] = [(key(r['job_id']), r['direction'], r['dimension'], r['evidence']) for r in db.execute('select * from kernels')]
    out['chunks'] = [(key(r['job_id']), r['first_x'], r['next_x'], r['total_x'], r['capped'], coverage(r))
                     for r in db.execute('select * from chunks')]
    construction = []
    for r in jobs.values():
        if r['kind'] == 'deduplicate':
            continue
        result = r['result'] if 'result' in r.keys() else ''
        if r['kind'] == 'switching' and r['status'] == 'done':
            parsed = parse_toml(result)
            total = db.execute('select count(*) from evaluations where job_id=?', (r['id'],)).fetchone()[0]
            if 'evaluations' in parsed:
                parsed['evaluations'] = total
            result = canonical(parsed)
        construction.append((key(r['id']), r['status'], r['direction'], r['combination'], result))
    out['construction_jobs'] = construction
    ea_jobs, ea_timing = [], []
    for r in jobs.values():
        if r['kind'] != 'deduplicate':
            continue
        payload = parse_toml(r['payload'])
        result = parse_toml(r['result'] if 'result' in r.keys() else '')
        for field in ('promoted_parent', 'verified_equivalent_parent'):
            if field in result:
                result[field] = parents[result[field]]
        ea_jobs.append((parents.get(r['parent_id']), r['job_key'], canonical(payload), r['status'], canonical(result)))
    out['ea_jobs'] = ea_jobs
    comps = []
    for r in db.execute('select candidate_id,target_parent,status,evidence from comparisons'):
        evidence = parse_toml(r['evidence'])
        comps.append((r['candidate_id'], parents[r['target_parent']], r['status'], canonical(strip_timing(evidence))))
        ea_timing.append((r['candidate_id'], parents[r['target_parent']], r['status'],
                          {k: v for k, v in evidence.items() if k in TIMING_KEYS} if isinstance(evidence, dict) else None))
    out['ea_comparisons'] = comps
    groups = {}
    for r in db.execute('select id,class_id from candidates where apn=1 and degree=2'):
        groups.setdefault(r['class_id'], []).append(r['id'])
    out['ea_partitions'] = [sorted(g) for c, g in groups.items() if c is not None]
    status = {
        'running_jobs': sum(r['status'] == 'running' for r in jobs.values()),
        'failed_jobs': sum(r['status'] in ('failed', 'blocked') for r in jobs.values()),
        'unresolved_apn_luts': len(groups.get(None, [])),
        'admitted_parents': len(parents),
        'cosets': db.execute('select coalesce(sum(next_x-first_x),0) from chunks').fetchone()[0],
        'switching_directions': db.execute('select count(*) from kernels').fetchone()[0],
        'job_statuses': [list(r) for r in db.execute('select kind,status,count(*) from jobs group by kind,status order by kind,status')],
        'expanded_parents': db.execute("select count(*) from parents p where not exists(select 1 from jobs j where j.parent_id=p.id and j.kind in ('prepare_v5','v5','switching') and j.status!='done')").fetchone()[0],
    }
    out['status'] = [status]
    raw['jobs'] = [(r['id'], r['parent_id'], r['kind'], r['job_key'], r['status']) for r in jobs.values()]
    raw['candidates'] = [(r['id'], r['class_id']) for r in db.execute('select id,class_id from candidates')]
    raw['paths'] = [(r['id'], r['job_id'], r['child_id'], r['cursor']) for r in db.execute('select id,job_id,child_id,cursor from paths')]
    db.close()
    return out, raw, ea_timing

def rows(values):
    return sorted(canonical(v) for v in values)

def compare(a, b, label, limit=5):
    ra, rb = rows(a), rows(b)
    equal = ra == rb
    digest = hashlib.sha256(('\n'.join(ra)+'\n').encode()).hexdigest()[:16]
    report = {'section': label, 'equal': equal, 'rows': [len(ra), len(rb)], 'sha256_a': digest}
    if not equal:
        sa, sb = set(ra), set(rb)
        report['only_a'] = sorted(sa-sb)[:limit]
        report['only_b'] = sorted(sb-sa)[:limit]
        report['count_only_a'] = len(sa-sb)
        report['count_only_b'] = len(sb-sa)
    return report

if __name__ == '__main__':
    a, b = sys.argv[1], sys.argv[2]
    ids = '--ids' in sys.argv
    sa, raw_a, ta = summarize(a)
    sb, raw_b, tb = summarize(b)
    reports = [compare(sa[k], sb[k], k) for k in sa]
    if ids:
        reports += [compare(raw_a[k], raw_b[k], 'ids:'+k) for k in raw_a]
    ok = all(r['equal'] for r in reports)
    for r in reports:
        line = f"{'EQUAL' if r['equal'] else 'DIFF '} {r['section']:<20} rows {r['rows'][0]:>7} {r['rows'][1]:>7} sha {r['sha256_a']}"
        print(line)
        if not r['equal']:
            print('   only A ('+str(r['count_only_a'])+'):', *[x[:400] for x in r['only_a']], sep='\n     ')
            print('   only B ('+str(r['count_only_b'])+'):', *[x[:400] for x in r['only_b']], sep='\n     ')
    print('status A', canonical(sa['status'][0]))
    print('status B', canonical(sb['status'][0]))
    print('EA comparison statuses A', sorted({x[2] for x in ta}), 'B', sorted({x[2] for x in tb}))
    print('SCIENCE', 'EQUAL' if ok else 'DIFFERENT')
    sys.exit(0 if ok else 1)
