# bench/profiling — opt-in profiling environment

Raw flame graphs are diagnostic artifacts, not the main thesis visualization.
`make -C bench consolidate` reconstructs these saved profiles with FlameGraphs
and persists normalized owner/subsystem/operation summaries in the separate
analysis database. See [the analysis workflow](../analysis/README.md).
New artifacts include approach, case parameters, seed, source hash, CPU and
thread count for guarded joins to benchmark data. Older artifacts remain usable
for standalone summaries but are not automatically joined to timings.

This directory is a Julia environment, separate from the root workspace, for
`bench/profile.jl`. It holds `FlameGraphs.jl`, `ProfileSVG.jl`, and
`ProfileView.jl` — none a dependency of `bench/run.jl` or
`bench/run_papers.jl`, which never profile anything.

Profiling is never automatic. A profiled execution is never a benchmark
measurement: `bench/run.jl` and `bench/run_papers.jl` time every case exactly
as before, and `bench/profile.jl` writes nothing to the `benchmark` table.
Run it by hand, for a case you have already decided is worth a closer look
after reading the benchmark data.

## Setup

```bash
julia --project=bench/profiling -e 'using Pkg; Pkg.instantiate()'
```

## Use

```bash
# a core VBF/VBFCatalog case, from bench/suites/
julia --project=bench/profiling bench/profile.jl --group=spectra --name=differential_uniformity_apn --n=14

# a paper reproduction case, from bench/paper_suites/
julia --project=bench/profiling bench/profile.jl --paper=Beierle_202107 --case=Beierle_202107_algorithm1

# also open an interactive ProfileView.jl window (needs a display)
julia --project=bench/profiling bench/profile.jl --paper=Beierle_202107 --case=Beierle_202107_algorithm1 --view
```

Each run does exactly one profiled execution — a warm-up first (uncounted),
then `Profile.clear()`, then one `Profile.@profile` call — and writes into
`bench/profiles/core/<case>/<timestamp>/` or
`bench/profiles/papers/<paper_id>/<case>/<timestamp>/`:

- `profile_raw.jls` — the raw samples in `Profile.retrieve()`'s portable
  form, safe to reload in a later session (see below).
- `attribution.json` — the estimated core/paper/other runtime split (see
  `bench/profiling/attribution.jl`), plus the case's identity and timings.
- `flamegraph.svg` — unless `--no-svg`.

Reload a saved profile later, in this same environment:

```julia
using Serialization, FlameGraphs
include("bench/profiling/attribution.jl"); using .ProfileAttribution
saved = deserialize(open("bench/profiles/.../profile_raw.jls"))
g = flamegraph(saved.data; lidict = saved.lidict)
attribute_flamegraph(g)
```

## The attribution estimate

`bench/profiling/attribution.jl` walks each sample's FULL call stack (via the
`FlameGraphs.jl` tree), not only its leaf frame. A frame under
`packages/VBF/src` or `packages/VBFCatalog/src` owns `:core`; a frame under
any `papers/` directory owns `:paper`. For a sample whose leaf has no owner,
the owner is whichever is *nearest going outward from the leaf* — so
`paper -> VBF -> BLAS` attributes to `:core` (VBF is nearer than paper), and
`paper -> some other package` attributes to `:paper` (nothing else on the
stack owns it). This is a sampling-based ESTIMATE, not an exact
instrumentation — every stored fraction carries `samples_total` next to it so
a reader can see how much evidence backs it.
