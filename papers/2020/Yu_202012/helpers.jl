# Shared utilities for Yu et al. (2020) paper reproduction
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# VBF API used: primitive_polynomial, terms_to_lut, gf_pow, SBox

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
    has_f2_cyclic_structure(M, n) -> Bool

Check Theorem 2: M[((u+1)%n)+1, ((v+1)%n)+1] == M[u+1,v+1]² in GF(2ⁿ) for all 0≤u,v<n.
True iff the QAM corresponds to a function with F₂ coefficients.
Uses `primitive_polynomial(n)` for the squaring operation.
"""
function has_f2_cyclic_structure(M::Matrix{Int}, n::Int)
    mod = primitive_polynomial(n)
    for u in 0:(n-1), v in 0:(n-1)
        u == v && continue
        expected = gf_pow(M[u+1, v+1], 2, n; modulus = mod)
        actual = M[(u + 1) % n + 1, (v + 1) % n + 1]
        actual == expected || return false
    end
    true
end

