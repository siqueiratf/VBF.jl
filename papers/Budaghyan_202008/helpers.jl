# Implements core helpers for isotopic shift construction.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: I (Definition I.1), VI (Equation 6)
#
# Pseudocode:
#   1. F_L(x) = F(x ⊕ L(x)) ⊕ F(x) ⊕ F(L(x))           (Def. I.1)
#   2. G_{i,L}(x) = x^{2^i}·L(x) + x·L(x)^{2^i}          (Eq. 6, same as 1 for Gold)
#   3. Tr(x) = x ⊕ x² ⊕ x⁴ ⊕ … ⊕ x^{2^{n-1}} ∈ {0,1}
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, differential_uniformity

using VBF

# ── Isotopic shift ────────────────────────────────────────────────────────────

"""
    isotopic_shift_lut(F_lut, L_lut) -> Vector{Int}

LUT of the isotopic shift F_L: F_L(x) = F(x⊕L(x)) ⊕ F(x) ⊕ F(L(x)).
"""
function isotopic_shift_lut(F_lut::Vector{<:Integer}, L_lut::Vector{<:Integer})
    N = length(F_lut)
    out = Vector{Int}(undef, N)
    for x in 0:N-1
        lx = L_lut[x+1]
        out[x+1] = F_lut[(x ⊻ lx)+1] ⊻ F_lut[x+1] ⊻ F_lut[lx+1]
    end
    out
end

# ── Linear map LUTs ───────────────────────────────────────────────────────────

"""
    zero_map_lut(n) -> Vector{Int}

LUT for the zero linear map L(x) = 0.
"""
zero_map_lut(n::Int) = zeros(Int, 1 << n)

"""
    identity_map_lut(n) -> Vector{Int}

LUT for the identity linear map L(x) = x.
"""
identity_map_lut(n::Int) = collect(0:(1<<n)-1)

"""
    linear_monomial_lut(n, j, u; modulus) -> Vector{Int}

LUT for L(x) = u·x^{2^j} over GF(2^n).
"""
function linear_monomial_lut(
    n::Int,
    j::Int,
    u::Integer;
    modulus::Int = primitive_polynomial(n),
)
    exp = 1 << j
    [gf_mul(u, gf_pow(x, exp, n; modulus = modulus), n; modulus = modulus) for x in 0:(1<<n)-1]
end

"""
    linear_trinomial_lut(n, j1, j2, a, b, c; modulus) -> Vector{Int}

LUT for L(x) = a·x^{2^j1} + b·x^{2^j2} + c·x over GF(2^n).
"""
function linear_trinomial_lut(
    n::Int,
    j1::Int,
    j2::Int,
    a::Integer,
    b::Integer,
    c::Integer;
    modulus::Int = primitive_polynomial(n),
)
    e1 = 1 << j1
    e2 = 1 << j2
    [
        gf_mul(a, gf_pow(x, e1, n; modulus = modulus), n; modulus = modulus) ⊻
        gf_mul(b, gf_pow(x, e2, n; modulus = modulus), n; modulus = modulus) ⊻
        gf_mul(c, x, n; modulus = modulus) for x in 0:(1<<n)-1
    ]
end

# ── Kernel / valence helpers ──────────────────────────────────────────────────

"""
    kernel_size(L_lut) -> Int

Number of x with L_lut[x+1] = 0 (including x=0).
"""
kernel_size(L_lut::Vector{<:Integer}) = count(==(0), L_lut)

"""
    is_2to1(L_lut) -> Bool

True when L has exactly a 1-dimensional kernel (2 preimages for each nonzero output).
"""
is_2to1(L_lut::Vector{<:Integer}) = kernel_size(L_lut) == 2

"""
    is_zero_map(lut) -> Bool
"""
is_zero_map(lut::Vector{<:Integer}) = all(==(0), lut)

# ── GF arithmetic helpers ─────────────────────────────────────────────────────

"""
    find_c_for_d(d, n; modulus) -> Int

Return any c ∈ GF(2^n) with c² ⊕ c = d (Artin–Schreier equation).
Throws if no solution exists.
"""
function find_c_for_d(d::Integer, n::Int; modulus::Int = primitive_polynomial(n))
    for c in 0:(1<<n)-1
        gf_pow(c, 2, n; modulus = modulus) ⊻ c == d && return c
    end
    error("find_c_for_d: no solution for d=$d in GF(2^$n)")
end

"""
    gold_lut(n, i; modulus) -> Vector{Int}

LUT for Gold function G_i(x) = x^{2^i+1} over GF(2^n).  Requires gcd(i,n)=1.
"""
function gold_lut(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    exp = (1 << i) + 1
    [gf_pow(x, exp, n; modulus = modulus) for x in 0:(1<<n)-1]
end

# ── Report utilities ──────────────────────────────────────────────────────────

function print_header(io::IO, title::String, n::Int, mod::Int)
    println(io, "=" ^ 64)
    println(io, "Paper: Budaghyan et al. (2020) — Constructing APN Functions")
    println(io, "       Through Isotopic Shifts. IEEE Trans. IT 66(8):5299-5309")
    println(io, "Field: GF(2^$n),  modulus = 0x$(string(mod, base=16))")
    println(io, "Julia: $(VERSION),  date: $(Dates.today())")
    println(io, "-" ^ 64)
    println(io, title)
    println(io, "=" ^ 64)
end

function print_check(io::IO, desc::String, passed::Bool)
    tag = passed ? "[PASS]" : "[FAIL]"
    println(io, "  $tag $desc")
    passed || error("Check failed: $desc")
end

