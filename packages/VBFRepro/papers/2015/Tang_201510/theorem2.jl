# Implements Theorem 2: algebraic degree = n-1 for all even n >= 6
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: 4.1 — Algebraic degree
#
# Theorem 2: For every even n >= 6, F (Construction 1) has algebraic degree n-1.
# This is maximum for bijective (n,n)-functions.
#
# Pseudocode:
#   1. For each n, build U = U_max.
#   2. Compute F via construction1_sbox.
#   3. Check algebraic_degree(F) == n-1.
# VBF API used: algebraic_degree, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem2_report([io]; ns) -> NamedTuple

Verify algebraic degree = n-1 (maximum for bijections) for Construction 1.
"""
function theorem2_report(io::IO = stdout; ns::Vector{Int} = [6, 8])
    print_section("Theorem 2 — algebraic degree = n-1 (maximum for bijections)", io)
    println(io, "  For every even n >= 6, F has algebraic degree n-1")

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for n in ns
        u   = build_u_max(n)
        F   = construction1_sbox(n, u)
        deg = algebraic_degree(F)
        ok  = deg == n - 1
        all_ok &= ok
        print_check("n=$n  algebraic-degree=$deg == n-1=$(n-1)", ok, io)
        results[n] = (; algebraic_degree = deg, expected = n - 1, ok)
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem2_report()
end
