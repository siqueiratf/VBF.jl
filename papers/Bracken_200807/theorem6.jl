# Implements Theorem 6 — CCZ equivalence and coding theory consequences.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: 5 — CCZ equivalence and coding theory
#
# Pseudocode:
#   Theorem 6 (thm:code-ccz): f CCZ-equivalent to g iff [C_f] = [C_g]  (Dillon, proved here).
#   Computational consequences at n=6:
#     1. Walsh spectra of Family 1 and Family 2 equal Gold x^3 spectrum.
#     2. Family 1 (n=6) CCZ-equiv to Dillon T1 = x^3 + θ^{11}x^6 + θx^9.
#     3. Family 2 (v≠0, n=6) CCZ-equiv to Dillon T2 = x^3 + θx^{24} + x^{10}.
#     4. Family 2 (v=0, n=6) CCZ-equiv to Gold x^3  (binomials from [2]).
#     5. Family 1 and Family 2 (v≠0) are NOT CCZ-equivalent to Gold (power mapping).
# VBF API used: SBox, absolute_walsh_spectrum, are_ccz_equivalent, gold_apn,
#               differential_uniformity

include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))


"""
    dillon_T1(; modulus) -> SBox

Dillon's APN trinomial T1 on GF(64): F(x) = x^3 + θ^{11}·x^6 + θ·x^9, θ=2 (primitive).
Listed in Dillon (2006) Banff slides [ref. 7]; CCZ-class representative for Family 1 (n=6).
Uses the primitive polynomial (x^6+x+1); APN under both primitive and Conway polynomials.
"""
function dillon_T1(; modulus::Int = primitive_polynomial(6))
    n, θ  = 6, 2
    θ11   = gf_pow(θ, 11, n; modulus)
    SBox([gf_pow(x, 3, n; modulus) ⊻
          gf_mul(θ11, gf_pow(x, 6, n; modulus), n; modulus) ⊻
          gf_mul(θ,   gf_pow(x, 9, n; modulus), n; modulus)
          for x in 0:(1 << n) - 1])
end

"""
    dillon_T2() -> SBox

Dillon's APN trinomial T2 on GF(64): F(x) = x^3 + θ·x^{24} + x^{10}, θ=2 (primitive).
Listed in Dillon (2006) Banff slides [ref. 7]; CCZ-class representative for Family 2 v≠0 (n=6).
Must be built under the Conway polynomial x^6+x^4+x^3+x+1 — it is not APN under x^6+x+1.
"""
function dillon_T2()
    n, θ, m = 6, 2, conway_polynomial(6)
    SBox([gf_pow(x, 3, n; modulus=m) ⊻
          gf_mul(θ, gf_pow(x, 24, n; modulus=m), n; modulus=m) ⊻
          gf_pow(x, 10, n; modulus=m)
          for x in 0:(1 << n) - 1])
end


function theorem6_report(io::IO = stdout)
    print_section("Theorem 6 — CCZ ↔ code equivalence + Walsh spectrum (Section 5)", io)
    println(io, "  Theorem 6 (Dillon, proved in paper): f CCZ-equiv g iff [C_f]=[C_g].")
    println(io, "  Computational consequences verified at n=6:")
    println(io)

    n       = 6
    modulus = primitive_polynomial(n)
    gold    = gold_apn(n, 1)     # Gold x^3 on GF(64)
    gold_ws = absolute_walsh_spectrum(gold)

    T1      = dillon_T1(; modulus)
    T2      = dillon_T2()          # uses Conway poly internally — see dillon_T2 docstring

    F1      = theorem1_sbox(3, 1, [0, 0]; modulus)              # Family 1 trinomial
    F2_0    = theorem3_sbox(2, 1, 0)                            # Family 2 v=0 (binomial)
    F2_v    = theorem3_sbox(2, 1, 1)                            # Family 2 v≠0 (trinomial)

    # ── APN sanity checks ──────────────────────────────────────────────────────
    println(io, "  Dillon trinomial APN checks (n=6):")
    t1_apn = differential_uniformity(T1) == 2
    t2_apn = differential_uniformity(T2) == 2
    print_check("Dillon T1 = x^3+θ^{11}x^6+θx^9 is APN on GF(64)", t1_apn, io)
    print_check("Dillon T2 = x^3+θx^{24}+x^{10}  is APN on GF(64)", t2_apn, io)
    println(io)

    # ── Walsh spectrum checks (paper: "same as Gold x^3, at least for F_{64}") ─
    println(io, "  Walsh spectrum equality to Gold x^3 (n=6):")
    ws_T1   = absolute_walsh_spectrum(T1) == gold_ws
    ws_T2   = absolute_walsh_spectrum(T2) == gold_ws
    ws_F1   = absolute_walsh_spectrum(F1) == gold_ws
    ws_F2_0 = absolute_walsh_spectrum(F2_0) == gold_ws
    ws_F2_v = absolute_walsh_spectrum(F2_v) == gold_ws
    print_check("Dillon T1 Walsh spectrum = Gold", ws_T1, io)
    print_check("Dillon T2 Walsh spectrum = Gold", ws_T2, io)
    print_check("Family 1 trinomial Walsh spectrum = Gold", ws_F1, io)
    print_check("Family 2 v=0 (binomial) Walsh spectrum = Gold", ws_F2_0, io)
    print_check("Family 2 v≠0 trinomial Walsh spectrum = Gold", ws_F2_v, io)
    println(io)

    # ── CCZ equivalence checks ──────────────────────────────────────────────────
    println(io, "  CCZ-equivalence checks (n=6, both sides quadratic APN → CCZ=EA via ortho-deriv):")
    ccz_F1_T1   = are_ccz_equivalent(F1, T1)
    ccz_F2v_T2  = are_ccz_equivalent(F2_v, T2)
    ccz_F2_0_G  = are_ccz_equivalent(F2_0, gold)
    ccz_F1_G    = are_ccz_equivalent(F1, gold)
    ccz_F2v_G   = are_ccz_equivalent(F2_v, gold)
    ccz_T1_T2   = are_ccz_equivalent(T1, T2)
    print_check("Family 1 CCZ-equiv Dillon T1  (paper claim)", ccz_F1_T1, io)
    print_check("Family 2 v≠0 CCZ-equiv Dillon T2 (paper claim)", ccz_F2v_T2, io)
    print_check("Family 2 v=0 CCZ-equiv Gold x^3 (binomial from [2])", ccz_F2_0_G, io)
    print_check("Family 1 NOT CCZ-equiv Gold  (not a power mapping CCZ class)", !ccz_F1_G, io)
    print_check("Family 2 v≠0 NOT CCZ-equiv Gold", !ccz_F2v_G, io)
    print_check("Dillon T1 and T2 are in distinct CCZ classes (not equiv)", !ccz_T1_T2, io)
    println(io)

    all_pass = t1_apn & t2_apn & ws_T1 & ws_T2 & ws_F1 & ws_F2_0 & ws_F2_v &
               ccz_F1_T1 & ccz_F2v_T2 & ccz_F2_0_G & !ccz_F1_G & !ccz_F2v_G & !ccz_T1_T2
    print_check("All Theorem 6 checks pass", all_pass, io)
    print_kv("completeness",
             "Walsh+CCZ exhaustive for n=6; general CCZ proof via code equiv out of scope (Magma)", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
