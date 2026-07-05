# Implements Proposition 4.1 — WZ spaces X × S from i-compatible subspaces
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 4 — Constructions of some WZ spaces for Gold APN permutations
#
# Pseudocode:
#   Given an i-compatible additive subspace S of F_{2^n}:
#     X = {x : Tr(a·x) = 0 for all a ∈ S^{-1/(2^i+1)}}
#     Z = X × S is a WZ space of f(x) = x^{2^i+1}  (dim X = n - dim S).
# VBF API used: parity, gold_apn, walsh_zeroes, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition4_1_span(S, n, i; modulus, dual, tm) -> Vector{UInt32}

Field-packed span of the Proposition 4.1 WZ space `X × S`. `S` is a list of
field elements forming an i-compatible additive subspace (0 included).
"""
function proposition4_1_span(
    S::Vector{Int},
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    dual::Vector{Int} = gold_dual_table(n, i; modulus),
    tm::Vector{Int} = trace_mask_table(n; modulus),
)
    masks = [tm[dual[s+1]+1] for s in S]
    X = Int[x for x = 0:(1<<n)-1 if all(m -> parity(m & x) == 0, masks)]
    field_pack_span([(x, s) for s in S for x in X], n)
end

"""
    proposition4_1_build(n, i; modulus) -> NamedTuple

Verify Proposition 4.1 for every S in the paper's catalog of i-compatible
subspaces at (n, i): {0}, all μF_2, subfields F_{2^m} (m|n), and — when
3 | n — all μ-scalings of the 2- and 3-dim subspaces of the F_8-subfield.
Each resulting space is checked against the ACTUAL Walsh zeros of f.
"""
function proposition4_1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    F = gold_apn(n, i; modulus)
    dual = gold_dual_table(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    catalog = icompatible_catalog(n, i; modulus)
    spans = Set{Vector{UInt32}}()
    all_wz = true
    all_dim = true
    for S in catalog
        z = proposition4_1_span(S, n, i; modulus, dual, tm)
        all_dim &= length(z) == 1 << n
        all_wz &= is_wz_space_lat(z, F, tm; zset)
        push!(spans, z)
    end
    trivials_ok =
        proposition4_1_span([0], n, i; modulus, dual, tm) == z_a0_span(n) &&
        proposition4_1_span(collect(0:(1<<n)-1), n, i; modulus, dual, tm) == z_0b_span(n)
    (; n, i, n_catalog = length(catalog), n_distinct = length(spans),
       all_wz, all_dim, trivials_ok, spans)
end

"""
    icompatible_catalog(n, i; modulus) -> Vector{Vector{Int}}

The paper's known i-compatible subspaces (Ex 3.3, Prop 3.4, Cor 3.6 with all
μ-scalings), deduplicated. Per Problem 3.7 no others are known; the 2-dim
case is verified exhaustively in `definition3_2.jl`.
"""
function icompatible_catalog(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    seen = Set{Vector{Int}}()
    push!(seen, [0])
    push!(seen, collect(0:(1<<n)-1))
    # μ-scalings of subfields F_{2^m}, 1 ≤ m < n, m | n  (μF_2 included via m=1)
    for m in filter(m -> n % m == 0 && m < n, 1:n)
        sub = subfield_elements(n, m; modulus)
        for mu = 1:(1<<n)-1
            push!(seen, sort([gf_mul(mu, s, n; modulus) for s in sub]))
        end
    end
    # μ-scalings of the 2-dim subspaces of the F_8-subfield (Cor 3.6)
    if n % 3 == 0
        els = UInt32.(filter(!=(0), subfield_elements(n, 3; modulus)))
        for b in extract_linear_subspaces(els, 2; max_bits = n)
            sp = Int.(span_from_basis(b))
            for mu = 1:(1<<n)-1
                push!(seen, sort([gf_mul(mu, s, n; modulus) for s in sp]))
            end
        end
    end
    collect(seen)
end

function proposition4_1_report(io::IO = stdout; n::Int = 5, i::Int = 1)
    r = proposition4_1_build(n, i)
    print_section("Proposition 4.1 — X × S spaces from i-compatible S, n=$n, i=$i", io)
    print_check(io, "every X × S has 2^$n elements (dim = n)", r.all_dim)
    print_check(io, "every X × S is a WZ space (checked against actual LAT)", r.all_wz)
    print_check(io, "S = {0} gives Z_a0 and S = F_{2^$n} gives Z_0b", r.trivials_ok)
    print_kv(io, "i-compatible subspaces in catalog", r.n_catalog)
    print_kv(io, "distinct WZ spaces produced", r.n_distinct)
    print_kv(io, "completeness", "exhaustive over the paper's i-compatible catalog")
end

if abspath(PROGRAM_FILE) == @__FILE__
    for (n, i) in ((5, 1), (7, 1), (9, 1))
        proposition4_1_report(; n, i)
    end
end
