"""
    F2AffineMap{N, T<:Unsigned}

An F₂-affine map `A : F₂ᴺ → F₂ᴺ`, the sum of an F₂-linear map and a constant:
`A(x) = linear(x) ⊕ constant`.

# Fields
- `linear::F2LinearMap{N, T}`
- `constant::T`

# Constructors
- `F2AffineMap(L::F2LinearMap, c)` — explicit.
- `F2AffineMap{N,T}(cols, c)`      — build linear part from `cols`.

# Examples
```jldoctest
julia> using VBF

julia> L = identity_linear_map(4);

julia> A = F2AffineMap(L, UInt8(0b0101));

julia> A(0b1010)
0x0f
```
"""
struct F2AffineMap{N,T<:Unsigned}
    linear::F2LinearMap{N,T}
    constant::T

    function F2AffineMap{N,T}(
        linear::F2LinearMap{N,T},
        constant::T,
    ) where {N,T<:Unsigned}
        if N < 8 * sizeof(T)
            mask = T((1 << N) - 1)
            constant & mask == constant || throw(
                ArgumentError(
                    "F2AffineMap{$N, $T}: constant = $constant exceeds $N-bit range",
                ),
            )
        end
        new{N,T}(linear, constant)
    end
end

F2AffineMap(L::F2LinearMap{N,T}, c::Integer) where {N,T} =
    F2AffineMap{N,T}(L, T(c))

F2AffineMap{N,T}(cols::AbstractVector{<:Integer}, c::Integer) where {N,T} =
    F2AffineMap{N,T}(F2LinearMap{N,T}(convert(Vector{T}, cols)), T(c))

# --- accessors ----------------------------------------------------------------

inputbits(::F2AffineMap{N}) where {N} = N::Int
storage_type(::F2AffineMap{N,T}) where {N,T} = T

"""
    is_linear(A::F2AffineMap)

`true` if the affine constant is zero (so `A` is in fact linear).
"""
is_linear(A::F2AffineMap{N,T}) where {N,T} = A.constant == zero(T)

# --- evaluation ---------------------------------------------------------------

@inline (A::F2AffineMap)(x::Integer) = A.linear(x) ⊻ A.constant

# --- Base interface -----------------------------------------------------------

Base.:(==)(a::F2AffineMap{N,T}, b::F2AffineMap{N,T}) where {N,T} =
    a.constant == b.constant && a.linear == b.linear
Base.:(==)(a::F2AffineMap{N}, b::F2AffineMap{N}) where {N} =
    a.constant == b.constant && a.linear == b.linear
Base.:(==)(::F2AffineMap, ::F2AffineMap) = false

Base.hash(A::F2AffineMap{N,T}, h::UInt) where {N,T} =
    hash(A.constant, hash(A.linear, hash((:F2AffineMap, N, T), h)))

Base.copy(A::F2AffineMap{N,T}) where {N,T} =
    F2AffineMap{N,T}(copy(A.linear), A.constant)

function Base.show(io::IO, A::F2AffineMap{N,T}) where {N,T}
    print(io, "F2AffineMap{", N, ", ", T, "}")
    is_linear(A) && print(io, " (linear)")
end

function Base.show(io::IO, ::MIME"text/plain", A::F2AffineMap{N,T}) where {N,T}
    show(io, A)
    println(io)
    println(io, "  constant = ", repr(A.constant))
    println(io, "  linear:")
    for j = 1:N
        println(io, "    e", j - 1, " ↦ ", repr(A.linear.cols[j]))
    end
end
