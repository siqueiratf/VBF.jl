# Implements Table II (Section IV.E)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.E — Examples: Table II — Switching class representatives
#
# Pseudocode:
#   For each APN representative F:
#     Compute m_F = min_{β,b} |Π_F^β(b)| using pi_multiset
#     Compute lower bound = ⌈m_F/3⌉ + 1
# VBF API used: SBox, pi_multiset, compute_m_F, lower_bound_distance,
#               differential_uniformity, gf_monomial_lut

include(joinpath(@__DIR__, "helpers.jl"))

# Table II expected values from the paper
const TABLE2_EXPECTED = [
    (4, "x^3",  3,  2),
    (5, "x^3",  15, 6),
    (5, "x^5",  15, 6),
    (5, "x^15", 9,  4),
    (6, "x^3",  27, 10),
]

"""
    table2_report(; io) -> NamedTuple

Table II: m_F and lower bounds for switching class representatives.
Monomial cases n=4,5 and Gold x^3 at n=6 are computed exactly.
x^15 at n=5 is verified APN and its m_F computed.
n=6 Edel-Pott polynomial representatives (1.2, 2.1) require VBFCatalog.
"""
function table2_report(; io::IO = stdout)
    print_section("Table II — Switching class representatives: m_F and bounds", io)
    println(io, "  n    F       m_F   bound   APN?   match?")

    all_ok = true
    results = []

    # Monomial representatives
    for (n, label, exp_m, exp_bd) in TABLE2_EXPECTED
        if label == "x^3"
            lut = gf_monomial_lut(n, 3)
        elseif label == "x^5"
            lut = gf_monomial_lut(n, 5)
        elseif label == "x^15"
            lut = gf_monomial_lut(n, 15)
        else
            continue
        end
        F = SBox{n}(lut)
        apn = differential_uniformity(F) == 2
        if !apn
            println(io, "  $n    $label   ---   ---   NO (not APN, skip)")
            push!(results, (; n, label, apn = false))
            continue
        end
        mF = compute_m_F(F)
        bd = lower_bound_distance(mF)
        match = (mF == exp_m && bd == exp_bd)
        all_ok &= match
        marker = match ? "✓" : "✗ (exp m=$exp_m, bd=$exp_bd)"
        println(io, "  $n    $label   $mF   $bd   YES   $marker")
        push!(results, (; n, label, mF, bd, apn, match))
    end

    # Note about n=6 polynomial representatives
    println(io)
    println(io, "  [NOTE] n=6 Edel-Pott representatives 1.2 (m_F=27) and 2.1 (m_F=15)")
    println(io, "         require VBFCatalog to load the polynomial APN functions.")
    println(io, "         Gold x^3 (n=6, m_F=27) is included above as representative 1.1.")

    print_check("Table II monomial cases match paper", all_ok, io)
    (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table2_report()
end
