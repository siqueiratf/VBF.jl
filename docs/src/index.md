# VBF: vectorial Boolean function analysis

VBF is a Julia workspace for analysing vectorial Boolean functions, with a focus
on APN (almost perfect nonlinear) functions and the linear / affine / EA / CCZ
equivalence hierarchy. It reimplements, in native Julia, the algorithmic content
of the sboxU cryptanalysis stack and several satellite projects, with no runtime
or build dependency on any of them.

The source lives at [github.com/zambonin/VBF.jl](https://github.com/zambonin/VBF.jl).

## Packages

- **VBF** — the algorithms (pure; its only dependency is `Random`):
  representations, F2 linear algebra, spectra, EA/CCZ invariants, the equivalence
  predicates, and the construction/search routines.
- **VBFCatalog** — the data layer (uses VBF): the curated SQLite catalog,
  multi-source reconciliation, the bibliography, data importers, and bulk corpora.

## Quick start

Requires Julia ≥ 1.12. From the repository root:

```julia
using Pkg
Pkg.activate("packages/VBF")
Pkg.instantiate()

using VBF          # the algorithms
using VBFCatalog   # the algorithms plus the catalog
```

## API reference

The pages under **API reference** in the sidebar are generated from the source
docstrings, one page per concept directory of `packages/VBF/src`:
representations, linear algebra, spectra, invariants, the equivalence hierarchy,
constructions, random objects, and rendering — plus the VBFCatalog data layer.
Each entry carries its underlying mathematics and references.
