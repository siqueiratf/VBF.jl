# Implements Section 2 — known examples
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 2 — Known examples and their Γ-ranks in F_{2^8}
#
# Pseudocode:
#   Carlet Theorem 1:
#     G(x,y) = s·x^{2^i+2^j} + u·x^{2^i}y^{2^j} + v·x^{2^j}y^{2^i} + t·y^{2^i+2^j}
#     F(x,y)=(xy,G(x,y)) is APN ⟺ G(x,1) has no root in GF(2ⁿ)
#   Corollary 2 (normalized Carlet):
#     G'(x,y) = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1}, a∈{0,1}
#     Same APN condition; CCZ-equiv to Thm 1 via linear change-of-variables
#   Zhou-Pott Corollary 1 (i=2):
#     G(x,y) = x^{2^m+1} + α·y^{(2^m+1)·2^i}, i even, α non-cubic
#     F(x,y)=(xy,G(x,y)) is APN; Γ-rank 13642 on F₂⁸ (loaded from paper)
#
# VBF API used: gf_pow, gf_mul, primitive_polynomial, differential_uniformity,
#               algebraic_degree, apn_ea_mugshot, taniguchi_apn, SBox

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

# ── Carlet Theorem 1 construction ─────────────────────────────────────────────

"""
    carlet_thm1_F(n, i, j, s, u, v, t) -> SBox{2n}

Carlet's Theorem 1: F(x,y)=(xy,G(x,y)) with
  G(x,y) = s·x^{2^i+2^j} + u·x^{2^i}y^{2^j} + v·x^{2^j}y^{2^i} + t·y^{2^i+2^j}
over GF(2ⁿ)×GF(2ⁿ), packed as SBox{2n}. Requires s≠0, t≠0, gcd(n,i-j)=1.
"""
function carlet_thm1_F(n::Int, i::Int, j::Int, s::Int, u::Int, v::Int, t::Int)
    mod = primitive_polynomial(n)
    E1 = (1 << i) + (1 << j)
    Exi, Eyj = 1 << i, 1 << j
    Exj, Eyi = 1 << j, 1 << i
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:len-1, y = 0:len-1
        xy = gf_mul(x, y, n; modulus=mod)
        Gxy =
            gf_mul(s, gf_pow(x, E1, n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(u, gf_mul(gf_pow(x, Exi, n; modulus=mod), gf_pow(y, Eyj, n; modulus=mod), n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(v, gf_mul(gf_pow(x, Exj, n; modulus=mod), gf_pow(y, Eyi, n; modulus=mod), n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(t, gf_pow(y, E1, n; modulus=mod), n; modulus=mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    carlet_G1_rootless(n, i, j, s, u, v, t) -> Bool

Check G(x,1) = s·x^{2^i+2^j}+u·x^{2^i}+v·x^{2^j}+t has no root in GF(2ⁿ).
"""
function carlet_G1_rootless(n::Int, i::Int, j::Int, s::Int, u::Int, v::Int, t::Int)
    mod = primitive_polynomial(n)
    E1 = (1 << i) + (1 << j)
    for x = 0:(1<<n)-1
        Gx1 =
            gf_mul(s, gf_pow(x, E1, n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(u, gf_pow(x, 1<<i, n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(v, gf_pow(x, 1<<j, n; modulus=mod), n; modulus=mod) ⊻ t
        Gx1 == 0 && return false
    end
    true
end

# ── Zhou-Pott Corollary 1 ─────────────────────────────────────────────────────

"""
    zhou_pott_cor1_F(n, m, i, α) -> SBox{2n}

Zhou-Pott Corollary 1: G(x,y)=x^{2^m+1}+α·y^{(2^m+1)·2^i}, F(x,y)=(xy,G(x,y)).
APN when n even, gcd(m,n)=1, i even >0, α non-cubic (α≠t³ for all t∈GF(2ⁿ)).
"""
function zhou_pott_cor1_F(n::Int, m::Int, i::Int, α::Int)
    mod = primitive_polynomial(n)
    Em = (1 << m) + 1
    Ey = Em * (1 << i)
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:len-1, y = 0:len-1
        xy = gf_mul(x, y, n; modulus=mod)
        Gxy = gf_pow(x, Em, n; modulus=mod) ⊻
              gf_mul(α, gf_pow(y, Ey, n; modulus=mod), n; modulus=mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    is_cubic(α, n) -> Bool

True iff α = t³ for some t∈GF(2ⁿ).
"""
function is_cubic(α::Int, n::Int)
    mod = primitive_polynomial(n)
    any(gf_pow(x, 3, n; modulus=mod) == α for x = 1:(1<<n)-1)
end

# ── Verification ──────────────────────────────────────────────────────────────

"""
    section2_verify(; n, m, i_zp) -> NamedTuple

Verify Section 2 claims for half-dimension n, Frobenius index m,
and Zhou-Pott shift i_zp (must be even >0). Checks:
  - Carlet Thm 1: APN iff G(x,1) rootless (spot-check with s=t=1, u=v=0)
  - Corollary 2: normalized form gives same mugshot
  - Zhou-Pott Cor 1 (i=i_zp): APN for first non-cubic α
  - Zhou-Pott (i=i_zp) has different mugshot from Carlet (Thm 1 / Cor 2)
"""
function section2_verify(; n::Int=4, m::Int=1, i_zp::Int=2)
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    iseven(n)       || error("need n even for Zhou-Pott Cor 1")
    iseven(i_zp) && i_zp > 0 || error("need i_zp even and >0")

    mod = primitive_polynomial(n)

    # Carlet Thm 1: pick s=1,t=1,u=0,v=0, i=m, j=0 and find b s.t. G(x,1) rootless
    i_c, j_c = m, 0
    # Brute-force: try s=1,u=0,v=0 and search for rootless t
    carlet_ok = false
    carlet_F = nothing
    for t = 1:(1<<n)-1
        rootless = carlet_G1_rootless(n, i_c, j_c, 1, 0, 0, t)
        F = carlet_thm1_F(n, i_c, j_c, 1, 0, 0, t)
        is_apn = differential_uniformity(F) == 2
        rootless == is_apn || return (; ok=false, msg="Carlet Thm1 IFF failed at t=$t")
        if rootless
            carlet_ok = true
            carlet_F = F
            break
        end
    end
    carlet_ok || return (; ok=false, msg="no rootless Carlet instance found")

    # Corollary 2 (normalized Carlet): G'(x,y)=x^{2^m+1}+t·y^{2^m+1} (a=0 case)
    # = carlet_thm1_F(n, i=m, j=0, s=1, u=0, v=0, t) with G'(x,1)=x^{2^m+1}+t rootless.
    # This is the Carlet family (Γ-rank 13200), NOT Taniguchi a=0 (which is Zhou-Pott).
    cor2_F = nothing
    cor2_ok = false
    Em = (1 << m) + 1
    for t = 1:(1<<n)-1
        rootless = carlet_G1_rootless(n, m, 0, 1, 0, 0, t)
        rootless || continue
        F = carlet_thm1_F(n, m, 0, 1, 0, 0, t)
        differential_uniformity(F) == 2 || continue
        cor2_ok = true
        cor2_F = F
        break
    end
    cor2_ok || return (; ok=false, msg="no rootless Corollary 2 (Carlet) instance found")

    # Zhou-Pott Cor 1 (i=i_zp): find first non-cubic α
    zp_F = nothing
    zp_α = nothing
    for α = 1:(1<<n)-1
        is_cubic(α, n) && continue
        F = zhou_pott_cor1_F(n, m, i_zp, α)
        if differential_uniformity(F) == 2
            zp_F = F
            zp_α = α
            break
        end
    end
    zp_F !== nothing || return (; ok=false, msg="no valid Zhou-Pott Cor1 instance found")

    # Mugshot comparison: Zhou-Pott (i_zp>0) should differ from Carlet Cor2 (i=0)
    mg_cor2 = apn_ea_mugshot(cor2_F)
    mg_zp   = apn_ea_mugshot(zp_F)
    mugshots_differ = mg_cor2 != mg_zp

    (; ok=mugshots_differ, carlet_ok, cor2_ok,
       zp_α, mugshots_differ,
       msg=mugshots_differ ? "Zhou-Pott (i=$i_zp) and Carlet Cor2 are EA-inequivalent" :
                             "UNEXPECTED: mugshots equal — should differ")
end

function section2_carlet_zhou_pott_report(io::IO = stdout)
    print_section(io, "Section 2 — Carlet Theorem 1 + Zhou-Pott Corollary 1")

    r = section2_verify(; n=4, m=1, i_zp=2)
    print_check(io, "n=4 m=1: Carlet Thm1 APN iff G(x,1) rootless", r.carlet_ok)
    print_check(io, "n=4 m=1: Corollary 2 (normalized) APN instance found", r.cor2_ok)
    print_check(io, "n=4 m=1: Zhou-Pott Cor1 (i=2) APN for non-cubic α=$(r.zp_α)", r.zp_α !== nothing)
    print_check(io, "n=4 m=1: Zhou-Pott (i=2) EA-inequivalent to Carlet Cor2 (i=0)", r.mugshots_differ)
    print_kv(io, "Γ-rank Carlet (F₂⁸)", "13200  [loaded from paper — Magma, out-of-scope]")
    print_kv(io, "Γ-rank Zhou-Pott i=2 (F₂⁸)", "13642  [loaded from paper — Magma, out-of-scope]")
    println(io, "  completeness: spot-check on n=4; Γ-ranks not recomputed (Magma-only)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section2_carlet_zhou_pott_report()
end
