"""
Stennes' linear-equivalence-class representative algorithm.

Given a permutation `F : F₂ⁿ → F₂ⁿ`, computes the lexicographically smallest
LUT `R_F` in the linear-equivalence class of `F`, together with invertible
F₂-linear maps `A`, `B` such that

    B(R_F(x)) = F(A(x))   for all x,

equivalently `R_F = B⁻¹ ∘ F ∘ A`. Two permutations are linearly equivalent
iff their representatives agree, so the decision procedure for linear
equivalence reduces to two representative computations plus a vector
comparison — the asymptotically faster route compared to backtracking
once `n ≥ 6`.

Port of the C++ implementation in
`sboxU/cpp/ccz/linear_representative.cpp` by Lukas Stennes
(see references in `data-raw/bibliography.bib`).

The algorithm progressively defines `A` and `B` one input at a time,
propagating each newly-fixed value via F₂-linearity (`A(x ⊕ y) =
A(x) ⊕ A(y)`) to as many further inputs as the constraint graph permits.
When propagation stalls, it branches over the candidate next value for
the least-undefined input of `A`, recursing with lexicographic pruning.

Permutations only; non-permutations are rejected by the public wrapper.
"""

# ---------------------------------------------------------------------------
# Inner-loop helpers.
# ---------------------------------------------------------------------------

# After A[new_x] is set, push the implication A[new_x ⊕ i] = A[i] ⊕ A[new_x]
# for every `i` already in A's domain. Returns false on contradiction.
#
# An A-entry equal to 0 at index != 0 is the "undefined" sentinel (since A is
# invertible the only x with A[x] = 0 is x = 0, so the sentinel is sound).
function _stennes_propagate!(A::Vector{T}, new_x::Integer, len::Int) where {T<:Integer}
    new_y = @inbounds A[new_x + 1]
    @inbounds for i in 1:(len - 1)
        e = A[i + 1]
        e == 0 && continue
        idx = (new_x ⊻ i) + 1
        expected = e ⊻ new_y
        if A[idx] == 0
            A[idx] = expected
        elseif A[idx] != expected
            return false
        end
    end
    return true
end

# Lex-compare R_S (current candidate prefix) against R_S_best (best seen so
# far); return true if R_S is strictly worse and search may be pruned.
# Sentinel for "no best yet": R_S_best[2] == 0 (R_S_best[1] is always 0 by
# linearity at the origin).
function _stennes_is_worse(R_S::Vector{T}, R_S_best::Vector{T}, len::Int) where {T<:Integer}
    @inbounds if R_S_best[1] == 0 && R_S_best[2] == 0
        return false
    end
    @inbounds for x in 1:len
        if R_S[x] > R_S_best[x]
            return true
        end
        if R_S[x] < R_S_best[x]
            return false
        end
    end
    return false
end

# ---------------------------------------------------------------------------
# Recursive core. Mirrors `subroutine<set_t, int_type>` in the C++ port.
#
# Each recursive call receives the algorithmic state by value (we copy on
# entry). Branching at the end allocates a fresh A vector per guess; the
# state otherwise is `R_S_best, A_best, B_best` which thread through the
# recursion by mutable reference.
# ---------------------------------------------------------------------------

function _stennes_subroutine(
    S::Vector{T}, S_inv::Vector{T},
    A_in::Vector{T}, B_in::Vector{T}, R_S_in::Vector{T},
    D_A_in::_DBSet, D_B_in::_DBSet,
    C_A_in::_DBSet, C_B_in::_DBSet,
    N_A_in::_DBSet, N_B_in::_DBSet,
    U_A_in::_DBSet, U_B_in::_DBSet,
    R_S_best::Vector{T}, A_best::Vector{T}, B_best::Vector{T},
    len::Int,
) where {T<:Integer}
    A = copy(A_in); B = copy(B_in); R_S = copy(R_S_in)
    D_A = copy(D_A_in); D_B = copy(D_B_in)
    C_A = copy(C_A_in); C_B = copy(C_B_in)
    N_A = copy(N_A_in); N_B = copy(N_B_in)
    U_A = copy(U_A_in); U_B = copy(U_B_in)

    while !_db_isempty(N_A)
        x = _db_least(N_A)
        y = _db_least(U_B)
        @inbounds B[y + 1] = S[A[x + 1] + 1]
        if !_stennes_propagate!(B, y, len)
            return false
        end

        D_B_new = _db_xor_shift(D_B, y, len)
        D_B = _db_unite(D_B, D_B_new)
        U_B = _db_setminus(U_B, D_B_new, len)

        SoA_N_A = _db_empty(len)
        for xi in _db_elements(N_A)
            @inbounds _db_add!(SoA_N_A, S[A[xi + 1] + 1])
        end

        B_D_B_new = _db_empty(len)
        for d in _db_elements(D_B_new)
            @inbounds bd = B[d + 1]
            _db_add!(B_D_B_new, bd)
            if _db_in(bd, SoA_N_A)
                C_B = _db_add(C_B, d)
            else
                N_B = _db_add(N_B, d)
            end
        end

        C_A_new = _db_empty(len)
        for xi in _db_elements(N_A)
            @inbounds if _db_in(S[A[xi + 1] + 1], B_D_B_new)
                _db_add!(C_A_new, xi)
            end
        end
        C_A = _db_unite(C_A, C_A_new)
        N_A = _db_setminus(N_A, C_A_new, len)

        for xi in _db_elements(C_A_new)
            @inbounds target = S[A[xi + 1] + 1]
            y_found = T(0)
            @inbounds for i in 0:(len - 1)
                if B[i + 1] == target
                    y_found = T(i)
                    break
                end
            end
            @inbounds R_S[xi + 1] = y_found
        end

        if _stennes_is_worse(R_S, R_S_best, len)
            return false
        end

        while _db_isempty(N_A) && !_db_isempty(N_B)
            x2 = _db_least(U_A)
            y2 = _db_least(N_B)
            @inbounds A[x2 + 1] = S_inv[B[y2 + 1] + 1]
            if !_stennes_propagate!(A, x2, len)
                return false
            end

            D_A_new = _db_xor_shift(D_A, x2, len)
            D_A = _db_unite(D_A, D_A_new)
            U_A = _db_setminus(U_A, D_A_new, len)

            SinvoB_N_B = _db_empty(len)
            for yi in _db_elements(N_B)
                @inbounds _db_add!(SinvoB_N_B, S_inv[B[yi + 1] + 1])
            end

            A_D_A_new = _db_empty(len)
            for d in _db_elements(D_A_new)
                @inbounds ad = A[d + 1]
                _db_add!(A_D_A_new, ad)
                if _db_in(ad, SinvoB_N_B)
                    C_A = _db_add(C_A, d)
                else
                    N_A = _db_add(N_A, d)
                end
            end

            C_B_new = _db_empty(len)
            for yi in _db_elements(N_B)
                @inbounds if _db_in(S_inv[B[yi + 1] + 1], A_D_A_new)
                    _db_add!(C_B_new, yi)
                end
            end
            C_B = _db_unite(C_B, C_B_new)
            N_B = _db_setminus(N_B, C_B_new, len)

            for yi in _db_elements(C_B_new)
                @inbounds target = S_inv[B[yi + 1] + 1]
                x_found = T(0)
                @inbounds for i in 0:(len - 1)
                    if A[i + 1] == target
                        x_found = T(i)
                        break
                    end
                end
                @inbounds R_S[x_found + 1] = T(yi)
            end

            if _stennes_is_worse(R_S, R_S_best, len)
                return false
            end
        end
    end

    if _db_isempty(U_A) && _db_isempty(U_B)
        @inbounds for i in 1:len
            R_S_best[i] = R_S[i]
            A_best[i] = A[i]
            B_best[i] = B[i]
        end
        return true
    end

    # Branch: pick the smallest still-undefined A input and try every y not
    # yet used as an A-image.
    x_branch = _db_least(U_A)
    D_A_new = _db_xor_shift(D_A, x_branch, len)
    U_A = _db_setminus(U_A, D_A_new, len)
    D_A = _db_unite(D_A, D_A_new)
    N_A = _db_unite(N_A, D_A_new)

    Y = _db_full(len)
    A_set = _db_empty(len)
    @inbounds for i in 0:(len - 1)
        _db_add!(A_set, A[i + 1])
    end
    Y = _db_setminus(Y, A_set, len)

    found_any = false
    for y_guess in _db_elements(Y)
        A_next = copy(A)
        @inbounds A_next[x_branch + 1] = T(y_guess)
        if !_stennes_propagate!(A_next, x_branch, len)
            continue
        end
        if _stennes_subroutine(
            S, S_inv,
            A_next, B, R_S,
            D_A, D_B, C_A, C_B, N_A, N_B, U_A, U_B,
            R_S_best, A_best, B_best, len,
        )
            found_any = true
        end
    end
    return found_any
end

# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

"""
    linear_representative(F::SBox{N,T}) -> NamedTuple

Compute the linear-equivalence-class representative of a permutation `F`
using Stennes' algorithm.

Returns a named tuple `(representative, A, B)`:

- `representative::SBox{N,T}` — lexicographically smallest LUT in the
  linear-equivalence class of `F`.
- `A::F2LinearMap{N,T}` — invertible input map.
- `B::F2LinearMap{N,T}` — invertible output map. Satisfies
  `B(representative(x)) == F(A(x))` for all `x ∈ F₂ⁿ`, equivalently
  `representative == B⁻¹ ∘ F ∘ A`.

Throws `ArgumentError` if `F` is not a permutation.

# Examples

```jldoctest
julia> using BFA

julia> F = load_apn_function("n5_Gold_x3");

julia> rep = linear_representative(F);

julia> rep.representative isa SBox{5, UInt8}
true

julia> linear_representative(load_apn_function("n5_Gold_x3")).representative ==
       linear_representative(load_apn_function("n5_Gold_x3")).representative
true
```
"""
function linear_representative(F::SBox{N,T}) where {N,T}
    is_permutation(F) ||
        throw(ArgumentError("linear_representative: F must be a permutation"))
    len = 1 << N
    S = Vector{T}(F.lut)
    S_inv = Vector{T}(undef, len)
    @inbounds for x in 0:(len - 1)
        S_inv[S[x + 1] + 1] = T(x)
    end

    R_S_best = zeros(T, len)
    A_best = zeros(T, len)
    B_best = zeros(T, len)

    A0 = zeros(T, len)
    B0 = zeros(T, len)
    R_S0 = zeros(T, len)

    D_A = _db_add!(_db_empty(len), 0)
    D_B = _db_add!(_db_empty(len), 0)

    if S[1] == 0  # F(0) = 0
        C_A = _db_add!(_db_empty(len), 0)
        C_B = _db_add!(_db_empty(len), 0)
        N_A = _db_empty(len)
        N_B = _db_empty(len)
    else
        C_A = _db_empty(len)
        C_B = _db_empty(len)
        N_A = _db_add!(_db_empty(len), 0)
        N_B = _db_add!(_db_empty(len), 0)
    end

    U_A = _db_setminus(_db_full(len), D_A, len)
    U_B = _db_setminus(_db_full(len), D_B, len)

    _stennes_subroutine(
        S, S_inv,
        A0, B0, R_S0,
        D_A, D_B, C_A, C_B, N_A, N_B, U_A, U_B,
        R_S_best, A_best, B_best, len,
    )

    R = SBox{N,T}(R_S_best)
    A_map = _stennes_linear_from_lut(A_best, N, T)
    B_map = _stennes_linear_from_lut(B_best, N, T)
    return (representative = R, A = A_map, B = B_map)
end

# Extract the column representation of a linear map from its full LUT.
# Column j (0-based) is the image of the unit vector 2^j.
function _stennes_linear_from_lut(lut::Vector{T}, N::Int, ::Type{T}) where {T}
    cols = T[lut[(1 << j) + 1] for j in 0:(N - 1)]
    return F2LinearMap{N,T}(cols)
end
