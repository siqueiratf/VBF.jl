# Implements paper-local helpers for the Budaghyan–Carlet–Leander (2009) reproduction.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218–4229.
# Section: General — shared LUT builders, adjoint operator, CCZ signatures, I/O.
#
# Pseudocode:
#   * build the paper's concrete APN functions (eqs 4–8) as 0-based LUTs
#   * build the three known permutation classes x + L(x³)
#   * L*  (adjoint w.r.t. the trace form) via the reverse trace-vector map
#   * ortho-derivative differential spectrum = a quadratic-APN CCZ invariant
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, gf_relative_trace, SBox,
#               ortho_derivative, differential_spectrum, sorted_pairs, print_banner

using VBF

# ── Report header ─────────────────────────────────────────────────────────────

"""Print the paper banner (title + venue)."""
function print_header(io::IO = stdout)
    print_banner(
        io,
        "Budaghyan, Carlet, Leander (2009):",
        "On a construction of quadratic APN functions",
        "Proc. IEEE Information Theory Workshop (ITW) 2009, pp. 374-378",
    )
end

# ── Field-element conventions ─────────────────────────────────────────────────

# α = 2 is a root of the primitive modulus returned by primitive_polynomial(n),
# hence a generator of GF(2ⁿ)* (a primitive element in the paper's sense).
primitive_element(::Integer) = 2

_mod(n::Integer) = primitive_polynomial(n)

# ── Concrete APN functions from the paper (0-based LUTs) ──────────────────────

"""
    apn_eq6(n, a; modulus) -> Vector{Int}

Eq. (6) `x³ + a⁻¹·trₙ(a³·x⁹)`. With `a = 1` this is the base function
`x³ + trₙ(x⁹)` of ref. [3]. Budaghyan–Carlet–Leander (2009), Corollary 3.
"""
function apn_eq6(n::Integer, a::Integer = 1; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    ai = gf_inv(a, n; modulus)
    a3 = gf_pow(a, 3, n; modulus)
    out = Vector{Int}(undef, N)
    for x = 0:(N-1)
        x3 = gf_pow(x, 3, n; modulus)
        x9 = gf_pow(x, 9, n; modulus)
        t = gf_trace(gf_mul(a3, x9, n; modulus), n; modulus)
        out[x+1] = x3 ⊻ gf_mul(ai, t, n; modulus)
    end
    out
end

"""
    apn_eq7(n, a; modulus) -> Vector{Int}

Eq. (7) `x³ + a⁻¹·trₙ³(a⁶·x¹⁸ + a¹²·x³⁶)`; with `a=1` this is eq. (4)
`x³ + trₙ³(x¹⁸ + x³⁶)`. Budaghyan–Carlet–Leander (2009), Corollary 3 / 1.
"""
function apn_eq7(n::Integer, a::Integer = 1; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    ai = gf_inv(a, n; modulus)
    a6 = gf_pow(a, 6, n; modulus)
    a12 = gf_pow(a, 12, n; modulus)
    out = Vector{Int}(undef, N)
    for x = 0:(N-1)
        x3 = gf_pow(x, 3, n; modulus)
        x18 = gf_pow(x, 18, n; modulus)
        x36 = gf_pow(x, 36, n; modulus)
        inner = gf_mul(a6, x18, n; modulus) ⊻ gf_mul(a12, x36, n; modulus)
        t = gf_relative_trace(inner, n, 3; modulus)
        out[x+1] = x3 ⊻ gf_mul(ai, t, n; modulus)
    end
    out
end

"""
    apn_eq8(n, a; modulus) -> Vector{Int}

Eq. (8) `x³ + a⁻¹·trₙ³(a³·x⁹ + a⁶·x¹⁸)`; with `a=1` this is eq. (5)
`x³ + trₙ³(x⁹ + x¹⁸)`. Budaghyan–Carlet–Leander (2009), Corollary 3 / 1.
"""
function apn_eq8(n::Integer, a::Integer = 1; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    ai = gf_inv(a, n; modulus)
    a3 = gf_pow(a, 3, n; modulus)
    a6 = gf_pow(a, 6, n; modulus)
    out = Vector{Int}(undef, N)
    for x = 0:(N-1)
        x3 = gf_pow(x, 3, n; modulus)
        x9 = gf_pow(x, 9, n; modulus)
        x18 = gf_pow(x, 18, n; modulus)
        inner = gf_mul(a3, x9, n; modulus) ⊻ gf_mul(a6, x18, n; modulus)
        t = gf_relative_trace(inner, n, 3; modulus)
        out[x+1] = x3 ⊻ gf_mul(ai, t, n; modulus)
    end
    out
end

# eqs (4),(5) are the a=1 specialisations of (7),(8).
apn_eq4(n::Integer; modulus::Integer = _mod(n)) = apn_eq7(n, 1; modulus)
apn_eq5(n::Integer; modulus::Integer = _mod(n)) = apn_eq8(n, 1; modulus)

# ── The three known permutation classes  x + L(x³)  (Section II.A) ─────────────

"""
    L_class_lut(cls, n; modulus) -> Vector{Int}

Full LUT of the linear map `L` for the three permutation classes of the paper:
`:trace` → `L(y)=trₙ(y)`, `:class2` → `L(y)=trₙ³(y⁴+y²)`, `:class3` →
`L(y)=trₙ³(y+y²)`. Budaghyan–Carlet–Leander (2009), Section II.A.
"""
function L_class_lut(cls::Symbol, n::Integer; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    out = Vector{Int}(undef, N)
    for y = 0:(N-1)
        if cls === :trace
            out[y+1] = gf_trace(y, n; modulus)
        elseif cls === :class2
            z = gf_pow(y, 4, n; modulus) ⊻ gf_pow(y, 2, n; modulus)
            out[y+1] = gf_relative_trace(z, n, 3; modulus)
        elseif cls === :class3
            z = y ⊻ gf_pow(y, 2, n; modulus)
            out[y+1] = gf_relative_trace(z, n, 3; modulus)
        else
            throw(ArgumentError("L_class_lut: unknown class $(repr(cls))"))
        end
    end
    out
end

"""Apply a linear map given as a full LUT."""
apply_L(Llut::Vector{Int}, y::Integer) = Llut[Int(y)+1]

"""
    perm_from_L(Llut, n; modulus) -> Vector{Int}

LUT of `x + L(x³)` (the candidate permutation). Budaghyan–Carlet–Leander (2009),
Section II.A.
"""
function perm_from_L(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    [x ⊻ apply_L(Llut, gf_pow(x, 3, n; modulus)) for x = 0:(N-1)]
end

"""
    apn_from_L(Llut, n; modulus) -> Vector{Int}

LUT of `F(x³) = x³ + L(x⁹)`, the APN output of Proposition 1.
Budaghyan–Carlet–Leander (2009), Proposition 1.
"""
function apn_from_L(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    [gf_pow(x, 3, n; modulus) ⊻ apply_L(Llut, gf_pow(x, 9, n; modulus)) for x = 0:(N-1)]
end

"""
    apn_corollary2(n, a, b, Llut; modulus) -> Vector{Int}

LUT of `a·x³ + L(a³·x⁹ + a²b·x⁶ + ab²·x³)`, Budaghyan–Carlet–Leander (2009),
Corollary 2 (APN whenever `x + L(x³)` is a permutation, `n` even).
"""
function apn_corollary2(
    n::Integer,
    a::Integer,
    b::Integer,
    Llut::Vector{Int};
    modulus::Integer = _mod(n),
)
    N = 1 << Int(n)
    a2 = gf_pow(a, 2, n; modulus)
    a3 = gf_pow(a, 3, n; modulus)
    b2 = gf_pow(b, 2, n; modulus)
    a2b = gf_mul(a2, b, n; modulus)
    ab2 = gf_mul(a, b2, n; modulus)
    out = Vector{Int}(undef, N)
    for x = 0:(N-1)
        x3 = gf_pow(x, 3, n; modulus)
        x6 = gf_pow(x, 6, n; modulus)
        x9 = gf_pow(x, 9, n; modulus)
        inner =
            gf_mul(a3, x9, n; modulus) ⊻ gf_mul(a2b, x6, n; modulus) ⊻
            gf_mul(ab2, x3, n; modulus)
        out[x+1] = gf_mul(a, x3, n; modulus) ⊻ apply_L(Llut, inner)
    end
    out
end

# ── Adjoint linear operator w.r.t. the trace form (Prop. 5/6) ─────────────────

"""
    adjoint_lut(Llut, n; modulus) -> Vector{Int}

The adjoint `L*` of a linear map `L` (given as a full LUT) w.r.t. the trace
bilinear form: the unique linear map with `trₙ(x·L(y)) = trₙ(L*(x)·y)` for all
`x,y`. Computed by inverting the (nondegenerate) trace-vector map
`c ↦ (trₙ(c·eⱼ))ⱼ`. Budaghyan–Carlet–Leander (2009), Propositions 5–6.
"""
function adjoint_lut(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    nn = Int(n)
    N = 1 << nn
    # rev[tracevector+1] = c, the element whose trace-vector is that pattern.
    rev = fill(-1, N)
    for c = 0:(N-1)
        tv = 0
        for j = 0:(nn-1)
            tv |= gf_trace(gf_mul(c, 1 << j, n; modulus), n; modulus) << j
        end
        rev[tv+1] = c
    end
    adj = Vector{Int}(undef, N)
    for x = 0:(N-1)
        phi = 0
        for j = 0:(nn-1)
            lej = apply_L(Llut, 1 << j)                # L(eⱼ)
            phi |= gf_trace(gf_mul(x, lej, n; modulus), n; modulus) << j
        end
        adj[x+1] = rev[phi+1]
    end
    adj
end

# ── APN / CCZ helpers ─────────────────────────────────────────────────────────

"""Wrap a 0-based LUT into an SBox on GF(2ⁿ)."""
as_sbox(lut::Vector{Int}, n::Integer) = SBox{Int(n)}(lut)

"""`true` iff the LUT is APN (differential uniformity 2)."""
is_apn_lut(lut::Vector{Int}, n::Integer) = differential_uniformity(as_sbox(lut, n)) == 2

"""
    od_signature(F::SBox) -> Union{Vector, Nothing}

Ortho-derivative differential spectrum, a fast CCZ/EA invariant for *quadratic*
APN functions (Canteaut–Couvreur–Perrin 2022; Yoshiara 2012: quadratic
CCZ ⟺ EA). Distinct signatures ⇒ CCZ-inequivalent. `nothing` if `F` is not a
quadratic APN.
"""
function od_signature(F::SBox)
    od = ortho_derivative(F)
    od === nothing && return nothing
    sorted_pairs(differential_spectrum(od))
end
od_signature(lut::Vector{Int}, n::Integer) = od_signature(as_sbox(lut, n))
