# Implements Proposition 5.1 — trivially intersecting pair {Z_0b, Z(ξ, μ)}
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 5 — Trivially intersecting pairs of WZ spaces
#
# Pseudocode:
#   n = 3k (k odd), ξ ∈ F_8, μ ∈ F_{2^n}^*:
#     Z = {(x, μ^{-(2^i+1)}(ξTr(μx) + Tr(ξ^{2^i}μx)))}  (Prop 4.2 space)
#     {Z_0b, Z} intersects trivially (x = 0 forces the second component to 0).
# VBF API used: gold_apn, walsh_zeroes, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_2.jl"))

"""
    proposition5_1_pair(xi, mu, n, i; modulus) -> (Y, Z)

The Proposition 5.1 pair: `Y = Z_0b` and `Z` the Proposition 4.2 space.
"""
proposition5_1_pair(xi::Int, mu::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(n)) =
    (z_0b_span(n), proposition4_2_span(xi, mu, n, i; modulus))

"""
    proposition5_1_build(n, i; modulus, mu_limit) -> NamedTuple

Verify for all ξ ∈ F_8 \\ {0,1} and μ (bounded by `mu_limit`): both spaces
are WZ spaces (actual LAT) and the intersection is trivial.
"""
function proposition5_1_build(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    mu_limit::Int = (1 << n) - 1,
)
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    xis = filter(x -> x != 0 && x != 1, subfield_elements(n, 3; modulus))
    n_pairs = 0
    all_ok = true
    for xi in xis, mu = 1:min(mu_limit, (1 << n) - 1)
        Y, Z = proposition5_1_pair(xi, mu, n, i; modulus)
        all_ok &=
            is_wz_space_lat(Y, F, tm; zset) &&
            is_wz_space_lat(Z, F, tm; zset) &&
            intersects_trivially(Y, Z)
        n_pairs += 1
    end
    (; n, i, n_pairs, all_ok, exhaustive = mu_limit >= (1 << n) - 1)
end

function proposition5_1_report(io::IO = stdout; n::Int = 9, i::Int = 1, mu_limit::Int = (1 << n) - 1)
    r = proposition5_1_build(n, i; mu_limit)
    print_section("Proposition 5.1 — pair {Z_0b, Z(ξ, μ)}, n=$n, i=$i", io)
    print_check(io, "all $(r.n_pairs) pairs: WZ spaces + trivial intersection", r.all_ok)
    print_kv(
        io,
        "completeness",
        r.exhaustive ? "exhaustive over (F_8 \\ {0,1}) × F_{2^$n}^*" :
        "budget-limited (μ ≤ $mu_limit)",
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition5_1_report(; n = 3, i = 1)
    proposition5_1_report(; n = 9, i = 1)
end
