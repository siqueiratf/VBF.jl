# Implements Construction 1 and Theorem 1
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: 3 — New differentially 4-uniform bijections
#
# Construction 1: For even n >= 6, U subset F_{2^n} with:
#   a) for any x in U, x+1 in U
#   b) for any x in U, tr1n(x^{-1}) = 1
#   F(x) = (x+1)^{-1} if x in U, x^{-1} otherwise  (0^{-1} = 0)
#
# Theorem 1: F is differentially 4-uniform (bijection with delta_F = 4).
#
# Pseudocode:
#   1. Build U = U_max (maximal valid set) via build_u_max.
#   2. Compute F via construction1_sbox.
#   3. Verify is_permutation(F) = true.
#   4. Verify differential_uniformity(F) = 4.
# VBF API used: is_permutation, differential_uniformity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    construction1_report([io]; ns) -> NamedTuple

Verify bijection and Theorem 1 (diff-4-uniform) for Construction 1 with U = U_max.
"""
function construction1_report(io::IO = stdout; ns::Vector{Int} = [6, 8])
    print_section("Construction 1 + Theorem 1 — differentially 4-uniform bijection", io)
    println(io, "  F(x) = (x+1)^{-1} if x in U, x^{-1} otherwise  (0^{-1}=0)")

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for n in ns
        u = build_u_max(n)
        F = construction1_sbox(n, u)
        perm  = is_permutation(F)
        du    = differential_uniformity(F)
        ok_p  = perm
        ok_du = du == 4
        ok    = ok_p && ok_du
        all_ok &= ok
        print_check("n=$n  |U_max|=$(length(u))  bijection", ok_p, io)
        print_check("n=$n  |U_max|=$(length(u))  diff-uniformity=4", ok_du, io)
        print_kv("  algebraic-degree", algebraic_degree(F), io)
        results[n] = (; u_size = length(u), is_permutation = perm,
                        differential_uniformity = du, ok)
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    construction1_report()
end
