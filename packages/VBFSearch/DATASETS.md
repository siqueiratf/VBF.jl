# APN dataset scopes

The published reference remains in VBFCatalog. Unpublished discoveries belong to
VBFSearch; they are excluded from the default catalog and current campaign roots.
The local registry is `data/research/datasets/registry.json`. Paths below are
relative to `packages/VBFSearch/`.

| Collection | Location | Meaning |
| --- | --- | --- |
| Earlier discoveries | `data/research/datasets/earlier-discoveries-190638.sqlite` | 111,009 recovered representatives + 79,445 later finite-search representatives + 184 pilot representatives. |
| Completed published-root result | `data/research/freezes/published-roots-b52-20261017/` | Complete direct V5 and switching expansion of 24,294 roots: 1,237,894 classes including roots, 294,000 absent from the pinned published reference. |
| Completed-root witness ledger | `data/search/literature-b52-closure-20261014/run-compact-v15-20261016/closure.normalized.sqlite.zst` | Original construction/admission witnesses and IDs in normalized archival storage. Use the pinned restoration helper for SQL inspection or original execution. |
| Current recursive checkpoint | `data/search/literature-b52-closure-20261014/run-reduced-20261020/` | Stopped resumable campaign, frozen code, root inputs, derivations, reports and graph. |
| Pinned published reference | `data/research/references/published-literature-20261017/` | Published-only comparison scope and signature/member evidence. |

## Merged earlier discoveries

The single SQLite file is self-contained, approximately 1.97 GiB. Its tables are:

- `classes`: 190,638 representatives, one per distinct separating signature.
  This is a class-count lower bound; equal signatures do not certify equivalence.
- `exact_luts`: 645,851 distinct exact LUTs, including supporting/reference
  observations and matching-signature alternatives retained from the source runs.
- `observations` and `runs`: 676,241 original candidate observations across the
  recovered run, completed finite B52 run, and two pilot arms.
- `representative_sources`: source membership, including the pilots' overlap.
- `archives`, `archive_parts` and `archived_files`: six verified original source
  directory archives in bounded tar.zst chunks, with every file digest.
- `source_artifacts` and `metadata`: original freeze evidence and merge identity.

The original 190,454 classes retain their exact IDs, LUTs and source fields.
`legacy_190454` exposes that prefix. The completed-root comparison's 32,671
historical overlaps refer to this prefix; it did not compare the additional 184
pilot representatives. Original source paths are historical paths; the merged
database now contains the source bytes.

All 315,910 candidate records from the first nine-hour B52 search are retained
with identical evidence in the completed split-run archive. The 44,350 discoveries
from that first segment are included in the later 79,445.

List or restore embedded original evidence:

```sh
python3 packages/VBFSearch/data/research/datasets/extract_archive.py
python3 packages/VBFSearch/data/research/datasets/extract_archive.py finite_b52 --output /path/to/restore
```

The output restores paths relative to the VBFSearch package root. The extractor
checks the compressed archive SHA-256. SQLite clients can query representative
LUTs directly without restoring original experiments.

## Retained search provenance

The completed-root freeze's derivations refer to class/path IDs in its original
compressed ledger. The current campaign uses different IDs and some different
representatives; these are separate evidence namespaces. The original ledger
stays alongside the frozen result, now in losslessly normalized archival storage.
Use `run-compact-v15-20261016/storage-tools/archive-v2/restore_checkpoint.py` to
restore the original schema for its frozen code, or `--normalized-only` for SQL
inspection. See [STORAGE.md](STORAGE.md) for storage and restoration details.

The current checkpoint retains 3,554,200 admitted parents and 7,650,225 exact LUTs.
Admission is not a claim that every parent is new to the literature. The campaign
remains stopped. `data/search/literature-b52-closure-20261014/current.json` identifies
the selected collections and prepared restart.

The cleanup removed other experiments after verifying the merge, archives,
protected search checksums, source files and inputs. See [INVENTORY.md](INVENTORY.md),
[STORAGE.md](STORAGE.md), and `data/research/analyses/cleanup-20261020/`.
Generated databases remain ignored. Nothing was pushed.
