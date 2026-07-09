# Implements Proposition 25 (Section 3.4.3, Table 2) from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.4.3 — On the Rank of the Linear System (6)
#
# Proposition 25: For quadratic F, G and v, w with
#   rank Jac_lin G(v) = rank Jac_lin F(w) = r  (n = m here),
# the homogeneous system (8)  X·Jac_lin G(v) − Jac_lin F(w)·Y = 0
# has m²+n² unknowns, mn equations and rank ≤ r(m+n−r); the affine system (6)
# (adding Y·v = w) has (m+1)n equations and rank ≤ r(m+n−r) + (n−r).
#
# Table 2 (experimental): for s = 1 the bounds are always reached (sharp);
# for concatenated systems (s = 2, 3, Eq. (7)) the rank is at most the sum
# (10) Σᵢ (rᵢ(m+n−rᵢ) + (n−rᵢ)) and generally smaller.
#
# Pseudocode:
#   1. Draw deterministic pseudo-random quadratics F; set G = A₀∘F∘B₀ + C₀ + a
#      (EA-equivalent) and G' an independent quadratic (mirrors the paper's
#      protocol of testing both equivalent and inequivalent pairs).
#   2. For pairs (v,w) with matching Jac_lin ranks r: build system (6)/(8),
#      compute GF(2) ranks, compare to the bounds; record sharpness.
#   3. For s ∈ {2,3}: build concatenated systems (7); verify rank ≤ (10).
# VBF API used: SBox, F2LinearMap (via helpers/algorithm1 system builder)

include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "section3_2.jl"))   # _demo_maps

"""
    _system_ranks(F::SBox{N,T}, G::SBox{N,T}, pairs) -> (rank8, rank_full)

GF(2) ranks of the concatenated homogeneous part (8) (the s·n² matrix
equations only) and of the full affine system (6)/(7) (including Y·vᵢ = wᵢ),
for guess pairs `pairs = [(wᵢ, vᵢ), ...]`.
"""
function _system_ranks(
    F::SBox{N,T},
    G::SBox{N,T},
    pairs::Vector{Tuple{Int,Int}},
) where {N,T}
    n2 = N * N
    s = length(pairs)
    n_unknowns = 2 * n2
    W = nwords_for_bits(n_unknowns + 1)
    n_rows = s * (n2 + N)

    work = Matrix{UInt64}(undef, W, n_rows)
    _build_combined_system!(work, F, G, pairs)
    # Copy out the homogeneous rows (first n² rows of each s-block).
    hom = zeros(UInt64, W, s * n2)
    for b in 0:(s-1), r in 1:n2
        src = b * (n2 + N) + r
        dst = b * n2 + r
        for w in 1:W
            hom[w, dst] = work[w, src]
        end
    end

    full = solve_augmented_gf2!(work, n_rows, n_unknowns)
    rank_full = full === nothing ? -1 : full.rank
    if full === nothing
        # Rank of an inconsistent affine system: rank of coefficient matrix.
        work2 = Matrix{UInt64}(undef, W, n_rows)
        _build_combined_system!(work2, F, G, pairs)
        # Clear the RHS bit so the solve cannot fail.
        rhs_wi = (n_unknowns >>> 6) + 1
        rhs_bit = UInt64(1) << (n_unknowns & 63)
        for i in 1:n_rows
            work2[rhs_wi, i] &= ~rhs_bit
        end
        rank_full = solve_augmented_gf2!(work2, n_rows, n_unknowns).rank
    end

    rank8 = solve_augmented_gf2!(hom, s * n2, n_unknowns).rank
    return (rank8, rank_full)
end

"""
    proposition25_report(; io, n_values, max_pairs_per_r) -> NamedTuple

Verify Proposition 25 and the Table 2 observations for n = m ∈ n_values.
The paper reports tests for m, n ∈ {6, 8}.
"""
function proposition25_report(;
    io::IO = stdout,
    n_values::Vector{Int} = [6, 8],
    max_pairs_per_r::Int = 40,
)
    print_section("Proposition 25 (Table 2): rank bounds of systems (6)/(8)", io)
    results = Bool[]

    for N in n_values
        m = n = N
        nmax = (1 << N) - 1

        F = pseudo_random_multirank_quadratic(N)
        T = storage_type(F)
        A0, B0 = _demo_maps(N, T)
        C0_cols = T[T(1) << (N-1-j) for j in 0:(N-1)]
        C0 = F2LinearMap{N,T}(C0_cols)
        G = build_ea_triple(F, A0, B0, C0, T(3))
        G2 = pseudo_random_quadratic(N; seed = 0xDEADBEEFCAFEF00D)

        rt_F = rank_table(F)

        for (label, GG) in (("EA-equiv n=$N", G), ("independent n=$N", G2))
            rt_G = rank_table(GG)
            bound_ok = true
            sharp8 = Dict{Int,Int}()
            sharp6 = Dict{Int,Int}()
            tested = Dict{Int,Int}()
            for r in sort(collect(keys(rank_distribution(rt_F, N))))
                ws = [a for a in 1:nmax if rt_F[a+1] == r]
                vs = [a for a in 1:nmax if rt_G[a+1] == r]
                isempty(vs) && continue
                cnt = 0
                for w in ws, v in vs
                    cnt ≥ max_pairs_per_r && break
                    cnt += 1
                    rank8, rank6 = _system_ranks(F, GG, [(w, v)])
                    b8 = r * (m + n - r)
                    b6 = b8 + (n - r)
                    if rank8 > b8 || rank6 > b6
                        bound_ok = false
                    end
                    tested[r] = get(tested, r, 0) + 1
                    rank8 == b8 && (sharp8[r] = get(sharp8, r, 0) + 1)
                    rank6 == b6 && (sharp6[r] = get(sharp6, r, 0) + 1)
                end
            end
            push!(results, bound_ok)
            print_check("$label: s=1 ranks ≤ r(m+n−r) and ≤ r(m+n−r)+(n−r)", bound_ok, io)
            sharp_all = sharp8 == tested && sharp6 == tested
            push!(results, sharp_all)
            print_check("$label: s=1 bounds reached for every tested (v,w) (Table 2)", sharp_all, io)
            print_kv("$label: pairs tested per rank", sort(collect(tested)), io)
        end

        # s = 2, 3 concatenated systems: rank ≤ Σᵢ (rᵢ(m+n−rᵢ) + (n−rᵢ))  (Eq. (10))
        rt_G = rank_table(G)
        for s in (2, 3)
            ok = true
            below = 0
            trials = 0
            ws = [a for a in 1:nmax]
            for start in 1:12
                pairs = Tuple{Int,Int}[]
                bound = 0
                k = start
                while length(pairs) < s
                    w = ws[mod1(7k + start, nmax)]
                    r = rt_F[w+1]
                    vs = [a for a in 1:nmax if rt_G[a+1] == r]
                    isempty(vs) && (k += 1; continue)
                    v = vs[mod1(3k + start, length(vs))]
                    push!(pairs, (w, v))
                    bound += r * (m + n - r) + (n - r)
                    k += 1
                end
                bound = min(bound, 2 * N * N)
                _, rank_full = _system_ranks(F, G, pairs)
                trials += 1
                rank_full ≤ bound || (ok = false)
                rank_full < bound && (below += 1)
            end
            push!(results, ok)
            print_check("n=$N s=$s: concatenated rank ≤ bound (10) [$below/$trials strictly below]", ok, io)
        end
    end

    all_ok = all(results)
    print_check("Proposition 25 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition25_report()
end
