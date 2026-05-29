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
export gauss_jordan!, rank_f2, linear_basis, is_in_span, complete_basis, complete_basis_reversed
export mobius!, mobius, anf
export walsh_hadamard!, walsh_hadamard, walsh_transform
export PRIMITIVE_POLYNOMIALS, primitive_polynomial
export CONWAY_POLYNOMIALS, conway_polynomial
export gf_mul, gf_pow, gf_inv, gf_monomial_lut
export evaluate_polynomial, polynomial_to_lut
export polynomial_terms, terms_to_lut, monomial_power_table
export quadratic_exponents, encode_quadratic, decode_quadratic_lut
export random_function_sbox, random_permutation_sbox
export random_linear_function, random_invertible_linear_map
export random_linear_permutation, random_affine_permutation, random_linear_subspace

# (the data/catalog layer's exports moved to the VBFCatalog package)

# tier 5 — algorithms
export is_invertible, compose, solve_f2, kernel_f2
export extract_linear_subspaces, span_from_basis
export smallest_basis, find_2d_subspaces, expand_subspaces, subspace_count_signature
export identity_affine_map, zero_affine_map
export block_diagonal_affine_map, swap_affine_map
export generating_affine_map, generating_affine_map_r
export affine_map_from_masks, affine_map_from_range_and_image

# tier 6 — equivalence
export are_linear_equivalent
export linear_representative
export linear_equivalences, self_linear_equivalences, self_affine_equivalences
export are_sets_linear_equivalent
export is_3_to_1, triplicate_adjoint, is_equivalent_to_triplicate, triplicate_adjoints
export canonical_triplicate, are_3to1_linear_equivalent, self_3to1_linear_equivalences
export canonical_3to1_representative
export are_affine_equivalent
export affine_representative
export affine_class_signature
export EAPartition, nbuckets
export ea_multiplicities, ea_partition, ea_partition_signature
export enumerate_bucket_maps, outer_permutations, outer_permutations_all
export inner_permutation
export are_ea_equivalent, ea_equivalence_certificate
export ea_equivalences, partition_automorphisms, permutation_order
export FunctionGraph, ccz_equivalent_function
export graph_image_by, graph_xor_equivalence
export ccz_block_decomposition, ea_mapping
export ccz_matrix, ea_matrix
export walsh_zeroes, walsh_zeroes_size
export thickness, thickness_spectrum, enumerate_ccz_class
export TUDecomposition, tu_decomposition_from_space_basis, get_tu_decompositions
export apply_tu, core, twist
export are_ccz_equivalent

# tier 7 — APN-specific invariants
export ortho_derivative, is_quadratic_apn
export ortho_integral
export sigma_multiplicities
export APNEAMugshot, apn_ea_mugshot
export bent_components, nonbent_components, nonbent_signature
export image_set, image_subspaces, pi_multiset
export ccz_equivalent_quadratic_function
export automorphisms_from_ortho_derivative, ea_mappings_from_ortho_derivative
export enumerate_ea_classes_apn_quadratic
export switching_neighbors
export search_quadratic_apn
export trims, apn_trims, trim_spectrum
export extend_quadratic_apn
export quadratic_apn_matrix, is_qam, qam_to_sbox
export qam_cyclic_orbits, qam_from_cyclic, independent_conjugate_elements
export cyclic_qam_subset_representatives, is_cyclic_qam, search_qam

# tier 4 — statistics
export ddt, differential_spectrum, differential_uniformity
export lat, absolute_walsh_spectrum, linearity, walsh_power_moment
export bct, boomerang_spectrum, boomerang_uniformity
export fbct, fbct_spectrum, fbct_uniformity
export algebraic_degree, degree_spectrum
export linear_structures, has_linear_structure
export ddt_coeff_probability, expected_max_distribution
export expected_differential_uniformity_distribution
export lat_coeff_probability, expected_linearity_distribution
export bct_coeff_probability, expected_boomerang_uniformity_distribution
export table_anomaly, table_negative_anomaly

# tier 8 — presentation
export to_markdown, to_latex, table_to_markdown, table_to_latex

# tier 3..5 — populated by later phases
