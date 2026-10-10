# Implements Theorem 7.2 — Gologlu biprojective APN families F1, F2.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 7 — Theorem 7.2 ([41] = Gologlu)
#
# Theorem 7.2: APN on F_{2^{2m}}:
#   F1(x,y) = (x^{2^i+1}+xy^{2^i}+y^{2^i+1}, x^{2^{2i}+1}+x^{2^{2i}}y+y^{2^{2i}+1})
#             if gcd(3i,m)=1;
#   F2(x,y) = (x^{2^i+1}+xy^{2^i}+y^{2^i+1}, x^{2^{3i}}y+xy^{2^{3i}})
#             if gcd(3i,m)=1 and m odd.
#
# Pseudocode: build both families via biprojective_sbox (Gologlu_202207 helper)
# at the smallest affordable parameters and assert differential uniformity 2:
#   F1 at (m=4, i=1) n=8 and (m=5, i=1) n=10;
#   F2 at (m=5, i=1) and (m=5, i=2) n=10.
# Also prints informational probes outside the hypotheses (not asserted, the
# conditions are sufficient, not claimed necessary).
# VBF API used: differential_uniformity, algebraic_degree, print_section,
#               print_check, print_kv
# Reuses biprojective_sbox from the Gologlu_202207 reproduction.

include(joinpath(@__DIR__, "..", "..", "2022", "Gologlu_202207", "helpers.jl"))
include(joinpath(@__DIR__, "helpers.jl"))

_gologlu_f1(m, i; modulus) =
    biprojective_sbox(m, i, (1, 0, 1, 1), 2i, (1, 1, 0, 1); modulus = modulus)
_gologlu_f2(m, i; modulus) =
    biprojective_sbox(m, i, (1, 0, 1, 1), 3i, (0, 1, 1, 0); modulus = modulus)

"""
    theorem7_2_report([io]) -> NamedTuple

Verify Theorem 7.2: Gologlu F1 is APN at (m=4,i=1) and (m=5,i=1);
Gologlu F2 is APN at (m=5,i=1) and (m=5,i=2).
"""
function theorem7_2_report(io::IO = stdout)
    print_section("Theorem 7.2 — Gologlu biprojective families F1, F2", io)

    all_ok = true
    for (m, i) in ((4, 1), (5, 1))
        gcd(3i, m) == 1 || error("invalid parameters (m=$m, i=$i)")
        F  = _gologlu_f1(m, i; modulus = primitive_polynomial(m))
        ok = (differential_uniformity(F) == 2)
        all_ok &= ok
        print_check("F1 (m=$m, i=$i, n=$(2m), gcd(3i,m)=1) is APN", ok, io)
    end
    for (m, i) in ((5, 1), (5, 2))
        (gcd(3i, m) == 1 && isodd(m)) || error("invalid parameters (m=$m, i=$i)")
        F  = _gologlu_f2(m, i; modulus = primitive_polynomial(m))
        ok = (differential_uniformity(F) == 2)
        all_ok &= ok
        print_check("F2 (m=$m, i=$i, n=$(2m), m odd, gcd(3i,m)=1) is APN", ok, io)
    end

    # informational probes outside the hypotheses (not part of all_ok)
    du_f1_bad = differential_uniformity(
        _gologlu_f1(3, 1; modulus = primitive_polynomial(3)))   # gcd(3,3)=3
    du_f2_bad = differential_uniformity(
        _gologlu_f2(4, 1; modulus = primitive_polynomial(4)))   # m even
    print_kv("probe: F1 (m=3,i=1, gcd(3i,m)=3) differential uniformity", du_f1_bad, io)
    print_kv("probe: F2 (m=4,i=1, m even) differential uniformity", du_f2_bad, io)

    print_kv("completeness", "spot-checks at n=8,10 (Thm 7.2 conditions are sufficient)", io)
    (; all_ok, du_f1_bad, du_f2_bad)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem7_2_report()
end
