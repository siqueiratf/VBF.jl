#!/usr/bin/env python3
r"""
Self-contained refutation of the novelty claim of

    O. Kuznetsov, "Quadratic APN Functions in Dimension 8 via Gröbner Basis
    Search in a Self-Equivalence Subspace" (arXiv:2606.11967).

The paper reports four *new* CCZ classes of quadratic APN over GF(2^8) — CLASS-A,
B, C, D. This script shows they are the functions of Table 9 of

    Y. Edel, A. Pott, "A new almost perfect nonlinear function which is not
    quadratic", Adv. Math. Commun. 3(1):59-81, 2009,

i.e. published 17 years earlier. It reconstructs Edel-Pott's Table-9 functions
directly from *their* polynomials, over *their* primitive field (Table 2:
u^8+u^4+u^3+u^2+1), and computes the ortho-derivative signature hash with
Kuznetsov's *own* recipe (his src/classify_apn.py). The hashes reproduce the
values Kuznetsov prints in his Table tab:fullsig for all six classes.

No third-party APN catalog is used. Requirements: SageMath + sboxU
(https://github.com/lpp-crypto/sboxU) — the same tools the paper itself uses.

Run:  sage -python verify_edelpott.py     (or: <venv-with-sage+sboxU>/python verify_edelpott.py)
"""
import hashlib, json
from sage.all import GF, PolynomialRing
import sboxU

# ---- Edel-Pott (2009) field: Table 2 primitive polynomial for n=8 -----------
R = PolynomialRing(GF(2), "X"); X = R.gen()
F = GF(2**8, name="u", modulus=X**8 + X**4 + X**3 + X**2 + 1)
u = F.gen()
assert u.multiplicative_order() == 255, "u must be primitive"
ELT = [sum((((i >> j) & 1)) * u**j for j in range(8)) for i in range(256)]
def _to_int(y):
    if y == 0: return 0
    p = y.polynomial(); return sum(int(p[j]) << j for j in range(p.degree() + 1))
def lut(f):                       # function object -> 256-entry LUT (int)
    return [_to_int(f(x)) for x in ELT]

# ---- Kuznetsov's own signature-hash recipe (src/classify_apn.py) ------------
def _stable(o):
    try: return json.dumps(o, sort_keys=True, default=str)
    except Exception: return repr(o)
def sig_hash(sb):
    pi = sboxU.ortho_derivative(sb)
    sig = (_stable(sboxU.differential_spectrum(pi)),
           _stable(sboxU.absolute_walsh_spectrum(pi)))
    return hashlib.sha256(repr(sig).encode()).hexdigest()[:16]

# ---- Edel-Pott Table 9 (n=8): Gold-x^3 switching chain + function 2.1 -------
# 1.k = 1.parent + u^a * tr(u^b x^3 + u^c x^9)   [absolute trace, GF(2)]
CHAIN = [                       # (name, parent, a, b, c)
    ("1.2", "1.1", 0, 48, 0), ("1.3", "1.1", 1, 63, 252),
    ("1.5", "1.2", 51, 253, 102), ("1.8", "1.5", 68, 153, 51),
    ("1.11", "1.8", 85, 243, 170), ("1.15", "1.11", 102, 6, 119),
]
def build_chain():
    L = {"1.1": lut(lambda x: x**3)}            # 1.1 = Gold x^3
    for nm, par, a, b, c in CHAIN:
        ua = u**a; out = L[par][:]
        for i, x in enumerate(ELT):
            if (u**b * x**3 + u**c * x**9).trace() == 1:
                out[i] = _to_int(ELT[out[i]] + ua)
        L[nm] = out
    return L

def build_2_1():                                # 2.1 = x^3 + x^17 + u^16(x^18+x^33) + u^15 x^48
    return lut(lambda x: x**3 + x**17 + u**16 * (x**18 + x**33) + u**15 * x**48)

# ---- Kuznetsov's published hashes (arXiv:2606.11967, Table tab:fullsig) ------
KUZ = {"A": "9d95d9c4a5e2dfdd", "B": "c5f52f5659346f9f", "C": "74a30c1a17d45761",
       "D": "024ba500f4bac35b", "E": "11cc72af6d61925d", "F": "d15183d1bdf9a1b4"}

def main():
    L = build_chain()
    # Edel-Pott Table-9 function  ==  Kuznetsov class
    MAP = [("A", "2.1", build_2_1()), ("B", "1.3", L["1.3"]), ("C", "1.2", L["1.2"]),
           ("D", "1.11", L["1.11"]), ("E", "1.1", L["1.1"]), ("F", "1.15", L["1.15"])]
    print("Kuznetsov class   Edel-Pott 2009 (Table 9)   sig_hash            published   match")
    ok = True
    for cls, ep, sb in MAP:
        h = sig_hash(sb); m = (h == KUZ[cls]); ok &= m
        print(f"  CLASS-{cls:1s}          function {ep:5s}            {h}    {KUZ[cls]}    {'OK' if m else 'FAIL'}")
    assert ok, "at least one class did NOT match Kuznetsov's published hash"
    print("\nAll six of Kuznetsov's classes reproduce Edel-Pott (2009) Table-9 functions.")
    print("The four 'new' classes A,B,C,D = Edel-Pott 2.1, 1.3, 1.2, 1.11 -- not new.")

if __name__ == "__main__":
    main()
