"""
The function graph and CCZ-mapping primitive.

For a function `F : F₂ⁿ → F₂ⁿ`, the **graph** is the subset

    Γ_F := { (x, F(x)) : x ∈ F₂ⁿ }  ⊂  F₂ⁿ × F₂ⁿ = F₂²ⁿ.

Two functions `F, G : F₂ⁿ → F₂ⁿ` are **CCZ-equivalent** iff there
exists an invertible F₂-affine map `L : F₂²ⁿ → F₂²ⁿ` such that
`L(Γ_F) = Γ_G` as sets — this is the **Carlet-Charpin-Zinoviev**
equivalence, strictly broader than EA-equivalence (which lives inside
the subgroup of CCZ-mappings of "block-triangular" form).

# Internal representation

A graph entry `(x, y)` with `x, y ∈ F₂ⁿ` is packed into a single
`2n`-bit integer as `(x << n) | y` — the high `n` bits hold the input,
the low `n` bits hold the output. This matches the sboxU C++
representation in `cpp/ccz/graph.cpp`.

Functions exposed:
- [`FunctionGraph`](@ref) — the graph type.
- [`ccz_equivalent_function`](@ref) — apply an affine `L` of `F₂²ⁿ`
  to a graph and recover the resulting function (or `nothing` if the
  result is not a function — i.e., some input ends up mapping to
  multiple outputs).
"""

# ---------------------------------------------------------------------------
# The 2n-bit packed graph type.
# ---------------------------------------------------------------------------

"""
    FunctionGraph{N}

The graph `Γ_F = {(x, F(x)) : x ∈ F₂ⁿ}` packed as a sorted vector of
`2n`-bit integers (`UInt32` for `N ≤ 16`). Stored sorted by `(x, y)`,
i.e., by the packed value itself — which gives sorted-by-`x` since `x`
is the high `n` bits.

# Constructors
- `FunctionGraph(F::SBox{N,T})` — build from an S-box.
- `FunctionGraph{N}(packed::Vector{UInt32})` — build from a pre-packed
  vector. The vector is sorted on construction.
"""
struct FunctionGraph{N}
    packed::Vector{UInt32}
    function FunctionGraph{N}(packed::Vector{UInt32}) where {N}
        N isa Int && 1 ≤ N ≤ 16 ||
            throw(ArgumentError("FunctionGraph: N must be an Int in 1:16, got $N"))
        2 * N ≤ 32 ||
            throw(ArgumentError("FunctionGraph: 2N must fit in UInt32; got N=$N"))
        # The graph contains 2ⁿ entries.
        length(packed) == (1 << N) ||
            throw(ArgumentError("FunctionGraph: packed must have length 2^N = $(1 << N)"))
        # Internal storage is sorted ascending.
        sort!(packed)
        new{N}(packed)
    end
end

function FunctionGraph(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    packed = Vector{UInt32}(undef, n_size)
    @inbounds for x in 0:(n_size - 1)
        packed[x + 1] = (UInt32(x) << N) | UInt32(F.lut[x + 1])
    end
    # Already sorted: `(x << N) | y` is strictly increasing as x grows.
    return FunctionGraph{N}(packed)
end

inputbits(::FunctionGraph{N}) where {N} = N::Int

Base.length(g::FunctionGraph) = length(g.packed)

function Base.show(io::IO, g::FunctionGraph{N}) where {N}
    print(io, "FunctionGraph{", N, "}(",
          length(g.packed), " entries; 2N=", 2N, " bits packed)")
end

# ---------------------------------------------------------------------------
# Apply an F₂-affine map L : F₂²ⁿ → F₂²ⁿ to a graph.
# ---------------------------------------------------------------------------

"""
    ccz_equivalent_function(F::SBox{N,T}, L::F2AffineMap{M, S}) ->
        Union{SBox{N,T}, Nothing}

Apply an F₂-affine map `L : F₂²ⁿ → F₂²ⁿ` (with `M = 2N`) to the graph
of `F` and reconstruct the resulting function. Returns:

- `SBox{N,T}` — the CCZ-equivalent function, if `L` is **admissible**
  for `F` (the image graph is still a function graph: every `x` has a
  unique image).
- `nothing` — if `L(Γ_F)` is not a function graph (some input collides).

This mirrors `cpp_ccz_equivalent_function` in `sboxU/cpp/ccz/graph.cpp`.

# Examples

```jldoctest
julia> using BFA

julia> F = load_literature_sbox("PRESENT");

julia> # Identity on F₂²ⁿ → recovers F itself.
       L_id = identity_linear_map(8);

julia> ccz_equivalent_function(F, F2AffineMap(L_id, UInt8(0))) == F
true
```
"""
function ccz_equivalent_function(
    F::SBox{N,T}, L::F2AffineMap{M, S},
) where {N,T,M,S}
    M == 2 * N ||
        throw(ArgumentError("ccz_equivalent_function: L must operate on F₂^{2N} = F₂^$(2N); got input length $M"))
    n_size = 1 << N
    mask = (UInt32(1) << N) - UInt32(1)
    # Build the LUT, marking unset slots with the forbidden value 2^(N+1).
    forbidden = UInt32(1) << (N + 1)
    lut = fill(forbidden, n_size)
    graph = FunctionGraph(F)
    @inbounds for entry in graph.packed
        # Evaluate L on the entry (converting widths)
        z = UInt32(L(S(entry)))
        x = z >> N
        y = z & mask
        if lut[x + 1] != forbidden
            return nothing
        end
        lut[x + 1] = y
    end
    return SBox{N, T}(T.(lut))
end
