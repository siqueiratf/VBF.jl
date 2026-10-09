# Kasami x^57 class and sboxU setup

**Path**: `census/quadratic_apn8/kasami_x57/`

This folder decides by computation if the CCZ class of the Kasami function
x^57 on GF(2^8) contains a quadratic function. The result is in
[REPORT.md](REPORT.md). The folder `../permutation/` uses the same sboxU
installation.

## Install sboxU (outside the repository)

The paper used sboxU v1.3.1. PyPI has only sboxU 1.1.0. The GitHub tag `v1.3`
is older than v1.3.1, and the `main` branch is v2.0. The commit that sets
`version = "1.3.1"` in `setup.py` is
`e1374ae47b2751a3a5045091bb010c6460426c93` (2025-04-29). We install this
commit. sboxU imports SAGE (`from sage.all import ...`). SAGE is not on the
machine, so we install the pip distribution of SAGE, passagemath.

System: Arch Linux, Python 3.14.7 (`/usr/bin/python3.14`), uv 0.12.10,
g++ (GCC) 16.2.1. sboxU builds on Python 3.14 without problems.

```sh
mkdir -p ~/.venvs ~/.venvs/src
cd ~/.venvs && uv venv --python 3.14 sboxu
uv pip install --python ~/.venvs/sboxu/bin/python passagemath-standard   # binary wheels, a few minutes
git clone https://github.com/lpp-crypto/sboxU ~/.venvs/src/sboxU          # main = v2.0, not used
git clone --branch legacy https://github.com/lpp-crypto/sboxU ~/.venvs/src/sboxU-legacy
git clone ~/.venvs/src/sboxU-legacy ~/.venvs/src/sboxU-1.3.1
git -C ~/.venvs/src/sboxU-1.3.1 checkout e1374ae47b2751a3a5045091bb010c6460426c93
uv pip install --python ~/.venvs/sboxu/bin/python ~/.venvs/src/sboxU-1.3.1  # about 1.5 min (C++ build)
```

Installed versions: `sboxu 1.3.1` (commit e1374ae), `passagemath-standard
10.8.12`, `numpy 2.5.3`, `cython 3.3.0`, `setuptools 84.0.0`. Test:

```sh
~/.venvs/sboxu/bin/python -c "from sboxU import *; print(algebraic_degree([0,1,3,2]))"
```

The Makefiles use `PY ?= $(HOME)/.venvs/sboxu/bin/python`. Give
`PY=/path/to/python` for a different environment.

## sboxU v1.3.1 bug: thread count

`lat_zeroes_cpp` (file `sboxu_cpp_diff_lin.cpp`) gives each thread
`floor(2^n / n_threads)` LAT columns. When `n_threads` does not divide 2^n, the
last columns are not computed. Then `get_lat_zeroes_spaces` misses subspaces.

| Function (n = 6) | 1 thread | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Dillon APN permutation | 222 | 222 | **164** | 222 | **110** | **110** |
| Kim function | 222 | 222 | 222 | 222 | **148** | **148** |

VBF (`extract_linear_subspaces(walsh_zeroes(F), 6)`) gives 222 for both. The
scripts in this folder and in `../permutation/` use 1 thread. They refuse a
thread count that does not divide 2^n. They also compare the number of Walsh
zeroes with an independent numpy calculation. The sboxU default for n = 8 is
16 threads (correct, because 16 divides 256), but it uses more than 3 threads.

## Files

| File | Content |
|---|---|
| `export_luts.jl` | Writes `data/luts.tsv`: catalog rows 43, 581, 634 (x^57 class), 41 (Gold x^3), 40 (Calderini), and VBF `dillon_apn_permutation`, `kim_apn` |
| `power_luts.py` | Builds x^57, x^228, x^3 from the definition (moduli 0x11B, 0x11D) in `data/power_luts.tsv`; checks the catalog rows |
| `ccz_ea_classes.py` | Lists the Walsh-zero subspaces, one CCZ-equivalent function per subspace, its degree and EA invariants |
| `control_n8.py` | Positive control at n = 8 from a non-quadratic start |
| `sigma_check.jl` | σ hash, `classify_ccz` and `new_classes_553.tsv` check of degree-2 representatives |
| `vbf_subspace_count.jl` | Independent subspace count with VBF (optional, slow for n = 8) |
| `Makefile` | `make help`, `make check` |
| `data/` | LUTs and logs |
