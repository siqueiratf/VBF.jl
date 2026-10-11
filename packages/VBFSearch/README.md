# Reproducible APN search

VBFSearch consumes VBF mathematics and VBFCatalog reference data. It owns search
configuration, scheduling, transactional checkpoints, candidate evidence and
snapshot exports. The CLI, Julia API and documentation inspector use the same
implementation. Mathematical checks use VBF; there is no second verification
engine and no Python dependency.

Research studies live in [VBFWorkingPaper](../VBFWorkingPaper/README.md): census
sampling, hyperplane experiments, finite literature domains and publication
figures. Original-source corpus preparation remains in VBFCatalog.

## Search, stop and resume

Instantiate the root Julia >=1.12 project and prepare
[VBFCatalog and its signature index](../VBFCatalog/README.md), then run:

```sh
bin/vbf search --output packages/VBFCatalog/data/search/experiment01 --duration 8h --threads 30
bin/vbf status packages/VBFCatalog/data/search/experiment01
bin/vbf stop packages/VBFCatalog/data/search/experiment01
bin/vbf resume packages/VBFCatalog/data/search/experiment01 --duration 8h --threads 30
```

The default method is V5 Fourier extension; `--method switching` selects switching.
Runs remain in the foreground. The duration starts after validation and planning;
compilation and indivisible computations can exceed it. Stop is cooperative.

Default seeds come from exact quadratic eight-bit APN LUTs in VBFCatalog, with
catalog IDs and the database digest recorded. The Gold seed comes first and
remaining parents are sampled with `--seed` and capped by `--parents` (default
1000). Explicit `--input candidates.tsv` replaces catalog seeds. Inputs accept
`sigma_hash` and `lut_hex`, or coefficient encodings handled by VBF. Every input
LUT and signature is checked with VBF, and input bytes are copied into the run.
Exact LUT identity controls deduplication; equal signatures never merge classes.
Explicit inputs retain their selected parent set without adding a Gold parent.

Each run freezes a finite parent plan. Discovered functions are persisted but do
not become parents in that run. `bin/vbf report RUN` exports
`RUN/publication/seeds.tsv` for an explicit subsequent run. Additional-signature
counts exclude every input signature, including unselected parents.

Resume requires matching code, Julia version, scientific parameters, reference
and input digests. Catalog references freeze their covered source names and
content digests: adding another corpus does not change an existing run's scope;
changing a covered source refuses resume. Runtime duration, worker count, slice budgets and V5 chunk
size may change. A writer lease prevents simultaneous enumeration of a run.
Candidates and cursors commit together in SQLite; interrupted uncommitted work
may repeat. Old checkpoints can be recovered from Git history and are unsupported.

V5 options include `--target-b6 52 --bent max --chunk-size 128`; `--bent 28,30`
selects explicit bent counts. The full eight-bit affine-kernel cap is 23. Switching
persists quotient bases and every nonzero combination; `--slice 60s --evaluations
10000` sets slice budgets. Optional bounded CCZ-class exploration uses
`--ea-representatives N --orbit-duration 30s`; its partial coverage is recorded.

## Validation and mathematical scope

```sh
bin/vbf validate --input candidates.tsv --output packages/VBFCatalog/data/search/import01
bin/vbf audit packages/VBFCatalog/data/search/experiment01
bin/vbf classify packages/VBFCatalog/data/search/experiment01 --duration 30s --nodes 1000000
bin/vbf compare --candidate HEX --target HEX --relation ccz \
  --duration 60s --nodes 1000000 --output comparison.toml
bin/vbf verify comparison.toml
bin/vbf report packages/VBFCatalog/data/search/experiment01
```

Candidate properties use VBF's differential spectrum, algebraic degree,
ortho-derivative and signature. Graph maps use VBF's affine-map invertibility and
`ccz_equivalent_function`; EA maps additionally preserve the output subspace.
`verify` checks stored witnesses and separating invariants through these same
APIs. It is not an independently implemented verification or formal proof.

Different signatures separate verified quadratic APNs under EA and CCZ by
Yoshiara 2012. Equal signatures require an actual equivalence check. The solver
returns a checked positive witness, finite exhaustive computational inequivalence,
or an inconclusive resource stop. Cached exhaustive negatives require the same
solver-source fingerprint. For nonquadratic functions, EA inequivalence alone
does not establish CCZ inequivalence.

Reference absence is relative to the documented quadratic corpus. Gold coverage
and Yoshiara 2016 can exclude APN power functions, but neither conclusion proves
that every non-power literature construction has been covered. Literature-wide
novelty remains unresolved. Classification describes only the supplied snapshot;
finite plan exhaustion never classifies all APNs. These guarantees depend on the
correctness of VBF and the reference provenance and coverage.

Audits re-evaluate candidates and check database integrity, graph witnesses and
contiguous enumeration ledgers. They do not provide a separate implementation of
extension filters or a negative solver proof tree. `--limit N` records partial
validation explicitly.

## Storage, exports and API

`run.sqlite` is authoritative: it stores exact LUTs, properties, the frozen plan,
cursors, comparisons, coverage and sessions. TOML files are readable summaries.
Status and report read consistent snapshots while a writer is active. Stop a
writer or use SQLite's backup API before copying its database; preserve the WAL.

`source/` archives fingerprinted sources and the environment, including dirty
files. Sessions record configuration, reference scope, CPU, Julia settings,
platform, times, PID and Git state. Restore public data and installed dependencies
separately. Start searches in fresh Julia processes from stable source files.

Reports write JSON snapshots, candidate and relationship CSVs, reusable seed TSVs
and LaTeX counts. Figures are downstream WorkingPaper output:

```sh
julia --project=packages/VBFWorkingPaper \
  packages/VBFWorkingPaper/src/search_figures.jl packages/VBFCatalog/data/search/experiment01
```

```julia
using VBF, VBFSearch
config = SearchConfig(output="packages/VBFCatalog/data/search/run01", method=:v5,
                      duration=8*3600, workers=30)
search(config) # start Julia with --threads=30
resume(config.output; duration=8*3600, workers=30)
evidence = candidate_properties(gold_apn(8).lut; detailed=true)
certificate = compare(gold_apn(8).lut, gold_apn(8).lut)
@assert verify_comparison(certificate)
snapshot = report_snapshot(config.output)
```

## Register discoveries and replay the historical B52 experiment

```sh
# Search and register newly separating classes with one command.
bin/vbf discover --name b52-next --corpus legacy20261009_n8 --parents 1000 \
    --method v5 --target-b6 52 --bent max \
    --duration 8h --threads 30 --chunk-size 32768
# Or register the current snapshot of a stopped, catalog-local run.
bin/vbf publish packages/VBFCatalog/data/search/experiment01 --name experiment01_n8
# Repeat the recovered 11,405-parent plan, using the current catalog baseline.
bin/vbf discover --name b52-replay --method v5 --target-b6 52 --bent max \
    --input packages/VBFCatalog/data/search/legacy20261009/parents.tsv \
    --parents 11405 --seed 82026 --duration 8h --threads 30 --chunk-size 32768
```

Registration rechecks LUT identity, APN, degree and signature with VBF and selects
one representative per distinct signature absent from the current catalog.
Matching signatures remain unresolved in the run. `VBFCatalog.import_lut_corpus!`
owns conversion, corpus registration and compact storage; Search writes the
immutable input and declaration in the catalog, then tops up its index. Rerunning
publication reuses the immutable dataset and rejects changed results under the
same name. Resume remains possible after registration. Publish a changed run
snapshot under a fresh name; each increment retains its own immutable input.
Registration means new relative to that frozen catalog, never proven
literature-wide novelty. Publication freezes timestamp-free coefficient gzip
inputs under `VBFCatalog/src/data/luts/`; rebuilds consume these files and their
checksum-bound declarations without reading a previous catalog or run database.
The derived catalog class summary retains its frozen snapshot until explicitly
rebuilt with the [catalog classification command](../VBFCatalog/README.md).

`--corpus NAME` selects eight-bit quadratic APN parents from a named catalog
corpus, including registered discoveries. Repeat it for several corpora. Sampling
uses `--seed` and the parent limit; selected source/member IDs and exact LUTs are
frozen in the run. With no corpus or input, seeds come from curated catalog entries.
Explicit input files and corpus selection are mutually exclusive. Named corpora
replace the default seed set, so later epochs can explore prior discoveries
without exporting files or restoring the old research code.

On 2026-10-10, 114,062 archived rows passed validation, yielding 111,835 distinct
LUTs and 111,009 distinct signatures absent from the expanded public reference.
The historical 110,868-signature union accounts for most of these; later runs add
141. The public reference first gained the 546 missing May 2025 signatures and
the Galissant slide LUT that had previously lived in a separate supplement.
The full inputs and validation evidence remain under
`packages/VBFCatalog/data/search/legacy20261009/validated/`.

The old search recursively promoted discoveries and pruned by histogram keys.
The recovered plan fixes its 11,405 completed parents and uses the tested VBF
Fourier construction without that pruning. This is a reproducible restricted
replay, not a byte-identical repeat of its scheduling or an exhaustive search of
all APNs. A completed pilot on its first recorded parent recovered all 25
historical child signatures in about 30 seconds. The full 11,405-parent replay
has not been executed; eight hours is a resumable budget, not a completion claim.
Existing archived discoveries are now catalogued, so rediscovering them will
not increment new-to-catalog counts.

Run tests with
`julia --project=. -e 'using Pkg; Pkg.test("VBFSearch")'`. Self-contained fixtures
cover checkpointing, resume, configuration, classification, evidence and exports;
the full internet corpus is not required. Two include adapters under
`src/verification/` serve existing catalog rebuild callers; they delegate all
mathematics to VBF and can disappear when those callers move to catalog APIs.
