# Task 4: automorphism group size and CCZ-equivalence to a permutation for one function.
# Usage: julia --project=/home/ts/VBF.jl aut_perm.jl COEFFS [aut|perm]
# Run under `timeout 120` per call (see run_aut_perm.sh); prints one TSV result line.
using VBF, Printf
include(joinpath(@__DIR__, "profiles_lib.jl")); using .Profiles
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK
cs = ARGS[1]; what = ARGS[2]
F = SBox{8}(UInt8.(QK.lut(coeff_matrix(cs), 8)))
# warm-up on a tiny instance so that compile time is not counted
G = gold_apn(4, 1)
what == "aut" ? automorphisms_from_ortho_derivative(G) : is_ccz_equivalent_to_permutation(G)
if what == "aut"
    t = @elapsed a = automorphisms_from_ortho_derivative(F)
    @printf("%s\taut\t|Stab|=%d\t|Aut|=2^8*|Stab|=%d\t%.2f s\n", cs, length(a), 256 * length(a), t)
else
    t = @elapsed p = is_ccz_equivalent_to_permutation(F)
    @printf("%s\tperm\t%s\t\t%.2f s\n", cs, p, t)
end
