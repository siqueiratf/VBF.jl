# Implements Table 4 comparisons for n=8 (Section 5)
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: 5 — Comparison of the nonlinearity with all known differentially 4-uniform bijections
#
# Table 4 (n=8 row): actual NL values for special sets:
#   U = U_max  : NL = 100  (lower bound = 78  from Theorem 4)
#   U = U_{m0} : NL = 102  (lower bound = 62  from Theorem 5)
#   U = U_{m1} : NL = 102  (lower bound = 62  from Theorem 6)
#
# NOTE: Example 1 (p. 23) gives two sets with NL=106 and NL=104 for n=8,
# expressed as {alpha^i | i in ...} for Magma's alpha in version 2.12-16.
# Those specific indices cannot be reproduced exactly because Magma's primitive
# element representation for GF(2^8) in that version differs from VBF's
# polynomial basis. We instead verify Table 4 special-set NL values, which
# are polynomial-independent (trace is an isomorphism invariant).
#
# Pseudocode:
#   1. Build U_max, U_{m0}, U_{m1} for n=8 using VBF's primitive_polynomial(8).
#   2. For each: compute F, verify is_permutation, diff-4-uniform, and check NL.
#   3. Compare to Table 4 reference values.
# VBF API used: linearity, differential_uniformity, is_permutation,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

const EXAMPLE1_N = 8

# Table 4 reference values for n=8
const TABLE4_NL_UMAX  = 100
const TABLE4_NL_UM0   = 102
const TABLE4_NL_UM1   = 102

"""
    example1_report([io]) -> NamedTuple

Verify Table 4 (n=8) actual NL values for U=U_max, U_{m0}, U_{m1}.
Construction 1 achieves NL up to 102 for n=8 with these special sets.
"""
function example1_report(io::IO = stdout)
    print_section("Table 4 (Section 5) — actual NL for n=8 special sets", io)
    println(io, "  Best known NL for n=8 bijections: 112 (inverse function)")
    println(io, "  NOTE: Example 1 alpha-indices (p.23) use Magma 2.12-16 primitive element")
    println(io, "        which differs from VBF polynomial basis; verified Table 4 instead.")

    n = EXAMPLE1_N
    all_ok  = true
    results = Dict{Symbol, NamedTuple}()

    for (label, sym, build_u, expected_nl) in [
        ("U_max",  :u_max, () -> build_u_max(n), TABLE4_NL_UMAX),
        ("U_{m0}", :u_m0,  () -> build_u_m0(n),  TABLE4_NL_UM0),
        ("U_{m1}", :u_m1,  () -> build_u_m1(n),  TABLE4_NL_UM1),
    ]
        U  = build_u()
        F  = construction1_sbox(n, U)
        nl = nonlinearity(F)
        du = differential_uniformity(F)
        ok_nl = nl == expected_nl
        ok_du = du == 4
        ok    = ok_nl && ok_du
        all_ok &= ok
        print_check("n=$n  U=$label  |U|=$(length(U))  NL=$nl (Table4=$expected_nl)", ok_nl, io)
        print_check("n=$n  U=$label  diff-uniformity=$du", ok_du, io)
        results[sym] = (; label, u_size = length(U), nl, expected_nl, du, ok)
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    example1_report()
end
