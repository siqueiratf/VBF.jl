# Reproducible quadratic APN discovery at n = 8

This is the authoritative workflow for new reproducible experiments. It reuses
VBF's bounded switching and graph-equivalence algorithms, the existing Fourier
extension implementation, and the source-independent signature verifier.
Historical runners remain available to reproduce their original experiments;
their progress files do not provide the guarantees below.

Read [AUDIT.md](AUDIT.md) for the research assessment and unresolved novelty
questions. The [web inspector](../web/README.md) uses the same validation rules.

## Prerequisites and reference scope

Run commands from the repository root with Julia >= 1.12 and the root project
instantiated. Build the original-source reference using
[rebuild_corpus/README.md](../rebuild_corpus/README.md), and reproduce the
[literature supplement](../reports/literature/LITERATURE.md).
`open_reference` requires the completed comparison manifest, the exact SQLite
SHA256 and the correct signature count. It independently checks the public
supplement and all four Gold exponents k = 1, 3, 5, 7 over GF(256).

Default seed/exclusion inputs are the Framework `desk1/found.tsv`, the 553
census coefficients, the extra coefficient, the 773 trial records, the 463
hyperplane records and the public supplement. Missing inputs cause an error.
Additional TSVs can be passed with repeated `--input PATH`. Inputs are copied
into the experiment; the prior four-file independent verification is reused
only when both input and reference digests match. Other records are rechecked.
`review_history.jl --full true` disables reuse and verifies every historical
record again. Generated artifacts and source archives stay under ignored
`results/`; original copyrighted inputs remain outside git.

## Eight hours, stop, resume

```sh
julia --startup-file=no --project=. --threads=30 \
  census/quadratic_apn8/discovery/run.jl \
  --outdir census/quadratic_apn8/discovery/results/experiment01 \
  --workers 30 --method switching --limit 1000 \
  --wall-seconds 28800 --seconds 60 --evaluations 10000

touch census/quadratic_apn8/discovery/results/experiment01/STOP

rm census/quadratic_apn8/discovery/results/experiment01/STOP
julia --startup-file=no --project=. --threads=30 \
  census/quadratic_apn8/discovery/run.jl \
  --outdir census/quadratic_apn8/discovery/results/experiment01 \
  --workers 30 --method switching --limit 1000 \
  --wall-seconds 28800 --seconds 60 --evaluations 10000 --resume true
```

`limit` defines the frozen parent plan, with a Gold control first and the
remaining seeds sampled deterministically from eligible historical records.
It does not request exploration of the entire APN graph. Generated neighbors
are persisted but are not automatically promoted to new parents. Start another
explicit experiment with their exported TSVs to extend the exploration.

Code, Julia version, frozen inputs, reference digests and semantic parameters
must agree on resume. Time budgets, evaluation slice sizes, chunk sizes and
worker count may change. Changing the target construction requires a new run.
The exact implementation and environment manifests are archived under
`source/`, including uncommitted code; the session also records HEAD and dirty
status. To replay an old implementation, use this archive and supply the
recorded reference and supplement with `--baseline PATH --supplement PATH`.
The source archive is not a self-contained copy of the public data: restore
the reference artifacts and dependencies using their manifests first.

Stop is cooperative. A completed candidate and the next cursor are committed
in one SQLite transaction (WAL, synchronous FULL). Restart recovers a running
unit as paused. Constraint preprocessing for an interrupted parent is rebuilt;
committed combinations are skipped. A crash during a transaction may require
repeating that uncommitted computation, but cannot skip it. Time limits can
overshoot during compilation or an indivisible computation. `STOP` remains
effective until removed. Only one enumeration process may own a run.

## Fourier extensions and finite coverage

Use `--method v5 --target-b6 52 --v5-bent max --chunk-x 128` for the existing
V5 construction. `--v5-bent 28,30` selects explicit V5 bent counts instead.
The plan covers the chosen V5s of the frozen seed component spaces and every
matching ordered quotient coset and its two-dimensional extensions. It uses
the existing mathematical filters, no histogram-key deduplication, and a kernel
cap of 23, the full quotient dimension. Chunk size is a checkpoint interval,
not a search truncation. Stops occur between cosets; an interrupted coset can
be repeated after a crash. The extension implementation's completeness still
depends on its mathematical filters and their correct implementation.

Switching units persist the quotient basis for each of 255 nonzero output
directions and evaluate every nonzero basis combination. A unit is complete
only at its terminal cursor with all 255 kernels and the expected evaluation
count. `audit.jl` reconstructs generated LUTs from the bases and checks
contiguous combinations and chunks. `finite_plan_exhausted` refers to these
frozen units, never all APNs or an entire CCZ class. Optional
`--ea-representatives N --orbit-seconds S` adds witnessed nonquadratic parents;
orbit completion and representative selection limits are recorded separately.
A partial orbit does not become a complete CCZ-class exploration.

## Validation and equivalence evidence

```sh
julia --project=. census/quadratic_apn8/discovery/review_history.jl
julia --project=. census/quadratic_apn8/discovery/validate.jl \
  --input candidates.tsv --outdir census/quadratic_apn8/discovery/results/import01
julia --project=. census/quadratic_apn8/discovery/audit.jl \
  census/quadratic_apn8/discovery/results/experiment01
julia --project=. census/quadratic_apn8/discovery/classify.jl \
  census/quadratic_apn8/discovery/results/experiment01 \
  --seconds 30 --nodes 1000000 --max-pairs 100

# HEX can be a 512-digit LUT, 56-digit Boolean ANF, or existing compact encoding.
julia --project=. census/quadratic_apn8/discovery/compare.jl \
  --candidate HEX --target HEX --relation ccz \
  --seconds 60 --nodes 1000000 --out comparison.toml
julia --startup-file=no \
  census/quadratic_apn8/discovery/verify_certificate.jl comparison.toml
```

Import validates all records unless `--limit N` is supplied, in which case its
report explicitly states that input validation is partial. Full DDT enumeration
and Boolean ANF degree are independent of VBF; quadratic APNs additionally
require every nonzero polar map to have rank seven. Sigma is recomputed by the
existing independent verifier. A non-APN input includes a differential witness.

Exact LUT identity controls deduplication. Equal sigma values create comparison
buckets, not automatic class merges. Different sigma values separate quadratic
APN CCZ classes by Yoshiara 2012. A matching value leaves equivalence unresolved.
`classify.jl` independently rechecks a frozen quadratic-APN snapshot and resolves
its equal-sigma buckets. Only verified positive witnesses join components;
budget stops preserve unresolved pairs. It records `classification.toml` with
a signature lower bound, proven equivalence components and whether the exact
class count of that snapshot is established. Repeated calls reuse decisive pair
evidence and retry budget stops. This is a classification of supplied candidates,
not canonicalization of all APNs or a novelty result against all literature.
The bounded graph solver returns an independently checked positive affine map,
an exhaustive computational negative, or an inconclusive budget stop. The
standard-library-only verifier checks positive maps and quadratic invariant
separations; it cannot certify a native solver's exhausted tree without replay.
For arbitrary functions use CCZ; an EA negative alone does not prove CCZ
inequivalence. All Gold signatures being excluded also excludes every APN
power function by Yoshiara 2016, Theorem 2.

## Storage, audit and publication

`run.sqlite` is authoritative. `metadata` stores immutable provenance; `seeds`
and `units` define the plan; `kernels`, `evaluations` and `chunks` record coverage;
`candidates` retains exact LUTs and independent properties; `comparisons` stores
pair evidence; `sessions` records launches. Candidate origin records preserve
the original TSV columns, including construction parents and switching data.
`manifest.toml`, session files, `progress.toml`, `summary.toml`, `audit.toml`
and import `validation.toml` are human-readable views, not alternate cursors.
Use SQLite's backup API or stop the writer before copying its database alone;
an active WAL must not be omitted.

```sh
python3 census/quadratic_apn8/discovery/report.py \
  census/quadratic_apn8/discovery/results/experiment01
make -C census/quadratic_apn8/discovery test
make -C census/quadratic_apn8/web test
```

The report takes a consistent database snapshot and exports exact candidate
LUTs and pair relationships as CSV, counts as LaTeX, the manifest and evidence
as JSON, and validation/coverage figures as SVG and PDF (Python >=3.11,
matplotlib). Its figures label signature buckets and reference scope explicitly.
The first three absent candidates in LUT-digest order also have independent
integer recomputations of their ortho-derivative spectra, bound to their stored
sigma values, exported as numeric JSON and SVG/PDF panels. This selection is
for inspection, not a statistical sample.
Audit rechecks every candidate by default. `--limit N` makes the candidate audit
partial even though the ledger is checked. Neither audit option independently
rebuilds every nullspace or replays every Fourier rejection; those algorithmic
dependencies remain explicit. No census estimate or discovery rate is promoted
to an exhaustive classification or literature-wide novelty proof.
