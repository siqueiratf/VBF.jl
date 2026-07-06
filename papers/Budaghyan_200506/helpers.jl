# Implements paper-local helpers for Budaghyan–Carlet–Pott (2005/2006).
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: General — trace-component truth tables, boolean algebraic degree
#
# Pseudocode:
#   1. boolean_alg_degree  = algebraic degree of a GF(2)-valued truth table
#   2. trace_component_tt(F, n) = truth table of x ↦ Tr(F(x))  ∈ {0,1}
# VBF API used: gf_trace, primitive_polynomial, mobius!, print_banner,
#               print_section, print_check, print_kv

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

paper_banner(io::IO = stdout) = print_banner(
    io,
    "Budaghyan, Carlet, Pott (2006): New Classes of Almost Bent and",
    "Almost Perfect Nonlinear Polynomials. IEEE Trans. IT 52(3):762–777",
)
