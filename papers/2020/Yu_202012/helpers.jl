# Shared utilities for Yu et al. (2020) paper reproduction
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# VBF API used: primitive_polynomial, terms_to_lut, gf_pow, gf_trace, rank_f2,
#   quadratic_apn_matrix, linearity, SBox

using VBF

"""
    sbox_from_exponents(n, exps) -> SBox{n}

Build a homogeneous quadratic SBox from exponents of a polynomial with F₂ coefficients:
F(x) = x^e1 ⊕ x^e2 ⊕ … All exponents must have 2-adic weight 2.
Uses `primitive_polynomial(n)` to match `search_qam`/`qam_from_cyclic` internals.
"""
function sbox_from_exponents(n::Int, exps::AbstractVector{Int})
    mod = primitive_polynomial(n)
    terms = [(1, e) for e in exps]
    SBox{n}(terms_to_lut(terms, n, mod))
end

"""
    sbox_from_exponents_with_trace(n, exps, trace_exps) -> SBox{n}

Build `F(x) = ⊕_{e ∈ exps} x^e  ⊕  ⊕_{g ∈ trace_exps} Tr(x^g)`, where `Tr` is the
absolute trace `GF(2ⁿ) → F₂` (its value 0/1 is read as a field element).
Used for the Edel–Pott (2009) reference forms `x³+Tr(x⁹)` and `x⁹+Tr(x³)` that
Table 3 claims its two trinomials are CCZ-equivalent to.
"""
function sbox_from_exponents_with_trace(
    n::Int,
    exps::AbstractVector{Int},
    trace_exps::AbstractVector{Int},
)
    mod = primitive_polynomial(n)
    lut = zeros(Int, 1 << n)
    for x = 0:((1<<n)-1)
        acc = 0
        for e in exps
            acc ⊻= gf_pow(x, e, n; modulus = mod)
        end
        for g in trace_exps
            acc ⊻= gf_trace(gf_pow(x, g, n; modulus = mod), n; modulus = mod)
        end
        lut[x+1] = acc
    end
    SBox{n}(lut)
end

"""
    has_f2_cyclic_structure(M, n) -> Bool

Whether the `n×n` matrix `M` over `GF(2ⁿ)` satisfies the *Frobenius-shift* relation
`M[u+1, v+1] == M[u, v]²` (indices mod `n`) — i.e. shifting both indices by one
squares the entry.

**This is the criterion of Theorem 2 only in a normal basis** `{α₀,…,α_{n-1}}` with
`α_{i+1} = α_i²`, which is the basis the paper pins for `H = Mα^t C_F Mα`. Theorem 2's
"iff" (the relation holds ⟺ the coefficients `c_{i,t}` lie in F₂) is a statement about
that `H`, and **does not transfer to another basis**.

VBF's [`quadratic_apn_matrix`](@ref) works in the **bit basis** `bᵢ = 2^{i-1}` of
`primitive_polynomial(n)`, *not* a normal basis. So on a bit-basis matrix this predicate
is **not** a test for "F has coefficients in F₂" — concretely,
`has_f2_cyclic_structure(quadratic_apn_matrix(x³), n)` is `false` for n = 6,7,8,9 even
though `x³` manifestly has F₂ coefficients (see `theorem2.jl`, which asserts exactly
this). Use [`has_f2_coefficients`](@ref) to test that property of a function.

What this predicate *is* good for: it is the invariant that `qam_from_cyclic(n, 1, ·)`
establishes by construction, so it characterises the matrices the QAM search enumerates.
"""
function has_f2_cyclic_structure(M::Matrix{Int}, n::Int)
    mod = primitive_polynomial(n)
    for u = 0:(n-1), v = 0:(n-1)
        u == v && continue
        expected = gf_pow(M[u+1, v+1], 2, n; modulus = mod)
        actual = M[(u+1)%n+1, (v+1)%n+1]
        actual == expected || return false
    end
    true
end

"""
    has_f2_coefficients(F) -> Bool

Whether the univariate coefficients of `F` all lie in F₂, tested by the Frobenius
criterion `F(x²) = F(x)²` for every `x` (a polynomial over `GF(2ⁿ)` is fixed by the
Frobenius map on its coefficients exactly when those coefficients are in F₂).

This is the property the paper is about, and — unlike
[`has_f2_cyclic_structure`](@ref) applied to a bit-basis matrix — it is
basis-independent.
"""
function has_f2_coefficients(F::SBox{N}) where {N}
    mod = primitive_polynomial(N)
    for x = 0:((1<<N)-1)
        lhs = Int(F(gf_pow(x, 2, N; modulus = mod)))
        rhs = gf_pow(Int(F(x)), 2, N; modulus = mod)
        lhs == rhs || return false
    end
    true
end

"""
    is_almost_bent(F) -> Bool

Whether `F` is AB (almost bent): `linearity(F) == 2^((n+1)/2)`, defined for odd `n`.
The paper's abstract claims the two new n=9 functions s₁, s₂ "are also AB".
"""
function is_almost_bent(F::SBox{N}) where {N}
    isodd(N) || throw(ArgumentError("is_almost_bent: AB is defined for odd n, got n=$N"))
    linearity(F) == 1 << ((N + 1) ÷ 2)
end

"""
    qam_min_row_rank(M) -> Int

The minimum, over all `2ⁿ-1` nonzero F₂-linear combinations `S` of the rows of the
`n×n` matrix `M` over `GF(2ⁿ)`, of the F₂-rank of the `n` field elements
`⊕_{j∈S} M[i,j]` (one per row `i`). This is the quantity Theorem 1 bounds.
"""
function qam_min_row_rank(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    size(M, 2) == n || throw(ArgumentError("qam_min_row_rank: matrix must be square"))
    vec = Vector{UInt}(undef, n)
    best = n
    @inbounds for mask = 1:((1<<n)-1)
        for i = 1:n
            acc = 0
            s = mask
            while s != 0
                acc ⊻= M[i, trailing_zeros(s)+1]
                s &= s - 1
            end
            vec[i] = UInt(acc)
        end
        r = rank_f2(vec; nbits = n)
        r < best && (best = r)
    end
    best
end
