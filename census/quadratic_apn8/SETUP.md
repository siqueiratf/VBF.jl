# Setup of a new machine

This file tells how to run the census from a fresh clone on another machine (for
example a Framework desktop with 64 GB). All paths are relative to the repository root.
`SRC` is the machine that has the data now (`/home/ts/VBF.jl`).

## 1. Julia and packages

- Use Julia 1.13.1. The packages need Julia ≥ 1.12 (`compat` in
  `packages/VBF/Project.toml` and `packages/VBFCatalog/Project.toml`). The results in
  `README.md` come from Julia 1.13.1.
- Git does not track the root `Manifest.toml`. To get the same package versions, copy it
  from `SRC` (step 2). Without it, `Pkg.instantiate` resolves new versions.
- Install the packages:

```
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

`make test` also runs `Pkg.instantiate`.

## 2. Data that git ignores

| File | Size | Needed by |
|---|---:|---|
| `packages/VBFCatalog/corpora/ccz_sigma_index.sqlite` | 681,914,368 B | `make analyze`, `make report` (σ lookup) |
| `packages/VBFCatalog/corpora/beierle2025_n8.sqlite` | 178,012,160 B | `make spot_check`, rebuild of the index, most subprojects |
| `Manifest.toml` (optional) | small | identical package versions |

Together they are about 860 MB. The eight smaller n = 8 corpora in the same directory
and `packages/VBFCatalog/BFA_catalog.sqlite` are in git.

You do not need these files for the analysis data: `census/quadratic_apn8/data/` holds
the 4,012,000 legacy samples in compact form. The full sample files (90 MB) stay on `SRC`.

### 2a. Copy (recommended)

Run on the new machine, from the repository root. Replace `ts@src-host` with the user
and host name of `SRC`. In the worktrees on `SRC` the two files are symbolic links;
`-L` copies the target files.

```
rsync -avL --progress \
  ts@src-host:/home/ts/VBF.jl/packages/VBFCatalog/corpora/ccz_sigma_index.sqlite \
  ts@src-host:/home/ts/VBF.jl/packages/VBFCatalog/corpora/beierle2025_n8.sqlite \
  packages/VBFCatalog/corpora/
rsync -av ts@src-host:/home/ts/VBF.jl/Manifest.toml .    # optional
```

`scp` also works:
`scp ts@src-host:/home/ts/VBF.jl/packages/VBFCatalog/corpora/{ccz_sigma_index,beierle2025_n8}.sqlite packages/VBFCatalog/corpora/`.

### 2b. Rebuild (if you cannot copy)

The rebuild takes hours. Do it in this order.

1. Download `new_apns.txt` (3,395,265,744 bytes, MD5 `dd6ae0655ba8a299a3d668cfc6cf10bf`)
   from Zenodo record 16752428 (https://doi.org/10.5281/zenodo.16752428). Put it in a
   directory, for example `~/data/beierle2025/`. Check it:

   ```
   md5sum ~/data/beierle2025/new_apns.txt
   ```

2. Install the build environment and build the corpus store (uses all threads):

   ```
   julia --project=packages/VBFCatalog/data-build -e 'using Pkg; Pkg.instantiate()'
   make -C packages/VBFCatalog/data-build beierle2025 BFA_BEIERLE2025_PATH=$HOME/data/beierle2025
   ```

3. Build the σ index over the `functions` table and all 9 corpora:

   ```
   julia --startup-file=no --project=packages/VBFCatalog/data-build -t auto \
     packages/VBFCatalog/data-build/build_sigma_index.jl
   ```

   Do not use `--functions-only`: it skips the corpora, and the index then refuses to
   answer at n = 8. The script also writes `equivalence_classes` into the tracked
   `packages/VBFCatalog/BFA_catalog.sqlite`. Check `git status` afterwards. Restore the
   file with `git checkout packages/VBFCatalog/BFA_catalog.sqlite` if you do not want
   that change.

A rebuilt file has the same rows, but its SHA-256 can differ (other SQLite version).

### 2c. Check

```
cd packages/VBFCatalog/corpora
sqlite3 -readonly beierle2025_n8.sqlite 'SELECT COUNT(*) FROM members;'
#   3775599
sqlite3 -readonly ccz_sigma_index.sqlite \
  'SELECT COUNT(*), COUNT(DISTINCT sigma_hash) FROM ccz_sigma_index WHERE n = 8;'
#   4005445|3808491
sqlite3 -readonly ccz_sigma_index.sqlite 'SELECT COUNT(*) FROM sigma_coverage WHERE indexed = 0;'
#   0  (no coverage gaps)
sqlite3 -readonly ccz_sigma_index.sqlite \
  'SELECT source, COUNT(*) FROM ccz_sigma_index WHERE n = 8 GROUP BY source ORDER BY 2 DESC;'
```

The last query must list 10 sources: beierle2025_n8 3,775,599; simonberg_gf4_n8 196,863;
beierleleander2022_n8 12,923; yuwangli2014_qam_n8 8,179; beierleleanderperrin2022_n8
6,368; yuperrin2022_qam_n8 5,412; functions 67; edelpott2009_n8 22; wengtangong2013_n8
10; taniguchi2019_n8 2.

SHA-256 of the files on `SRC` (a copy must match; a rebuild can differ):

```
a097f3afcca010d959f5c39a995c856465b3ba9494b81eb0d0e8fa670f1036dd  beierle2025_n8.sqlite
057ad40ed46cd0e97965ee56ec11854059b14109931f932713f3ade2d55b2f49  ccz_sigma_index.sqlite
```

## 3. Run

From `census/quadratic_apn8/`:

```
make test                    # unit tests, no σ index needed
make analyze                 # legacy run from data/: 4,012,000 samples, 1,661 hits,
                             # mass 5.464e6, coverage 0.6770, N(cov) 5.621e6, 553 new σ
make verify_data threads=16  # regenerate s1 (seed 1) and check it against data/
make report threads=16       # exact counts + validation + analysis -> results/report.toml
```

`make analyze` prints `new σ list vs new_classes_553.tsv: identical` when the setup is
correct.

## 4. Choice of `threads`

- `threads` sets the Julia threads (`julia -t`). It changes only the speed.
- `streams` sets the RNG scheme. Its default is `threads`. A chunk is a function of
  (samples, seed, streams, n, m). Thus:
  - To reproduce a legacy (8,8) chunk, use 12 streams: `make verify_data threads=16`
    (`verify_data` always uses `verify_streams=12`), or
    `make sample ... threads=16 streams=12`.
  - For new chunks, any value is valid. Use new seeds (from `first_seed=141`) and write
    down `streams`. Chunks with different stream counts can be analyzed together.
- Use the number of physical cores. On a 16-core CPU (for example the Ryzen AI Max of the
  Framework desktop), use `threads=16`. Simultaneous multithreading (32 logical CPUs)
  gives little gain for this integer workload. Leave one or two cores free when you
  use the machine for other work.
- Memory is not a limit on a 64 GB machine. The sampler keeps one chunk of text lines
  (about 2 MB per 100,000 samples).
- Speed: one (8,8) sample takes about 0.04 s on one free core (12,000 samples took 221 s
  on 2 threads). A 100,000-sample chunk thus takes about 4 to 5 minutes on 16 cores,
  and 40 chunks take about 3 hours. A busy machine is slower.

Example of a new run of 1,000,000 samples and its analysis together with the legacy data:

```
make sample first_seed=141 chunks=10 threads=16
make analyze data="data/legacy_chunks.tsv results/chunks"
```
