"""
    VBFCatalog

The curated catalog and data layer for [`VBF`](https://github.com/). Provides:

  - a generated SQLite catalog (`.cache/vbfcatalog/catalog.sqlite`) of literature S-boxes,
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

include("catalog.jl")
include("sources.jl")
include("bibliography.jl")
include("build.jl")
include("corpus.jl")
include("records.jl")
include("sigma.jl")

# Public catalog/data API; anything not exported is internal.

# literature S-boxes
export load_literature_sbox, literature_sbox_names, literature_sbox_metadata

# catalog open / build / content addressing
export catalog_path, catalog_source_dir, is_catalog_built, load_catalog, create_catalog
export canonical_lut_bytes, lut_sha256_hex, SCHEMA_VERSION
export finalize_catalog!

# queries
export list_functions, count_functions, find_function, load_sbox

# declarative APN catalog
export apn_catalog_names, apn_catalog_metadata, load_apn_function

# bibliography
export BibEntry, load_bibliography, parse_bibtex, bibliography_path

# bulk corpora
export list_corpora, corpus_info, corpus_length, corpus_function
export corpus_coefficients, corpus_store_path, materialize_corpus_luts
export build_corpus_store!, register_corpus!
export catalog_data_dir, with_corpus_rows, corpus_digest

# σ-signature CCZ classification + novelty oracle
export sigma_key, sigma_hash, build_sigma_index!, classify_ccz, is_novel
export sigma_index_path
export refresh_curated_sigma_index!

export signature_summary, signature_count
export candidate_lut, each_candidate
export import_lut_corpus!
export write_corpus_input

end # module VBFCatalog
