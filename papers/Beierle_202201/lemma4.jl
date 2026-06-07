# Implements Lemma 4 from Beierle & Leander (2022).
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: §4.2 — Finding quadratic APN functions in the canonical classes, p.11
#
# Lemma 4: Let A, B ∈ GL(n, F_2). If B has strictly fewer fixed points than A
# and (|Fix_B|, |Fix_A|) ∉ {(1,2), (2,4)}, no function F: F_2^n → F_2^n with
# F ∘ A = B ∘ F can be APN.
#
# Used to prune canonical LE-automorphism classes before running the search.
# Analogous to Proposition 4 in Beierle_202107.
#
# VBF API used: none (operates on look-up table vectors directly)

"""
    fixed_point_count(lut::Vector{Int}) -> Int

Count the number of fixed points of the map x ↦ lut[x+1] on {0, …, 2^n − 1}.
"""
function fixed_point_count(lut::Vector{Int})::Int
    count(i -> lut[i + 1] == i, 0:(length(lut) - 1))
end

"""
    lemma4_excludes(A_lut, B_lut) -> Bool

Return true if Lemma 4 guarantees that no APN function F with F ∘ A = B ∘ F exists.
The condition is: |Fix_B| < |Fix_A| and (|Fix_B|, |Fix_A|) ∉ {(1,2), (2,4)}.
Beierle–Leander (2022), §4.2, Lemma 4.
"""
function lemma4_excludes(A_lut::Vector{Int}, B_lut::Vector{Int})::Bool
    fix_A = fixed_point_count(A_lut)
    fix_B = fixed_point_count(B_lut)
    fix_B >= fix_A && return false
    (fix_B, fix_A) == (1, 2) && return false
    (fix_B, fix_A) == (2, 4) && return false
    return true
end
