"""
Quadratic APN Matrices (QAM) — Yu–Wang–Li (DCC 2014), as used by the QAM search
method of Ivković–Nikova (eprint 2024/1838).

A quadratic homogeneous function `F : F₂ⁿ → F₂ⁿ` (degree 2, `F(0)=0`, no linear or
constant part) is captured by its **derivative matrix** `M` over `GF(2ⁿ)`:
fixing the bit basis `bᵢ = 2^{i-1}` of `F₂ⁿ`,

    M[i, j] = D_{bⱼ}F(bᵢ) = F(bᵢ ⊕ bⱼ) ⊕ F(bᵢ) ⊕ F(bⱼ).

`M` is symmetric with zero diagonal (the second-order derivative / associated
bilinear form). [`quadratic_apn_matrix`](@ref) builds it directly from the lookup
table — no field multiplication needed.

`M` is a **QAM** — equivalently `F` is APN — exactly when, for every nonempty
subset `S ⊆ {1,…,n}` of rows, the `n` field elements `⊕_{j∈S} M[i, j]` (one per
row `i`) have `GF(2)`-rank at least `n-1` ([`is_qam`](@ref)). This is the
matrix characterisation of the APN property for quadratic functions (Yu–Wang–Li),
the test at the heart of the QAM construction method.
"""

"""
    quadratic_apn_matrix(F::SBox{N}) -> Matrix{Int}

The `N×N` derivative matrix (over `GF(2ᴺ)`, entries as integers) of the quadratic
homogeneous function `F` in the bit basis `bᵢ = 2^{i-1}`:
`M[i,j] = F(bᵢ ⊕ bⱼ) ⊕ F(bᵢ) ⊕ F(bⱼ)`. Symmetric with zero diagonal. For a
quadratic homogeneous `F`, [`is_qam`](@ref) of this matrix decides APN-ness.
"""
function quadratic_apn_matrix(F::SBox{N}) where {N}
    M = zeros(Int, N, N)
    @inbounds for i in 1:N
        bi = 1 << (i - 1)
        Fbi = Int(F(bi))
        for j in i + 1:N
            bj = 1 << (j - 1)
            v = Int(F(bi ⊻ bj)) ⊻ Fbi ⊻ Int(F(bj))
            M[i, j] = v
            M[j, i] = v
        end
    end
    M
end

"""
    is_qam(M::AbstractMatrix{<:Integer}) -> Bool

Test whether the symmetric, zero-diagonal `n×n` matrix `M` over `GF(2ⁿ)` is a
Quadratic APN Matrix: for every nonempty subset `S` of its `n` rows, the `n`
field elements `⊕_{j∈S} M[i, j]` (`i = 1,…,n`) must have `GF(2)`-rank `≥ n-1`.
Equivalently, the quadratic function whose derivative matrix is `M` is APN.
"""
function is_qam(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    size(M, 2) == n || throw(ArgumentError("is_qam: matrix must be square"))
    n <= 8 * sizeof(UInt) || throw(ArgumentError("is_qam: n too large"))
    vec = Vector{UInt}(undef, n)
    @inbounds for mask in 1:(1 << n) - 1            # nonempty row subsets
        for i in 1:n
            acc = 0
            s = mask
            while s != 0
                j = trailing_zeros(s) + 1
                acc ⊻= M[i, j]
                s &= s - 1
            end
            vec[i] = UInt(acc)
        end
        rank_f2(vec; nbits = n) < n - 1 && return false
    end
    true
end

"""
    is_qam(F::SBox) -> Bool

Whether the quadratic homogeneous function `F` is APN, via its
[`quadratic_apn_matrix`](@ref) and the QAM test.
"""
is_qam(F::SBox) = is_qam(quadratic_apn_matrix(F))

"""
    qam_to_sbox(M::AbstractMatrix{<:Integer}) -> SBox

Recover the quadratic homogeneous function whose derivative matrix is the
symmetric, zero-diagonal `n×n` matrix `M` over `GF(2ⁿ)`:
`F(x) = ⊕_{i<j, xᵢ=xⱼ=1} M[i,j]` (`xᵢ` the bits of `x`). This is the inverse of
[`quadratic_apn_matrix`](@ref) on the homogeneous representative (`F(bᵢ)=0`), and
`F` is APN iff `M` is a QAM. No field multiplication is needed.
"""
function qam_to_sbox(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    size(M, 2) == n || throw(ArgumentError("qam_to_sbox: matrix must be square"))
    lut = zeros(Int, 1 << n)
    @inbounds for x in 1:(1 << n) - 1
        acc = 0
        for i in 1:n
            ((x >> (i - 1)) & 1) == 1 || continue
            for j in i + 1:n
                ((x >> (j - 1)) & 1) == 1 && (acc ⊻= M[i, j])
            end
        end
        lut[x + 1] = acc
    end
    SBox{n}(lut)
end
