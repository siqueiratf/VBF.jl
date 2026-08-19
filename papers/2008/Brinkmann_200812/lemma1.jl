# Implements Section 3, Lemma 1: APN characterization via 2-dimensional affine subspaces.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 3 — APN Functions
#
# Pseudocode:
#   1. Enumerate all 2D affine subspaces {a, a⊕b, a⊕c, a⊕b⊕c} with b≠0, c≠0, b≠c
#   2. For each, check F(a)⊕F(a⊕b)⊕F(a⊕c)⊕F(a⊕b⊕c) ≠ 0
#   3. Verify equivalence with differential_uniformity(F) == 2
# VBF API used: SBox, differential_uniformity

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    check_lemma1(F::SBox{N,T}) -> Bool

Lemma 1: s is APN iff for all {t,u,v,w} ∈ A(F₂ⁿ) (2D affine subspaces),
s(t) ⊕ s(u) ⊕ s(v) ⊕ s(w) ≠ 0.
A 2D affine subspace is {a, a⊕b, a⊕c, a⊕b⊕c} for b≠0, c≠0, b≠c.
Returns true iff the condition holds for all subspaces (i.e., F is APN).
"""
function check_lemma1(F::SBox{N,T}) where {N,T}
    n = 1 << N
    lut = F.lut
    for a in 0:n-1
        for b in 1:n-1
            for c in b+1:n-1
                t = a
                u = a ⊻ b
                v = a ⊻ c
                w = a ⊻ b ⊻ c
                if lut[t+1] ⊻ lut[u+1] ⊻ lut[v+1] ⊻ lut[w+1] == 0
                    return false
                end
            end
        end
    end
    return true
end

"""
    lemma1_report(io)

Section 3 — Lemma 1: APN via 2D affine subspaces.
Verifies Lemma 1 for the n=4 EA-canonical representatives and a non-APN function.
"""
function lemma1_report(io::IO = stdout)
    print_section(io, "Lemma 1 — APN via 2D affine subspaces (Section 3)")
    println(io, "  s is APN ⟺ ∀{t,u,v,w} ∈ A(F₂ⁿ): s(t)⊕s(u)⊕s(v)⊕s(w) ≠ 0")

    F1, F2 = table2_luts()

    apn_by_lemma1 = check_lemma1(F1)
    apn_by_du     = differential_uniformity(F1) == 2
    print_check(io, "F1 (n=4, Gold class): Lemma 1 check = $apn_by_lemma1", apn_by_lemma1)
    print_check(io, "F1: Lemma 1 ↔ DDT check agreement", apn_by_lemma1 == apn_by_du)

    apn_by_lemma1 = check_lemma1(F2)
    apn_by_du     = differential_uniformity(F2) == 2
    print_check(io, "F2 (n=4, non-power class): Lemma 1 check = $apn_by_lemma1", apn_by_lemma1)
    print_check(io, "F2: Lemma 1 ↔ DDT check agreement", apn_by_lemma1 == apn_by_du)

    non_apn = SBox{4}([x % 3 for x in 0:15])
    apn_by_lemma1 = check_lemma1(non_apn)
    apn_by_du     = differential_uniformity(non_apn) == 2
    print_check(io, "Non-APN function: Lemma 1 detects non-APN = $(!apn_by_lemma1)", !apn_by_lemma1)
    print_check(io, "Non-APN: Lemma 1 ↔ DDT check agreement", apn_by_lemma1 == apn_by_du)
end

if abspath(PROGRAM_FILE) == @__FILE__
    lemma1_report()
end
