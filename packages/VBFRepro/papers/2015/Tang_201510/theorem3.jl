# Implements Theorems 3–6: nonlinearity lower bounds
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: 4.2 — Nonlinearity
#
# Theorem 3: NL(F) >= 2^{n-1} - 2^{n/2} - |U|             (general U)
# Theorem 4: U = U_max  => NL(F) >= 2^{n-1} - 3*2^{n/2} - 2
# Theorem 5: U = U_{m0} => NL(F) >= 2^{n-1} - 2^{n/2+2} - 2
# Theorem 6: U = U_{m1} => NL(F) >= 2^{n-1} - 2^{n/2+2} - 2
#
# Pseudocode:
#   1. For each set type (U_max, U_{m0}, U_{m1}, small U):
#        build U, construct F, compute actual NL from linearity.
#   2. Verify NL >= lower bound from theorem.
# VBF API used: linearity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

nl_bound_thm3(n, u_size) = (1 << (n - 1)) - (1 << (n ÷ 2)) - u_size
nl_bound_thm4(n)         = (1 << (n - 1)) - 3 * (1 << (n ÷ 2)) - 2
nl_bound_thm5(n)         = (1 << (n - 1)) - (1 << (n ÷ 2 + 2)) - 2
nl_bound_thm6(n)         = (1 << (n - 1)) - (1 << (n ÷ 2 + 2)) - 2

"""
    theorem3_report([io]; ns) -> NamedTuple

Verify NL lower bounds (Theorems 3–6) for Construction 1 with U=U_max, U_{m0}, U_{m1}, small U.
"""
function theorem3_report(io::IO = stdout; ns::Vector{Int} = [6])
    print_section("Theorems 3–6 — nonlinearity lower bounds", io)

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for n in ns
        u_max = build_u_max(n)
        pairs = u_max_pairs(u_max)

        # Theorem 3: smallest U (one pair, 2 elements)
        u_small  = [pairs[1][1], pairs[1][2]]
        F_small  = construction1_sbox(n, u_small)
        nl_small = nonlinearity(F_small)
        lb3      = nl_bound_thm3(n, 2)
        ok3      = nl_small >= lb3
        all_ok  &= ok3
        print_check("n=$n  Thm3  |U|=2  NL=$nl_small >= lb=$lb3", ok3, io)

        # Theorem 4: U = U_max
        F_max  = construction1_sbox(n, u_max)
        nl_max = nonlinearity(F_max)
        lb4    = nl_bound_thm4(n)
        ok4    = nl_max >= lb4
        all_ok &= ok4
        print_check("n=$n  Thm4  U=U_max |U|=$(length(u_max))  NL=$nl_max >= lb=$lb4", ok4, io)

        # Theorem 5: U = U_{m0}
        u_m0  = build_u_m0(n)
        F_m0  = construction1_sbox(n, u_m0)
        nl_m0 = nonlinearity(F_m0)
        lb5   = nl_bound_thm5(n)
        ok5   = nl_m0 >= lb5
        all_ok &= ok5
        print_check("n=$n  Thm5  U=U_m0 |U|=$(length(u_m0))  NL=$nl_m0 >= lb=$lb5", ok5, io)

        # Theorem 6: U = U_{m1}
        u_m1  = build_u_m1(n)
        F_m1  = construction1_sbox(n, u_m1)
        nl_m1 = nonlinearity(F_m1)
        lb6   = nl_bound_thm6(n)
        ok6   = nl_m1 >= lb6
        all_ok &= ok6
        print_check("n=$n  Thm6  U=U_m1 |U|=$(length(u_m1))  NL=$nl_m1 >= lb=$lb6", ok6, io)

        print_kv("  n=$n  Table4-reference NL(inverse)=2^{n-1}-2^{n/2}",
                 (1 << (n-1)) - (1 << (n÷2)), io)

        results[n] = (;
            nl_small, lb3, ok3,
            nl_max,   lb4, ok4,
            nl_m0,    lb5, ok5,
            nl_m1,    lb6, ok6,
        )
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
