# Archived evidence of expensive reproduction runs

CI makes regression evidence (the paper tests) on every push. A run that is too expensive
for CI, for example a full search, is made once and archived here, so that the website can
show it without running it again.

Layout: `<paper-id>/<run-id>/record.toml`, and `output.log` when it is at most 1 MiB. A larger
log is kept elsewhere (for example in a Zenodo record); `record.toml` then gives its `url`
and its SHA-256.

Make and archive a record:

```sh
bin/vbfrepro run 200900-edel-switching --target theorem7 --param full_search=true --evidence
bin/vbfrepro archive packages/VBFRepro/src/results/runs/200900-edel-switching/RUN-ID
bin/vbfrepro evidence packages/VBFRepro/evidence
```

`record.toml` uses the schema `vbf-evidence-1` (see `packages/VBFRepro/src/evidence.jl`).
Its `provenance` says where and when the run was made. Its `fingerprint` gives the digests
of the executable dependencies of the run. A record stays valid as a historical result after
the code changes; the website calls it current only while its fingerprint equals the one of
the published commit. `archive` refuses a run made from a checkout with local changes.
