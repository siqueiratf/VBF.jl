# Catalog importers

Run these scripts in this directory's Julia environment. They are not loaded by
`using VBFCatalog`. The [package guide](../../README.md) describes the build.

`sources.toml` in `../data/` is the single registry for originals, adapters and
corpora. `fetch.jl` and `load_sources.jl` use the same source pins and checksums;
`readers.jl` parses heterogeneous raw formats without executing upstream code.
`write.jl` computes VBF properties and writes normalized function records once.

```sh
make catalog                # build .cache/vbfcatalog/catalog.sqlite from inputs
make check                  # declaration agreement and package tests
make reproducible           # two complete builds; require identical bytes
make fetch SOURCE=beierle2025
make convert SOURCE=beierle2025  # install large external members explicitly
make index threads=30       # generate signatures for installed data
```

Downloaded originals and generated stores stay outside the package, under
`.cache/vbfcatalog/`. The catalog build registers external descriptors without
requiring their downloads. Installing external data verifies the original
checksum, APN properties, member count and packed coefficient digest.

VBFSearch publication freezes coefficient inputs under `../data/luts/` and adds
checksums, counts and provenance to `../data/sources.toml`. Rebuilds use those
inputs without reopening a search run or an old catalog. Full reference rebuilds
and corpus classification belong to [VBFSearch tools](../../../VBFSearch/tools/README.md).
