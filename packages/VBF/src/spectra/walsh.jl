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
- [`walsh_hadamard!`](@ref) — in-place FWHT on signed integer vectors.
- [`walsh_hadamard`](@ref)  — allocating counterpart.
- [`walsh_transform`](@ref) — convenience: convert a `{0,1}`-valued truth
  table to `±1`, then FWHT.

# Properties (used as test invariants)
- Involution up to scale: `walsh_hadamard!(walsh_hadamard!(v)) == 2^N · v`.
- Parseval: `sum(abs2, v_after) == 2^N · sum(abs2, v_before)`.
- The all-zero Boolean function ↦ spectrum `[2^N, 0, 0, …, 0]`.
"""

"""
    walsh_hadamard!(v::Vector{<:Signed}; threaded=false) -> v

In-place FWHT. `length(v)` must be a power of 2. After the call,
`v[u + 1] = ∑ₓ (-1)^{u · x} · v_in[x + 1]`. The element type is
preserved; choose a width that can hold every intermediate sum.
`threaded=true` parallelizes independent butterflies for fixed-width vectors
of at least 2^18 elements when multiple default-pool Julia threads are available.
Small vectors and BigInt use the serial kernel to avoid scheduling overhead.
"""
function walsh_hadamard!(v::Vector{<:Signed}; threaded::Bool = false)
    n_pow = length(v)
    n_pow ≥ 1 || throw(ArgumentError("walsh_hadamard!: empty input"))
    n = trailing_zeros(n_pow)
    1 << n == n_pow || throw(
        ArgumentError("walsh_hadamard!: length $n_pow is not a power of 2"),
    )
    if threaded && isbitstype(eltype(v)) && n_pow >= (1 << 18) && Threads.nthreads() > 1
        return _walsh_hadamard_threaded!(v)
    end
    block = 1
    if eltype(v) === Int32 && n_pow >= 8
        # Fixed early stages avoid a short inner loop for every butterfly.
        # Keep GC response bounded even when many searches transform in parallel.
        chunk_size = 1 << 14
        for lo in 1:chunk_size:n_pow
            n_pow >= (1 << 16) && GC.safepoint()
            _walsh_hadamard_prefix8!(v,lo,min(n_pow,lo+chunk_size-1))
        end
        block = 8
    end
    while block < n_pow
        # A large serial transform can otherwise delay collection requested by
        # independent tasks. Keep the SIMD butterflies allocation-free.
        n_pow >= (1 << 16) && GC.safepoint()
        step = 2 * block
        @inbounds for start = 0:step:(n_pow-1)
            @simd for i = 1:block
                a = v[start+i]
                b = v[start+i+block]
                v[start+i] = a + b
                v[start+i+block] = a - b
            end
        end
        block = step
    end
    v
end

"""Fuse the width-1, width-2 and width-4 Int32 butterflies over complete groups."""
@noinline function _walsh_hadamard_prefix8!(v::Vector{Int32},lo::Int,hi::Int)
    @inbounds @simd for i in lo:8:hi-7
        a=v[i];b=v[i+1];c=v[i+2];d=v[i+3]
        e=v[i+4];f=v[i+5];g=v[i+6];h=v[i+7]
        ab=a+b;am=a-b;cd=c+d;cm=c-d
        ef=e+f;em=e-f;gh=g+h;gm=g-h
        t0=ab+cd;t1=am+cm;t2=ab-cd;t3=am-cm
        t4=ef+gh;t5=em+gm;t6=ef-gh;t7=em-gm
        v[i]=t0+t4;v[i+1]=t1+t5;v[i+2]=t2+t6;v[i+3]=t3+t7
        v[i+4]=t0-t4;v[i+5]=t1-t5;v[i+6]=t2-t6;v[i+7]=t3-t7
    end
    v
end

"""Parallel butterflies with a barrier between stages and disjoint writes."""
function _walsh_hadamard_threaded!(v)
    pairs = length(v) ÷ 2
    chunks = prevpow(2, Threads.nthreads())
    chunk_pairs = pairs ÷ chunks
    block = 1
    while block < length(v)
        # Capturing the stage value in a fresh binding avoids sharing the
        # loop's reassigned block variable with worker tasks.
        let stage = block
            Threads.@threads :dynamic for chunk = 1:chunks
                lo = (chunk-1) * chunk_pairs
                if stage <= chunk_pairs
                    @inbounds for start = (2lo):(2stage):(2(lo+chunk_pairs)-1)
                        @simd for j = 1:stage
                            a, b = v[start+j], v[start+j+stage]
                            v[start+j], v[start+j+stage] = a + b, a - b
                        end
                    end
                else
                    # A late-stage chunk is one contiguous slice of each half.
                    start = lo + (lo & -stage)
                    @inbounds @simd for j = 1:chunk_pairs
                        a, b = v[start+j], v[start+j+stage]
                        v[start+j], v[start+j+stage] = a + b, a - b
                    end
                end
            end
        end
        block *= 2
    end
    return v
end

"""
    walsh_hadamard(v::AbstractVector{<:Integer}) -> Vector{Int}

Allocating FWHT.
"""
walsh_hadamard(v::AbstractVector{<:Integer}) =
    walsh_hadamard!(Int[Int(x) for x in v])

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
    1 << n == n_pow || throw(
        ArgumentError("walsh_transform: length $n_pow is not a power of 2"),
    )
    v = Vector{Int}(undef, n_pow)
    @inbounds for i = 1:n_pow
        b = f[i]
        b == 0 ||
            b == 1 ||
            throw(ArgumentError("walsh_transform: f[$i] = $b not in {0,1}"))
        v[i] = 1 - 2 * Int(b)
    end
    walsh_hadamard!(v)
end
