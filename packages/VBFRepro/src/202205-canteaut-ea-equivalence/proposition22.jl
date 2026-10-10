# Implements Proposition 22 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.4.2 — Rank Table and Connection with the Differential Spectrum
#
# Proposition 22: For a quadratic F : F₂ⁿ → F₂ᵐ,
#   ℛ_dist(F)[r] = 2^{-r} · 𝒟_dist(F)[2^{n-r}]   for all r = 0,...,min(m,n).
#
# where (Definition 19):
#   𝒟_dist(F)[k] = #{(a,b) ∈ (F₂ⁿ)² : a ≠ 0, δ_F(a,b) = k}
#   ℛ_dist(F)[r] = #{a ∈ F₂ⁿ \ {0} : rank(Jac_lin F(a)) = r}
#
# Remark 23 is also checked: ℛ_dist(F)[n] = 0 for every quadratic F.
#
# Proof sketch: rank(Jac_lin F(a)) = r iff the right kernel has dimension n-r,
# iff the DDT row for a consists only of 0 and 2^{n-r}; each such row has
# exactly 2^r entries equal to 2^{n-r}. Hence: ℛ_dist(F)[r] · 2^r = 𝒟_dist(F)[2^{n-r}].
#
# Pseudocode:
#   1. Compute rank_table(F): rank_table[a+1] = rank(Jac_lin F(a))
#   2. Compute ℛ_dist(F) from rank_table
#   3. Compute DDT of F; aggregate 𝒟_dist(F)
#   4. Verify: ℛ_dist(F)[r] == 𝒟_dist(F)[2^{n-r}] / 2^r for each r
# VBF API used: SBox, ddt, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

"""
    ddt_distribution(F::SBox{N,T}) -> Dict{Int,Int}

𝒟_dist(F)[k] = #{(a,b) : a ≠ 0, δ_F(a,b) = k}. Computed from the full DDT.
"""
function ddt_distribution(F::SBox{N,T}) where {N,T}
    D = ddt(F)
    n_size = 1 << N
    dist = Dict{Int,Int}()
    @inbounds for a in 1:(n_size-1)
        for b in 0:(n_size-1)
            k = D[a+1, b+1]
            dist[k] = get(dist, k, 0) + 1
        end
    end
    return dist
end

"""
    verify_proposition22(F::SBox{N,T}) -> Bool

Check ℛ_dist(F)[r] = 𝒟_dist(F)[2^{n-r}] / 2^r for ALL r in 0..N (not only the
ranks that occur: absent ranks must have 𝒟_dist(F)[2^{n-r}] = 0 too), plus
Remark 23 (ℛ_dist(F)[n] = 0).
"""
function verify_proposition22(F::SBox{N,T}) where {N,T}
    rt = rank_table(F)
    rdist = rank_distribution(rt, N)
    ddist = ddt_distribution(F)
    for r in 0:N
        lhs = get(rdist, r, 0)
        rhs = get(ddist, 1 << (N - r), 0)
        lhs * (1 << r) == rhs || return false
    end
    return get(rdist, N, 0) == 0   # Remark 23
end

"""
    proposition22_report(; io, n_values) -> NamedTuple

Verify Proposition 22 on Gold x^3 (APN: degenerate single-rank distribution)
AND on a deterministic non-APN quadratic whose rank distribution takes several
values — the case that exercises the formula at more than one r simultaneously.
"""
function proposition22_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section(
        "Proposition 22: ℛ_dist(F)[r] = 𝒟_dist(F)[2^{n-r}] / 2^r",
        io,
    )
    results = Bool[]
    for N in n_values
        F = gold_apn(N)
        ok = verify_proposition22(F)
        push!(results, ok)

        rdist = rank_distribution(F)
        print_kv("Gold x^3 n=$N rank distribution", sort(collect(rdist)), io)
        print_check("Gold x^3 n=$N: Prop 22 holds", ok, io)
    end

    # Multi-rank case: non-APN quadratic, several distinct Jac_lin ranks
    Q = pseudo_random_multirank_quadratic(6)
    rdist_q = rank_distribution(Q)
    okq = verify_proposition22(Q) && length(rdist_q) ≥ 2
    push!(results, okq)
    print_kv("multirank quadratic n=6 rank distribution", sort(collect(rdist_q)), io)
    print_check("multirank quadratic n=6: Prop 22 holds at every rank", okq, io)

    all_ok = all(results)
    print_check("Proposition 22 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition22_report()
end
