# APN dataset scopes

The default `VBFCatalog` is the published reference. Unpublished search discoveries
belong to `VBFSearch` experiment databases and must not be registered as reference
corpora. In particular, `legacy20261009_n8` is deliberately excluded from the
default catalog and its signature index.

The local registry is `data/research/datasets/registry.json`. It records absolute
paths, content hashes, scopes, and the current comparison report. Generated SQLite
files and reports remain ignored research artifacts.
Paths beginning with `data/` below are relative to `packages/VBFSearch/`;
`.cache/` is relative to the repository root.

| Role | Local database or bundle | Meaning |
| --- | --- | --- |
| Published reference | `.cache/vbfcatalog/`; pinned copy under `data/research/references/published-literature-20261017/` | Published corpora, named literature functions, and public reference supplements. No private historical discoveries. |
| Earlier discoveries | `data/research/freezes/apn-20261014-190454/classes.sqlite` | The earlier 111,009 classes plus 79,445 later classes. Original packed input and frozen audit metadata are preserved in `source_artifacts`. |
| Published-root result | `data/research/freezes/published-roots-b52-20261017/classes.sqlite` | Classes observed directly in complete V5 and switching expansions of the 24,294 published roots. Includes the initial seeds. |
| Comparison evidence | `data/research/freezes/published-roots-b52-20261017/comparisons.sqlite` | Literature and historical membership evidence for the published-root result. This contains relationships and witnesses, not a reference corpus. |
| Recursive campaign archive | Path recorded in the registry | The full stopped campaign ledger, including recursive work. This is a different scope from the direct published-root result. |
| Current recursive checkpoint | `data/search/literature-b52-closure-20261014/run-validation-20261018T232756Z/closure.sqlite` | The later recursive campaign, stopped on 19 October 2026. Its published-reference comparisons are under `reports/`; it remains separate from both class freezes above. |

The published-root result's `roots`, `methods`, and `derivations` tables preserve
which original parent and construction produced each class. A derivation records
the first path identifier in the retained campaign ledger and its multiplicity;
that ledger retains the full construction and admission witnesses.

`comparison.json` answers two independent questions: absence from the published
reference, and overlap with the earlier discovery dataset. It also records the
classes outside both. A positive overlap requires exact equality or a replayed
EA graph certificate. Different quadratic ortho-derivative signatures certify
separation; matching signatures alone do not merge classes. CCZ/EA agreement for
quadratic APNs supplies the interpretation of these comparisons.

The reproducible consumers live under `tools/datasets/`: `freeze.jl`,
`prepare_comparisons.jl`, `verify_comparisons.jl`, `restrict_reference.jl`,
and `compact.jl`.
Run expensive verification under an explicit Julia thread limit. The reference
restriction tool only reuses repeated-bucket classification when every removed
record was a singleton; it refuses a restriction that would alter shared-bucket
evidence. Pin the original catalog before changing its source set.

Historical checkpoints can be stored as verified `.sqlite.zst` archives. Their
adjacent manifests record the original byte hash and restore command; restore
the SQLite file before opening one. Current storage locations and controller
restart policies are described in [STORAGE.md](STORAGE.md).

## Shared copies

Git tracks both class datasets in a compact, lossless form: the vault archive
`data/research/vault/apn-datasets-20261017.tar.zst.part*` (63 MB). Run
`make -C packages/VBFSearch/data/research/vault restore-datasets` to rebuild
both `classes.sqlite` files. The restore checks the logical SHA-256 of every
table; see `data/research/vault/README.md`. The comparison witnesses, the
campaign ledger and the pinned reference are not in git: the tools above
calculate the witnesses again, and a catalog build gives the reference again.
