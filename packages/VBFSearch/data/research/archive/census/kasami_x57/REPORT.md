# Does the CCZ class of x^57 on GF(2^8) contain a quadratic function?

Date: 2026-10-08. Tool: sboxU v1.3.1 (commit e1374ae of the `legacy` branch).
See README.md for the installation.

**Verdict: the gap is closed.** The CCZ class of x^57 is equal to the EA class
of x^57. Every function in this class has algebraic degree 4. Thus the class
contains no quadratic function, and it cannot contain a function of
`../new_classes_553.tsv`.

## Method

Canteaut and Perrin (2019) show that each function G that is CCZ-equivalent to
F comes from an n-dimensional subspace V of the Walsh zeroes Z_F.
`sboxU.ccz_equivalent_function(F, V)` gives G for each V. Thus one function
for each subspace gives at least one representative of each EA class in the CCZ
class. The algebraic degree (≥ 2) is an EA invariant. Thus the CCZ class
contains a quadratic function if and only if a representative has degree 2.

`ccz_ea_classes.py` lists the subspaces with
`get_lat_zeroes_spaces(F, n_threads=1)`. Then it calculates the degree and the
thickness spectrum of each representative. The number of Walsh zeroes from
sboxU must be equal to the number from a numpy fast Walsh transform.

**CAUTION — sboxU thread bug.** Use 1 thread. If the thread count does not
divide 2^n, `lat_zeroes_cpp` drops LAT columns, and the result is incomplete
(with 3 threads, the Dillon permutation shows 164 subspaces, not 222). The
scripts refuse other thread counts.

## Result for x^57

| Input | Walsh zeroes | 8-dim subspaces | Thickness | Degrees |
|---|---:|---:|---|---|
| catalog 43 (x^57, 0x11B) | 16,575 | 1 | {0: 1} | {4: 1} |
| catalog 581 (x^57, 0x11D) | 16,575 | 1 | {0: 1} | {4: 1} |
| catalog 634 (x^228, 0x11B) | 16,575 | 1 | {0: 1} | {4: 1} |
| x^57 mod 0x11B and 0x11D (`power_luts.py`) | 16,575 | 1 | {0: 1} | {4: 1} |
| x^228 mod 0x11B and 0x11D | 16,575 | 1 | {0: 1} | {4: 1} |

The only subspace has thickness 0. Thus it is F_2^8 × {0}, which gives F
again. The CCZ class has 1 EA class, of degree 4. Each run takes 0.25 s.
`power_luts.py` shows that the catalog rows are equal to x^57 and x^228 built
from the definition.

## Positive controls (`make controls`)

| Start | n | Start degree | Subspaces | Degrees of representatives | Quadratic found |
|---|---:|---:|---:|---|---|
| Dillon APN permutation | 6 | 4 | 222 | {2: 1, 3: 63, 4: 158} | yes |
| Kim function | 6 | 2 | 222 | {2: 1, 3: 63, 4: 158} | yes |
| Gold x^3 (id 41) | 8 | 2 | 256 | {2: 1, 3: 255} | yes |
| Calderini (id 40) | 8 | 2 | 352 | {2: 1, 3: 255, 4: 96} | yes |
| degree-3 member of the Gold x^3 class | 8 | 3 | 256 | {2: 1, 3: 255} | yes |
| degree-4 member of the Calderini class | 8 | 4 | 352 | {2: 1, 3: 255, 4: 96} | yes |

- The degree-2 representative from the Dillon start matches catalog id 31 by
  σ, like the Kim function. Gold and Calderini match ids 41 and 40.
- The method finds a quadratic function from a non-quadratic start at n = 6
  and at n = 8.
- The subspace count is a CCZ invariant. It is the same from the quadratic and
  the non-quadratic start (256 and 352).

## Literature

- S. Yoshiara, "Equivalences of power APN functions with power or quadratic
  APN functions", J. Algebraic Combin. 44(3) (2016) 561–585,
  doi:10.1007/s10801-016-0680-z. The full text is paywalled. The statements
  below come from secondary sources (arXiv:1709.07664, Section II, items 4–5):
  - Theorem 2: a quadratic APN function f is CCZ-equivalent to a power APN
    function if and only if f is EA-equivalent to a Gold function.
  - Theorem 1: for n ≥ 3, power APN functions x^d and x^e are CCZ-equivalent
    if and only if e ≡ d·2^a mod 2^n − 1, or (n odd only) de ≡ 2^a.
- These theorems also cover x^57 at n = 8. The cyclotomic class of 57,
  {39, 57, 78, 114, 147, 156, 201, 228}, contains no Gold exponent (the
  classes of 3 and 9). Thus no quadratic APN function is CCZ-equivalent to
  x^57.
- EA = CCZ for quadratic APN functions is Yoshiara, J. Algebraic Combin. 35(3)
  (2012) 461–475.
- The computation does not use these theorems. It gives a stronger result: the
  CCZ class is equal to the EA class.

## Limits

An independent subspace count at n = 8 with VBF `extract_linear_subspaces` did
not finish (Gold x^3 was stopped after 45 min). At n = 6, VBF and sboxU agree
(222 for Dillon and for Kim).

## Commands

```
make -C census/quadratic_apn8/kasami_x57 help
make -C census/quadratic_apn8/kasami_x57 check       # about 5 min, 1 thread; prints "kasami_x57 check: PASS"
make -C census/quadratic_apn8/kasami_x57 controls
make -C census/quadratic_apn8/kasami_x57 vbf_count   # optional; does not finish for n = 8
```
