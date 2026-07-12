# Implements paper-local helpers for the Budaghyan–Carlet–Leander (2009) reproduction.
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: General — shared LUT builders, explicit-graph CCZ map, formatting
#
# helpers.jl carries ONLY paper-specific constructions. All field arithmetic,
# spectra, invariants, equivalence tests and report emitters come from VBF.
#
# VBF API used: SBox, gf_pow, gf_mul, gf_trace, gf_relative_trace,
#               primitive_polynomial, ortho_derivative, differential_spectrum

using VBF

# ── Report header (only the banner text is paper-specific) ───────────────────

"""Print paper title, authors, and venue via the core banner emitter."""
function print_header(io::IO = stdout)
    print_banner(
        io,
        "Budaghyan, Carlet, Leander (2009):",
        "Constructing new APN functions from known ones",
        "Finite Fields Appl. 15 (2009) 150–159",
    )
end

# ── Paper-specific LUT builders ──────────────────────────────────────────────

"""
    gold_plus_trace(n, base_exp, trace_exp; modulus) -> SBox{n}

Build `x^{base_exp} + tr(x^{trace_exp})` over `GF(2ⁿ)`. The absolute trace lands
in `GF(2)`, so it flips the low bit (adds the field element `1`). This is the
paper's core construction shape (Corollary 1: `3, 9`; §2.1: `5, 3` and `9, 3`).
"""
function gold_plus_trace(
    n::Integer,
    base_exp::Integer,
    trace_exp::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    nn = Int(n)
    SBox{nn}([
        gf_pow(x, base_exp, nn; modulus = modulus) ⊻
        gf_trace(gf_pow(x, trace_exp, nn; modulus = modulus), nn; modulus = modulus)
        for x = 0:((1 << nn) - 1)
    ])
end

"""
    apn_x3_tr_x9(n; modulus) -> SBox{n}

The flagship function `F(x) = x³ + tr(x⁹)` of Corollary 1, APN for every `n`.
"""
apn_x3_tr_x9(n::Integer; modulus::Integer = primitive_polynomial(n)) =
    gold_plus_trace(n, 3, 9; modulus = modulus)

# ── Boolean-difference φ_F(x,a) = F(x)+F(x+a)+F(a)+F(0) ───────────────────────

"""
    phi(F::SBox{N}, a) -> Vector{Int}

The second-order difference `φ_F(x,a) = F(x)+F(x+a)+F(a)+F(0)`, indexed by `x`
(0-based). Used to check the Theorem 1 / Theorem 2 conditions on `ℓ_a`.
"""
function phi(F::SBox{N}, a::Integer) where {N}
    lut = F.lut
    F0 = lut[1]
    Fa = lut[a + 1]
    [lut[x + 1] ⊻ lut[(x ⊻ a) + 1] ⊻ Fa ⊻ F0 for x = 0:((1 << N) - 1)]
end

# ── Explicit-graph CCZ map (Proposition 1(3), Proposition 3) ─────────────────

"""
    graph_affine_map(F::SBox{N}, corr) -> Union{SBox{N},Nothing}

Apply the affine automorphism `L(x,y) = (x + corr(y), y)` of `GF(2ⁿ)²` to the
graph `G_F = {(x, F(x))}` and reconstruct the resulting function `F'` with
`L(G_F) = G_{F'}` (the CCZ construction used throughout the paper). Returns
`nothing` when the image is not a function graph (i.e. `L` restricted to `G_F`
is not injective in the first coordinate). `corr(y)` is a `GF(2ⁿ)` value.
"""
function graph_affine_map(F::SBox{N}, corr) where {N}
    len = 1 << N
    out = fill(-1, len)
    @inbounds for x = 0:(len - 1)
        y = F.lut[x + 1]
        u = x ⊻ Int(corr(y))
        out[u + 1] == -1 || return nothing
        out[u + 1] = y
    end
    any(==(-1), out) && return nothing
    SBox{N}(out)
end

# ── Ortho-derivative signature (CCZ-invariant for quadratic APN) ─────────────

"""
    ortho_signature(F::SBox) -> Union{Vector{Pair{Int,Int}},Nothing}

Sorted differential spectrum of the ortho-derivative of a quadratic APN `F`,
a CCZ-invariant (Canteaut–Couvreur–Perrin). Used to certify CCZ-inequivalence
at `n=8` where the Δ-rank is out of range (`delta_rank` supports `n ≤ 7`).
Returns `nothing` when the ortho-derivative is undefined.
"""
function ortho_signature(F::SBox)
    od = ortho_derivative(F)
    od === nothing && return nothing
    sort(collect(differential_spectrum(od)))
end
