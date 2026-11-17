# Getting started

This tutorial installs VBF.jl, gets the catalog data and runs a first analysis.
It takes about 15 minutes, most of them for the downloads.

## 1. Install the tools

You need:

- Julia 1.12 or later. Install it with [juliaup](https://julialang.org/install/).
- `git`, `make`, `curl` and `gzip`.
- About 1.5 GB of free disk for the catalog data.

Check the Julia version:

```sh
julia --version
```

## 2. Get the code

```sh
git clone https://github.com/siqueiratf/VBF.jl.git
cd VBF.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

The last command installs the Julia packages of the workspace. The first time,
it takes some minutes.

## 3. Get the catalog data

```sh
make -C docs data
```

The command installs `catalog.sqlite`, `members.sqlite` and
`ccz_sigma_index.sqlite` in `.cache/vbfcatalog/`. It downloads about 490 MB
from Zenodo and checks the SHA-256 of each file. If Zenodo has no data for your
commit, the command builds the data from the original sources (about 45
minutes). See [Prebuilt catalog data](data.md).

## 4. A first analysis

Start Julia in the workspace:

```sh
julia --project=.
```

Then analyse the Gold function ``x^3`` on ``\mathbb{F}_{2^8}``:

```julia
using VBF, VBFCatalog

F = SBox{8}(gf_monomial_lut(8, 3))   # x^3 with the default modulus
differential_uniformity(F)           # 2: the function is APN
algebraic_degree(F)                  # 2: the function is quadratic
linearity(F)                         # 32

db = load_catalog()
list_functions(db; n = 8, is_apn = true)   # the 70 APN functions of the catalog with n = 8
classify_ccz(F)   # (:sigma_match, "functions", 41): same signature as catalog row 41
close(db)
```

## 5. Next steps

- Inspect a function in the browser with the [APN inspector](inspector.md):
  `make -C docs serve-inspector`.
- Run the reproduction of a paper with the [command-line tools](cli.md):
  `bin/vbfrepro list`, then `bin/vbfrepro test 202211-yu-qam`.
- Read one [paper reproduction](reproductions.md) next to its paper.
- Start a [search](generated/search.md) for new quadratic APN functions.
- Look up a function in the [API reference](api/module.md).
