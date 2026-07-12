# Implements Lemma 5 from Beierle & Leander (2022).
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: §4.2 — Finding quadratic APN functions in the canonical classes, p.11
#
# Lemma 5: Let A ∈ GL(n, F_2) and F: F_2^n → F_2^n be APN with F ∘ A = F.
# Let c be the number of distinct cycles of A as a permutation on F_2^n.
# Then c ≥ ⌈2^(2n) / (3·2^n − 2)⌉, which equals (2^n+2)/3 for even n
# and (2^n+1)/3 for odd n.
#
# Applied as a filter for canonical classes with B = I_n (so F ∘ A = F) or
# A = I_n (so B ∘ F = F, equivalently F ∘ B^{−1} = F, checked by symmetry).
# Analogous to Proposition 5 in Beierle_202107.
#
# VBF API used: none

"""
    cycle_count(lut::Vector{Int}) -> Int

Count the number of distinct cycles of the permutation x ↦ lut[x+1] on {0, …, 2^n−1}.
"""
function cycle_count(lut::Vector{Int})::Int
    n_pts = length(lut)
    visited = falses(n_pts)
    ncycles = 0
    for start in 0:(n_pts - 1)
        visited[start + 1] && continue
        ncycles += 1
        cur = start
        while !visited[cur + 1]
            visited[cur + 1] = true
            cur = lut[cur + 1]
        end
    end
    return ncycles
end

"""
    lemma5_min_cycles(n) -> Int

Lower bound on the number of A-cycles required for an APN F with F ∘ A = F to exist.
Equals ⌈2^(2n) / (3·2^n − 2)⌉ = (2^n+2)/3 for even n, (2^n+1)/3 for odd n.
Beierle–Leander (2022), §4.2, Lemma 5.
"""
function lemma5_min_cycles(n::Int)::Int
    field_size = 1 << n
    isodd(n) ? (field_size + 1) ÷ 3 : (field_size + 2) ÷ 3
end

"""
    lemma5_excludes(A_lut, n) -> Bool

Return true if Lemma 5 guarantees that no APN F with F ∘ A = F can exist,
i.e., the number of A-cycles on F_2^n is below the required lower bound.
Apply with A_lut being the non-identity component of the LE-automorphism pair.
Beierle–Leander (2022), §4.2, Lemma 5.
"""
function lemma5_excludes(A_lut::Vector{Int}, n::Int)::Bool
    cycle_count(A_lut) < lemma5_min_cycles(n)
end
