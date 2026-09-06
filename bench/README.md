# VBF benchmark suite

The suite measures the public API of `packages/VBF` and the read queries of
`packages/VBFCatalog`. It writes four files that a paper or a thesis reads
directly. It changes nothing under `packages/`, it rebuilds no database, and it
runs no git command.

## Start the suite

Run one of these from the repository root.

```bash
make -C bench quick     # level 1, the fast cases only   about 1 minute
make -C bench bench     # level 2, the default set       about 4 minutes
make -C bench full      # level 3, every case            about 30 minutes
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

CAUTION: give level 3 at least 4 GB of free memory. The case
`equivalence/partition_automorphisms` at `n = 6` returns 14.4 million maps and
holds about 1.7 GB for each call.

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

## The crossings

A table of 229 timings is data. A crossing turns that data into a result,
because it puts each measurement against a prediction that the measurement can
contradict. Run this after any suite target.

```bash
make -C bench crossings          # about one second; it measures nothing
```

The command reads `bench/generated/benchmarks.csv`, the machine file beside it,
and the predictions in `bench/crossings.toml`. It writes ten more files into
`bench/generated/`.

### Crossing 1 — the dimension against the predicted exponent

The script fits `log2` of the minimum time against `n`, so the slope of a
series is an exponent. `bench/crossings.toml` holds the exponent that the
algorithm predicts, and the table prints the two side by side.

CAUTION: the `n` column of the CSV holds three different quantities: a bit
width, a matrix side and a machine word width. A fit that mixes them returns a
number that looks like a growth rate and is not one. The `[size_kind]` section
of `bench/crossings.toml` separates them, and the script gives a power-law
model to a matrix side and an exponential model to a bit width.

Three guards keep the table honest.

1. A series whose fastest point is under one microsecond reads "inconclusive".
   The fixed cost of one call is then a large part of the measurement.
2. A series that the straight line misses by more than half a bit reads
   "curved fit". Its slope is an average over two regimes and not one
   exponent, so read the `pair_slope_min` and `pair_slope_max` columns.
3. A case with three or more points, no prediction and no exclusion appears as
   "unmodelled" in the console and in the header of the CSV. A new case can
   therefore never drop out of the article without a word.

The `[[extrapolation_check]]` entries test a fit against a point that another
instrument measured. The Gamma-rank fit over n = 5 to 7 gives 141.9 s at
n = 8; `bench/calibration.toml` measured 166.8 s there, a ratio of 0.85.

### Crossing 2 — the cost of a yes against the cost of a no

Every decision procedure in `bench/suites/05_equivalence.jl` registers a
positive case and a negative case. The two answers take different code paths,
so one mean over both has no meaning. `[[polarity]]` pairs them and states
which side the code should favour. The table prints the ratio and names the
faster answer, and the script marks a pair whose direction misses its
expectation.

### Crossing 3 — the allocation against the time

The scatter of allocated bytes against seconds shows which cases stop for the
reason of memory. The reach table joins this crossing to the first one: each
fitted series gives a largest `n` under one hour and a largest `n` under 4 GiB,
and the smaller of the two is the one that stops the operation.

CAUTION: the `bytes` column comes from `@allocated`. It is the total that one
call allocates, and it is not the peak resident memory. Two figures for peak
resident memory exist in this repository, and both come from another
instrument: 0.95 GB for the Gamma-rank at n = 8, in `bench/calibration.toml`,
and about 1.7 GB for one call of `equivalence/partition_automorphisms` at
n = 6.

### The files

| File | What it is |
|---|---|
| `crossing_growth.csv` | one row per fitted series: slope, prediction, verdict, reach |
| `crossing_growth_table.tex` | the `booktabs` table of crossing 1 |
| `crossing_growth.dat` | the measured points, for a `pgfplots` growth figure |
| `crossing_reach_table.tex` | the largest `n` under one hour and under 4 GiB |
| `crossing_polarity.csv` | one row per decision procedure, both answers |
| `crossing_polarity_table.tex` | the `booktabs` table of crossing 2 |
| `crossing_memory.csv` | every case, heaviest allocation first |
| `crossing_memory_table.tex` | the `booktabs` table of the heaviest cases |
| `crossing_memory.dat` | the scatter data of crossing 3 |
| `crossings_facts.tex` | one `\newcommand` per figure that the prose quotes |
| `CROSSINGS.md` | the provenance: the machine, the units, the unmodelled cases, the excluded series and the external checks |

The three CSV files hold data only. They carry one header line of column names
and no comment line, so pandas, R or a spreadsheet reads them with no filter.
Everything that a reader needs to interpret them is in `CROSSINGS.md`.

`bench/crossings.tex` is the fragment that you paste into the paper. It is not
generated. It inputs the four tables, draws the two figures and writes the
captions. `bench/preview_crossings.tex` compiles that fragment on its own, so
you can read it on screen. The preview is a proofing harness. Do not paste it
into a paper.

### Add a prediction

Open `bench/crossings.toml` and add a `[[growth]]` block.

```toml
[[growth]]
case = "spectra/ddt"
predicted_slope = 2.0
kind   = "exact"          # or "lower_bound"
basis  = "the table holds 2^{2n} cells and every cell is written once"
source = "bench/suites/03_spectra.jl"
```

Follow these rules.

1. Give the exponent from the algorithm, never from the measurement.
2. Use `lower_bound` when each unit of work itself grows with `n`.
3. Name the file that documents the exponent in `source`.
4. Exclude a series through `[[excluded]]` when its points do not measure one
   algorithm on one family of inputs. Give the reason.

## Related files

- `bench/calibrate.jl` and `bench/calibration.toml` are the earlier, hand-written
  probe of a few primitives. They stay, because `report.md` cites them.
- `bench/gamma8_probe.jl` is a single experiment on the Gamma-rank at n = 8.
- `bench/crossings.jl`, `bench/crossings.toml`, `bench/crossings.tex` and
  `bench/preview_crossings.tex` build the crossings above.
