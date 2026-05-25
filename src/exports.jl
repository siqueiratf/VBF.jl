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

# tier 3 — data
export load_literature_sbox, literature_sbox_names, literature_sbox_metadata

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

# tier 3..5 — populated by later phases
