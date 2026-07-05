# Implements Proposition 2.2 — trivially intersecting WZ pair ⟹ permutation
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 2 — Preliminaries
#
# Pseudocode:
#   Given WZ spaces S, T of f with S ∩ T = {(0,0)} and bases B1, B2:
#     1. G' has rows Tr(a_i·x + b_i·f(x)) — B1 rows form G'_1, B2 rows G'_2.
#     2. Both row spaces are simplex codes ⟹ columns of G' read as (x', g(x'))
#        with g a permutation.
#     3. rowspace(G') = rowspace(G) ⟹ g is CCZ-equivalent to f.
#   Implemented in helpers.jl as `wz_pair_to_permutation` on top of VBF's
#   `ccz_equivalent_function`.
# VBF API used: gold_apn, is_permutation, differential_uniformity,
#   are_ccz_equivalent, algebraic_degree, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))

"""
    proposition2_2_build(n, i; modulus, mus, check_ccz) -> NamedTuple

Exercise Proposition 2.2 on f(x) = x^{2^i+1}:
  * the trivial pair {Z_a0, Z_0b} (recovers a linear transform of f), and
  * the pairs {Z_a0, Z(m=n, μ)} from Proposition 4.3 — trivially
    intersecting: an element of Z(m=n, μ) lying in Z_a0 has second
    component μ^{2^i+1}·b = 0, which forces b = 0 and hence the
    element (0, 0).
For every pair the result must be an APN permutation; with `check_ccz` the
CCZ equivalence to f is confirmed by `are_ccz_equivalent` (n = 5 default).
"""
function proposition2_2_build(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    mus::Vector{Int} = [1, 2, 3],
    check_ccz::Bool = n <= 5,
)
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    za0 = z_a0_span(n)
    z0b = z_0b_span(n)
    results = NamedTuple[]
    pairs = Any[("{Z_a0, Z_0b}", za0, z0b)]
    for mu in mus
        push!(pairs, ("{Z_a0, Prop4.3(m=$n, μ=$mu)}", za0, proposition4_3_span(n, mu, n, i; modulus)))
    end
    for (label, S, T) in pairs
        trivially = intersects_trivially(S, T)
        g = wz_pair_to_permutation(F, S, T; tm)
        push!(
            results,
            (;
                label,
                trivially,
                perm = is_permutation(g),
                apn = differential_uniformity(g) == 2,
                degree = algebraic_degree(g),
                ccz = check_ccz ? are_ccz_equivalent(F, g) : missing,
            ),
        )
    end
    (; n, i, results, check_ccz)
end

function proposition2_2_report(io::IO = stdout; n::Int = 5, i::Int = 1)
    r = proposition2_2_build(n, i)
    print_section("Proposition 2.2 — WZ pair ⟹ CCZ-equivalent permutation, n=$n, i=$i", io)
    for res in r.results
        ok =
            res.trivially &&
            res.perm &&
            res.apn &&
            (res.ccz === missing || res.ccz === true)
        print_check(io, "$(res.label): APN permutation, degree $(res.degree)", ok)
    end
    print_kv(
        io,
        "CCZ equivalence to f",
        r.check_ccz ? "verified with are_ccz_equivalent" :
        "exact by construction (rowspace equality); invariants checked",
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition2_2_report(; n = 5, i = 1)
    proposition2_2_report(; n = 7, i = 1)
end
