# Reproducible APN search

VBFSearch consumes VBF mathematics and VBFCatalog reference data. It owns search
configuration, scheduling, transactional checkpoints, candidate evidence and
snapshot exports. The CLI, Julia API and documentation inspector use the same
implementation. Mathematical checks use VBF; there is no second verification
engine and no Python dependency.

Research studies live in [VBFPaper](../VBFPaper/README.md): census
sampling, hyperplane experiments, finite literature domains and publication
figures. Original-source corpus preparation remains in VBFCatalog.

## Search, stop and resume

Instantiate the root Julia >=1.12 project and prepare
[VBFCatalog and its signature index](../VBFCatalog/README.md), then run:

```sh
bin/vbf search --output packages/VBFSearch/data/search/experiment01 --duration 8h --threads 30
bin/vbf status packages/VBFSearch/data/search/experiment01
bin/vbf stop packages/VBFSearch/data/search/experiment01
bin/vbf resume packages/VBFSearch/data/search/experiment01 --duration 8h --threads 30
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

## Closure campaign and its dashboard

The closure campaign starts from published roots. It makes new quadratic APN
classes with V5 extensions and switching, and then expands each new class again.
A campaign directory holds `campaign.toml` and the audited root files. Its `run/`
folder holds `closure.sqlite` and `progress.toml`. Git does not track campaign
directories. The real campaign (24,294 published roots) is only on the computer
that ran it.

Run all commands from the repository root. Before the first run, do these steps
one time:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
make -C packages/VBFCatalog/src/import catalog
make -C docs inspector-instantiate
```

### Make a demo campaign

`tools/closure_demo.jl` writes a small campaign from published catalog functions.
It takes the first ROOTS functions (default 3) of a corpus with P6 bminK b6 = 52
and different sigma hashes. The demo has no audit of the full published pool.
Use it to see the dashboard, not as a research result.

```sh
julia --project=. packages/VBFSearch/tools/closure_demo.jl packages/VBFSearch/data/search/demo-closure
```

Start the search with the threaded controller `tools/closure_continuous.jl`.
It reads a TOML file. `evidence` must be a new directory for each start.
`concurrency` is the number of worker threads.
The commands below use bash syntax. In fish, write `set D $PWD/...` in place of `D=$PWD/...`.

```sh
D=$PWD/packages/VBFSearch/data/search/demo-closure
printf 'run = "%s/run"\nevidence = "%s/evidence-1"\nconcurrency = 10\nduration_seconds = 28800\n' $D $D > $D/continuous.toml
julia --startup-file=no --threads=10,1 --project=packages/VBFSearch packages/VBFSearch/tools/closure_continuous.jl $D/continuous.toml
```

This search continues for 8 h (28800 s). To stop it before that time, write a
`STOP` file: `touch $D/run/STOP`. To continue later, change `evidence` to a new
directory and start the controller again.

The CLI `bin/vbf closure run|resume DIR/run` uses one worker. Its `--jobs`
option is a limit on the number of jobs, not a number of threads, and
`--evaluations` has a default of 1000. With the defaults, the CLI stops after a
few jobs with the state `paused_budget`. Use `bin/vbf closure status DIR/run`
to see the progress of either controller.

### Open the dashboard

Start the server in a second terminal. The search can continue at the same time,
because the server only reads the run.

```sh
make -C docs serve-search campaign=packages/VBFSearch/data/search/demo-closure port=8766
```

Then open these pages in a browser:

| Page | URL | Data |
|---|---|---|
| Live progress | `http://127.0.0.1:8766/` | `run/progress.toml` and `run/closure.sqlite` |
| Class graph | `http://127.0.0.1:8766/graph` | `run/graph/`, written by `closure_graph.jl` |
| Structure report | `http://127.0.0.1:8766/structure` | The JSON file given with `--structure` |

The class graph shows "preparing" until a graph snapshot exists. Write one
snapshot with this command:

```sh
julia --threads=1,1 --project=docs/inspector docs/inspector/closure_graph.jl --run packages/VBFSearch/data/search/demo-closure/run --once
```

Remove `--once` to keep the graph current. The builder then writes a new
snapshot after 500 more completed parents and 600 s; change these values with
`--every-seeds` and `--min-seconds`.

The structure report needs a report JSON. Give its path with
`julia --threads=1,1 --project=docs/inspector docs/inspector/closure_monitor.jl --campaign DIR --port 8766 --structure FILE`.
The page reads the keys `bent`, `du`, `automorphisms`, `yield` and others.
`VBFPaper/src/analysis/closure_structure.jl` writes a different `structure.json`,
and no tool in this repository writes the keys of the page now.

To watch a campaign on another computer, start the monitor there with
`host=0.0.0.0`. On the local computer, start `closure_monitor.jl` with
`--upstream http://HOST:8766/api/progress`. The local `--campaign` directory
must hold the same `campaign.toml` and root files.

## Validation and mathematical scope

```sh
bin/vbf validate --input candidates.tsv --output packages/VBFSearch/data/search/import01
bin/vbf audit packages/VBFSearch/data/search/experiment01
bin/vbf classify packages/VBFSearch/data/search/experiment01 --duration 30s --nodes 1000000
bin/vbf compare --candidate HEX --target HEX --relation ccz \
  --duration 60s --nodes 1000000 --output comparison.toml
bin/vbf verify comparison.toml
bin/vbf report packages/VBFSearch/data/search/experiment01
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
and LaTeX counts. Figures are downstream VBFPaper output:

```sh
julia --project=packages/VBFPaper \
  packages/VBFPaper/src/search_figures.jl packages/VBFSearch/data/search/experiment01
```

```julia
using VBF, VBFSearch
config = SearchConfig(output="packages/VBFSearch/data/search/run01", method=:v5,
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
# Or register the current snapshot of a stopped, stopped run.
bin/vbf publish packages/VBFSearch/data/search/experiment01 --name experiment01_n8
# Repeat the recovered 11,405-parent plan, using the current catalog baseline.
bin/vbf discover --name b52-replay --method v5 --target-b6 52 --bent max \
    --input packages/VBFSearch/data/search/legacy20261009/parents.tsv \
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
`packages/VBFSearch/data/search/legacy20261009/validated/`.

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

## Reference evidence and corpus classification

`src/reference/` owns digest-bound reference snapshots, equivalence checks and
signature-bucket classification. These workflows use catalog records and VBF
solvers; they do not write curated function definitions. The
[tool commands](tools/README.md) build or resume the derived evidence.

`open_reference` checks coverage and freezes a run's comparison scope.
`reference_metadata`, `reference_contains_signature` and
`reference_exact_lut_match` expose its documented data. Curated class APIs and
stored pair-check APIs now belong to VBFSearch. Their files live under `data/`,
which can be overridden with `VBF_SEARCH_DATA_DIR`.
