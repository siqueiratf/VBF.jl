# Implements Section 3.5 — Theorem 3 (Rank of cyclically shifted linear combination)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 3.5 — Reducing number of linear combinations for QAM check
#
# Pseudocode:
#   1. Fix normal basis B = {b, b², ..., b^{2^{n-1}}} for F₂ⁿ
#   2. Compute M_F (derivative matrix of F in basis B)
#   3. For all nonzero α ∈ F₂ⁿ (as row-selection bitmask):
#      a. Compute S = Σᵢ αᵢ rᵢ  (linear combo of rows of M_F, αᵢ ∈ F₂)
#      b. Compute S' = Σᵢ αᵢ rᵢ₊ₘ  (cyclically shifted selection)
#      c. Verify rank(S) = rank(S')  [Theorem 3]
# VBF API used: gf_pow, conway_polynomial, SBox

include(joinpath(@__DIR__, "helpers.jl"))

function _row_combo_rank(M::Matrix{Int}, alpha_mask::Int, shift::Int)
    n = size(M, 1)
    size(M, 2) == n || throw(ArgumentError("derivative matrix must be square"))
    0 < alpha_mask < (1 << n) || throw(ArgumentError("row selection must be nonzero and fit n bits"))
    all(v -> 0 <= v < (1 << n), M) || throw(ArgumentError("matrix entries must be n-bit field elements"))
    combo = zeros(UInt, n)
    for i in 0:n-1
        (alpha_mask >> i) & 1 == 1 || continue
        shifted_row = mod1(i + 1 + shift, n)
        for j in 1:n
            combo[j] ⊻= UInt(M[shifted_row, j])
        end
    end
    return rank_f2(combo; nbits=n)
end

"""
    verify_theorem3(; n=4, m=1) -> Bool

Theorem 3 (Ichanska et al. 2024): For any nonzero linear combination of rows of M_F
(with F₂ coefficients), the GF(2)-rank equals the rank of the cyclically shifted version
(shifted by m positions). Verified for n=4, Gold x^3, all 2^4-1 = 15 nonzero subsets.
"""
function verify_theorem3(; n::Int = 4, m::Int = 1)
    n >= 2 && 1 <= m <= n && n % m == 0 || throw(ArgumentError("requires m|n and 1 <= m <= n"))
    mod = conway_polynomial(n)
    b = find_normal_element(n; modulus = mod)
    F = SBox{n}([gf_pow(x, 3, n; modulus = mod) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = mod)

    for alpha in 1:(1<<n)-1
        r0 = _row_combo_rank(MF, alpha, 0)
        r1 = _row_combo_rank(MF, alpha, m)
        r0 == r1 || return false
    end
    true
end

function theorem3_report(io::IO = stdout)
    print_section(io, "Theorem 3: Rank preservation of cyclic row combinations (Section 3.5)")
    n = 4; m = 1; mod = conway_polynomial(n)
    b = find_normal_element(n; modulus = mod)
    print_kv(io, "n", n)
    print_kv(io, "m", m)
    print_kv(io, "normal element b", b)

    F = SBox{n}([gf_pow(x, 3, n; modulus = mod) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = mod)

    all_pass = true
    checked = 0
    for alpha in 1:(1<<n)-1
        r0 = _row_combo_rank(MF, alpha, 0)
        r1 = _row_combo_rank(MF, alpha, m)
        r0 == r1 || (all_pass = false)
        checked += 1
    end
    print_check(io, "rank(combo) = rank(cyclic_shift(combo, $m)) for all $checked nonzero selections", all_pass)
    print_kv(io, "F", "Gold x^3 over F₂⁴")
    print_kv(io, "completeness", "exact ($((1<<n)-1) nonzero row-subsets exhausted)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_report()
end
