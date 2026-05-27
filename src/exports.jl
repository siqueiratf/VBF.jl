# Explicit export list. Anything callable from a paper notebook lives here;
# anything not exported is internal and may break between versions.
# Aqua.test_undefined_exports verifies every name below resolves.

# tier 1 — types
export SBox, inputbits, storage_type, is_permutation
export F2LinearMap, identity_linear_map, zero_linear_map
export F2AffineMap, is_linear
export Spectrum, add!, sorted_pairs, total_mass

# tier 2 — F₂ⁿ primitives
export parity, f2_dot
export gauss_jordan!, rank_f2, linear_basis, is_in_span, complete_basis
export mobius!, mobius, anf
export walsh_hadamard!, walsh_hadamard, walsh_transform
export PRIMITIVE_POLYNOMIALS, primitive_polynomial
export CONWAY_POLYNOMIALS, conway_polynomial
export gf_mul, gf_pow, gf_inv, gf_monomial_lut

# tier 3 — data
export load_literature_sbox, literature_sbox_names, literature_sbox_metadata
export catalog_path, is_catalog_built, load_catalog, create_catalog
export canonical_lut_bytes, lut_sha256_hex, SCHEMA_VERSION
export list_functions, count_functions, find_function, load_sbox
export list_reconciliation_disagreements, count_reconciliation_disagreements
export reconciliation_summary, record_disagreement!, merge_source_repo!
export KNOWN_SOURCES, reconciliation_by_source, functions_by_source
export cross_source_matches, multi_source_functions
export apn_catalog_names, apn_catalog_metadata, load_apn_function
export artifact_path, have_artifact, list_artifacts
export BibEntry, load_bibliography, parse_bibtex, bibliography_path

# tier 5 — algorithms
export is_invertible, compose, solve_f2, kernel_f2

# tier 6 — equivalence
export are_linear_equivalent
export linear_representative
export are_affine_equivalent
export affine_representative
export affine_class_signature
export EAPartition, nbuckets
export ea_multiplicities, ea_partition, ea_partition_signature

# tier 4 — statistics
export ddt, differential_spectrum, differential_uniformity
export lat, absolute_walsh_spectrum, linearity
export bct, boomerang_spectrum, boomerang_uniformity
export fbct, fbct_spectrum, fbct_uniformity
export algebraic_degree, degree_spectrum
export linear_structures, has_linear_structure
export ddt_coeff_probability, expected_max_distribution
export expected_differential_uniformity_distribution
export lat_coeff_probability, expected_linearity_distribution
export bct_coeff_probability, expected_boomerang_uniformity_distribution
export table_anomaly, table_negative_anomaly

# tier 3..5 — populated by later phases
