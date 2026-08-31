# VBF benchmark suite

The suite measures the public API of `packages/VBF` and the read queries of
`packages/VBFCatalog`. It writes four files that a paper or a thesis reads
directly. It changes nothing under `packages/`, it rebuilds no database, and it
runs no git command.

## Start the suite

Run one of these from the repository root.

```bash
make -C bench quick     # level 1, the fast cases only   about 1 minute
make -C bench bench     # level 2, the default set       about 15 minutes
make -C bench full      # level 3, every case            an hour or more
make -C bench list      # print the registered cases, measure none
```

The equivalent direct calls are these.

```bash
julia --project=. bench/run.jl --level=2
julia --project=. bench/run.jl --group=spectra --group=invariants
julia --project=. bench/run.jl --n=8 --n=10
julia --project=. bench/run.jl --level=1 --target-seconds=0.25
```

CAUTION: do not start `make -C bench full` on a machine that you need for other
work. Level 3 runs the exhaustive equivalence searches. A loaded machine moves
every figure by up to a factor of two, as `bench/calibration.toml` records.

## The levels

| Level | Name | Cost of one case | Use |
|---|---|---|---|
| 1 | fast | under about 0.1 s | a quick check after a code change |
| 2 | medium | under about 5 s | the default; the table for the thesis |
| 3 | heavy | minutes | the complete picture for a final draft |

A case declares its own level through the `cost` field. The runner skips a case
when its cost is above the level that you ask for.

## The four artifacts

The suite writes these into `bench/generated/`.

- `benchmarks.csv` — the tidy dataset. One row is one measured case. A
  spreadsheet, R, pandas or pgfplots reads it without any further work.
- `benchmarks_table.tex` — a `booktabs` table of every case, grouped by library
  tier. Your preamble must load `booktabs`.
- `benchmarks_facts.tex` — one `\newcommand` per case. The value is the minimum
  time in seconds, already in maths mode.
- `benchmarks_meta.tex` — the machine, the Julia version, the thread count and
  the run parameters. A timing without a machine is not a result, so print this
  next to the table.

## Use the artifacts in the thesis

Put this in the document.

```latex
\usepackage{booktabs}
\input{bench/generated/benchmarks_facts.tex}
\input{bench/generated/benchmarks_meta.tex}

\begin{table}
  \centering
  \input{bench/generated/benchmarks_table.tex}
  \caption{Cost of the VBF operations on \bmMetaCPU{} under Julia
           \bmMetaJulia{}. The statistic is the \bmMetaStatistic{}.
           Measured on \bmMetaDate{} at level \bmMetaLevel{}.}
\end{table}

The ortho-derivative of an 8-bit APN function costs
\bmInvariantsOrthoDerivativeNEight{} seconds.
```

Run `make -C bench list` to see every case name. The command for a case is
`\bm` plus the group, plus the case name, plus `N` and the width, all in camel
case with each digit spelled as a word. The case `invariants/ortho_derivative`
at `n = 8` therefore gives `\bmInvariantsOrthoDerivativeNEight`.

A case name that ends with `!` gets `Bang` in the command, so the in-place
method and the allocating method stay apart. `spectra/walsh_hadamard!` at
`n = 8` gives `\bmSpectraWalshHadamardBangNEight`.

To plot the growth curve, read `benchmarks.csv` with `pgfplots` and filter on
the `case` column.

## Add a case

Every file in `bench/suites/` defines exactly one function, `register!(reg)`.
The runner includes one file, calls that function, then moves to the next file.
Use `bench/suites/01_representations.jl` as the model.

```julia
function register!(reg)
    bench!(reg; group = "spectra", name = "ddt", n = 8, cost = 1,
           setup = () -> gold_apn(8, 1),      # NOT timed
           call  = F -> ddt(F),               # timed
           note  = "difference table")
    return reg
end
```

Follow these rules.

1. Put every allocation that the case does not measure inside `setup`.
2. Give an honest `cost`. Measure it once before you tag it.
3. Give every bounded search an explicit limit. A case without a bound is a
   defect.
4. Keep `note` under about five words. It goes into the thesis table.
5. Set the `n` keyword whenever the operation is size-indexed.

## How the harness measures

`bench/harness.jl` repeats the method that `bench/calibrate.jl` already uses.

1. Seed the random number generator from the case name, so the payload repeats.
2. Build the payload through `setup`, and do not time it.
3. Call the operation once to warm it up and to compile it.
4. Choose the repetition count so the total is near one second, inside [3, 500].
5. Time each repetition with `@elapsed`, then report the minimum.

The minimum is the statistic of record. It is the least sensitive to scheduler
noise on a loaded machine. The CSV also holds the median, the mean, the standard
deviation and the allocated bytes.

## Related files

- `bench/calibrate.jl` and `bench/calibration.toml` are the earlier, hand-written
  probe of a few primitives. They stay, because `report.md` cites them.
- `bench/gamma8_probe.jl` is a single experiment on the Gamma-rank at n = 8.
