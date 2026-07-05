# Implements Proposition 5.2 — trivially intersecting pair {Y(ξ,μ), Z(ν)}
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 5 — Trivially intersecting pairs of WZ spaces
#
# Pseudocode:
#   n = 3k (k odd), ξ ∈ F_8, μ, ν ∈ F_{2^n}^*:
#     Y = Prop 4.2 space for (ξ, μ)
#     Z = {(ν(b + b^{1/2^i}), ν^{2^i+1}b) : b ∈ F_{2^n}}  (Prop 4.3, m = n)
#   If Tr((ξ + ξ^{2^i})(μν)^{-2^i}) = 0 then {Y, Z} intersects trivially.
#   Remark: for random ξ ∈ F_8\{0,1}, μ, ν the condition holds w.p. ≈ 1/2.
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, gold_apn, walsh_zeroes,
#   subfield_elements, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_2.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))

"Trace condition of Proposition 5.2: Tr((ξ + ξ^{2^i})·(μν)^{-2^i}) = 0."
function proposition5_2_condition(
    xi::Int,
    mu::Int,
    nu::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    lhs = xi ⊻ gf_pow(xi, 1 << i, n; modulus)
    mn_inv = gf_inv(gf_mul(mu, nu, n; modulus), n; modulus)
    gf_trace(gf_mul(lhs, gf_pow(mn_inv, 1 << i, n; modulus), n; modulus), n; modulus) == 0
end

"The Proposition 5.2 pair (Y from Prop 4.2, Z from Prop 4.3 with m = n)."
proposition5_2_pair(xi::Int, mu::Int, nu::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(n)) =
    (proposition4_2_span(xi, mu, n, i; modulus), proposition4_3_span(n, nu, n, i; modulus))

"""
    proposition5_2_build(n, i; modulus, samples, seed) -> NamedTuple

Sample (ξ, μ, ν) with a fixed seed; for every triple satisfying the trace
condition verify both spaces are WZ spaces and intersect trivially. Also
reports the observed fraction of triples satisfying the condition (paper
remark: ≈ 1/2).
"""
function proposition5_2_build(
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
    n_checked = 0
    all_ok = true
    for _ = 1:samples
        xi = rand(rng, xis)
        mu = rand(rng, 1:(1<<n)-1)
        nu = rand(rng, 1:(1<<n)-1)
        proposition5_2_condition(xi, mu, nu, n, i; modulus) || continue
        n_cond += 1
        Y, Z = proposition5_2_pair(xi, mu, nu, n, i; modulus)
        ok =
            is_wz_space_lat(Y, F, tm; zset) &&
            is_wz_space_lat(Z, F, tm; zset) &&
            intersects_trivially(Y, Z)
        all_ok &= ok
        n_checked += 1
    end
    (; n, i, samples, seed, n_cond, n_checked, all_ok, frac = n_cond / samples)
end

function proposition5_2_report(io::IO = stdout; n::Int = 9, i::Int = 1, samples::Int = 200, seed::Int = 42)
    r = proposition5_2_build(n, i; samples, seed)
    print_section("Proposition 5.2 — pair {Y(ξ,μ), Z(ν)} with trace condition, n=$n, i=$i", io)
    print_check(io, "all $(r.n_checked) condition-satisfying pairs: WZ + trivial intersection", r.all_ok)
    print_check(io, "condition frequency ≈ 1/2 (observed $(round(r.frac; digits = 3)))", 0.35 <= r.frac <= 0.65)
    print_kv(io, "seed", r.seed)
    print_kv(io, "completeness", "budget-limited ($(r.samples) sampled triples)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition5_2_report(; n = 3, i = 1)
    proposition5_2_report(; n = 9, i = 1)
end
