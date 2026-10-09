# CCZ-equivalence to a permutation: the 553 new functions

Date: 2026-10-08. Tool: sboxU v1.3.1 (see `../kasami_x57/README.md`).

**Claim tested:** none of the 553 functions of `../new_classes_553.tsv` is
CCZ-equivalent to a permutation. (Beierle et al. 2025 make the same claim for
their 3,775,599 functions.)

**Verdict: the claim holds.** 0 of 553 functions are CCZ-equivalent to a
permutation.

## Method

Canteaut and Perrin (2019): an APN function F is CCZ-equivalent to a
permutation if and only if Z_F contains two n-dimensional subspaces V and W
with V ∩ W = {0}. `perm_test.py` does these steps for each function:

1. Decode the coefficients. The decoder is equal to the Julia decoder on 3
   functions.
2. List the subspaces with `get_lat_zeroes_spaces(F, n_threads=1)`.
3. Call `ccz_equivalent_permutations(F, number="just one")`. If it returns a
   function, check that the function is a permutation with the same
   differential spectrum as F.
4. Check all pairs again in plain Python: the rank of the union of the two
   bases must be 2n. The two verdicts must agree.

Use 1 thread for each process (see the sboxU thread bug in
`../kasami_x57/REPORT.md`).

## Controls (`make controls`: PASS)

| Function | Expected | Result |
|---|---|---|
| Kim function (n = 6, degree 2) | true | true |
| Dillon permutation (n = 6) | true | true |
| Gold x^3 (n = 8, catalog id 41) | false | false |

## Result (`results.tsv`: sigma_hash, verdict, seconds, n_subspaces)

- 553 of 553 functions tested. 0 are CCZ-equivalent to a permutation.
- Subspaces for each function: minimum 378, median 430, maximum 486.
- sboxU time for each function: 0.08–0.18 s (mean 0.13 s). Wall time: about
  3.5 min with 3 processes.
- The hashes in `results.tsv` are exactly the 553 hashes of the list.

## Limits

- The verdict needs a complete list of subspaces. At n = 6, sboxU and VBF give
  the same list. At n = 8, no independent program counted the subspaces,
  because VBF did not finish.
- The subspace count is a CCZ invariant. At n = 8 it is the same from quadratic
  and non-quadratic starts (`../kasami_x57/control_n8.py`). This supports the
  completeness of the list.
- The pair check uses the same sboxU subspace list.

## Commands

```
make -C census/quadratic_apn8/permutation help
make -C census/quadratic_apn8/permutation controls
make -C census/quadratic_apn8/permutation check                     # all 553, about 4 min with procs=3
make -C census/quadratic_apn8/permutation check limit=20 seed=7     # random sample
```
