"""
    VBFCatalog

The curated catalog and data layer for [`VBF`](https://github.com/). Provides:

  - an on-disk SQLite catalog (`BFA_catalog.sqlite`) of literature S-boxes,
    declarative APN functions, and imported quadratic-APN CCZ-class
    representatives — content-addressed by LUT SHA-256, with full provenance;
  - query helpers (`list_functions`, `find_function`, `load_sbox`, …);
  - multi-source reconciliation against the upstream APN corpora;
  - a BibTeX-backed bibliography and content-addressed artifact scaffolding.

Depends on `VBF` for the S-box type and the statistics used to characterise
each row; `VBF` never depends on this package. Dev-time importers that
(re)build the catalog from the upstream checkouts live under `data-build/`.
"""
module VBFCatalog

using VBF

# Data layer; each file imports the storage deps it needs.
include("data/literature.jl")
include("data/catalog.jl")
include("data/queries.jl")
include("data/reconciliation.jl")
include("data/apn_catalog.jl")
include("data/artifacts.jl")
include("data/bibliography.jl")
include("data/corpus.jl")
include("data/sigma.jl")
include("data/ccz_fingerprint.jl")

include("exports.jl")

end # module VBFCatalog
