# Implements Proposition 7.5 — Kaleyski-Li family included in Gologlu F2.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 7 — Proposition 7.5 ([Kaleyski-Li 2020, personal comm.] in [Gologlu 2020])
#
# Theorem 7.4 (Kaleyski-Li): Let (m,i) = (5+6l, 3+4l) or (7+6l, 5+4l), integer l.
#   F(x,y) = (x^{2^i+1} + x^{2^i}*y + y^{2^i+1},  x^{2^i+1} + x^2*y + x*y^2)
# is APN over F_{2^{2m}}.  (For l=0: (m,i)=(5,3), j=1.)
#
# Proposition 7.5: L(x,y) = (x^{2^{m-i}}, y) maps F to Gologlu F2 at (m, i_new=m-i).
# Proof sketch: F_1^{2^{m-i}} = x^{5}+xy^4+y^5 = Gologlu F2 first component (i_new=2,m=5).
#
# Pseudocode:
#   1. Build F_KL = Kaleyski-Li at (m=5, i=3, j=1)
#   2. Build F_G2 = Gologlu F2 at (m=5, i=2) using biprojective_sbox from Gologlu_202207
#   3. Verify apn_ea_mugshot(F_KL) == apn_ea_mugshot(F_G2)
# VBF API used: gf_mul, gf_pow, differential_uniformity, apn_ea_mugshot,
#               print_section, print_check, print_kv

# Gologlu helpers first: both files define print_header and ours must win.
include(joinpath(@__DIR__, "..", "202207-gologlu-biprojective-apns", "helpers.jl"))
include(joinpath(@__DIR__, "helpers.jl"))

"""
    kaleyski_li_sbox(m, i, j; modulus) -> SBox{2m}

Kaleyski-Li biprojective APN (Theorem 7.4):
  F(x,y) = (x^{2^i+1} + x^{2^i}*y + y^{2^i+1},  x^{2^j}*y + x*y^{2^j})
over GF(2^m) x GF(2^m).
For (m,i,j) = (5,3,1): APN with (2^{m-i})-image = Gologlu F2.
"""
function kaleyski_li_sbox(m::Int, i::Int, j::Int;
                           modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei1 = (1 << i) + 1
    Ei  = 1 << i
    Ej  = 1 << j
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        f1 = gf_pow(x, Ei1, n; modulus = mod) ⊻
             gf_mul(gf_pow(x, Ei, n; modulus = mod), y, n; modulus = mod) ⊻
             gf_pow(y, Ei1, n; modulus = mod)
        f2 = gf_mul(gf_pow(x, Ej, n; modulus = mod), y, n; modulus = mod) ⊻
             gf_mul(x, gf_pow(y, Ej, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = f1 | (f2 << n)
    end
    SBox{2n}(lut)
end

"""
    proposition7_5_report([io]) -> NamedTuple

Verify Proposition 7.5: Kaleyski-Li (m=5,i=3,j=1) is EA-equiv to Gologlu F2 (m=5,i=2).
Requires n=10 computation (1024-element SBox). Optional — set skip=false to run.
"""
function proposition7_5_report(io::IO = stdout; skip::Bool = true)
    print_section("Proposition 7.5 — Kaleyski-Li subset of Gologlu F2", io)
    println(io, "  F_KL(x,y) = (x^9+x^8*y+y^9, x^2*y+x*y^2)  [m=5,i=3,j=1]")
    println(io, "  F_G2 = Gologlu F2(m=5,i=2) via biprojective_sbox")
    println(io, "  L(x,y)=(x^4,y) maps F_KL to F_G2 (Proposition 7.5 proof)")

    if skip
        println(io, "  [skip] n=10 SBox computation omitted by default (skip=true)")
        println(io, "         run proposition7_5_report(skip=false) to execute")
        return (; all_ok = nothing, skipped = true)
    end

    m   = 5
    mod_m = primitive_polynomial(m)

    F_KL = kaleyski_li_sbox(m, 3, 1; modulus = mod_m)
    F_G2 = biprojective_sbox(m, 2, (1, 0, 1, 1), 3 * 2, (0, 1, 1, 0); modulus = mod_m)

    du_kl = differential_uniformity(F_KL)
    du_g2 = differential_uniformity(F_G2)
    ok_apn = (du_kl == 2) && (du_g2 == 2)
    print_check("both F_KL and F_G2 are APN", ok_apn, io)

    mg_kl = apn_ea_mugshot(F_KL)
    mg_g2 = apn_ea_mugshot(F_G2)
    ok_eq = (mg_kl == mg_g2)
    print_check("F_KL EA-equiv F_G2 (mugshots match)", ok_eq, io)

    all_ok = ok_apn && ok_eq
    print_kv("completeness", "exhaustive (n=10, 1024-element SBox)", io)
    (; all_ok, skipped = false)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition7_5_report(skip = false)
end
