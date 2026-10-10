# Reproductions and performance

`VBFRepro` runs selected papers in isolated processes and records execution
evidence. Importing the package loads its standard-library runner. Mathematical
implementations remain in `VBF`; data import and queries belong to `VBFCatalog`;
production discovery and checkpoints belong to `VBFSearch`.

## Run a paper

From the repository root, instantiate the workspace once:

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
bin/vbfrepro list
bin/vbfrepro test Yu_202211d --timeout-seconds 300
bin/vbfrepro run Yu_202211d --target qam_correspondence --timeout-seconds 900
```

Each paper lives under `packages/VBFRepro/papers/<year>/<id>/` and retains its
standalone claim scripts and Make targets. Direct `make -C <paper> test` uses
the same shared environment. The recorded runner stores parameters, source and
input hashes, timestamps, status and stdout/stderr under `data/repro/runs/`.
On Unix, a timeout stops the process group, including its Julia subprocess.
A passing target establishes what its assertions check; a stopped computation
does not establish exhaustion or a negative mathematical result.

See the [runner guide](https://github.com/zambonin/VBF.jl/blob/main/packages/VBFRepro/README.md)
for dependencies, source identity and external-data limitations.

## Measure public APIs

Every package owns a separate `perf/` environment and workload definitions.
BenchmarkTools collects the timing samples and allocations; package-specific
setup determines meaningful inputs, dimensions and computation limits.
Performance dependencies do not enter the runtime library environments.

```sh
julia --project=packages/VBF/perf -e 'using Pkg; Pkg.instantiate()'
julia --project=packages/VBF/perf packages/VBF/perf/run.jl --list
julia --project=packages/VBF/perf packages/VBF/perf/run.jl \
  --group=spectra --workload=ddt --n=6 --seconds=1 --samples=100
```

The analogous `VBFCatalog`, `VBFSearch` and `VBFRepro` folders cover catalog,
discovery and paper workloads respectively. Results, configurations and source
identities go under `data/perf/`. Measurement leaves the curated catalog unchanged.
Profiling is a separate diagnostic execution; its samples are not benchmark
timing repetitions.

## Analyze saved evidence

One optional analysis environment owns reproduction metrics and saved performance
readers:

```sh
make -C packages/VBFRepro/analysis instantiate
make -C packages/VBFRepro/analysis grades
make -C packages/VBFRepro/analysis fast
make -C packages/VBFRepro/analysis consolidate
make -C packages/VBFRepro/analysis export
```

Outputs default to `data/repro/analysis/`. Historical custom-timer measurements
retain their original protocol and provenance; the analysis keeps them separate
from BenchmarkTools trials. Publication-specific configurations and templates
live under `manuscript/`.

See the [analysis guide](https://github.com/zambonin/VBF.jl/blob/main/packages/VBFRepro/analysis/README.md)
for the input/output options and documented statistical limits.
