# Manuscript figures from persisted benchmarks

Run from the repository root:

```sh
make -C packages/VBFRepro/src/analysis manuscript input=/absolute/historical.sqlite figure_output=/absolute/figures
make -C packages/VBFRepro/src/analysis test
```

The manuscript target uses the existing analysis environment. If dependencies
are absent, first run `make -C packages/VBFRepro/src/analysis instantiate`. No benchmark is rerun and
the catalog is opened with query-only protection. Override `input=PATH`,
`figure_output=DIR`, or `manuscript_config=PATH` as needed.

`manuscript.toml` pins the September 7, 2026 unrestricted level-2 API run and the
later paper-report run. The level-3 run and group-specific runs remain in the
exported run inventory; their different selections and repetitions are not
pooled with the baseline. Change the configuration deliberately for a new study.

`manuscript.jl` validates the recorded repetition sequence against each case's
persisted target and retains the conservative `BenchAnalysis.GROUP_KEYS`.
It emits CSVs for timing summaries, paper reports, catalog calls, all corpus
sizes, corpus-time projections and the run inventory. Summary CSVs preserve run,
source, parameters, first/last raw row IDs, medians, quartiles, mean and standard
deviation. Raw row IDs may be nonconsecutive; select by the run and case keys.

The growth CSV restricts the APN-EA mugshot series to the quadratic Gold path;
its n=5 and n=6 fallback cases remain in the full appendix.

The same script emits two PDF figures and LaTeX tables, including a page-breaking
appendix. Include `current_facts.tex` before those tables. `current_provenance.toml`
records the source snapshot, script/configuration/environment hashes and corpus
store hash recorded by the catalog; it does not rehash the entire corpus store.
`current_run_provenance.json` preserves the selected run's original machine,
source revision and source-tree hash, including its dirty-tree flag. Archive raw
data and resolved source/environment files with a published snapshot: hashes alone
cannot reconstruct a dirty source tree. Generated `current_*` files are disposable.

Corpus projections multiply each operation's median at n=8 by the selected
corpus member count, then divide by 3600 to obtain hours. The operations use a
Gold function (or its prepared orthogonal derivative for reconstruction), not a
representative sample of the Beierle corpus. Quartiles describe repeated calls
on that input, not uncertainty across functions. Projections exclude loading,
decoding and persistence and assume sequential constant-cost processing.

Corpus counts are stored memberships, not a deduplicated union or a count of
CCZ classes. The fixed-member Beierle read benchmark and the materializations
of 22/6,368-member corpora do not establish full-corpus throughput. Packed/LUT
byte totals describe representation payloads, not peak resident memory.

Compile the manuscript from its directory, with a fresh output directory:

```sh
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/vbf-tcc-build main.tex
cp /tmp/vbf-tcc-build/main.pdf main.pdf
```

Inspect the LaTeX log for errors, unresolved references and overfull boxes, and
render the changed PDF pages to check plots, captions and tables visually.
