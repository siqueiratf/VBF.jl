# Implements Proposition 2 and Observation 1 (Section III)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: III — Changing Points in General
#
# Pseudocode (Proposition 2):
#   For each a ≠ 0:
#     Compute U_a = {i : u_i ⊕ a ∈ U} with pairing p_a(i): u_i⊕a = u_{p_a(i)}
#     Ū_a = [K] \ U_a
#     Check condition (i): D_aF 2-to-1 on F₂ⁿ \ (U ∪ a+U)
#     Check conditions (ii-vi): derivative collision conditions on shifts V
#   Returns true iff G is APN (equivalent to direct APN check)
# VBF API used: SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    check_apn_conditions(F, U, V) -> Bool

Proposition 2: G (defined by shifting F at U by V) is APN iff all six conditions
hold for every derivative direction a ≠ 0.
U and V are Julia 1-based vectors of 0-based field elements.
"""
function check_apn_conditions(
    F::SBox{N,T},
    U::AbstractVector{<:Integer},
    V::AbstractVector{<:Integer},
) where {N,T}
    n = 1 << N
    lut = F.lut
    K = length(U)
    K == length(V) || throw(ArgumentError("U and V must have the same length"))
    U = collect(Int, U)
    V = collect(Int, V)
    U_set = Set(U)

    dF = (x, a) -> Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1])

    for a = 1:(n-1)
        aU = Set(u ⊻ a for u in U)
        excluded = union(U_set, aU)

        # U_a and p_a
        U_idx = Dict(u => i for (i, u) in enumerate(U))
        Ua = Int[]    # 1-based Julia indices
        pmap = Dict{Int,Int}()
        for (i, u) in enumerate(U)
            au = u ⊻ a
            if au ∈ U_set
                push!(Ua, i)
                pmap[i] = U_idx[au]
            end
        end
        Ua_set = Set(Ua)
        Uba = [i for i = 1:K if i ∉ Ua_set]

        # condition (i): D_aF ≤ 2-to-1 on F₂ⁿ \ excluded
        counts = Dict{Int,Int}()
        for x = 0:(n-1)
            x ∈ excluded && continue
            b = dF(x, a)
            c = get(counts, b, 0) + 1
            counts[b] = c
            c > 2 && return false
        end

        # condition (ii): i, j ∈ Ua, i ≠ j, u_i ⊕ u_j ≠ a
        for i in Ua, j in Ua
            i == j && continue
            U[i] ⊻ U[j] == a && continue
            rhs = V[i] ⊻ V[j] ⊻ V[pmap[i]] ⊻ V[pmap[j]]
            dF(U[i], a) ⊻ dF(U[j], a) == rhs && return false
        end

        # condition (iii): i ∈ Ua, j ∈ Ūa
        for i in Ua, j in Uba
            rhs = V[i] ⊻ V[j] ⊻ V[pmap[i]]
            dF(U[i], a) ⊻ dF(U[j], a) == rhs && return false
        end

        # condition (iv): i, j ∈ Ūa, i ≠ j
        for i in Uba, j in Uba
            i == j && continue
            rhs = V[i] ⊻ V[j]
            dF(U[i], a) ⊻ dF(U[j], a) == rhs && return false
        end

        # condition (v): i ∈ Ua, x ∉ excluded
        for i in Ua
            target = V[i] ⊻ V[pmap[i]]
            dFui = dF(U[i], a)
            for x = 0:(n-1)
                x ∈ excluded && continue
                dFui ⊻ dF(x, a) == target && return false
            end
        end

        # condition (vi): i ∈ Ūa, x ∉ excluded
        for i in Uba
            target = V[i]
            dFui = dF(U[i], a)
            for x = 0:(n-1)
                x ∈ excluded && continue
                dFui ⊻ dF(x, a) == target && return false
            end
        end
    end
    return true
end

"""
    proposition2_random_check(; n, K, ntrials, seed) -> NamedTuple

Verify Proposition 2 by comparing check_apn_conditions against direct APN check
on `ntrials` random (U, V) pairs of size K, using Gold x^3 over F₂ⁿ.
"""
function proposition2_random_check(;
    io::IO = stdout,
    n::Int = 5,
    K::Int = 1,
    ntrials::Int = 50,
    seed::Int = 42,
)
    F = gold_x3(n)
    sz = 1 << n
    rng = let s = seed
        function rng_next()
            s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
            s
        end
        rng_next
    end

    mismatches = 0
    for _ = 1:ntrials
        # random distinct K points from {0..sz-1}
        points = Int[]
        while length(points) < K
            x = Int(rng() % sz)
            x ∉ points && push!(points, x)
        end
        # random nonzero shifts
        shifts = [Int((rng() % (sz - 1)) + 1) for _ = 1:K]

        G = apply_modifications(F, points, shifts)
        cond = check_apn_conditions(F, points, shifts)
        direct = differential_uniformity(G) == 2
        cond != direct && (mismatches += 1)
    end
    all_ok = mismatches == 0
    print_section("Proposition 2 — APN conditions (n=$n, K=$K, $ntrials trials)", io)
    print_kv("mismatches (cond ≠ direct APN check)", mismatches, io)
    print_check("check_apn_conditions ↔ direct APN check ($ntrials trials)", all_ok, io)
    (; all_ok, mismatches, n, K, ntrials)
end

function proposition2_report(; io::IO = stdout)
    print_header(io)
    r1 = proposition2_random_check(; io, n = 5, K = 1, ntrials = 50)
    r2 = proposition2_random_check(; io, n = 5, K = 2, ntrials = 30)
    return (; r1, r2)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition2_report()
end
