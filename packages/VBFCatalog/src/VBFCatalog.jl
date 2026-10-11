"""
    VBFCatalog

The curated catalog and data layer for [`VBF`](https://github.com/). Provides:

  - an on-disk SQLite catalog (`src/data/catalog.sqlite`) of literature S-boxes,
    declarative APN functions, and imported quadratic-APN CCZ-class
    representatives — content-addressed by LUT SHA-256, with full provenance;
  - query helpers (`list_functions`, `find_function`, `load_sbox`, …);
  - pinned heterogeneous inputs and reconstructible compact corpora;
  - a BibTeX-backed bibliography for source provenance.

Depends on `VBF` for the S-box type and the statistics used to characterise
each row; `VBF` never depends on this package. Dev-time importers that
(re)build the catalog from the upstream checkouts live under `src/import/`.
"""
module VBFCatalog

using VBF

# Data layer; each file imports the storage deps it needs.
include("storage/literature.jl")
include("storage/catalog.jl")
include("storage/queries.jl")
include("storage/apn_catalog.jl")
include("storage/bibliography.jl")
include("storage/corpus.jl")
include("storage/records.jl")
include("storage/equivalence.jl")
include("storage/sigma.jl")
include("storage/summary.jl")
include("storage/classification.jl")
include("storage/reference.jl")

include("exports.jl")

end # module VBFCatalog
