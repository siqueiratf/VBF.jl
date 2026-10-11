# Faster eight-bit switching search

This runner uses the bounded switching and EA orbit tools on
`feat/apn-class-orbit-exploration` to search for additional **quadratic**
eight-bit APN classes. It complements the existing B6/V5 extension search.

The core switching constructor now visits each affine two-flat once. The
previous ordered-pair loop inserted its equation 24 times: three directions,
four first points, and two opposite points. At eight bits this reduces
16,581,120 equation insertions to 690,880. Selecting each flat's first occurrence
preserves pivot insertion order, kernels, quotient representatives, and neighbor
order. The optimization also applies to nonquadratic APN centers.

## Measured results (2026-10-09)

Constraint assembly, after warming both implementations, on this machine with
Julia 1.13.1:

| Eight-bit seed | Ordered pairs | One equation per flat | Speedup |
| --- | ---: | ---: | ---: |
| Gold | 13.76 s | 0.74 s | 18.6× |
| Prior study class `08b461b4…` | 14.34 s | 0.79 s | 18.1× |
| Public Galissant example | 14.32 s | 0.64 s | 22.4× |

All 255 constraint systems were identical to the reference for every benchmark
seed. These numbers measure constraint assembly, not the existing V5 search or
the complete discovery pipeline. Raw timings are in
`results/benchmark.toml`; `benchmark.jl` reproduces the comparison.

The eight-worker pilot searched 21 distinct seeds: Gold and samples from the
prior search, census, hyperplane scan, and public supplement. All 21 switching
searches completed, generating 256 verified quadratic neighbors: 255 matched
the rebuilt public baseline and **one additional signature** was absent from
both the public comparison set and the supplied study inputs. The final run
took 9.10 s after setup; source loading, input hashing and seed verification
are excluded, while first-use compilation in search workers is included.
Evidence is in `results/pilot_final/`.

The additional candidate switches the public Galissant example in direction
`u = 180`. Its signature is
`0ec9d9d94751f8ea9dfdd4321009745ac0a398580880744e9799c82b8683a4a8`,
and its LUT SHA-256 is
`876f0145d5d3b01ee4d1326f1dda07ef900139371fc3779963eea91332cfda84`.
For input bits `x0,…,x7`, it is `G = F XOR 180*s`, where

```text
s = x1 + x2 + x3 + x4 + x5 + x6
  + x1*x4 + x0*x5 + x3*x6 + x5*x6
  + x0*x7 + x2*x7 + x5*x7 + x6*x7.
```

The independent signature code verified degree two and all 255 polar ranks;
an additional Python full DDT check verified APN directly. Its signature
differs from the parent's and from every compared signature, supporting CCZ
inequivalence for these quadratic APNs. This is novelty relative to the
comparison inputs, not a claim of complete literature coverage. The full
Baudrin–Galissant–Perrin eight-bit switching dataset remains unavailable;
see [the literature audit](../reports/literature/LITERATURE.md).

A second pilot searched Gold and the two Galissant-related quadratic classes,
with up to two additional nonquadratic EA representatives per root and a
15-second orbit budget. It generated 385 verified neighbors (258 quadratic,
127 nonquadratic) and no further quadratic signatures. Gold's orbit census
completed; the other two orbit calls hit their time limits. The representative
cap also prevents exhaustive switching coverage of Gold's full CCZ class.
Evidence is in `results/orbit_final/`.

The two switching test items passed **1,386 assertions**, including independent
ordered-pair comparisons on quadratic and random nonquadratic tables, exhaustive
small-dimension coverage, observer compatibility and budget behavior.

## Run

Run from the repository root with Julia >= 1.12:

```sh
julia --project=. --threads=8 census/quadratic_apn8/fast_switching/search.jl \
  --limit 1000 --workers 8 --seconds 30 --evaluations 10000 \
  --outdir census/quadratic_apn8/fast_switching/results/run1000
```

`--limit` caps sampled seed classes; this is a deterministic reservoir sample
per input source, not a recursive closure or a uniform class sample. Duplicate
and small sources can produce fewer seeds than the cap. Gold is always included.
Each switching call has its own time and evaluation caps. Start with eight
workers and compare throughput before increasing concurrency.

For a two-hour run on 30 Julia threads, use:

```sh
julia --project=. --threads=30 census/quadratic_apn8/fast_switching/search.jl \
  --limit 1000000 --workers 30 --seconds 30 --evaluations 10000 \
  --wall-seconds 7200 \
  --input census/quadratic_apn8/fast_switching/results/pilot_final/new_classes.tsv \
  --outdir census/quadratic_apn8/fast_switching/results/run_2h_30t
```

`--wall-seconds` bounds the whole search after input loading and baseline
validation. Workers claim seeds dynamically and share the deadline; each orbit
or switching call receives the smaller of its own limit and the remaining time.
The search stops early if its finite seed pool is exhausted. The deadline is
cooperative: a running primitive or compilation must finish before its next
budget check. Final evidence writing and input rehashing occur after searching.
Sampled seeds are verified immediately before processing, so a large seed pool
does not delay the beginning of the timed search with a full verification pass.

To focus on a supplied TSV while retaining all default novelty exclusions:

```sh
julia --project=. --threads=3 census/quadratic_apn8/fast_switching/search.jl \
  --limit 3 --workers 3 --seconds 20 \
  --orbit-seconds 15 --ea-representatives 2 \
  --seed-input census/quadratic_apn8/results/literature_20261009/supplemental_luts.tsv \
  --seed-input census/quadratic_apn8/fast_switching/results/pilot_final/new_classes.tsv \
  --outdir census/quadratic_apn8/fast_switching/results/focused_orbits
```

`--input PATH` adds a comparison and sampling source; `--seed-input PATH`
restricts sampling to those sources and also adds their signatures to the
exclusion set. Both options may be repeated. Reuse previous outputs through
these options to explore further rounds. Every run requires a fresh output
directory and refuses to overwrite existing evidence.
For files with a status column, sampling includes `new`, `search` (the Framework
label), and `search-new`; every label remains in the novelty exclusion set.

The optional orbit route uses native partition refinement, optimized Walsh-zero
subspace extraction and verified CCZ maps. It searches additional nonquadratic
EA representatives: the quadratic representatives inside one quadratic APN CCZ
class already belong to a single EA class. Each searched representative's LUT
and graph map are saved for independent verification. Time-limited orbit calls
and representative caps provide partial coverage only. Nonquadratic neighbors
are counted but do not enter the quadratic signature novelty test.

## Comparison inputs and evidence

The runner requires the provenance-complete fresh baseline at
`../results/signature_rebuild/` (3,809,037 distinct signatures), checks its SHA-256
against `comparison.toml`, and opens SQLite read-only. It also excludes the
public Galissant supplement, the Framework `found.tsv`, the 553 census classes,
the extra/trial candidates, and the hyperplane candidates. Missing inputs stop
the run. An older catalog signature cache is not used.

Every sampled seed's stored signature is independently recomputed. Every
reported quadratic neighbor is independently verified again before comparison.
Distinct signatures certify inequivalence; equal signatures are conservative
exclusions, not equivalence proofs. The search can therefore omit classes hidden
by invariant collisions and does not claim completeness.

`new_classes.tsv` contains exact switched LUTs, parent identifiers, representative
indices, directions, and 28-byte squarefree ANF coefficients. The compact
coefficients remove affine terms; their signatures are independently checked
against the exact LUT signatures. They can seed subsequent quadratic extension
searches after measuring their bent profile. `parent_N.toml` records searched
representatives, maps, counts and completion/stop statuses; each checkpoint is
written through an atomic rename. `run.toml` records provenance at startup,
`progress.toml` is updated after each processed parent, and `summary.toml` binds
the inputs, baseline and principal algorithm sources by SHA-256. Generated
results remain ignored by git. A timed run's final summary distinguishes the
seed-pool size from the processed count and retains partial parent results.

Reproduce the timing comparison:

```sh
julia --project=. census/quadratic_apn8/fast_switching/benchmark.jl \
  census/quadratic_apn8/fast_switching/results/another_benchmark.toml \
  census/quadratic_apn8/fast_switching/results/pilot_final/parent_2.toml \
  census/quadratic_apn8/fast_switching/results/pilot_final/parent_21.toml
```

For this local Julia 1.13 installation, these commands were run with
`--compiled-modules=no --startup-file=no` to avoid writes to the user depot.

Test the runner's input selection with
`julia --project=. census/quadratic_apn8/fast_switching/test/runtests.jl`.
