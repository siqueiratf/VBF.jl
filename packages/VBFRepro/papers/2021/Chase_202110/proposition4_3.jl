# Implements Proposition 4.3 — subfield WZ spaces for m | n
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 4 — Constructions of some WZ spaces for Gold APN permutations
#
# Pseudocode:
#   m | n (n odd), μ ∈ F_{2^n}^*:
#     Z = {(μa, μ^{2^i+1}·b) : a ∈ F_{2^n}, b ∈ F_{2^m}, Tr^n_m(a) = b + b^{1/2^i}}
#   is a WZ space of f(x) = x^{2^i+1} (2^{n-m} choices of a per b ⟹ dim n).
# VBF API used: gf_mul, gf_pow, gf_relative_trace, subfield_elements,
#   gold_apn, walsh_zeroes, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition4_3_span(m, mu, n, i; modulus) -> Vector{UInt32}

Field-packed span of the Proposition 4.3 WZ space for subfield degree
`m | n` and `μ ∈ F_{2^n}^*`. `b^{1/2^i}` is computed as `b^{2^{n-i}}`.
"""
function proposition4_3_span(
    m::Int,
    mu::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    e = gold_exp(i)
    mue = gf_pow(mu, e, n; modulus)
    inv_frob = 1 << (n - i)     # b ↦ b^{2^{n-i}} = b^{1/2^i} on F_{2^n}
    bmap = Dict{Int,Vector{Int}}()
    for b in subfield_elements(n, m; modulus)
        t = b ⊻ gf_pow(b, inv_frob, n; modulus)
        push!(get!(bmap, t, Int[]), b)
    end
    pairs = NTuple{2,Int}[]
    for a = 0:(1<<n)-1
        bs = get(bmap, gf_relative_trace(a, n, m; modulus), nothing)
        bs === nothing && continue
        ma = gf_mul(mu, a, n; modulus)
        for b in bs
            push!(pairs, (ma, gf_mul(mue, b, n; modulus)))
        end
    end
    field_pack_span(pairs, n)
end

"""
    proposition4_3_build(n, i; modulus, mu_limit) -> NamedTuple

Verify Proposition 4.3 for all divisors m of n and all μ ∈ F_{2^n}^*
(bounded by `mu_limit` per divisor) against the actual Walsh zeros.
"""
function proposition4_3_build(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    mu_limit::Int = (1 << n) - 1,
)
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    all_wz = true
    all_dim = true
    per_m = Dict{Int,Int}()
    for m in filter(m -> n % m == 0, 1:n)
        spans = Set{Vector{UInt32}}()
        for mu = 1:min(mu_limit, (1 << n) - 1)
            z = proposition4_3_span(m, mu, n, i; modulus)
            all_dim &= length(z) == 1 << n
            all_wz &= is_wz_space_lat(z, F, tm; zset)
            push!(spans, z)
        end
        per_m[m] = length(spans)
    end
    exhaustive = mu_limit >= (1 << n) - 1
    (; n, i, all_wz, all_dim, per_m, exhaustive)
end

function proposition4_3_report(io::IO = stdout; n::Int = 5, i::Int = 1, mu_limit::Int = (1 << n) - 1)
    r = proposition4_3_build(n, i; mu_limit)
    print_section("Proposition 4.3 — subfield WZ spaces, n=$n, i=$i", io)
    print_check(io, "Z(m, μ) is a WZ space for all m | $n, μ tested", r.all_wz)
    print_check(io, "every Z(m, μ) has 2^$n elements (dim = n)", r.all_dim)
    for (m, c) in sort(collect(r.per_m))
        print_kv(io, "distinct spaces for m = $m", c)
    end
    print_kv(
        io,
        "completeness",
        r.exhaustive ? "exhaustive over μ ∈ F_{2^$n}^*" : "budget-limited (μ ≤ $mu_limit)",
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition4_3_report(; n = 5, i = 1)
    proposition4_3_report(; n = 7, i = 1)
    proposition4_3_report(; n = 9, i = 1)
end
