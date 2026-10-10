# Implements Proposition 4.2 — graph-type WZ spaces for n = 3k, k odd
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 4 — Constructions of some WZ spaces for Gold APN permutations
#
# Pseudocode:
#   n = 3k (k odd), ξ ∈ F_8 ⊂ F_{2^n}, μ ∈ F_{2^n}^*:
#     Z = {(x, μ^{-(2^i+1)}·(ξ·Tr(μx) + Tr(ξ^{2^i}·μx))) : x ∈ F_{2^n}}
#   is a WZ space of f(x) = x^{2^i+1}. For ξ ∈ {0, 1}, Z = Z_a0.
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, subfield_elements,
#   gold_apn, walsh_zeroes, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition4_2_span(xi, mu, n, i; modulus) -> Vector{UInt32}

Field-packed span of the Proposition 4.2 WZ space for parameters
`ξ ∈ F_8 ⊂ F_{2^n}` and `μ ∈ F_{2^n}^*`.
"""
function proposition4_2_span(
    xi::Int,
    mu::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    e = gold_exp(i)
    mu_inv_e = gf_pow(gf_inv(mu, n; modulus), e, n; modulus)
    xi2i = gf_pow(xi, 1 << i, n; modulus)
    pairs = Vector{NTuple{2,Int}}(undef, 1 << n)
    for x = 0:(1<<n)-1
        mx = gf_mul(mu, x, n; modulus)
        t1 = gf_trace(mx, n; modulus)
        t2 = gf_trace(gf_mul(xi2i, mx, n; modulus), n; modulus)
        v = (t1 == 1 ? xi : 0) ⊻ t2
        pairs[x+1] = (x, gf_mul(mu_inv_e, v, n; modulus))
    end
    field_pack_span(pairs, n)
end

"""
    proposition4_2_build(n, i; modulus) -> NamedTuple

Verify Proposition 4.2 for ALL (ξ, μ) ∈ F_8 × F_{2^n}^* against the actual
Walsh zeros, and that ξ ∈ {0, 1} degenerates to Z_a0.
"""
function proposition4_2_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    (n % 3 == 0 && isodd(n ÷ 3)) || throw(ArgumentError("need n = 3k, k odd"))
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    f8 = subfield_elements(n, 3; modulus)
    za0 = z_a0_span(n)
    all_wz = true
    trivial_ok = true
    spans = Set{Vector{UInt32}}()
    for xi in f8, mu = 1:(1<<n)-1
        z = proposition4_2_span(xi, mu, n, i; modulus)
        all_wz &= is_wz_space_lat(z, F, tm; zset)
        if xi == 0 || xi == 1
            trivial_ok &= z == za0
        else
            push!(spans, z)
        end
    end
    (; n, i, all_wz, trivial_ok, n_distinct_nontrivial = length(spans), spans)
end

function proposition4_2_report(io::IO = stdout; n::Int = 9, i::Int = 1)
    r = proposition4_2_build(n, i)
    print_section("Proposition 4.2 — graph-type WZ spaces, n=$n=3k, i=$i", io)
    print_check(io, "Z(ξ, μ) is a WZ space for all ξ ∈ F_8, μ ∈ F_{2^$n}^*", r.all_wz)
    print_check(io, "ξ ∈ {0, 1} degenerates to Z_a0", r.trivial_ok)
    print_kv(io, "distinct nontrivial spaces (ξ ∉ {0,1})", r.n_distinct_nontrivial)
    print_kv(io, "completeness", "exhaustive over F_8 × F_{2^$n}^*")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition4_2_report(; n = 3, i = 1)
    proposition4_2_report(; n = 9, i = 1)
    proposition4_2_report(; n = 9, i = 2)
end
