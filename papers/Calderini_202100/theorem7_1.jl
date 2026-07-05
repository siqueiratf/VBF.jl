# Implements Theorem 7.1 — reduction of biprojective APN to forms f1-f4.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 7 — Theorem 7.1
#
# Theorem 7.1: F(x,y) = (Ax^{2^i+1}+Bx^{2^i}y+Cxy^{2^i}+Dy^{2^i+1},
#                        ax^{2^j+1}+bx^{2^j}y+cxy^{2^j}+dy^{2^j+1}) APN
# implies F is EA-equivalent to one of
#   f1 = (x^{2^i+1}+x^{2^i}y+Axy^{2^i}+By^{2^i+1}, x^{2^j+1}+ax^{2^j}y+bxy^{2^j}+cy^{2^j+1})
#   f2 = (x^{2^i+1}+xy^{2^i}+Ay^{2^i+1},           x^{2^j+1}+ax^{2^j}y+bxy^{2^j}+cy^{2^j+1})
#   f3 = (x^{2^i+1}+Ay^{2^i+1},                    x^{2^j+1}+x^{2^j}y+axy^{2^j}+by^{2^j+1})
#   f4 = (x^{2^i+1}+Ay^{2^i+1},                    x^{2^j+1}+axy^{2^j}+by^{2^j+1}), a in {0,1},
# with i,j <= m/2.
#
# Verification at m=3 (n=6, i=j=1 is the only pair with i,j <= m/2): the paper
# proves analytically (Section 7) that leading coefficients can be normalized
# to A=a=1; from there we sweep all (B,C,D,b,c,d) in GF(2^3)^6 (262,144
# functions), collect EA-mugshots of every APN instance, and check the set
# equals the mugshot union of the APN f1-f4 instances (f-forms are special
# cases of the sweep, so set equality == the Theorem 7.1 inclusion).
# The un-normalized 8-coefficient sweep (16.7M functions, est. ~10 min) is
# skipped since the normalization step is analytic, not computational.
# VBF API used: differential_uniformity, apn_ea_mugshot, APNEAMugshot,
#               print_section, print_check, print_kv
# Reuses biprojective_sbox from the Gologlu_202207 reproduction.

include(joinpath(@__DIR__, "..", "Gologlu_202207", "helpers.jl"))
include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem7_1_report([io]; m) -> NamedTuple

Verify Theorem 7.1 at n=2m (default m=3): every APN biprojective function with
normalized leading coefficients is EA-equivalent (mugshot-level) to an APN
instance of the forms f1-f4.
"""
function theorem7_1_report(io::IO = stdout; m::Int = 3)
    print_section("Theorem 7.1 — biprojective reduction to f1-f4 (m=$m, n=$(2m), i=j=1)", io)
    mod_m = primitive_polynomial(m)
    len   = 1 << m
    q     = 1

    # exhaustive normalized sweep: F = (x^3+Bx^2y+Cxy^2+Dy^3, x^3+bx^2y+cxy^2+dy^3)
    sweep_mugs = Set{APNEAMugshot}()
    apn_sweep  = 0
    for B in 0:(len - 1), C in 0:(len - 1), D in 0:(len - 1)
        for b in 0:(len - 1), c in 0:(len - 1), d in 0:(len - 1)
            F = biprojective_sbox(m, q, (1, B, C, D), q, (1, b, c, d);
                                  modulus = mod_m)
            differential_uniformity(F) == 2 || continue
            apn_sweep += 1
            push!(sweep_mugs, apn_ea_mugshot(F))
        end
    end
    print_kv("APN instances in normalized sweep (A=a=1)", apn_sweep, io)
    print_kv("distinct EA-mugshots in sweep", length(sweep_mugs), io)

    # f1-f4 mugshot union
    f_mugs = Set{APNEAMugshot}()
    f_apn  = 0
    collect_apn!(F) = if differential_uniformity(F) == 2
        f_apn += 1
        push!(f_mugs, apn_ea_mugshot(F))
    end
    for A in 0:(len - 1), B in 0:(len - 1)
        for a in 0:(len - 1), b in 0:(len - 1), c in 0:(len - 1)
            collect_apn!(biprojective_sbox(m, q, (1, 1, A, B), q, (1, a, b, c);
                                           modulus = mod_m))
        end
    end
    for A in 0:(len - 1)
        for a in 0:(len - 1), b in 0:(len - 1), c in 0:(len - 1)
            collect_apn!(biprojective_sbox(m, q, (1, 0, 1, A), q, (1, a, b, c);
                                           modulus = mod_m))
        end
        for a in 0:(len - 1), b in 0:(len - 1)
            collect_apn!(biprojective_sbox(m, q, (1, 0, 0, A), q, (1, 1, a, b);
                                           modulus = mod_m))
        end
        for a4 in 0:1, b in 0:(len - 1)
            collect_apn!(biprojective_sbox(m, q, (1, 0, 0, A), q, (1, 0, a4, b);
                                           modulus = mod_m))
        end
    end
    print_kv("APN instances among f1-f4 forms", f_apn, io)
    print_kv("distinct EA-mugshots among f1-f4", length(f_mugs), io)

    ok_subset = issubset(sweep_mugs, f_mugs)
    ok_equal  = (sweep_mugs == f_mugs)
    print_check("every normalized APN mugshot appears among f1-f4 (Theorem 7.1)",
                ok_subset, io)
    print_check("mugshot sets coincide (f-forms are sweep special cases)", ok_equal, io)

    all_ok = apn_sweep > 0 && ok_subset && ok_equal
    print_kv("completeness",
             "exhaustive over normalized coefficients at m=$m (normalization step analytic)", io)
    (; all_ok, apn_sweep, sweep_classes = length(sweep_mugs),
       f_classes = length(f_mugs), ok_subset, ok_equal)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem7_1_report()
end
