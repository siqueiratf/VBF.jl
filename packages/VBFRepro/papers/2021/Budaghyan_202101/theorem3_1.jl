# Implements Theorem 3.1 and Tables 1 & 3.
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
# Section: 3.1 — Generalized linear shift; 3.2 — n=8; 3.4 — n=9
#
# Pseudocode:
#   Theorem 3.1:
#     Given n=km, m>1, F_{2^m}-polynomials L1,L2, i with gcd(i,m)=1:
#     F(x) = x*L1(x)^{2^i} + x^{2^i}*L2(x)
#     F is APN iff three conditions hold for all v in W (verified via DDT).
#   Table 1 (n=8, k=4, m=2): 12 APN polynomials, modulus = conway_polynomial(8)=285
#   Table 3 (n=9, k=m=3):   16 APN polynomials, modulus = primitive_polynomial(9)=529
# VBF API used: SBox, differential_uniformity, conway_polynomial, primitive_polynomial,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# n=8: must use Conway polynomial 285 (zeta=2 has order 255 there).
# primitive_polynomial(8)=283 has ord(2)=51 -- wrong for this paper's zeta.
const MOD8 = conway_polynomial(8)  # 285
const MOD9 = primitive_polynomial(9)  # 529

# ---- Table 1: n=8 entries (zeta-exponent notation, modulus=285) ----
# Each entry: (label, [(coeff_exp_or_nothing, power), ...])
const TABLE1_ENTRIES = [
    ("no. 9 in Table 6 [19]",
     [(136,66),(85,33),(85,18),(102,9),(221,6),(nothing,3)]),
    ("1.2",
     [(102,66),(204,9),(nothing,3)]),
    ("1.5",
     [(153,129),(204,66),(170,33),(85,18),(204,6),(nothing,3)]),
    ("1.7",
     [(102,129),(153,66),(170,33),(221,18),(221,9),(187,6),(nothing,3)]),
    ("1.8",
     [(nothing,66),(85,33),(nothing,18),(nothing,9),(nothing,3)]),
    ("1.10",
     [(204,129),(170,66),(153,33),(85,18),(153,9),(17,6),(nothing,3)]),
    ("1.11",
     [(204,66),(nothing,33),(nothing,18),(153,9),(nothing,3)]),
    ("1.12",
     [(170,129),(204,66),(17,33),(68,18),(221,9),(204,6),(nothing,3)]),
    ("1.16",
     [(238,129),(204,66),(119,33),(68,18),(85,9),(119,6),(nothing,3)]),
    ("1.17",
     [(17,129),(85,66),(34,33),(34,18),(187,9),(187,6),(nothing,3)]),
    ("3.1",
     [(17,129),(238,66),(153,33),(85,18),(238,9),(102,6),(nothing,3)]),
    ("1.3 (from x^9 shift)",
     [(153,129),(221,72),(170,33),(102,24),(nothing,12),(nothing,9),(136,3)]),
]

# ---- Table 3: n=9 entries (zeta-exponent notation, modulus=529) ----
# i=1 rows (10), i=2 rows (6), i=4 row (1)
const TABLE3_ENTRIES = [
    # i=1
    ("eq. to [6]",   1, [(nothing,129),(146,66),(nothing,17),(365,10),(nothing,3)]),
    ("new",          1, [(219,129),(292,66),(292,17),(219,10),(nothing,3)]),
    ("new",          1, [(365,129),(292,66),(365,17),(73,10),(nothing,3)]),
    ("new",          1, [(365,129),(365,66),(146,17),(365,10),(nothing,3)]),
    ("new",          1, [(365,129),(219,66),(292,17),(73,10),(nothing,3)]),
    ("new",          1, [(73,129),(365,66),(73,17),(73,10),(nothing,3)]),
    ("new",          1, [(365,129),(438,66),(292,10),(nothing,3)]),
    ("new",          1, [(365,129),(nothing,66),(438,10),(nothing,3)]),
    ("new",          1, [(73,129),(292,66),(nothing,10),(nothing,3)]),
    ("new",          1, [(73,129),(nothing,66),(219,17),(nothing,3)]),
    # i=2
    ("new",          2, [(146,257),(438,68),(438,12),(nothing,5)]),
    ("eq. to 8.1",   2, [(146,257),(365,33),(365,12),(nothing,5)]),
    ("new",          2, [(73,257),(146,68),(nothing,33),(nothing,5)]),
    ("new",          2, [(365,257),(438,68),(365,33),(438,12),(nothing,5)]),
    ("new",          2, [(146,257),(219,68),(73,33),(nothing,12),(nothing,5)]),
    ("new",          2, [(73,257),(219,68),(365,33),(nothing,5)]),
    # i=4
    ("new",          4, [(292,3),(146,80),(73,24),(nothing,17)]),
]

"""
    table1_build() -> Vector{NamedTuple}

Build SBox and check APN for each Table 1 entry over GF(2^8) (Conway poly 285).
"""
function table1_build()
    n = 8
    mod = MOD8
    [let lut = zeta_poly_lut(n, terms; modulus=mod)
         F = SBox{n}(lut)
         du = differential_uniformity(F)
         (; label, du, apn = du == 2)
     end
     for (label, terms) in TABLE1_ENTRIES]
end

"""
    table3_build() -> Vector{NamedTuple}

Build SBox and check APN for each Table 3 entry over GF(2^9) (poly 529).
"""
function table3_build()
    n = 9
    mod = MOD9
    [let lut = zeta_poly_lut(n, terms; modulus=mod)
         F = SBox{n}(lut)
         du = differential_uniformity(F)
         (; label, i_gold=i, du, apn = du == 2)
     end
     for (label, i, terms) in TABLE3_ENTRIES]
end

function theorem3_1_report(io::IO = stdout)
    print_section(io, "Theorem 3.1 — Generalized Linear Shift Construction (Section 3.1)")
    print_kv(io, "Construction", "F(x) = x*L1(x)^{2^i} + x^{2^i}*L2(x)")
    print_kv(io, "L1, L2", "F_{2^m}-polynomials (coefficients in subfield GF(2^m))")
    print_kv(io, "Condition", "gcd(i,m)=1; verified via DDT (APN iff du=2)")

    print_section(io, "Table 1 — APN polynomials over GF(2^8) (k=4, m=2, Conway poly 285)")
    print_kv(io, "Field", "GF(2^8), poly=0x$(string(MOD8,base=16)), zeta=2 (order 255)")
    entries8 = table1_build()
    all_apn8 = all(e.apn for e in entries8)
    for (idx, e) in enumerate(entries8)
        print_kv(io, "  [$idx] equiv. $(e.label)", "du=$(e.du)  " * status_str(e.apn))
    end
    print_check(io, "all $(length(entries8)) Table 1 entries are APN", all_apn8)

    print_section(io, "Table 3 — APN polynomials over GF(2^9) (k=m=3, poly 529)")
    print_kv(io, "Field", "GF(2^9), poly=0x$(string(MOD9,base=16)), zeta=2 (order 511)")
    entries9 = table3_build()
    all_apn9 = all(e.apn for e in entries9)
    new_count = count(e -> e.label == "new", entries9)
    for (idx, e) in enumerate(entries9)
        print_kv(io, "  [$idx] i=$(e.i_gold) $(e.label)", "du=$(e.du)  " * status_str(e.apn))
    end
    print_check(io, "all $(length(entries9)) Table 3 entries are APN", all_apn9)
    print_kv(io, "new APNs", "$new_count (paper claims 15 new)")
    print_kv(io, "completeness", "exhaustive — all Table 1 and Table 3 entries verified")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_1_report()
end
