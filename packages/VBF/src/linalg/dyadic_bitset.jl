"""
F₂ⁿ-indexed bitsets with fast *dyadic translation* (`{x ⊕ s : x ∈ B}`).

This module is the bitset substrate used by the Stennes linear-representative
algorithm (`equivalence/linear/canonical_representative.jl`), which spends most of its time
maintaining "the set of inputs whose image under the partially-built linear
map is known" and pushing those forward through `S` and `S⁻¹`. The single
non-trivial primitive is the XOR-translation: for an unknown linear map `A`
with `A[x₀]` just set, every previously-known `A[i]` extends to `A[i ⊕ x₀] =
A[i] ⊕ A[x₀]`, so the *domain* of `A` doubles in a structured way — its new
half is the dyadic translate by `x₀`.

A bitset is `Vector{UInt64}` of `ceil(nbits/64)` chunks (at least 1). Chunk
`i` (1-based) holds bits `64(i-1) .. 64i-1` of the indicator. `nbits` is
always a power of 2 in practice (S-box length).

Functions are prefixed `_db_` — they're internal to VBF.
"""

const _DBSet = Vector{UInt64}

@inline _db_nchunks(nbits::Int) = max(1, cld(nbits, 64))

@inline function _db_empty(nbits::Int)
    return zeros(UInt64, _db_nchunks(nbits))
end

function _db_full(nbits::Int)
    nc = _db_nchunks(nbits)
    if nbits >= 64
        return fill(typemax(UInt64), nc)
    else
        return UInt64[(UInt64(1) << nbits) - UInt64(1)]
    end
end

@inline _db_isempty(b::_DBSet) = all(==(UInt64(0)), b)

@inline _db_size(b::_DBSet) = sum(count_ones, b)

"""
    _db_least(b)

Smallest element of `b`. Caller must ensure `b` is non-empty.
"""
function _db_least(b::_DBSet)
    @inbounds for i in eachindex(b)
        c = b[i]
        if c != 0
            return Int(trailing_zeros(c)) + (i - 1) * 64
        end
    end
    return -1  # caller's fault — non-empty contract violated
end

@inline _db_intersect(a::_DBSet, b::_DBSet) = a .& b
@inline _db_unite(a::_DBSet, b::_DBSet) = a .| b

function _db_invert(b::_DBSet, nbits::Int)
    return _db_full(nbits) .⊻ b
end

@inline _db_setminus(a::_DBSet, b::_DBSet, nbits::Int) = a .& _db_invert(b, nbits)

function _db_add!(b::_DBSet, e::Integer)
    e_int = Int(e)
    idx = (e_int >> 6) + 1
    bit = e_int & 63
    @inbounds b[idx] |= UInt64(1) << bit
    return b
end

_db_add(b::_DBSet, e::Integer) = _db_add!(copy(b), e)

@inline function _db_in(e::Integer, b::_DBSet)
    e_int = Int(e)
    idx = (e_int >> 6) + 1
    bit = e_int & 63
    return ((@inbounds b[idx] >> bit) & UInt64(1)) != 0
end

function _db_elements(b::_DBSet)
    out = Int[]
    @inbounds for i in eachindex(b)
        c = b[i]
        while c != 0
            push!(out, Int(trailing_zeros(c)) + (i - 1) * 64)
            c &= c - UInt64(1)
        end
    end
    return out
end

@inline _db_permute_mask(x::UInt64, mask::UInt64, len::Int) =
    ((x & mask) << len) | ((x >> len) & mask)

"""
    _db_xor_shift(b, s, nbits)

The dyadic translation `{e ⊕ s : e ∈ b}` as a fresh bitset.

Implementation mirrors the cpp original: the high bits of `s` (`s ≥ 64`)
become a sequence of inter-chunk swaps, and the low six bits of `s`
become in-chunk butterfly permutations using `_db_permute_mask`.
"""
function _db_xor_shift(b::_DBSet, s::Integer, nbits::Int)
    a = copy(b)
    s_u = UInt64(s)

    # inter-chunk swaps (high bits of s, i.e. s ≥ 64)
    if nbits > 64
        high = s_u >> 6
        if high != 0
            nc = length(a)
            bit = UInt64(1)
            while bit <= high
                if (high & bit) != 0
                    step = Int(bit)
                    @inbounds for i in 0:(nc - 1)
                        if (i & step) == 0
                            j = i + step
                            a[i + 1], a[j + 1] = a[j + 1], a[i + 1]
                        end
                    end
                end
                bit <<= 1
            end
        end
    end

    # in-chunk butterflies (low six bits of s)
    if ((s_u >> 5) & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x00000000FFFFFFFF, 32)
        end
    end
    if ((s_u >> 4) & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x0000FFFF0000FFFF, 16)
        end
    end
    if ((s_u >> 3) & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x00FF00FF00FF00FF, 8)
        end
    end
    if ((s_u >> 2) & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x0F0F0F0F0F0F0F0F, 4)
        end
    end
    if ((s_u >> 1) & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x3333333333333333, 2)
        end
    end
    if (s_u & 1) != 0
        @inbounds for i in eachindex(a)
            a[i] = _db_permute_mask(a[i], 0x5555555555555555, 1)
        end
    end

    return a
end
