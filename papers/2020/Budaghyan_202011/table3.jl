# Implements Table III from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Table III (Γ-ranks of all known CCZ-inequivalent APN functions over GF(2^10))
#
# Pseudocode:
#   1. Build all APN functions listed in Table III over GF(2^10)
#   2. Verify APN-ness and compute extended Walsh spectra (CCZ-invariants)
#   3. Report paper's Γ-rank values from Table III as reference
#      (Γ-rank for n=10 requires a 2^20 × 2^20 matrix; out of scope here)
#   4. Show mugshot comparison for C_3, C_7 vs. known APN families
# VBF API used: build_ci_sbox, gold_apn, gf_monomial_lut, differential_uniformity,
#               absolute_walsh_spectrum, apn_ea_mugshot, SBox

include(joinpath(@__DIR__, "helpers.jl"))
using Printf

# ── Build Table III APN functions over GF(2^10) ──────────────────────────────

function _x339_dobbertin_n10()
    # Dobbertin: x^(2^{4k}+2^{3k}+2^{2k}+2^k-1) for n=5k, k=2 → exponent = 339
    SBox{10}(gf_monomial_lut(10, 339))
end

function _x9_gold_n10()
    # x^9 = x^(2^3+1); Gold k=3, gcd(3,10)=1 — APN over GF(2^10)
    SBox{10}(gf_monomial_lut(10, 9))
end

"""
    table3_functions() -> Vector{NamedTuple}

Returns the APN functions from Table III that can be verified computationally.
Γ-ranks are loaded from Table III of the paper (computation requires Magma for n=10).

NOTE: The paper's TeX lists "x^5 | Gold | 136492". x^5 = x^{2^2+1} with gcd(2,10)=2
is NOT APN over GF(2^10) (differential uniformity 4). This appears to be a TeX
conversion artifact; the actual exponent is unclear without the original PDF.
That entry is omitted here and noted in the report.
"""
function table3_functions()
    [
        (; name="x^3",   family="Gold",      gamma_rank_paper=125042, sbox=gold_apn(10, 1)),
        (; name="x^9",   family="Gold/APN",  gamma_rank_paper=186416, sbox=_x9_gold_n10()),
        (; name="x^339", family="Dobbertin", gamma_rank_paper=280604, sbox=_x339_dobbertin_n10()),
        (; name="C_3",   family="new",       gamma_rank_paper=166068, sbox=build_ci_sbox(10, 3, 2)),
        (; name="C_7",   family="new",       gamma_rank_paper=166168, sbox=build_ci_sbox(10, 7, 0)),
    ]
end

function table3_report(io::IO = stdout)
    print_section("Table III: APN functions over GF(2^10)", io)
    println(io, "  Γ-ranks are loaded from Table III of the paper.")
    println(io, "  Γ-rank for n=10 requires a 2^20×2^20 matrix (≈128 GB); out of scope.")
    println(io, "  NOTE: Paper's TeX lists 'x^5 | Gold | 136492'. x^5 is NOT APN over")
    println(io, "        GF(2^10) (du=4); this entry is omitted — likely TeX conversion artifact.")
    println(io, "  We verify APN-ness and compute extended Walsh spectra (CCZ-invariants).")
    println(io)

    funcs = table3_functions()
    spectra = [absolute_walsh_spectrum(f.sbox) for f in funcs]

    println(io, "  Function  Family      Γ(paper)   APN  Walsh-spec")
    for (f, sp) in zip(funcs, spectra)
        apn = differential_uniformity(f.sbox) == 2
        print_check(
            @sprintf("%-8s  %-10s  %-9d  %-4s  %s",
                f.name, f.family, f.gamma_rank_paper, apn ? "yes" : "no",
                repr(sp)[1:min(40, end)]),
            apn, io,
        )
    end
    println(io)

    # EA-mugshot comparison: C_3 and C_7 vs. known families
    c3_idx = findfirst(f -> f.name == "C_3", funcs)
    c7_idx = findfirst(f -> f.name == "C_7", funcs)
    m_c3 = apn_ea_mugshot(funcs[c3_idx].sbox)
    m_c7 = apn_ea_mugshot(funcs[c7_idx].sbox)

    print_section("EA-mugshot comparison (EA-inequivalence)", io)
    for f in funcs
        if f.name ∉ ("C_3", "C_7")
            mf = apn_ea_mugshot(f.sbox)
            ineq3 = m_c3 != mf
            ineq7 = m_c7 != mf
            print_check("C_3 ≠_EA $(f.name) (mugshot differs)", ineq3, io)
            print_check("C_7 ≠_EA $(f.name) (mugshot differs)", ineq7, io)
        end
    end
    print_check("C_3 ≠_EA C_7 (mugshots differ)", m_c3 != m_c7, io)

    println(io)
    println(io, "  NOTE: CCZ-inequivalence (C_3, C_7 vs. each other and vs. known)")
    println(io, "        is established in the paper via Γ-rank comparison (Table III).")
    println(io, "        EA-inequivalence (mugshots differ) is verified above.")
end
