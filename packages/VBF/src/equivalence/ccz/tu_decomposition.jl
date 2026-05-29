"""
TU-decompositions of vectorial Boolean functions (Perrin 2017).

A `TU_t` decomposition of an `n`-bit function `s` writes it, up to outer
linear maps `A`, `B` and a linear "drift" `C`, as two keyed mini-block
ciphers: a family of `t`-bit **keyed permutations** `T` and a family of
`(n-t)`-bit functions `U`. With `y = A(x)`, `x₂ = y ≫ t`, `x₁ = y ∧ (2ᵗ-1)`:

    s(x) = B( (T[x₂](x₁) ∥ U[x₁](x₂)) ⊕ C(y) ).

The integer `t` is the [`thickness`](@ref) of the Walsh-zero subspace
the decomposition is read off from. This file ports
`sboxU/ccz/tu_decompositions.py` (`TUdecomposition`,
`tu_decomposition_from_space_basis`, `get_tu_decompositions`) on top of
the affine algebra in `algorithms/affine_system.jl` and the Walsh-zero
machinery (`walsh_zeroes`, `extract_linear_subspaces`, `thickness`).

!!! note "Square functions only"
    Implemented for `(n,n)`-functions (`m = n`), matching the rest of
    VBF. The upstream code carries a separate output length `m`; here
    `m = n = N`.

!!! note "Omitted: `insert_before/after_T/U`"
    The four `insert_*` linear-manipulation helpers from the upstream
    `TUdecomposition` are **not** ported. They build their adjusted outer
    map with `block_diagonal_F2AffineMap`, whose branch ordering (the
    first argument lands in the *high* coordinates, per
    `cpp_block_diagonal_F2AffineMap`) does not line up with the `t`-bit
    branch being the *low* coordinates in `get_S_box`; the upstream
    intent there is ambiguous. They are auxiliary (unused by
    [`get_tu_decompositions`](@ref)), so they are left out rather than
    ported incorrectly.
"""

# Raw-LUT helpers for the t-bit / (n-t)-bit mini-blocks (whose bit-widths
# are runtime values, so they are kept as plain LUTs rather than SBoxes).

function _is_perm_lut(lut::Vector{T}) where {T}
    n = length(lut)
    seen = falses(n)
    @inbounds for v in lut
        i = Int(v) + 1
        (1 ≤ i ≤ n) || return false
        seen[i] && return false
        seen[i] = true
    end
    true
end

function _inv_lut(lut::Vector{T}) where {T}
    n = length(lut)
    out = Vector{T}(undef, n)
    @inbounds for x in 0:n-1
        out[Int(lut[x + 1]) + 1] = T(x)
    end
    out
end

"""
    TUDecomposition{N, T}

The `TU_t` decomposition of an `N`-bit function. Fields:

- `t`        — thickness (the `T` blocks are `t`-bit permutations).
- `A, B, C`  — outer affine maps ([`F2AffineMap`](@ref){N,T}); `A`, `B`
  are bijective, `C` is the linear drift.
- `Tblocks`  — `2^(N-t)` keyed permutations, each a length-`2^t` LUT;
  `Tblocks[x₂+1]` is keyed by `x₂`.
- `Ublocks`  — `2^t` functions, each a length-`2^(N-t)` LUT;
  `Ublocks[x₁+1]` is keyed by `x₁`.
- `Tinv`     — the inverses of `Tblocks`.
- `Uprime`   — the `U'` view, indexed by `T[x₂](x₁)` instead of `x₁`
  (the partner used by [`twist`](@ref)).

Reconstruct the underlying function with [`apply_tu`](@ref).
"""
struct TUDecomposition{N, T}
    t::Int
    A::F2AffineMap{N, T}
    B::F2AffineMap{N, T}
    C::F2AffineMap{N, T}
    Tblocks::Vector{Vector{T}}
    Ublocks::Vector{Vector{T}}
    Tinv::Vector{Vector{T}}
    Uprime::Vector{Vector{T}}
end

# Validate the T blocks, invert them, derive U', and assemble.
function _build_tu(A::F2AffineMap{N, T}, B::F2AffineMap{N, T}, C::F2AffineMap{N, T},
                   Tblocks::Vector{Vector{T}}, Ublocks::Vector{Vector{T}}) where {N, T}
    t = trailing_zeros(length(Tblocks[1]))
    n_t = N - t
    length(Tblocks) == (1 << n_t) ||
        throw(ArgumentError("TU decomposition: expected $(1 << n_t) T blocks, got $(length(Tblocks))"))
    length(Ublocks) == (1 << t) ||
        throw(ArgumentError("TU decomposition: expected $(1 << t) U blocks, got $(length(Ublocks))"))
    Tinv = Vector{Vector{T}}(undef, length(Tblocks))
    @inbounds for (k, Tk) in enumerate(Tblocks)
        _is_perm_lut(Tk) ||
            throw(ArgumentError("ill-formed TU-decomposition: every T block must be a permutation"))
        Tinv[k] = _inv_lut(Tk)
    end
    Uprime = [Vector{T}(undef, 1 << n_t) for _ in 1:(1 << t)]
    @inbounds for x1 in 0:(1 << t) - 1, x2 in 0:(1 << n_t) - 1
        k = Int(Tblocks[x2 + 1][x1 + 1])
        Uprime[k + 1][x2 + 1] = Ublocks[x1 + 1][x2 + 1]
    end
    TUDecomposition{N, T}(t, A, B, C, Tblocks, Ublocks, Tinv, Uprime)
end

"""
    apply_tu(td::TUDecomposition{N, T}) -> SBox{N, T}

Reconstruct the function whose decomposition is `td`. Inverse of
[`tu_decomposition_from_space_basis`](@ref); ports
`TUdecomposition.get_S_box`.
"""
function apply_tu(td::TUDecomposition{N, T}) where {N, T}
    t = td.t
    mask_t = (T(1) << t) - T(1)
    n_size = 1 << N
    result = Vector{T}(undef, n_size)
    @inbounds for x in 0:n_size - 1
        y = td.A(T(x))
        x2 = y >> t
        x1 = y & mask_t
        y1 = td.Tblocks[Int(x2) + 1][Int(x1) + 1]
        y2 = td.Ublocks[Int(x1) + 1][Int(x2) + 1]
        combined = y1 | (y2 << t)
        z = combined ⊻ td.C(y)
        result[x + 1] = td.B(z)
    end
    SBox{N, T}(result)
end

"""
    core(td::TUDecomposition{N, T}) -> TUDecomposition{N, T}

The decomposition's "core": the same `T`/`U` mini-blocks with the outer
maps stripped (`A = B = identity`, `C = 0`). Ports `TUdecomposition.core`.
"""
core(td::TUDecomposition{N, T}) where {N, T} =
    _build_tu(identity_affine_map(N, T), identity_affine_map(N, T),
              zero_affine_map(N, T), td.Tblocks, td.Ublocks)

"""
    twist(td::TUDecomposition{N, T}) -> TUDecomposition{N, T}

The "twist": the core built from the inverse `T` blocks and the `U'`
view (`A = B = identity`, `C = 0`). Ports `TUdecomposition.twist`.
"""
twist(td::TUDecomposition{N, T}) where {N, T} =
    _build_tu(identity_affine_map(N, T), identity_affine_map(N, T),
              zero_affine_map(N, T), td.Tinv, td.Uprime)

"""
    tu_decomposition_from_space_basis(s::SBox{N, T}, basis::Vector{UInt32})
        -> TUDecomposition{N, T}

Read a TU-decomposition of `s` off the Walsh-zero subspace whose basis
is `basis` (each a `2N`-bit packed `(a ≪ N) | b`). The thickness `t` of
the subspace becomes the `t` of the decomposition. Ports
`tu_decomposition_from_space_basis`. Throws if `t = 0`.
"""
function tu_decomposition_from_space_basis(s::SBox{N, T}, basis::Vector{UInt32}) where {N, T}
    n = N
    m = N
    t = thickness(basis, m)
    t == 0 && throw(ArgumentError("cannot do a TU decomposition when t = 0"))
    mask_m = (UInt32(1) << m) - UInt32(1)

    # Reorder to extract a basis of the low-m (thickness) projection.
    reordered = UInt32[]
    projected = UInt32[]
    old_rank = 0
    for b in basis
        cand = vcat(projected, b & mask_m)
        new_rank = rank_f2(cand; nbits = m)
        if new_rank > old_rank
            push!(reordered, b)
            projected = cand
            old_rank = new_rank
        end
    end
    length(reordered) == t ||
        throw(ArgumentError("invalid Walsh-zero subspace basis for TU decomposition"))

    sanitized = reordered[1:t]
    # Clear the low-m part of every remaining basis vector by adding a
    # combination of the thickness vectors.
    for b in basis
        if !(b in reordered)
            for coeff in 0:(1 << t) - 1
                bp = b
                for i in 0:t-1
                    ((coeff >> i) & 1) == 1 && (bp ⊻= reordered[i + 1])
                end
                if (bp & mask_m) == 0
                    push!(sanitized, bp)
                    break
                end
            end
        end
    end

    basis_A = T[T(b >> m) for b in sanitized[t + 1:n]]
    basis_C = T[T(b >> m) for b in sanitized[1:t]]
    basis_B = T[T(b & mask_m) for b in sanitized[1:t]]

    A = transpose(generating_affine_map_r(basis_A, n))
    B = transpose(inv(generating_affine_map(basis_B, m)))
    rai = affine_map_from_range_and_image(basis_B, basis_C, n)
    C = compose(compose(inv(B), transpose(rai)), inv(A))

    Ainv = inv(A)
    Binv = inv(B)
    s_prime = Vector{T}(undef, 1 << n)
    @inbounds for x in 0:(1 << n) - 1
        y = Ainv(T(x))
        y = s.lut[Int(y) + 1]
        y = Binv(y)
        s_prime[x + 1] = y ⊻ C(T(x))
    end

    mask_t = (T(1) << t) - T(1)
    n_t = n - t
    Tblocks = [Vector{T}(undef, 1 << t) for _ in 1:(1 << n_t)]
    Ublocks = [Vector{T}(undef, 1 << n_t) for _ in 1:(1 << t)]
    @inbounds for x1 in 0:(1 << t) - 1, x2 in 0:(1 << n_t) - 1
        x = x1 | (x2 << t)
        sp = s_prime[x + 1]
        Tblocks[x2 + 1][x1 + 1] = sp & mask_t
        Ublocks[x1 + 1][x2 + 1] = sp >> t
    end

    return _build_tu(A, B, C, Tblocks, Ublocks)
end

"""
    get_tu_decompositions(F::SBox{N, T}; bases=nothing) -> Vector{TUDecomposition{N, T}}

Every TU-decomposition of `F` obtainable from an `N`-dimensional
Walsh-zero subspace of positive thickness. Ports `get_tu_decompositions`.
Pass `bases` (a vector of `2N`-bit subspace bases) to reuse a previously
computed Walsh-zero enumeration.
"""
function get_tu_decompositions(F::SBox{N, T}; bases = nothing) where {N, T}
    spaces = bases === nothing ?
        extract_linear_subspaces(walsh_zeroes(F), N; max_bits = 2N) : bases
    result = TUDecomposition{N, T}[]
    for w in spaces
        t = thickness(w, N)
        (t > 0 && t ≤ N) && push!(result, tu_decomposition_from_space_basis(F, w))
    end
    return result
end

# --- Base interface -----------------------------------------------------------

Base.:(==)(a::TUDecomposition{N, T}, b::TUDecomposition{N, T}) where {N, T} =
    apply_tu(a) == apply_tu(b)

function Base.show(io::IO, td::TUDecomposition{N, T}) where {N, T}
    print(io, "TUDecomposition{", N, ", ", T, "} (t = ", td.t, ")")
end

function Base.show(io::IO, ::MIME"text/plain", td::TUDecomposition{N, T}) where {N, T}
    show(io, td)
    println(io)
    println(io, "  T: ", length(td.Tblocks), " keyed ", td.t, "-bit permutations")
    println(io, "  U: ", length(td.Ublocks), " functions of ", N - td.t, " bits")
end
