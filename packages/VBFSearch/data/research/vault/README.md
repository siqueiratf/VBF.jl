# Search data vault

This folder keeps the raw output of our APN searches. Before 2026-10-13, this
output was only on one local disk. Some files are larger than the GitHub limit
of 100 MB, so each data set is a zstd-compressed tar archive in parts of at most
95 MiB. Git tracks the parts as normal files. Git LFS is not used.

Nothing in an archive is changed. Each file is byte-identical to the original,
and a manifest gives the SHA-256 of each original file. The one exception is
`apn-datasets-20261017`: it keeps the content of two SQLite databases in a
compact, lossless form, and a restore rebuilds the databases.

| Archive | Original files | Compressed | Contents |
|---|---|---|---|
| `class-orbit-hits` | 10 files, 1284 MB | 188 MB, 2 parts | The `.hits` logs of the class-orbit search (`archive/class-orbit/state/`). `selfequiv_class22.hits` has 97,920,000 hits (1.27 GB). |
| `census-b52-hyperplane` | 52 files, 834 MB | 85 MB, 1 part | The B6 = 52 search (`desk1_framework`, `trial`, novelty table with 109,943 verified new functions), the hyperplane scan, the `repro`/`validate` samples and the independent audit of 2026-10-09. |
| `beierle2025-class-count` | 106 files, 102 MB | 30 MB, 1 part | The Knuth-estimator study that extends Beierle et al. 2025: 40 sample chunks, `s1.tsv`, `s77.tsv`, the 84 new CCZ classes (`final_new.tsv`) and the scripts. |
| `apn-datasets-20261017` | 36 files, 149 MB | 63 MB, 1 part | The two frozen APN class datasets of 2026-10-17 in compact form: the 1,237,894 classes of the direct expansion of the 24,294 published roots, and the 190,454 earlier discoveries. See [the section below](#the-frozen-apn-class-datasets). |

The search code that wrote these files is in `../archive/class-orbit/code/` and
`../archive/census/code/`. It is the code as it was at commit `277eca9` of the
former `research/quadratic-apn8-census` branch. The checkpoints (`*.ckpt.toml`)
are tracked in `../archive/class-orbit/state/`.

## Restore

You must have `zstd`, GNU `tar` and `sha256sum`.

1. Check the parts: `make -C packages/VBFSearch/data/research/vault verify`.
2. Put the `.hits` files back next to their checkpoints:
   `make -C packages/VBFSearch/data/research/vault restore-hits`.
3. Unpack the other data sets into `restored/`:
   `make -C packages/VBFSearch/data/research/vault restore-census restore-beierle`.
4. Unpack the frozen APN class datasets and rebuild their SQLite databases:
   `make -C packages/VBFSearch/data/research/vault restore-datasets`.
   This step also needs Julia and the root environment.

Each restore target checks every unpacked file against its manifest. Git
ignores `restored/` and the `.hits` files.

## The frozen APN class datasets

`apn-datasets-20261017` keeps the content of two databases. The scopes are in
`packages/VBFSearch/DATASETS.md`.

| Folder in the archive | Original database | Classes |
|---|---|---:|
| `published-roots-b52-20261017/` | `../freezes/published-roots-b52-20261017/classes.sqlite` | 1,237,894 |
| `apn-20261014-190454/` | `../freezes/apn-20261014-190454/classes.sqlite` | 190,454 |

`packages/VBFSearch/tools/datasets/compact.jl` wrote each `compact/` folder:

- Each class LUT is one 37-byte `quadratic-coeffs-v1` record of VBF
  (`encode_quadratic`). The record holds the univariate coefficients of 2-adic
  weight at most 2 over GF(2^8), modulo the Conway polynomial 285. It keeps the
  constant and linear parts, so it gives the exact LUT.
- The export omits `lut_sha256` and `sigma_hash`. Before it omits them, it checks
  for every class that SHA-256 of the LUT and `VBF.sigma_hash` give the stored
  values.
- All other tables and columns are TSV files. `manifest.json` records the
  schema, the row count and a logical SHA-256 of each table.

The restore calculates the LUT, `lut_sha256` and `sigma_hash` again. Then it
checks the row count and the logical SHA-256 of each table, and the foreign
keys. The rebuilt databases are logically equal to the originals. Their file
SHA-256 is different from the values in `../datasets/registry.json`, because
SQLite writes its own header fields. The restore also writes
`representatives.tsv` again, byte for byte (SHA-256 `5b63b124…`). A full
restore took 4 min 36 s with 32 threads.

Each dataset folder also keeps the small provenance files of its freeze:
`comparison.json` and `REPORT.txt` of the published-root result, and the
audit records of the historical freeze. `references/` keeps the manifest of
the pinned published reference, and `datasets/` keeps the local registry.

## Paths in the archives

- `apn8-census-worktree/` is the former Claude worktree of the census branch
  (`.claude/worktrees/apn8-census/`).
- `vbf-clone/` is the former clone at `/home/ts/vbf/VBF.jl`.
- The `.hits` paths are relative to the repository root.

Some files hold absolute paths of the machine where the search ran, for example
`outdirs` in `novelty/summary.toml`.

## What is not in the vault

`search_b52/results/index/sigma_n8.bin` (121,871,712 bytes, SHA-256
`699217ead3faaafbe351c58160c3b119ff7a955109cd2f35f3712ec9ae5b5d21`) is a cache.
The `index` target of the B6 = 52 Makefile builds it again from
`ccz_sigma_index.sqlite`, and it does not compress. The `Manifest.toml` files
are also absent, because Julia writes them again.

These files of the frozen datasets are also not in the vault:

- `candidate_audit.tsv` (77,627,437 bytes) and `additional_reference.tsv`
  (45,919,229 bytes) of the historical freeze. `freeze.json` in the archive
  records their SHA-256.
- `comparisons.sqlite` (273,883,136 bytes, SHA-256
  `391f001ec25209cd4aac59d22ca72a93f411c20a2c9295e7c20303c7e3acceab`) of the
  published-root result. It holds the EA witnesses of the 943,894 literature
  pairs and the 32,671 historical pairs. `tools/datasets/prepare_comparisons.jl`
  and `verify_comparisons.jl` calculate them again: the literature pairs took
  1,209 s with 12 threads, and the historical pairs took 255 s with 2 threads.
  `comparison.json` keeps the results.
- The campaign ledger `run-compact-v15-20261016/closure.sqlite` (52 GB), and
  the pinned published reference (1.2 GB). A catalog build from the pinned
  originals gives the reference again.

Until 2026-10-17, the 111,009 B6 = 52 discoveries were the catalog corpus
`legacy20261009_n8` (see `../../search/legacy20261009/`). The default catalog
no longer holds them. The historical dataset in `apn-datasets-20261017` keeps
the original packed file `legacy20261009.coeffs.gz` in its `source_artifacts`
table. The vault keeps the raw run as well.
