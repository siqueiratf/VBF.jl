# Implements Corollary 24 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.4.2 — Rank Table and Connection with the Differential Spectrum
#
# Corollary 24: A quadratic function F : F₂ⁿ → F₂ⁿ is APN if and only if
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
#     some a≠0 has rank(Jac_lin F(a)) < n-1
# VBF API used: SBox, is_apn

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

For a non-APN quadratic function G, verify some nonzero a has rank < N-1.
"""
function verify_corollary24_non_apn(G::SBox{N,T}) where {N,T}
    target = N - 1
    for a in 1:((1<<N)-1)
        jac_lin_rank(G, a) < target && return true
    end
    return false
end

"""
    corollary24_report(; io, n_values) -> NamedTuple

Verify Corollary 24:
- APN functions have rank n-1 at all nonzero inputs.
- A non-APN quadratic (same input/output) has some rank < n-1.
"""
function corollary24_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section(
        "corollary 24: F APN ⟺ rank(Jac_lin F(a)) = n-1 for all nonzero a",
        io,
    )
    results = Dict{Int,Bool}()
    for N in n_values
        T = N ≤ 8 ? UInt8 : UInt16
        F = gold_apn(N)

        ok_apn = verify_corollary24_apn(F)
        print_check("Gold x^3 n=$N (APN): rank = $(N-1) for all a≠0", ok_apn, io)

        # Build a non-APN quadratic: use the identity function (degree 1, but linear part rank 1)
        # Better: use the linear function x (degree 1, not quadratic at all).
        # Instead, take a quadratic non-APN: add x^3 + x^2 (in the 4-bit sense for concrete check)
        # For a clean demo: if n=5, take the function with DDT max = 4 (diff. unif. 4).
        # We'll just construct a non-APN by modifying the Gold function at one point.
        lut_nonAPN = collect(F.lut)
        # Swap two LUT entries to break APN; do it carefully to keep it quadratic-enough
        # Actually the simplest quadratic non-APN for this check: x^5 on F_2^6 (Kasami diff-unif=2)
        # For n=5, take the function x^5 (power function):
        lut_q = gf_monomial_lut(N, 5)  # x^5: may or may not be APN depending on N
        G = SBox{N,T}(T.(lut_q))

        if differential_uniformity(G) == 2
            # x^5 is APN on n=5 (it's Gold with i=2): verify it also has rank n-1
            ok_non = verify_corollary24_apn(G)
            print_check("x^5 n=$N (also APN): rank = $(N-1) for all a≠0", ok_non, io)
            results[N] = ok_apn && ok_non
        else
            ok_non = verify_corollary24_non_apn(G)
            print_check(
                "x^5 n=$N (non-APN): some a≠0 has rank < $(N-1)",
                ok_non,
                io,
            )
            rdist = rank_distribution(G)
            print_kv("x^5 n=$N rank distribution", sort(collect(rdist)), io)
            results[N] = ok_apn && ok_non
        end
    end
    all_ok = all(values(results))
    print_check("Corollary 24 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    corollary24_report()
end
