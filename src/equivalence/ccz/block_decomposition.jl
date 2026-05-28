"""
Block decomposition of `2n × 2n` CCZ-maps, and the EA-mapping builder.

A CCZ-mapping `L : F₂²ⁿ → F₂²ⁿ` can be written in `n × n` blocks

    L = [ A  D ]
        [ C  B ]

acting on `(input ‖ output)` coordinates. `ccz_block_decomposition`
recovers `(A, B, C, D)`; `ea_mapping` builds the CCZ-map corresponding
to an extended-affine triple. Ports `cpp_ccz_block_decomposition` and
`cpp_EA_mapping` from `sboxU/cpp/ccz/graph.cpp`.
"""

"""
    ccz_block_decomposition(L::F2LinearMap{M,S}) ->
        @NamedTuple{A, B, C, D}

Split the `2n × 2n` map `L` (M = 2n, even) into four `n × n` blocks in
the layout `[A D; C B]`. Each block is an `F2LinearMap{n, S}`.

Column `i` of `L` (0-based) contributes `A`'s and `C`'s `i`-th columns
(its low and high `n` bits); column `n+i` contributes `D`'s and `B`'s.
"""
function ccz_block_decomposition(L::F2LinearMap{M,S}) where {M,S}
    iseven(M) ||
        throw(ArgumentError("ccz_block_decomposition: M = $M must be even"))
    n = M ÷ 2
    mask = (S(1) << n) - S(1)
    Acols = Vector{S}(undef, n)
    Bcols = Vector{S}(undef, n)
    Ccols = Vector{S}(undef, n)
    Dcols = Vector{S}(undef, n)
    @inbounds for i in 1:n
        v = L.cols[i]
        w = L.cols[n + i]
        Acols[i] = v & mask
        Ccols[i] = (v >> n) & mask
        Dcols[i] = w & mask
        Bcols[i] = (w >> n) & mask
    end
    return (A = F2LinearMap{M ÷ 2, S}(Acols), B = F2LinearMap{M ÷ 2, S}(Bcols),
            C = F2LinearMap{M ÷ 2, S}(Ccols), D = F2LinearMap{M ÷ 2, S}(Dcols))
end

"""
    ea_mapping(A::F2LinearMap{N,S}, B::F2LinearMap{N,S}, C::F2LinearMap{N,S})
        -> F2LinearMap{2N, UInt32}

The CCZ-map of an extended-affine equivalence with invertible linear
parts `A` (input side) and `B` (output side) and linear drift `C`.
Matches `cpp_EA_mapping`: the first `n` columns are `B(eᵢ)` (low half),
the next `n` are `(A⁻¹(eᵢ) ≪ n) | (C∘A⁻¹)(eᵢ)`.

Stored over `UInt32` to match the function-graph packing.
"""
function ea_mapping(A::F2LinearMap{N,S}, B::F2LinearMap{N,S},
                    C::F2LinearMap{N,S}) where {N,S}
    A_inv = inv(A)
    C_prime = compose(C, A_inv)        # C ∘ A⁻¹
    cols = Vector{UInt32}(undef, 2N)
    @inbounds for i in 0:(N - 1)
        ei = S(1) << i
        cols[i + 1] = UInt32(B(ei))
        cols[N + i + 1] = (UInt32(A_inv(ei)) << N) | UInt32(C_prime(ei))
    end
    return F2LinearMap{2N, UInt32}(cols)
end
