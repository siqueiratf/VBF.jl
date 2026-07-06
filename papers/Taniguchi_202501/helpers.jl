# Implements paper-local helpers for the Taniguchi et al. (2025) reproduction.
# Paper: Taniguchi, Polujan, Pott, Arshad (2025),
#        "Changing APN functions on affine subspaces of small codimensions"
# Section: General — shared helpers
#
# VBF API used: gf_mul, gf_pow, gf_trace, gf_relative_trace,
#               print_banner, print_section, print_check, print_kv

using VBF
using Dates

function print_header(io::IO = stdout)
    print_banner(io,
        "Taniguchi, Polujan, Pott, Arshad (2025)",
        "Changing APN functions on affine subspaces of small codimensions",
        "Julia $(VERSION)  |  $(today())")
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]   Theorem 3.2: H-equiv characterization (n=4,5)")
    println(io, "  [exact]   Example 3.3: valid L counts (n=4: 448, n=5: 4608)")
    println(io, "  [exact]   Table 3.1: 13 linearized polynomials, APN + EA-class")
    println(io, "  [exact]   Theorem 3.7: exponential sum criterion")
    println(io, "  [exact]   Example 4.2: codim-2 APN on GF(2^8)")
    println(io, "  [loaded]  Γ-ranks 13842/11818 (Magma, paper claim)")
    println(io)
end

const PAPER_MODULUS_6 = 91   # α^6 + α^4 + α^3 + α + 1 = conway_polynomial(6)
const PAPER_MODULUS_8 = 285  # α^8 + α^4 + α^3 + α^2 + 1 = conway_polynomial(8)

function paper_modulus(n::Int)
    n == 6 && return PAPER_MODULUS_6
    n == 8 && return PAPER_MODULUS_8
    return conway_polynomial(n)
end

"""
Evaluate linearized polynomial L(x) = Σᵢ coeffs[i+1] · x^{2^i} over GF(2^n).
"""
function linearized_poly_eval(coeffs::Vector{Int}, x::Int, n::Int, mod::Int)
    acc = 0
    xi = x
    for i in 1:length(coeffs)
        if coeffs[i] != 0
            acc ⊻= gf_mul(coeffs[i], xi, n; modulus=mod)
        end
        if i < length(coeffs)
            xi = gf_mul(xi, xi, n; modulus=mod)
        end
    end
    acc
end

"""
Build full LUT for linearized polynomial over GF(2^n).
"""
function linearized_poly_lut(coeffs::Vector{Int}, n::Int, mod::Int)
    N = 1 << n
    lut = Vector{Int}(undef, N)
    for x in 0:N-1
        lut[x+1] = linearized_poly_eval(coeffs, x, n, mod)
    end
    lut
end

"""
B_F(x, a) for F(x) = x^3 (Gold): B_F(x,a) = x²·a + x·a².
"""
function bilinear_form_gold(x::Int, a::Int, n::Int, mod::Int)
    x2 = gf_mul(x, x, n; modulus=mod)
    a2 = gf_mul(a, a, n; modulus=mod)
    gf_mul(x2, a, n; modulus=mod) ⊻ gf_mul(x, a2, n; modulus=mod)
end

"""
All elements of trace-zero hyperplane T₀ = {x ∈ GF(2^n) : Tr(x) = 0}.
"""
function trace_zero_elements(n::Int, mod::Int)
    N = 1 << n
    [x for x in 0:N-1 if gf_trace(x, n; modulus=mod) == 0]
end

"""
Fixed element e₀ with Tr(e₀) = 1.
"""
function trace_one_element(n::Int, mod::Int)
    N = 1 << n
    for x in 1:N-1
        gf_trace(x, n; modulus=mod) == 1 && return x
    end
    error("no trace-one element found")
end

"""
Build LUT for G(x) = F(x) + Tr(x)·L(x).
"""
function build_g_lut(F_lut::Vector{Int}, L_coeffs::Vector{Int}, n::Int, mod::Int)
    N = 1 << n
    lut = Vector{Int}(undef, N)
    for x in 0:N-1
        fx = F_lut[x+1]
        tr = gf_trace(x, n; modulus=mod)
        if tr == 0
            lut[x+1] = fx
        else
            lut[x+1] = fx ⊻ linearized_poly_eval(L_coeffs, x, n, mod)
        end
    end
    lut
end

"""
α^exp in GF(2^n), where α = 2 (primitive element).
"""
alpha_power(exp::Int, n::Int, mod::Int) = gf_pow(2, exp, n; modulus=mod)

# ── Table 3.1 data (shared across table3_1.jl, theorem3_7.jl) ──────────────

# Coefficients as α-powers; nothing = zero coefficient.
# L_i(x) = Σⱼ α^{aⱼ} · x^{2^j}, j = 0..5
const TABLE_3_1_RAW = [
    ("G1",  [nothing, nothing, nothing, nothing, nothing, nothing], "D1"),
    ("G2",  [42, 3, 34, 59, 59, 12],                              "D10"),
    ("G3",  [18, 60, 17, 4, 17, 4],                               "D2"),
    ("G4",  [18, 60, 57, 7, 32, 62],                              "D3"),
    ("G5",  [42, 1, 29, 55, 9, 56],                               "D5"),
    ("G6",  [42, 21, nothing, 4, 48, 16],                         "D6"),
    ("G7",  [42, 19, 51, 59, 26, 38],                             "D7"),
    ("G8",  [42, 19, 60, 11, 25, 13],                             "D12"),
    ("G9",  [42, 21, 22, 31, 15, 61],                             "D13"),
    ("G10", [42, 47, 35, 54, 23, 27],                             "D8"),
    ("G11", [42, 21, 23, 32, 14, 51],                             "D11"),
    ("G12", [42, 21, 4, 56, 17, 20],                              "D4"),
    ("G13", [42, 21, nothing, 27, 34, 52],                        "D9"),
]

"""
Convert Table 3.1 α-power coefficients to field element coefficient vectors.
"""
function table3_1_coefficients(n::Int = 6, mod::Int = PAPER_MODULUS_6)
    entries = []
    for (name, powers, dk) in TABLE_3_1_RAW
        coeffs = Int[p === nothing ? 0 : alpha_power(p, n, mod) for p in powers]
        push!(entries, (name=name, coeffs=coeffs, dillon=dk))
    end
    entries
end
