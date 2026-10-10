# Reproducible APN search

`bin/vbf` is the supported repository command. Mathematical constructions live
in `VBF`; seeds and data access use `VBFCatalog`; this directory orchestrates
experiments and stores validation evidence. Its production sources do not import
`census/`. The source-independent verifiers are in `verification/`.

Read [AUDIT.md](AUDIT.md) for the research assessment and unresolved novelty
questions. The [web inspector](../../census/quadratic_apn8/web/README.md) uses the
same evidence layer. [Reference preparation](../../data/apn/README.md) describes
the required ignored data artifacts. Julia >= 1.12 and the instantiated root
project are required. Reports additionally need Python >= 3.11 and matplotlib.

## Search, stop and resume

```sh
bin/vbf search --output search/apn/results/experiment01 --duration 8h --threads 30
bin/vbf status search/apn/results/experiment01
bin/vbf stop search/apn/results/experiment01
bin/vbf resume search/apn/results/experiment01 --duration 8h --threads 30
```

The default method is V5 Fourier extension, with one worker unless `--threads`
is supplied. `--method switching` selects switching. A fresh output directory
must be empty. Runs stay in the foreground: use your normal terminal/session
supervisor for long experiments. Durations accept seconds or suffixes `s`, `m`,
`h`; the search budget starts after input verification and initial planning.
Compilation and indivisible computations can exceed the requested time bound.

Default seeds are all exact quadratic eight-bit APN LUTs in `VBFCatalog`.
The materialized seed TSV records catalog IDs and the catalog database digest.
Exact LUT identity, not sigma equality, controls seed deduplication. A Gold
control comes first; the remaining parents are sampled deterministically with
`--seed` and capped by `--parents` (default 1000). No historical candidate list
is required. To choose discovered functions or another explicit seed set:

```sh
bin/vbf search --output search/apn/results/next --input candidates.tsv \
  --parents 100 --duration 8h --threads 30
```

Inputs use TSV columns `sigma_hash` and `lut_hex` (or existing `sigma`, `coeffs`
formats). Payloads accept 256-byte LUTs, 28-byte square-free Boolean quadratic
coefficients or 37-byte catalog encodings. Explicit inputs replace catalog
seeds. Every supplied signature and quadratic APN property is independently
rechecked unless an exact input digest has a matching completed verification
report. Inputs are copied into the run. Additional-discovery counts exclude
all supplied input signatures, including records not selected as parents.

Each run freezes a finite parent plan. New candidates are stored but are not
promoted to parents in the same run; use an explicit subsequent experiment to
extend exploration. `bin/vbf report RUN` writes `RUN/publication/seeds.tsv`
with every persisted quadratic APN, ready for `--input` in a subsequent run.
Exhausting the plan never means classifying all APNs.

Resume recovers semantic options and reference locations from the manifest,
including an interrupted launch before its first session file was written. Code, Julia version, frozen input bytes and reference
digests must still match. Worker count, duration, slice budgets and chunk size
may change. The writer lock prevents concurrent enumeration of one run. A
verified resume clears `STOP` after acquiring that lock. Old census checkpoints
are deliberately unsupported; their research outputs remain available for
inspection or import into new experiments.

Candidate records and next cursors commit together in SQLite transactions
(WAL, synchronous FULL). Interrupted units become paused on restart. A crash
can repeat uncommitted work or preprocessing, but cannot skip committed
combinations. Stop is cooperative, polled by workers between supported
boundaries. It is not an instantaneous process kill.

## Construction options and coverage

V5 options: `--target-b6 52 --bent max --chunk-size 128`; `--bent 28,30` selects
explicit bent counts. `VBF.QuadraticExtensions` supplies the Fourier algorithms
and their small-dimension brute-force control. The run explores chosen V5 spaces
of frozen parents, matching quotient cosets and admissible two-dimensional
extensions. It uses no histogram-key deduplication and sets the affine kernel
cap to 23, the full eight-bit quotient dimension. Chunk size controls checkpoints,
not truncation. An interrupted coset may repeat after a crash.

Switching persists every direction's quotient basis and enumerates every
nonzero basis combination. `--slice 60s --evaluations 10000` controls work per
slice. `--ea-representatives N --orbit-duration 30s` optionally adds witnessed
nonquadratic parents from bounded CCZ-class exploration. Its representative
and completion limits are recorded separately; partial orbit exploration does
not certify an exhausted CCZ class.

Finite completion remains conditional on correctness of the mathematical
filters and enumeration implementations. Audits check ledger coverage and
stored candidates; they do not independently replay every rejected extension
or recompute every kernel.

## Validate, compare, classify and export

```sh
bin/vbf validate --input candidates.tsv --output search/apn/results/import01
bin/vbf audit search/apn/results/experiment01
bin/vbf classify search/apn/results/experiment01 --duration 30s --nodes 1000000
bin/vbf compare --candidate HEX --target HEX --relation ccz \
  --duration 60s --nodes 1000000 --output comparison.toml
bin/vbf verify comparison.toml
bin/vbf report search/apn/results/experiment01
make -C search/apn test
```

`validate --limit N` and `audit --limit N` explicitly record partial validation.
The independent verifier enumerates the full DDT, computes Boolean ANF degree,
checks every polar rank and recomputes the ortho-derivative signature. Positive
affine graph witnesses and invariant separations can be rechecked by the
standard-library-only certificate verifier.

Different signatures separate verified quadratic APN CCZ classes by Yoshiara
2012. Equal signatures create comparison buckets; they never merge classes.
The bounded solver returns a verified witness, exhaustive computational
inequivalence, or an inconclusive resource stop. For nonquadratic references,
EA inequivalence alone does not imply CCZ inequivalence. Classification resolves
candidate buckets incrementally and retains unresolved pairs and lower bounds.
It describes only the supplied finite snapshot. Reference absence and the
Yoshiara 2016 exclusion of APN powers do not establish literature-wide novelty.

`run.sqlite` is authoritative: it stores the plan, cursors, exact LUTs, properties,
comparisons, coverage ledger and sessions. TOML summaries are human-readable
views, not separate checkpoint state. `status` reads a consistent database
snapshot while a writer is active. Stop the writer or use SQLite's backup API
before copying the database; an active WAL must not be omitted.

`source/` archives the fingerprinted implementation and environment, including
uncommitted sources. Sessions record configuration, reference scope, CPU,
platform, Julia settings, time, PID, HEAD and dirty status. Public data and
installed dependencies must be restored separately for replay.

Reports export exact LUTs, relationship CSVs, LaTeX counts, JSON provenance and
SVG/PDF figures. The first three absent candidates in LUT-digest order have
independently recomputed integer ortho-derivative spectra, exported numerically
and plotted. This deterministic inspection sample is not a statistical sample.
