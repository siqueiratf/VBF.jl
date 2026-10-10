# Public catalog/data API; anything not exported is internal.

# literature S-boxes
export load_literature_sbox, literature_sbox_names, literature_sbox_metadata

# catalog open / build / content addressing
export catalog_path, is_catalog_built, load_catalog, create_catalog
export canonical_lut_bytes, lut_sha256_hex, SCHEMA_VERSION

# queries
export list_functions, count_functions, find_function, load_sbox

# reconciliation
export list_reconciliation_disagreements, count_reconciliation_disagreements
export reconciliation_summary, record_disagreement!, merge_source_repo!
export KNOWN_SOURCES, reconciliation_by_source, functions_by_source
export cross_source_matches, multi_source_functions

# declarative APN catalog
export apn_catalog_names, apn_catalog_metadata, load_apn_function

# artifacts
export artifact_path, have_artifact, list_artifacts

# bibliography
export BibEntry, load_bibliography, parse_bibtex, bibliography_path

# bulk corpora
export list_corpora, corpus_info, corpus_length, corpus_function
export corpus_coefficients, corpus_store_path, materialize_corpus_luts
export build_corpus_store!, register_corpus!

# σ-signature CCZ classification + novelty oracle
export sigma_key, sigma_hash, build_sigma_index!, classify_ccz, is_novel
export ccz_fingerprint_key, ccz_fingerprint_hash, build_ccz_fingerprint_index!
export ccz_fingerprint_index_path, classify_ccz_fingerprint, is_novel_fingerprint
export populate_ccz_equivalence_classes!, sigma_index_path

export AuditedAPNReference, open_apn_reference, close_apn_reference
export reference_metadata, reference_contains_signature, reference_exact_lut_match

export signature_summary, signature_count
