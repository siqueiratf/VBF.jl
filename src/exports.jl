# Explicit export list. Anything callable from a paper notebook lives here;
# anything not exported is internal and may break between versions.
# Aqua.test_undefined_exports verifies every name below resolves.

# tier 1 — types
export SBox, inputbits, storage_type
export F2LinearMap, identity_linear_map, zero_linear_map
export F2AffineMap, is_linear
export Spectrum, add!, sorted_pairs, total_mass

# tier 2 — F₂ⁿ primitives
# (populated as primitives are added)

# tier 3..5 — populated by later phases
