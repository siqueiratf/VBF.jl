"""Replay all positive EA certificates in a saved proposal report, using Python stdlib.
Usage: python3 verify_proposal_witnesses.py REPORT.toml
"""
import tomllib,hashlib,struct,sys
with open(sys.argv[1],'rb') as f: d=tomllib.load(f)
def rank(cols):
 p={}
 for x in cols:
  while x:
   b=x.bit_length()-1
   if b in p:x^=p[b]
   else:p[b]=x;break
 return len(p)
def sha(lut):return hashlib.sha256(b''.join(struct.pack('<H',x) for x in lut)).hexdigest()
count=points=0
for r in d['proposals']:
 F=r['lut'];n=r['n'];mask=(1<<n)-1
 assert sha(F)==r['sha256_uint16_le']
 for proof in r.get('equivalence_checks',[])+r.get('proposal_pair_checks',[]):
  if proof['status'] not in ('identical_lut','ea_equivalent_witness_replayed'):continue
  G=proof['reference_lut'];A=proof['columns'];c=proof['constant']
  assert len(A)==2*n and rank(A)==2*n
  assert all(a>>n==0 for a in A[:n])
  assert rank(A[:n])==n and rank([a>>n for a in A[n:]])==n
  if 'reference_sha256_uint16_le' in proof:assert sha(G)==proof['reference_sha256_uint16_le']
  seen=set()
  for x,f in enumerate(F):
   q=(x<<n)|f;z=c
   for j,a in enumerate(A):
    if q>>j&1:z^=a
   y=z>>n;assert y not in seen;seen.add(y)
   assert G[y]==z&mask
  assert len(seen)==1<<n
  count+=1;points+=len(F)
print(f'Independent Python GF(2) rank/block/hash/full-graph replay: {count} positive certificates; {points} graph points; passed.')
