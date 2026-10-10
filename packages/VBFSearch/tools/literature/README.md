# Literature and historical evidence audits

These research consumers enumerate finite domains of published constructions,
compare them against an independently rebuilt quadratic reference, and verify
the resulting evidence. They use VBF mathematics, VBFCatalog reference data and
VBFSearch evidence routines. Run from the instantiated root project.

```sh
julia --project=. packages/VBFSearch/tools/literature/test_families.jl
julia --project=. packages/VBFSearch/tools/literature/test_verify_families.jl
python3 packages/VBFSearch/tools/literature/fetch_sources.py data/apn/rebuilds/survey01
python3 packages/VBFSearch/tools/literature/prepare_sources.py data/apn/rebuilds/survey01
julia --project=. -t 8 packages/VBFSearch/tools/literature/check_sources.jl \
  data/apn/rebuilds/survey01 data/apn/reference
julia --startup-file=no packages/VBFSearch/tools/literature/verify_evidence.jl \
  data/apn/rebuilds/survey01
julia --project=. packages/VBFSearch/tools/literature/review_history.jl \
  --outdir data/apn/runs/history --baseline data/apn/reference
```

`sources.tsv` pins downloaded inputs by digest. `family_coverage.toml` specifies
the finite parameter domains, formula sources, normalization assumptions and
known restrictions. `check_families.jl OUTDIR [BASELINE_DIR]` rejects existing
output reports and fingerprints the executable sources and paper inputs.
`verify_families.jl OUTDIR` independently checks generated LUTs and separating
invariants; it does not independently derive every published formula.
`confirm_history.jl FAMILY_DIR [HISTORY_REPORT]` binds those family comparisons
to historical candidate inputs at matching digests.

`review_history.jl --full true` rechecks every historical candidate rather than
reusing digest-bound independent validation. Its default output is
`data/apn/runs/history/`. Archived survey outputs, downloaded inputs and reports
are under `data/apn/archive/census/`; new outputs belong under `data/apn/rebuilds/`
or `data/apn/runs/`. Some formula audits require the ignored paper inputs and
downloaded files named by the ledger, so they are not self-contained from Git alone.

Finite parameter coverage and reference absence have an explicit scope. Neither
the reference nor this family ledger certifies that every construction in the
literature has been covered. See the [scientific assessment](../../AUDIT.md) and
[consolidation review](../../CENSUS_REVIEW.md).
