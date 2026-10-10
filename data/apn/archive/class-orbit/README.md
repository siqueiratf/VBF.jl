# Historical class-orbit experiment

This archive preserves the artifacts formerly stored at the repository root
under `search/`: `centers/`, `state/`, `control/`, target configuration, summaries,
`run.log`, the original [report](REPORT.md), and the call-site audit. The files
were moved without changing their contents. Historical path names and scientific
claims in those artifacts describe the original experiment; consult the
[current research assessment](../../../../packages/VBFSearch/AUDIT.md) for the
supported interpretation of novelty evidence.

The retired implementation is available in Git at commit
`361885d` under `search/`. This checkout also keeps an ignored `source/` snapshot
of those scripts and an ignored `migration.json` mapping original paths to their
new locations with SHA-256 hashes. They are provenance records, not supported
entry points. The commutant coefficient sweep is not a method of the current CLI;
its algorithm is preserved for any future consolidation.

The former `search/apn/results/` run directories now live at `data/apn/runs/`.
Their database bytes, manifests, frozen inputs and source archives were preserved.
Embedded original paths and source digests were not rewritten. Historical runs
remain inspectable, but relocation alone does not make an old checkpoint resumable
under changed code: the source and input identity checks still apply.

Start fresh experiments with [`bin/vbf`](../../../../packages/VBFSearch/README.md).
No experiment code is maintained in this data archive.
