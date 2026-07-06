# Implements Corollary 24 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.4.2 — Rank Table and Connection with the Differential Spectrum
#
# Corollary 24: A quadratic function F : F₂ⁿ → F₂ᵐ is APN if and only if
#   rank(Jac_lin F(a)) = n - 1 for all nonzero a ∈ F₂ⁿ.
#
# Proof: F APN ⟺ δ_F(a,b) ∈ {0,2} for all a ≠ 0, b ∈ F₂ⁿ.
# By Proposition 22: ℛ_dist(F)[r] = 𝒟_dist(F)[2^{n-r}] / 2^r.
# APN ⟹ 𝒟_dist(F)[2] = #{a≠0} · 2^{n-1} nonzero entries, 𝒟_dist(F)[k]=0 for k≠0,2.
# The only nonzero rank is r = n-1 (since 2^{n-r} = 2 ⟹ r = n-1). QED.
#
# Pseudocode:
#   For APN function:
#     all a≠0: rank(Jac_lin F(a)) == n-1
#   For non-APN quadratic:
#     some a≠0 has rank(Jac_lin F(a)) ≠ n-1
# VBF API used: SBox, differential_uniformity, gold_apn, gf_monomial_lut

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_corollary24_apn(F::SBox{N,T}) -> Bool

For an APN function F, verify rank(Jac_lin F(a)) = N-1 for all nonzero a.
"""
function verify_corollary24_apn(F::SBox{N,T}) where {N,T}
    target = N - 1
    for a in 1:((1<<N)-1)
        jac_lin_rank(F, a) == target || return false
    end
    return true
end

"""
    verify_corollary24_non_apn(G::SBox{N,T}) -> Bool

For a non-APN quadratic function G, verify some nonzero a has rank ≠ N-1.
"""
function verify_corollary24_non_apn(G::SBox{N,T}) where {N,T}
    target = N - 1
    for a in 1:((1<<N)-1)
        jac_lin_rank(G, a) != target && return true
    end
    return false
end

"""
    corollary24_report(; io, n_values) -> NamedTuple

Verify Corollary 24:
- APN functions have rank n-1 at all nonzero inputs (Gold x^3, x^5 on odd n).
- Non-APN quadratics (x^5 on n=6; a multirank quadratic) violate it.
"""
function corollary24_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section(
        "Corollary 24: F APN ⟺ rank(Jac_lin F(a)) = n-1 for all nonzero a",
        io,
    )
    results = Bool[]
    for N in n_values
        F = gold_apn(N)

        ok_apn = verify_corollary24_apn(F)
        push!(results, ok_apn)
        print_check("Gold x^3 n=$N (APN): rank = $(N-1) for all a≠0", ok_apn, io)

        # x^5 = Gold k=2: APN iff gcd(2, N) = 1
        T = storage_type(F)
        G = SBox{N,T}(T.(gf_monomial_lut(N, 5)))
        if differential_uniformity(G) == 2
            ok = verify_corollary24_apn(G)
            print_check("x^5 n=$N (also APN): rank = $(N-1) for all a≠0", ok, io)
        else
            ok = verify_corollary24_non_apn(G)
            print_check("x^5 n=$N (non-APN): some a≠0 has rank ≠ $(N-1)", ok, io)
            print_kv("x^5 n=$N rank distribution", sort(collect(rank_distribution(G))), io)
        end
        push!(results, ok)
    end

    # Multirank non-APN quadratic: both directions of the iff at once
    Q = pseudo_random_multirank_quadratic(6)
    okq = differential_uniformity(Q) > 2 && verify_corollary24_non_apn(Q)
    push!(results, okq)
    print_check("multirank quadratic n=6 (non-APN): rank ≠ n-1 somewhere", okq, io)

    all_ok = all(results)
    print_check("Corollary 24 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    corollary24_report()
end
