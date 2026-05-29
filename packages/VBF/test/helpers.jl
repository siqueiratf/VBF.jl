using VBF
using Random

# Random S-box / F₂-map generators used to live here; they now ship in
# `src/random_objects.jl` and are exported by BFA
# (`random_function_sbox`, `random_permutation_sbox`,
# `random_invertible_linear_map`, …). This file is kept as the shared
# test prelude.
