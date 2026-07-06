# Implements Proposition 3 + Remark 1
# Paper: Yu, Wang, Li (2013), "Constructing Differentially 4 Uniform
#        Permutations from Known Ones"
# Section: III — Proposition 3: I_{(0,v)} formula and δ characterization
#
# Pseudocode:
#   1. For each v ∈ F*_{2^n}, build I_{(0,v)} by swapping I(0) and I(v)
#   2. Verify formula: I_{(0,v)}(x) = (x+v)^{-1} + v·(x²+vx)^{-1}
#   3. Check δ(I_{(0,v)}) = 6 iff m even (n=2m)
#   4. Remark 1: nonlinearity checks
# VBF API used: gf_mul, gf_inv, gf_pow, SBox, differential_uniformity, nonlinearity

include(joinpath(@__DIR__, "helpers.jl"))

"""
Evaluate I_{(0,v)}(x) = (x+v)^{-1} + v·(x²+vx)^{-1} via Eq.(6).
Uses convention 0^{-1} = 0.
"""
function i0v_formula(x::Int, v::Int, n::Int, mod::Int)
    xpv = x ⊻ v
    term1 = xpv == 0 ? 0 : gf_inv(xpv, n; modulus=mod)

    x2 = gf_mul(x, x, n; modulus=mod)
    vx = gf_mul(v, x, n; modulus=mod)
    denom = x2 ⊻ vx  # x² + vx
    if denom == 0
        term2 = 0
    else
        term2 = gf_mul(v, gf_inv(denom, n; modulus=mod), n; modulus=mod)
    end
    term1 ⊻ term2
end

function proposition3_report(io::IO = stdout)
    print_section("Proposition 3: I_{(0,v)} characterization + Remark 1", io)

    for m in [2, 3, 4]
        n = 2 * m
        N = 1 << n
        mod = primitive_polynomial(n)

        println(io, "\n  --- m=$m, n=$n ---")

        # Check formula matches swap for all v ∈ F*
        formula_ok = true
        all_du = Int[]

        for v in 1:N-1
            # Build via swap
            G_swap = inverse_swap(0, v, n; modulus=mod)

            # Build via formula
            lut_formula = Vector{Int}(undef, N)
            for x in 0:N-1
                lut_formula[x+1] = i0v_formula(x, v, n, mod)
            end

            if G_swap.lut != lut_formula
                formula_ok = false
            end

            du = differential_uniformity(G_swap)
            push!(all_du, du)
        end

        print_check(io, "Eq.(6) formula matches swap (all v)", formula_ok)

        du_set = sort(unique(all_du))
        print_kv(io, "δ values seen", du_set)

        m_even = (m % 2 == 0)
        if m_even
            expected_max = 6
            all_6 = all(d -> d == 6, all_du)
            print_check(io, "δ=6 for all v (m=$m even)", all_6)
        else
            max_du = maximum(all_du)
            print_check(io, "δ ≤ 4 for all v (m=$m odd)", max_du <= 4)
        end

        # Remark 1: nonlinearity (sample one v)
        v1 = 1
        G = inverse_swap(0, v1, n; modulus=mod)
        nl = nonlinearity(G)
        I_nl = nonlinearity(SBox(inverse_function_lut(n; modulus=mod)))

        if m == 4
            print_kv(io, "nl(I_{(0,1)}) [m=4]", nl)
            print_check(io, "nl = 112 (Remark 1, m=4)", nl == 112)
        elseif m == 3
            print_kv(io, "nl(I_{(0,1)}) [m=3]", nl)
            print_check(io, "nl = 24 (Remark 1, m=3)", nl == 24)
        end
        print_kv(io, "nl(I) [inverse]", I_nl)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition3_report()
end
