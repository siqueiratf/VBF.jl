# Search data vault

This folder keeps the raw output of our APN searches. Before 2026-10-13, this
output was only on one local disk. Some files are larger than the GitHub limit
of 100 MB, so each data set is a zstd-compressed tar archive in parts of at most
95 MiB. Git tracks the parts as normal files. Git LFS is not used.

Nothing in an archive is changed. Each file is byte-identical to the original,
and a manifest gives the SHA-256 of each original file.

| Archive | Original files | Compressed | Contents |
|---|---|---|---|
| `class-orbit-hits` | 10 files, 1284 MB | 188 MB, 2 parts | The `.hits` logs of the class-orbit search (`archive/class-orbit/state/`). `selfequiv_class22.hits` has 97,920,000 hits (1.27 GB). |
| `census-b52-hyperplane` | 52 files, 834 MB | 85 MB, 1 part | The B6 = 52 search (`desk1_framework`, `trial`, novelty table with 109,943 verified new functions), the hyperplane scan, the `repro`/`validate` samples and the independent audit of 2026-10-09. |
| `beierle2025-class-count` | 106 files, 102 MB | 30 MB, 1 part | The Knuth-estimator study that extends Beierle et al. 2025: 40 sample chunks, `s1.tsv`, `s77.tsv`, the 84 new CCZ classes (`final_new.tsv`) and the scripts. |

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

Each restore target checks every unpacked file against its manifest. Git
ignores `restored/` and the `.hits` files.

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

The B6 = 52 discoveries are also in the catalog as corpus `legacy20261009_n8`
(see `../../search/legacy20261009/`). The vault keeps the raw run as well.
