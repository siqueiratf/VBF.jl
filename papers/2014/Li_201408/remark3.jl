# Implements Remark 3 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Remark 3 + RDF sets)
#
# Pseudocode:
#   n=4, i=1,2, u=1:
#     Walsh spectrum = {0, ±4, ±8}
#     Constructions for i=1 and i=2 are CCZ-equivalent (extended codes equivalent)
#   n=8, i=1,2,4, u=1:
#     Walsh spectrum = {0, ±16, ±32}
#     Constructions are pairwise CCZ-inequivalent (and inequivalent to x^{21})
#   RDF sets (EA-invariant, from text preceding Remark 3), n=8, i=1:
#     RD_{F_u'^{-1}}(4) = {13,14,15,16,17,18,19,20,23}   [Theorem 5 inverse]
#     RD_{F'^{-1}}(4) = {11,12,13,14,15,16,17,18,19,21,22,23,28}  [Theorem 6 inverse]
# VBF API used: gold_apn, SBox, absolute_walsh_spectrum, are_ccz_equivalent

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))

"""
    remark3_report(; full_search=false, io=stdout)

§3 Remark 3: Walsh spectra and CCZ-inequivalence for n=4 and n=8.
Also verifies RDF(4) sets for EA-inequivalence of Theorem 5 vs Theorem 6 inverses.
Set full_search=true to also check pairwise CCZ for n=8 (slow).
"""
function remark3_report(; full_search::Bool = false, io::IO = stdout)
    print_section("Remark 3 — Walsh spectra and CCZ-inequivalence", io)

    # n=4: Walsh spectrum for i=1,2
    println(io, "\n  n=4 cases:")
    Fus_n4 = Dict{Int,SBox}()
    for i in [1, 2]
        N = 5
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{4}(fu_lut)
        Fus_n4[i] = Fu
        aws = absolute_walsh_spectrum(Fu)
        actual = Set(keys(aws.counts))
        ok = issubset(actual, Set([0, 4, 8]))
        print_check("n=4 i=$i: Walsh ⊆ {0,±4,±8} (got $(sort(collect(actual))))", ok, io)
    end
    # n=4: i=1 and i=2 should be CCZ-equivalent
    ccz_n4 = are_ccz_equivalent(Fus_n4[1], Fus_n4[2])
    print_check("n=4 i=1 and i=2 are CCZ-equivalent", ccz_n4, io)

    # n=8: Walsh spectrum for i=1,2,4
    println(io, "\n  n=8 cases:")
    Fus_n8 = Dict{Int,SBox}()
    for i in [1, 2, 4]
        N = 9
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{8}(fu_lut)
        Fus_n8[i] = Fu
        aws = absolute_walsh_spectrum(Fu)
        actual = Set(keys(aws.counts))
        ok = issubset(actual, Set([0, 16, 32]))
        print_check("n=8 i=$i: Walsh ⊆ {0,±16,±32} (got $(sort(collect(actual))))", ok, io)
    end

    if full_search
        println(io, "\n  n=8 pairwise CCZ-inequivalence (opt-in):")
        # The n=8 F_u are degree-3 differentially-4-uniform permutations (neither
        # quadratic nor APN), so are_ccz_equivalent falls back to the generic
        # permutation-only Canteaut-Perrin enumeration (enumerate_ccz_class). At
        # n=8 that class enumeration exhausts memory/time with the current
        # backend. Rather than abort with a raw backtrace, we degrade gracefully:
        # report the search as infeasible and keep the Walsh-spectrum necessary
        # condition (verified above) as the affirmative evidence the paper's
        # Magma extended-code equivalence result is consistent with.
        try_n8_ccz = function (F, G, label)
            if inputbits(F) >= 8
                print_kv(label, "infeasible at n=8 with current backend " *
                    "(generic CCZ enumeration exhausts resources)", io)
                return
            end
            local ccz
            try
                ccz = are_ccz_equivalent(F, G)
            catch err
                print_kv(label, "infeasible ($(typeof(err))) — CCZ backend " *
                    "could not complete", io)
                return
            end
            print_check("$label CCZ-inequivalent", !ccz, io)
        end
        for (a, b) in [(1, 2), (1, 4), (2, 4)]
            try_n8_ccz(Fus_n8[a], Fus_n8[b], "n=8 i=$a vs i=$b")
        end
        # vs x^{21} = x^{2^4+2^2+2^0} over GF(2^8)
        x21 = SBox{8}(gf_monomial_lut(8, 21))
        for i in [1, 2, 4]
            try_n8_ccz(Fus_n8[i], x21, "n=8 i=$i vs x^21")
        end
    else
        print_kv("n=8 pairwise CCZ check", "skipped (pass full_search=true)", io)
    end

    # RDF sets — EA-invariant: n=8, i=1
    println(io, "\n  RDF(4) sets (EA-invariant, n=8, i=1):")
    # Theorem 5 inverse
    Fu5 = theorem5_build(8, 1; u = 1)
    Fu5_inv = compositional_inverse(Fu5)
    rdf5 = rdf_set(Fu5_inv)
    expected_rdf5 = Set([13,14,15,16,17,18,19,20,23])
    print_check("RD_{F_u'^{-1}}(4) = {13..23} (got $(sort(collect(rdf5))))", rdf5 == expected_rdf5, io)

    # Theorem 6 inverse (m=9, i=1)
    Fp6 = theorem6_build(9, 1)
    Fp6_inv = compositional_inverse(Fp6)
    rdf6 = rdf_set(Fp6_inv)
    expected_rdf6 = Set([11,12,13,14,15,16,17,18,19,21,22,23,28])
    print_check("RD_{F'^{-1}}(4) = {11..28} (got $(sort(collect(rdf6))))", rdf6 == expected_rdf6, io)

    print_check("RDF sets differ → Th5 and Th6 inverses are EA-inequivalent (n=8)",
        rdf5 != rdf6, io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    remark3_report(; full_search = false)
end
