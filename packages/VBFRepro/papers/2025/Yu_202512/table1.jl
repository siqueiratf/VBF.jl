# Implements Table 1 — 3 CCZ-inequivalent representatives for n=10
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 4.1 Algorithm, Table 1
#
# Pseudocode:
#   F1(x) = x^3 = x^{2^1+1}
#   F2(x) = x^9 = x^{2³+1}
#   F3(x) = x^513 + x^192 + x^96 + x^48 + x^33 + x^18 + x^12
#   Verify: is_quadratic_apn(Fi) for i=1,2,3
#   Verify: ortho-derivative spectra are pairwise distinct (CCZ-inequivalence)
# VBF API used: is_quadratic_apn, differential_spectrum, ortho_derivative, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

const N10 = 10
const MOD10 = conway_polynomial(N10)  # 1135

# Table 1 polynomial exponents (univariate over GF(2^10)).
const TABLE1_EXPONENTS = [
    [3],                                            # x^3 = x^{2^1+2^0} — Gold k=1 as printed in the supplied LaTeX
    [9],                                            # x^9 = x^{2^3+2^0} — Gold k=3
    [513, 192, 96, 48, 33, 18, 12],                 # shorter rep for x^3+Tr(x^9) class
]

const TABLE1_LABELS = [
    "x^3",
    "x^9",
    "x^513+x^192+x^96+x^48+x^33+x^18+x^12",
]

function build_table1_sboxes(modulus::Int = MOD10)
    [polynomial_sbox(N10, exps; modulus = modulus) for exps in TABLE1_EXPONENTS]
end

function table1_report(io::IO = stdout)
    print_section(io, "Table 1: 3 CCZ-inequivalent representatives for n=10")

    mod = MOD10
    boxes = build_table1_sboxes(mod)

    # Verify APN
    for (i, (F, lbl)) in enumerate(zip(boxes, TABLE1_LABELS))
        ok = is_quadratic_apn(F)
        print_check(io, "F$i = $lbl is APN over GF(2^10)", ok)
    end

    # Verify pairwise CCZ-inequivalence via ortho-derivative differential spectra
    spectra = [differential_spectrum(ortho_derivative(F)) for F in boxes]
    for i in 1:3, j in (i+1):3
        neq = spectra[i] != spectra[j]
        print_check(io, "F$i and F$j have distinct ortho-derivative spectra (CCZ-inequivalent)", neq)
    end

    print_kv(io, "n", N10)
    print_kv(io, "modulus (Conway x^10+x^3+1)", mod)
    print_kv(io, "completeness",
             "exact APN check; CCZ-inequivalence via ortho-derivative (sufficient but not necessary)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    table1_report()
end
