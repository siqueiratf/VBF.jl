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
function count_valid_L_bounded(n::Int; mod::Int = paper_modulus(n),
        max_evaluations::Int = 1 << 20, timeout_seconds::Real = Inf,
        start_index::Int = 0, e0::Int = trace_one_element(n, mod))
    2 <= n <= 6 || throw(ArgumentError("table-driven counter supports 2 <= n <= 6"))
    max_evaluations >= 0 || throw(ArgumentError("max_evaluations must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    gf_trace(e0, n; modulus = mod) == 1 || throw(ArgumentError("e0 must have trace one"))
    N = 1 << n; total = N^(n-1)
    0 <= start_index <= total || throw(ArgumentError("start_index outside enumerated region"))
    T0 = trace_zero_elements(n, mod)
    powers = [gf_pow(e0, 1 << (i-1), n; modulus = mod) for i in 1:n]
    inv_last = gf_inv(last(powers), n; modulus = mod)
    # All field arithmetic and B_F are loop-invariant tables. The inner loop
    # evaluates L and checks injectivity using a 64-bit set of output values.
    contributions = [gf_mul(c, gf_pow(x, 1 << (i-1), n; modulus = mod), n; modulus = mod)
                     for i in 1:n, c in 0:N-1, x in T0]
    dependent = [gf_mul(gf_mul(c, powers[i], n; modulus = mod), inv_last, n; modulus = mod)
                 for i in 1:n-1, c in 0:N-1]
    bilinear = [bilinear_form_gold(x, a ⊻ e0, n, mod) for a in T0, x in T0]
    coeffs = zeros(Int, n); values = zeros(Int, length(T0))
    count = 0; evaluated = 0; t0 = time()
    next_index = start_index
    while next_index < total && evaluated < max_evaluations && time()-t0 < timeout_seconds
        tmp = next_index; last_coefficient = 0
        for i in 1:n-1
            coeffs[i] = tmp % N; tmp ÷= N
            last_coefficient ⊻= dependent[i, coeffs[i]+1]
        end
        coeffs[n] = last_coefficient
        for k in eachindex(T0)
            v = 0
            for i in 1:n; v ⊻= contributions[i, coeffs[i]+1, k]; end
            values[k] = v
        end
        valid = true
        for j in eachindex(T0)
            seen = UInt64(0)
            for k in eachindex(T0)
                bit = UInt64(1) << (values[k] ⊻ bilinear[j,k])
                if seen & bit != 0; valid = false; break; end
                seen |= bit
            end
            valid || break
        end
        count += valid; evaluated += 1; next_index += 1
    end
    (; n, mod, e0, count, evaluated, total, start_index, next_index,
       exhaustive = start_index == 0 && next_index == total,
       interval_exhausted = next_index == total,
       status = next_index == total ? :exhausted : :budget_hit,
       normalization = "L(e0)=0", elapsed_seconds = time()-t0)
end

"""Complete count. n=6 requires an explicit full_search opt-in."""
function count_valid_L(n::Int; mod::Int = paper_modulus(n), verbose::Bool = false,
                       full_search::Bool = false, e0::Int = trace_one_element(n, mod))
    n <= 5 || full_search || throw(ArgumentError("n=$n requires full_search=true, or use count_valid_L_bounded"))
    r = count_valid_L_bounded(n; mod, e0, max_evaluations = typemax(Int))
    r.exhaustive || error("counter did not exhaust its specified region")
    r.count
end

function theorem3_2_report(io::IO = stdout; n::Int = 5, full_search::Bool = false,
        max_evaluations::Int = n <= 5 ? typemax(Int) : 1 << 20,
        timeout_seconds::Real = Inf, mod::Int = paper_modulus(n))
    print_section("Theorem 3.2 + Example 3.3 (n=$n)", io)
    r = count_valid_L_bounded(n; mod, max_evaluations = full_search ? typemax(Int) : max_evaluations,
                            timeout_seconds)
    expected = n == 4 ? 448 : n == 5 ? 4608 : n == 6 ? 40000 : nothing
    print_kv(io, "region", "$(r.total) linearized L with L(e0)=0; modulus=$(r.mod), e0=$(r.e0)")
    print_kv(io, "coverage", "$(r.status): $(r.evaluated)/$(r.total), next_index=$(r.next_index)")
    print_kv(io, "valid mappings in explored interval", r.count)
    if r.exhaustive && n in (4, 5)
        print_check(io, "count matches Example 3.3", r.count == expected)
    elseif n == 6
        print_kv(io, "publication claim", "approximately 40000; this is not an exact published count")
        if r.exhaustive
            print_check(io, "exhaustive count agrees with historical exact count 35648", r.count == 35648)
        else
            print_kv(io, "exact count status", "unresolved by this bounded run; historical value 35648")
        end
    end
    merge(r, (; expected, match = r.exhaustive && n in (4,5) ? r.count == expected : missing,
        historical_count_agreement = r.exhaustive && n == 6 ? r.count == 35648 : missing))
end

if abspath(PROGRAM_FILE) == @__FILE__
    n = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 5
    print_header()
    theorem3_2_report(; n=n)
end
