# Implements Theorem 3.2 + Example 3.3
# Paper: Taniguchi et al. (2025), "Changing APN functions on affine subspaces
#        of small codimensions"
# Section: 3.1 — A characterization for the quadratic case and H-equivalence
#
# Pseudocode:
#   1. Fix F(x) = x^3 (Gold APN), choose e₀ with Tr(e₀) = 1
#   2. For each linearized polynomial L with L(e₀) = 0:
#      a. For each a ∈ T₀, check L_a(x) = L(x) + B_F(x, a+e₀) injective on T₀
#      b. If all injective → L is valid (G(x) = F(x) + Tr(x)L(x) is APN)
#   3. Count valid L mappings
# VBF API used: gf_mul, gf_pow, gf_trace, gold_apn, SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
Check Theorem 3.2 condition: for all a ∈ T₀, the map
L_a: T₀ → GF(2^n), x ↦ L(x) + B_F(x, a + e₀) is injective.
Returns true if G(x) = F(x) + Tr(x)L(x) is APN (by Thm 3.2).
"""
function theorem3_2_check(L_coeffs::Vector{Int}, n::Int, mod::Int,
                          T0::Vector{Int}, e0::Int)
    for a in T0
        ae0 = a ⊻ e0
        seen = Set{Int}()
        for x in T0
            Lx = linearized_poly_eval(L_coeffs, x, n, mod)
            Bx = bilinear_form_gold(x, ae0, n, mod)
            val = Lx ⊻ Bx
            val in seen && return false
            push!(seen, val)
        end
    end
    true
end

"""
Enumerate all linearized polynomials L on GF(2^n) with L(e₀) = 0 that satisfy
Theorem 3.2 (making G(x) = x^3 + Tr(x)L(x) APN). Returns count of valid L.
"""
function count_valid_L(n::Int; mod::Int = paper_modulus(n), verbose::Bool = false)
    e0 = trace_one_element(n, mod)
    T0 = trace_zero_elements(n, mod)
    N = 1 << n

    # Enumerate all linearized polynomials: L(x) = Σᵢ aᵢ x^{2^i}, aᵢ ∈ GF(2^n)
    # Constraint: L(e₀) = 0
    # There are N^n total linearized polys, N^(n-1) with L(e₀) = 0
    # For n=4: 16^3 = 4096 candidates; n=5: 32^4 = 1048576; n=6: too many (64^5 ≈ 10^9)

    count = 0

    if n <= 5
        # Exhaustive enumeration
        # Parameterize: coeffs = [a₀, a₁, ..., a_{n-1}]
        # Constraint: L(e₀) = Σᵢ aᵢ · e₀^{2^i} = 0
        # Compute e₀^{2^i} values
        e0_powers = Vector{Int}(undef, n)
        xi = e0
        for i in 1:n
            e0_powers[i] = xi
            xi = gf_mul(xi, xi, n; modulus=mod)
        end

        # Fix a_{n-1} as dependent: a_{n-1} = (Σᵢ₌₀^{n-2} aᵢ · e₀^{2^i}) / e₀^{2^{n-1}}
        # (division in GF(2^n))
        e0_last_inv = gf_inv(e0_powers[n], n; modulus=mod)

        coeffs = zeros(Int, n)
        total_candidates = N^(n-1)

        for idx in 0:total_candidates-1
            # Decode idx into coeffs[1..n-1]
            tmp = idx
            partial_sum = 0
            for i in 1:n-1
                coeffs[i] = tmp % N
                tmp ÷= N
                partial_sum ⊻= gf_mul(coeffs[i], e0_powers[i], n; modulus=mod)
            end
            coeffs[n] = gf_mul(partial_sum, e0_last_inv, n; modulus=mod)

            if theorem3_2_check(coeffs, n, mod, T0, e0)
                count += 1
            end
        end
    else
        verbose && println("  n=$n: exhaustive search infeasible, skipping count")
        return -1
    end

    count
end

function theorem3_2_report(io::IO = stdout; n::Int = 5)
    mod = paper_modulus(n)
    print_section("Theorem 3.2 + Example 3.3 (n=$n)", io)

    if n <= 5
        cnt = count_valid_L(n; mod=mod, verbose=true)
        expected = n == 4 ? 448 : n == 5 ? 4608 : -1
        print_kv(io, "Valid L mappings found", cnt)
        if expected > 0
            print_check(io, "count matches paper (expected $expected)", cnt == expected)
        end
        return (; n, count=cnt, expected, match=(cnt == expected))
    else
        println(io, "  n=$n: exhaustive count infeasible (N^(n-1) = $(big(1<<n)^(n-1)))")
        println(io, "  Paper claims ~40000 valid L for n=6")
        return (; n, count=-1, expected=40000, match=false)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    n = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 5
    print_header()
    theorem3_2_report(; n=n)
end
