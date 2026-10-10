"""Replay every rank and orbit of the specified n30 coefficient CSV.

Usage: python3 test/verify_certificate.py results/orbit-.../coefficients.csv
Uses only Python standard-library arithmetic, independently of VBF.
"""
import csv, collections, pathlib, sys
import math, random, hashlib, json, time
n=30
modulus=1073741907
mask=(1<<n)-1
N=mask

def mul(a,b):
    z=0
    while b:
        if b&1: z^=a
        b>>=1
        a<<=1
        if a>>n: a^=modulus
    return z

def power(a,e):
    z=1
    while e:
        if e&1: z=mul(z,a)
        a=mul(a,a)
        e>>=1
    return z

def polynomial_mod(a,b):
    while a and a.bit_length()>=b.bit_length(): a^=b<<(a.bit_length()-b.bit_length())
    return a

def polynomial_gcd(a,b):
    while b: a,b=b,polynomial_mod(a,b)
    return a

def rank(columns):
    pivots={}
    for x in columns:
        while x:
            j=x.bit_length()-1
            if j in pivots: x^=pivots[j]
            else:
                pivots[j]=x
                break
    return len(pivots)

def trace(x):
    z=0
    for _ in range(n):
        z^=x
        x=mul(x,x)
    assert z in (0,1)
    return z

start=time.monotonic()
assert modulus.bit_length()==n+1
for p in (2,3,5):
    assert polynomial_gcd(power(2,1<<(n//p))^2,modulus)==1
assert power(2,1<<n)==2
assert power(2,N)==1
for p in (3,7,11,31,151,331): assert power(2,N//p)!=1
basis=[1<<j for j in range(n)]
trace_mask=sum(trace(x)<<j for j,x in enumerate(basis))
def tr(x): return (x&trace_mask).bit_count()&1

e1=5
e2=(1<<20)+(1<<12)
g=math.gcd(e2-e1,N)
count=N//g
assert (g,count)==(21483,49981)
inv=pow(5,-1,N)
assert math.gcd(1-e2*inv,N)==g
assert (1024-e2*inv)%g==1023%g
base=power(2,1023)
generator=power(2,g)
assert power(generator,count)==1
for p in (151,331): assert power(generator,count//p)!=1
seen=set()
c=base
for _ in range(count):
    assert c not in seen
    seen.add(c)
    c=mul(c,generator)
assert c==base and len(seen)==count and 1 not in seen

def F(x): return mul(2,power(x,e1))^mul(power(2,1024),power(x,e2))
def L(c,x): return power(x,4)^x^mul(c,power(x,1<<20)^power(x,1<<12))
def Q(c,x): return tr(power(x,5)^mul(c,power(x,e2)))

rng=random.Random(20261010)
a_values=[1,2]+[rng.randrange(1,N+1) for _ in range(6)]
for a in a_values:
    c=mul(base,power(a,e2-e1))
    assert c in seen
    scale=mul(2,power(a,5))
    for y in basis+[0,1,rng.randrange(N+1)]:
        x=mul(a,y)
        literal=F(x^a)^F(x)^F(a)
        assert literal==mul(scale,L(c,y))
    columns=[L(c,y) for y in basis]
    assert rank(columns)==28
    assert rank(columns+[1^c])==29

b_values=[1,2]+[rng.randrange(1,N+1) for _ in range(6)]
polar_hist={}
for b in b_values:
    u=power(mul(b,2),(-inv)%N)
    c=mul(mul(b,power(2,1024)),power(u,e2))
    assert c in seen
    for y in basis+[0,1,rng.randrange(N+1)]:
        assert tr(mul(b,F(mul(u,y))))==Q(c,y)
    q_basis=[Q(c,x) for x in basis]
    polar=[sum((Q(c,x^y)^q_basis[i]^q_basis[j])<<j for j,y in enumerate(basis)) for i,x in enumerate(basis)]
    r=rank(polar)
    assert r in (28,30)
    polar_hist[r]=polar_hist.get(r,0)+1

path=pathlib.Path(sys.argv[1])
started=time.monotonic()
d1=[power(x,4)^x for x in basis]
d2=[power(x,1<<20)^power(x,1<<12) for x in basis]
polar_coefficients=[]
q1=[power(x,5) for x in basis]
q2=[power(x,e2) for x in basis]
for i,x in enumerate(basis):
    for j in range(i+1,n):
        y=basis[j]
        a=power(x^y,5)^q1[i]^q1[j]
        b=power(x^y,e2)^q2[i]^q2[j]
        cmask=sum(tr(mul(z,b))<<k for k,z in enumerate(basis))
        polar_coefficients.append((i,j,tr(a),cmask))
c=base
hist_derivative=collections.Counter();hist_polar=collections.Counter();hist_augmented=collections.Counter()
checked=0
with path.open() as handle:
    for row in csv.DictReader(handle):
        checked+=1
        assert int(row['index'])==checked
        assert int(row['coefficient'])==c
        columns=[d1[j]^mul(c,d2[j]) for j in range(n)]
        dr=rank(columns); ar=rank(columns+[1^c])
        assert dr==int(row['derivative_rank'])==28
        assert ar==int(row['augmented_rank'])==29
        polar=[0]*n
        for i,j,a,b in polar_coefficients:
            if a^((c&b).bit_count()&1):
                polar[i]|=1<<j
                polar[j]|=1<<i
        pr=rank(polar)
        assert pr==int(row['polar_rank'])==28
        hist_derivative[dr]+=1;hist_augmented[ar]+=1;hist_polar[pr]+=1
        c=mul(c,generator)
assert checked==count and c==base
result=dict(implementation='independent Python stdlib polynomial arithmetic, full codeword-rank replay and trace masks derived from literal normalized polynomials',n=n,modulus=modulus,coefficients_checked=checked,coverage_complete=True,derivative_ranks=dict(hist_derivative),augmented_ranks=dict(hist_augmented),polar_ranks=dict(hist_polar),du4_certified=True,permutation_certified=True,walsh_support_inclusion_certified=True,coefficients_csv=str(path),coefficients_csv_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),elapsed_seconds=time.monotonic()-started)
print(json.dumps(result,sort_keys=True))
