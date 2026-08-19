# Implements paper-local helpers for Budaghyan–Carlet–Pott (2005/2006).
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: General — trace-component truth tables, boolean algebraic degree
#
# Pseudocode:
#   1. boolean_alg_degree  = algebraic degree of a GF(2)-valued truth table
#   2. trace_component_tt(F, n; c) = truth table of x ↦ Tr(c·F(x))  ∈ {0,1}
#   3. prop4_witnesses(F, m, d°F) = {c ∈ F*_{2^m} : d°(tr(cF)) ∉ {0,1,d°(F)}}
#   4. sbox_linearity = linearity, streaming for m too large to materialise a LAT
# VBF API used: gf_mul, gf_trace, primitive_polynomial, mobius!, walsh_hadamard!,
#               linearity, inputbits, print_banner, print_section, print_check,
#               print_kv

using VBF
using Dates

# TODO(promote-to-core): boolean_alg_degree is a generic Boolean-function
# invariant (Möbius transform + max nonzero Hamming weight). It duplicates
# algebraic_degree's internals for a raw truth table; promote a
# `truth_table_algebraic_degree`-style helper to VBF core and route this
# through it. Kept paper-local for now (core is frozen).
"""
    boolean_alg_degree(tt) -> Int

Algebraic degree of a Boolean function given by its truth table (values in {0,1}).
Applies the Möbius transform then returns the max Hamming weight of any nonzero index.
"""
function boolean_alg_degree(tt::Vector{<:Integer})
    a = UInt8.(tt .& 1)
    mobius!(a)
    deg = 0
    for (idx, c) in enumerate(a)
        c == 0x00 && continue
        w = count_ones(UInt(idx - 1))
        w > deg && (deg = w)
    end
    deg
end

"""
    trace_component_tt(F_lut, n; c = 1, modulus) -> Vector{Int}

Boolean truth table of x ↦ Tr(c·F(x)) over GF(2^n).

Proposition 4 quantifies over *some* `c ∈ F*_{2^n}` ("if there exists an element
c ∈ F*_{2^m} such that d°(tr(cF)) ∉ {0,1,d°(F)}"), so `c` must be a parameter:
a failure at `c = 1` alone says nothing about the criterion. See
[`prop4_witnesses`](@ref) for the full scan.
"""
function trace_component_tt(
    F_lut::Vector{<:Integer},
    n::Int;
    c::Integer = 1,
    modulus::Int = primitive_polynomial(n),
)
    ci = Int(c)
    ci == 1 && return [gf_trace(Int(F_lut[x+1]), n; modulus = modulus) for x in 0:(1<<n)-1]
    [
        gf_trace(gf_mul(ci, Int(F_lut[x+1]), n; modulus = modulus), n; modulus = modulus)
        for x in 0:(1<<n)-1
    ]
end

"""
    prop4_witnesses(F_lut, m, deg_F; modulus) -> Vector{Int}

Every `c ∈ F*_{2^m}` witnessing Proposition 4 for `F`, i.e. every `c ≠ 0` with
`d°(tr(cF)) ∉ {0, 1, d°(F)}`. Non-empty ⟺ `F` is EA-inequivalent to every power
function by Proposition 4.

The scan is `O(2^m)` truth tables of length `2^m`; keep `m ≤ 10` or so.
"""
function prop4_witnesses(
    F_lut::Vector{<:Integer},
    m::Int,
    deg_F::Int;
    modulus::Int = primitive_polynomial(m),
)
    wit = Int[]
    for c in 1:(1<<m)-1
        d = boolean_alg_degree(trace_component_tt(F_lut, m; c = c, modulus = modulus))
        d ∉ (0, 1, deg_F) && push!(wit, c)
    end
    wit
end

# TODO(promote-to-core): linearity_streaming is core `linearity` with the
# `2^m × 2^m` LAT replaced by one reused column buffer, so it needs O(2^m)
# instead of O(2^{2m}) memory (at m=15 the LAT alone is 8.6 GB). A
# `linearity(s; materialise = false)` option — or a streaming `lat` iterator —
# belongs in `packages/VBF/src/spectra/linear.jl`. Kept paper-local for now
# (core is frozen); the two agree wherever both can run.
"""
    linearity_streaming(s::SBox) -> Int

`linearity(s)` without materialising the LAT: one Walsh–Hadamard transform per
output mask `b`, keeping only the running maximum of `|LAT[a,b]|` over
`(a,b) ≠ (0,0)`.
"""
function linearity_streaming(s::SBox{N,T}) where {N,T}
    n = 1 << N
    lut = s.lut
    best = 0
    v = Vector{Int}(undef, n)
    @inbounds for b in 0:(n-1)
        bT = T(b)
        for x in 0:(n-1)
            v[x+1] = 1 - 2 * (count_ones(bT & lut[x+1]) & 1)
        end
        walsh_hadamard!(v)
        for a in 0:(n-1)
            (a == 0 && b == 0) && continue
            t = abs(v[a+1])
            t > best && (best = t)
        end
    end
    best
end

"""
    sbox_linearity(s::SBox) -> Int

Core [`linearity`](@ref) for input sizes whose LAT fits comfortably in memory,
[`linearity_streaming`](@ref) above that. Theorem 4 is exercised at m=15, where
the `2^15 × 2^15` `Int` LAT would need 8.6 GB.
"""
sbox_linearity(s::SBox) =
    inputbits(s) <= 12 ? linearity(s) : linearity_streaming(s)

# ── Report utilities ───────────────────────────────────────────────────────────

paper_banner(io::IO = stdout) = print_banner(
    io,
    "Budaghyan, Carlet, Pott (2006): New Classes of Almost Bent and",
    "Almost Perfect Nonlinear Polynomials. IEEE Trans. IT 52(3):762–777",
)
