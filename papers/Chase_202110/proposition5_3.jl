# Implements Proposition 5.3 — trivially intersecting pair {Y(ν), X × S}
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 5 — Trivially intersecting pairs of WZ spaces
#
# Pseudocode:
#   n = 3k (k odd), ξ a primitive element of F_8, μ, ν ∈ F_{2^n}^*:
#     Y = {(ν(b + b^{1/2^i}), ν^{2^i+1}b) : b ∈ F_{2^n}}   (Prop 4.3, m = n)
#     Z = X × S from Prop 4.1 with S = span{μ, ξμ}          (i-compatible by
#         Cor 3.6 + Ex 3.3(ii))
#   If Tr((ξ + ξ^{2^i})·μ^{2^i/(2^i+1)}·ν^{-2^i}) = 1 then {Y, Z} intersects
#   trivially.
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, gold_apn, walsh_zeroes,
#   subfield_elements, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_1.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))

"Trace condition of Proposition 5.3: Tr((ξ+ξ^{2^i})·μ^{2^i/(2^i+1)}·ν^{-2^i}) = 1."
function proposition5_3_condition(
    xi::Int,
    mu::Int,
    nu::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    lhs = xi ⊻ gf_pow(xi, 1 << i, n; modulus)
    mu_exp = gf_pow(mu, mod((1 << i) * inv_gold_exp(n, i), (1 << n) - 1), n; modulus)
    nu_exp = gf_pow(gf_inv(nu, n; modulus), 1 << i, n; modulus)
    t = gf_mul(gf_mul(lhs, mu_exp, n; modulus), nu_exp, n; modulus)
    gf_trace(t, n; modulus) == 1
end

"The Proposition 5.3 pair (Y from Prop 4.3 m = n, Z = X × span{μ, ξμ})."
function proposition5_3_pair(
    xi::Int,
    mu::Int,
    nu::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    Y = proposition4_3_span(n, nu, n, i; modulus)
    xim = gf_mul(xi, mu, n; modulus)
    S = sort([0, mu, xim, mu ⊻ xim])
    Z = proposition4_1_span(S, n, i; modulus)
    (Y, Z)
end

"""
    proposition5_3_build(n, i; modulus, samples, seed) -> NamedTuple

Sample (ξ, μ, ν) with ξ primitive in F_8; for every triple satisfying the
trace condition verify both spaces are WZ spaces and intersect trivially.
"""
function proposition5_3_build(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    samples::Int = 200,
    seed::Int = 42,
)
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    xis = filter(x -> x != 0 && x != 1, subfield_elements(n, 3; modulus))
    rng = MersenneTwister(seed)
    n_cond = 0
    all_ok = true
    for _ = 1:samples
        xi = rand(rng, xis)
        mu = rand(rng, 1:(1<<n)-1)
        nu = rand(rng, 1:(1<<n)-1)
        proposition5_3_condition(xi, mu, nu, n, i; modulus) || continue
        n_cond += 1
        Y, Z = proposition5_3_pair(xi, mu, nu, n, i; modulus)
        all_ok &=
            is_wz_space_lat(Y, F, tm; zset) &&
            is_wz_space_lat(Z, F, tm; zset) &&
            intersects_trivially(Y, Z)
    end
    (; n, i, samples, seed, n_cond, all_ok, frac = n_cond / samples)
end

function proposition5_3_report(io::IO = stdout; n::Int = 9, i::Int = 1, samples::Int = 200, seed::Int = 42)
    r = proposition5_3_build(n, i; samples, seed)
    print_section("Proposition 5.3 — pair {Y(ν), X × span{μ, ξμ}}, n=$n, i=$i", io)
    print_check(io, "all $(r.n_cond) condition-satisfying pairs: WZ + trivial intersection", r.all_ok)
    print_check(io, "condition frequency ≈ 1/2 (observed $(round(r.frac; digits = 3)))", 0.35 <= r.frac <= 0.65)
    print_kv(io, "seed", r.seed)
    print_kv(io, "completeness", "budget-limited ($(r.samples) sampled triples)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition5_3_report(; n = 3, i = 1)
    proposition5_3_report(; n = 9, i = 1)
end
