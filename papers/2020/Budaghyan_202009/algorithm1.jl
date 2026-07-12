# Implements Algorithm 1 (Section IV.A — Filtering Out Shift Candidates)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.A — The Case of Fixed u₁,...,uₖ: Filtering Out Shift Candidates
#
# Pseudocode (Algorithm 1):
#   For each i in [K]:
#     D_i ← F₂ⁿ
#     A ← {D_a^{u_i}F(x) ⊕ F(u_i) : a≠0, a⊕u_i∉U, x∉U∪(a+U)}
#     D_i ← D_i \ A
#   If G is APN then v_i ∈ D_i for every i.
# VBF API used: SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    algorithm1_filter(F, U) -> Vector{Int}

Algorithm 1: for each i ∈ [K], compute the domain D_i ⊆ F₂ⁿ of allowed shift values.
Returns the sizes |D_i| (one per point in U).
Also returns the forbidden sets A_i.
"""
function algorithm1_filter(F::SBox{N,T}, U::AbstractVector{<:Integer}) where {N,T}
    n = 1 << N
    lut = F.lut
    U = collect(Int, U)
    K = length(U)
    U_set = Set(U)

    domain_sizes = Int[]
    forbidden_sets = [Set{Int}() for _ = 1:K]

    for (i, ui) in enumerate(U)
        Fi_ui = Int(lut[ui+1])  # F(u_i)
        forbidden = forbidden_sets[i]

        for a = 1:(n-1)
            a ⊻ ui ∈ U_set && continue  # require a+u_i ∉ U
            Fab = Int(lut[(a ⊻ ui)+1])  # F(a ⊕ u_i) for shifted derivative
            aU = Set(u ⊻ a for u in U)

            for x = 0:(n-1)
                (x ∈ U_set || x ∈ aU) && continue  # x ∉ U ∪ (a+U)
                # D_a^{u_i}F(x) = F(x) ⊕ F(x⊕a) ⊕ F(a⊕u_i)
                val = Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1]) ⊻ Fab
                # forbidden value for v_i: D_a^{u_i}F(x) ⊕ F(u_i)
                push!(forbidden, val ⊻ Fi_ui)
            end
        end

        push!(domain_sizes, n - length(forbidden))
    end
    domain_sizes, forbidden_sets
end

"""
    algorithm1_report(; io, n, K, seed) -> NamedTuple

Demonstrate Algorithm 1 filtering on Gold x^3 for various n and K.
Shows |D_i| vs 2^n and verifies that APN shifts lie in the allowed domain.
"""
function algorithm1_report(; io::IO = stdout, n::Int = 6, K::Int = 1, seed::Int = 7)
    F = gold_x3(n)
    sz = 1 << n

    # pick K random distinct points
    rng_state = [seed]
    rng = () -> begin
        rng_state[1] = (rng_state[1] * 1664525 + 1013904223) & 0xFFFFFFFF
        rng_state[1]
    end
    points = Int[]
    while length(points) < K
        x = Int(rng() % sz)
        x ∉ points && push!(points, x)
    end

    print_section("Algorithm 1 — Filtering shift domains (n=$n, K=$K)", io)
    print_kv("F", "Gold x^3 over F₂^$n", io)
    print_kv("U (0-based)", points, io)

    domain_sizes, forbidden_sets = algorithm1_filter(F, points)
    for (i, (dsz, fset)) in enumerate(zip(domain_sizes, forbidden_sets))
        print_kv("  |D_$i|", "$dsz / $sz ($(sz - dsz) values filtered)", io)
    end

    # Verify: for an actual APN G (switching neighbor or trivial), v_i ∈ D_i
    # Use v_i = 1 and check whether G is APN; if so, v ∈ D_i must hold
    test_shift = 1
    G = apply_modifications(F, points, fill(test_shift, K))
    g_is_apn = differential_uniformity(G) == 2
    if g_is_apn
        all_in_domain = all(test_shift ∉ forbidden_sets[i] for i = 1:K)
        print_check("v=$test_shift ∈ D_i for all i (G is APN)", all_in_domain, io)
    else
        print_kv("  v=$test_shift gives non-APN G", "skipping domain membership check", io)
    end

    all_ok = all(d < sz for d in domain_sizes)
    print_check("filtering reduces domain (|D_i| < $sz for all i)", all_ok, io)
    (; all_ok, n, K, domain_sizes, sz)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
