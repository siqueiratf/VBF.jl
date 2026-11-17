# Prebuilt catalog data

The catalog of VBFCatalog is a set of SQLite files that the repository builds
from pinned original sources. The full build takes about 45 minutes and
downloads 3.16 GB. To skip it, download the prebuilt files of your commit from
Zenodo:

```sh
make -C docs data
```

| File | Content | Size |
|:---|:---|:---|
| `catalog.sqlite` | the curated APN functions, S-boxes, corpora and bibliography | 10 MB |
| `members.sqlite` | the 3,775,599 quadratic APN functions of Beierle et al. (2025) | 262 MB |
| `ccz_sigma_index.sqlite` | the ortho-derivative signature index of the quadratic APN functions | 682 MB |

The download is about 490 MB (gzip). The files go to `.cache/vbfcatalog/`;
set `BFA_DATA_DIR` to use another directory.

## Which version you get

Each Zenodo version is the data of one *prebuilt key*: a SHA-256 of the catalog
declarations, the code of `packages/VBFCatalog/src/` and its `Project.toml`.
Print the key of your checkout:

```sh
julia --project=packages/VBFCatalog/src/import packages/VBFCatalog/src/import/prebuilt.jl key
```

`make -C docs data` installs the version with the same key, after it checks the
SHA-256 of each file. Each version has a `manifest.toml` with the commit, the key
and the checksums. If Zenodo has no version for your key, for example after a
local change of the catalog, the command builds the data from the originals.
Use `make -C docs data prebuilt=0` to always build.

After each merge to `main` that changes the key, CI publishes a new version of
the record named in `packages/VBFCatalog/src/import/prebuilt.toml`. The first
version is [doi:10.5281/zenodo.24297662](https://doi.org/10.5281/zenodo.24297662).

## Use the data in your own research

```julia
using VBFCatalog
db = load_catalog()
list_corpora(db)                                  # the bulk corpora
corpus_function(db, "beierle2025_n8", 1)          # first member of the Beierle et al. corpus
close(db)
```

The data of Beierle et al. (2025) come from
[doi:10.5281/zenodo.16752428](https://doi.org/10.5281/zenodo.16752428)
under CC-BY-4.0. Cite the original sources of the corpora that you use; the
`bibliography` table of the catalog lists them.
