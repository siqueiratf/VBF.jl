# Implements paper-local helpers for Budaghyan–Carlet–Pott (2005/2006).
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: General — field utilities, trace functions, report formatting
#
# Pseudocode:
#   1. gf_trace(x, n)      = x + x^2 + x^4 + ... + x^{2^{n-1}}  ∈ {0,1}
#   2. gf_relative_trace(x, m, n) = x + x^{2^n} + x^{2^{2n}} + ... + x^{2^{(m/n−1)n}}
#   3. gold_lut(n, i)      = [x ↦ x^{2^i+1}] on GF(2^n)
#   4. boolean_alg_degree  = algebraic degree of a GF(2)-valued truth table
# VBF API used: gf_mul, gf_pow, primitive_polynomial, mobius!, SBox,
#               differential_uniformity, linearity, algebraic_degree

using VBF
using Dates

"""
    gold_lut(n, i; modulus) -> Vector{Int}

LUT for Gold function x^{2^i+1} over GF(2^n). Requires gcd(i, n) = 1.
"""
function gold_lut(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    exp = (1 << i) + 1
    [gf_pow(x, exp, n; modulus = modulus) for x in 0:(1<<n)-1]
end

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
    trace_component_tt(F_lut, n; modulus) -> Vector{Int}

Boolean truth table of x ↦ Tr(F(x)) over GF(2^n).
"""
function trace_component_tt(
    F_lut::Vector{<:Integer},
    n::Int;
    modulus::Int = primitive_polynomial(n),
)
    [gf_trace(F_lut[x+1], n; modulus = modulus) for x in 0:(1<<n)-1]
end

# ── Report utilities ───────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Budaghyan, Carlet, Pott (2006): New Classes of Almost Bent and")
    println(io, "Almost Perfect Nonlinear Polynomials. IEEE Trans. IT 52(3):762–777")
    println(io, "=" ^ 72)
end

