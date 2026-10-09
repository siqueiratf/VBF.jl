# Hyperplane scan of quadratic APN functions on F_2^8

**Path**: `census/quadratic_apn8/theory/hyperplane_scan/`

**Status**: The first pass is complete (11,684 functions, all 255 hyperplanes each). It
found 463 verified new CCZ classes (`new_classes_hyperplane.tsv`). A second pass with more
members of the bulk corpora runs on the original machine. The theory is in
[../HYPERPLANE.md](../HYPERPLANE.md), Section 6.

## Question

For a quadratic APN function F and a hyperplane H of the input space, how many APN
functions agree with F on H and differ from F on the other coset by a linear map? These
are the APN codimension-1 changes of Taniguchi, Polujan, Pott and Arshad (2025). Their
number is e(F|_H), the number of APN completions of the restriction (`../UNIQUENESS.md`).
The value k = e / 128 counts the classes of completions, and F itself is one of them. When
k > 1, the other completions are new candidate classes.

## Method (`scan.jl`)

For each input function F and each hyperplane H = ker(u), u = 1..255:

1. Calculate the pure quadratic coefficients of G = F|_H in a basis a_1..a_7 of H:
   c_ij = F(a_i + a_j) + F(a_i) + F(a_j) + F(0).
2. Calculate e(G) with the exact counter `FL3.count_completions(C, 7, 8)`.
3. If k > 1, build one extension for each coset, check that its differential uniformity
   is 2, calculate its σ, and give it a status: known (σ index), census553, extra,
   search773, raw546 or NEW.

The scan is threaded and resumable. A row in `results/functions.tsv` marks a completed
function. `analyze.jl` makes the tables and verifies every NEW class again (differential
uniformity 2, σ recalculated, absent from the index by a direct SQL query).

## Results of the first pass (`ANALYSIS_pass1.md`)

| Quantity | Value |
|---|---|
| Functions | 11,684 |
| Pairs (F, H) | 2,979,420 |
| Pairs with k > 1 | 10,587 |
| Thread-hours | 47.0 |
| Verified new classes (distinct σ) | 463 |
| New classes per thread-hour | 9.8 |

Rate of pairs with k > 1, by source:

| Source | Functions | Pair rate k > 1 | Functions with a pair k > 1 |
|---|---:|---:|---:|
| catalog (67 quadratic APN rows) | 67 | 15.2 % | 55 % |
| edelpott2009_n8 | 22 | 12.4 % | 68 % |
| beierleleander2022_n8 | 2,000 | 1.15 % | 62 % |
| beierleleanderperrin2022_n8 | 2,256 | 0.050 % | 11.8 % |
| yuwangli2014_qam_n8 | 2,000 | 0.067 % | 13.3 % |
| yuperrin2022_qam_n8 | 2,000 | 0.059 % | 13.7 % |
| census553 | 553 | 0.057 % | 13.0 % |
| search773 | 773 | 0.058 % | 13.1 % |
| beierle2025_n8 (random sample) | 2,000 | 0.054 % | 12.5 % |

Findings (details and status labels in `../HYPERPLANE.md`, Section 6):

- Generic functions have one common rate, about 5.7e-4 for each hyperplane. The events on
  different hyperplanes are close to independent.
- Structured families have much higher rates. In `beierleleander2022_n8`, the number of
  hyperplanes with k > 1 is a multiple of 3 for 1,230 of 1,242 functions. This agrees with
  an automorphism of order 3 (Proposition 6.1).
- The second class of a generic function is new with probability 0.313 ± 0.012. The census
  gives 0.323 ± 0.013 for a random class. This is a third, independent check of the coverage
  of the known list.

## Commands

Run from this folder (or with `make -C census/quadratic_apn8/theory/hyperplane_scan ...`).

| Command | Purpose |
|---|---|
| `make help` | Show the targets and parameters |
| `make scan source=edelpott2009_n8 threads=4` | Scan one source in the foreground |
| `make scan_bg source=all threads=10 timeout_seconds=28800` | Scan all sources in the background (log in `results/scan.log`) |
| `make status` | Progress per source |
| `make analyze` | Tables in `results/analysis.md`, verified new classes |

The first pass scanned the members listed in the "Functions" column above (corpora in a
fixed random order, `seed=1`). The cost is about 14–18 s for each function on one thread
(255 exact counts).

## Files

| File | Content |
|---|---|
| `scan.jl` | The scan (threaded, resumable) |
| `analyze.jl` | Tables and verification of the new classes |
| `Makefile` | Targets above |
| `new_classes_hyperplane.tsv` | Verified new classes: σ, coefficients, parent source, parent member, hyperplane u |
| `ANALYSIS_pass1.md` | Full tables of the first pass |
| `results/` | Raw outputs (ignored by git; regenerate with `make scan` and `make analyze`) |
