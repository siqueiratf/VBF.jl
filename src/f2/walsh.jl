"""
Fast Walsh-Hadamard Transform (FWHT).

The Walsh-Hadamard transform of a real-valued function `f : F₂ᴺ → ℝ` is
``W_f(u) = ∑_{x ∈ F₂ᴺ} (-1)^{u · x} · f(x)`` where `u · x` is the F₂
inner product.

For a Boolean function encoded as `±1` (`+1` ↦ bit `0`, `-1` ↦ bit `1`),
the transform produces the *Walsh spectrum* used in linear cryptanalysis;
for a vectorial Boolean function each component is transformed
independently to build the LAT.

# Public surface
- [`walsh_hadamard!`](@ref) — in-place FWHT on `Vector{Int}`.
- [`walsh_hadamard`](@ref)  — allocating counterpart.
- [`walsh_transform`](@ref) — convenience: convert a `{0,1}`-valued truth
  table to `±1`, then FWHT.

# Properties (used as test invariants)
- Involution up to scale: `walsh_hadamard!(walsh_hadamard!(v)) == 2^N · v`.
- Parseval: `sum(abs2, v_after) == 2^N · sum(abs2, v_before)`.
- The all-zero Boolean function ↦ spectrum `[2^N, 0, 0, …, 0]`.
"""

"""
    walsh_hadamard!(v::Vector{Int}) -> v

In-place FWHT. `length(v)` must be a power of 2. After the call,
`v[u + 1] = ∑ₓ (-1)^{u · x} · v_in[x + 1]`.
"""
function walsh_hadamard!(v::Vector{Int})
    n_pow = length(v)
    n_pow ≥ 1 || throw(ArgumentError("walsh_hadamard!: empty input"))
    n = trailing_zeros(n_pow)
    1 << n == n_pow ||
        throw(ArgumentError("walsh_hadamard!: length $n_pow is not a power of 2"))
    block = 1
    while block < n_pow
        step = 2 * block
        @inbounds for start in 0:step:n_pow - 1
            for i in 1:block
                a = v[start + i]
                b = v[start + i + block]
                v[start + i]         = a + b
                v[start + i + block] = a - b
            end
        end
        block = step
    end
    v
end

"""
    walsh_hadamard(v::AbstractVector{<:Integer}) -> Vector{Int}

Allocating FWHT.
"""
walsh_hadamard(v::AbstractVector{<:Integer}) = walsh_hadamard!(Int[Int(x) for x in v])

"""
    walsh_transform(f::AbstractVector{<:Integer}) -> Vector{Int}

Walsh spectrum of a Boolean function given as its `{0,1}` truth table.
Encodes the `{0,1}` values as `{+1,-1}` (mapping `0 ↦ +1`, `1 ↦ -1`) and
applies [`walsh_hadamard!`](@ref).

Throws `ArgumentError` if any entry is not `0` or `1`.
"""
function walsh_transform(f::AbstractVector{<:Integer})
    n_pow = length(f)
    n_pow ≥ 1 || throw(ArgumentError("walsh_transform: empty input"))
    n = trailing_zeros(n_pow)
    1 << n == n_pow ||
        throw(ArgumentError("walsh_transform: length $n_pow is not a power of 2"))
    v = Vector{Int}(undef, n_pow)
    @inbounds for i in 1:n_pow
        b = f[i]
        b == 0 || b == 1 ||
            throw(ArgumentError("walsh_transform: f[$i] = $b not in {0,1}"))
        v[i] = 1 - 2 * Int(b)
    end
    walsh_hadamard!(v)
end
