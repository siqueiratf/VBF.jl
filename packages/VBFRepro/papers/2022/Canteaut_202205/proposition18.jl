# Implements Proposition 18 (and Definition 17) from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.3 — The Jacobian Matrix of a Quadratic Function
#
# Definition 17 (YWL14): for a quadratic homogeneous P(X) = Σ_{k<ℓ} q_{k,ℓ}
# X^{2^{k-1}+2^{ℓ-1}} over F₂ⁿ and basis 𝓑 = (α₁..αₙ), the associated matrix is
#   H = Mᵀ C_P M,   (C_P)_{k,ℓ} = q_{k,ℓ} symmetric, zero diagonal,
#   M the Moore matrix M_{i,j} = α_j^{2^{i-1}}.
#
# Proposition 18: (α₁,…,αₙ) · Jac_lin F(x) = (x₁,…,xₙ) · H for all x, i.e. the
# QAM matrix H of YWL14 and Jac_lin F carry the same 2^{3n} binary values.
#
# We work in the bit basis α_j = 2^{j-1} (the polynomial basis of the field
# representation used by gf_*). In this basis, column j of Jac_lin F(x) is
# the field element jac_lin_cols(F, x)[j+1], and (x·H)_j = ⊕_{i: x_i=1} H[i,j].
# The check is done in both directions:
#   (a) H = Mᵀ C_P M (built from the univariate coefficients per Def. 17)
#       equals the derivative matrix `quadratic_apn_matrix(F)` of the core;
#   (b) the displayed identity of Prop 18 holds for all x, j;
#   (c) the QAM/APN characterisation (YWL14 Th. 1, restated after Remark 23):
#       is_qam(F) agrees with differential_uniformity(F) == 2.
#
# VBF API used: SBox, quadratic_apn_matrix, is_qam, gf_mul, gf_pow,
#               polynomial_terms, conway_polynomial, kim_apn, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

"""
    moore_matrix(N, modulus) -> Matrix{Int}

Moore matrix M_{i,j} = α_j^{2^{i-1}} over GF(2ᴺ) for the bit basis
α_j = 2^{j-1}.
"""
function moore_matrix(N::Int, modulus::Int)
    M = zeros(Int, N, N)
    for i in 1:N, j in 1:N
        M[i, j] = gf_pow(1 << (j-1), 1 << (i-1), N; modulus)
    end
    return M
end

"""
    cp_matrix(terms, N) -> Matrix{Int}

The symmetric zero-diagonal coefficient matrix C_P of Definition 17 from the
`(coefficient, exponent)` terms of a homogeneous quadratic univariate
polynomial: exponent 2^{k-1}+2^{ℓ-1} contributes q to (C_P)_{k,ℓ} = (C_P)_{ℓ,k}.
"""
function cp_matrix(terms::Vector{Tuple{Int,Int}}, N::Int)
    C = zeros(Int, N, N)
    for (c, e) in terms
        count_ones(e) == 2 || error("cp_matrix: exponent $e is not quadratic homogeneous")
        k = trailing_zeros(e) + 1             # position of low set bit
        ℓ = 64 - leading_zeros(e)             # position of high set bit
        C[k, ℓ] ⊻= c
        C[ℓ, k] ⊻= c
    end
    return C
end

"""
    ywl14_h_matrix(terms, N, modulus) -> Matrix{Int}

H = Mᵀ C_P M over GF(2ᴺ) (Definition 17), with M the Moore matrix of the bit
basis. Matrix products are over the field: entrywise gf_mul, XOR-sums.
"""
function ywl14_h_matrix(terms::Vector{Tuple{Int,Int}}, N::Int, modulus::Int)
    M = moore_matrix(N, modulus)
    C = cp_matrix(terms, N)
    # CM = C_P * M
    CM = zeros(Int, N, N)
    for k in 1:N, j in 1:N
        acc = 0
        for ℓ in 1:N
            acc ⊻= gf_mul(C[k, ℓ], M[ℓ, j], N; modulus)
        end
        CM[k, j] = acc
    end
    # H = Mᵀ * CM
    H = zeros(Int, N, N)
    for i in 1:N, j in 1:N
        acc = 0
        for k in 1:N
            acc ⊻= gf_mul(M[k, i], CM[k, j], N; modulus)
        end
        H[i, j] = acc
    end
    return H
end

"""
    verify_proposition18(F::SBox{N}, H::AbstractMatrix{<:Integer}) -> Bool

Check the displayed identity of Proposition 18 in the bit basis:
column j of Jac_lin F(x), read as a field element, equals ⊕_{i: xᵢ=1} H[i,j]
for all x and j.
"""
function verify_proposition18(F::SBox{N,T}, H::AbstractMatrix{<:Integer}) where {N,T}
    for x in 0:((1 << N) - 1)
        cols = jac_lin_cols(F, x)
        for j in 1:N
            acc = 0
            for i in 1:N
                ((x >> (i-1)) & 1) == 1 && (acc ⊻= Int(H[i, j]))
            end
            Int(cols[j]) == acc || return false
        end
    end
    return true
end

"""
    proposition18_report(; io) -> NamedTuple

Verify Definition 17 / Proposition 18 on Gold x³ (n=6) and the Kim mapping κ
(both homogeneous quadratic univariate), and the QAM/APN agreement on those
plus a non-APN quadratic.
"""
function proposition18_report(; io::IO = stdout)
    print_section("Proposition 18: QAM matrix H = MᵀC_P M vs Jac_lin", io)
    mod6 = conway_polynomial(6)

    cases = [
        ("Gold x^3 n=6", SBox{6}(terms_to_lut([(1, 3)], 6, mod6)), [(1, 3)]),
        ("Kim mapping κ", kim_apn(), [(1, 3), (1, 10), (2, 24)]),
    ]

    results = Bool[]
    for (name, F, terms) in cases
        H = ywl14_h_matrix(terms, 6, mod6)
        ok_a = H == quadratic_apn_matrix(F)
        print_check("$name: H = MᵀC_P M equals derivative matrix (Def 17)", ok_a, io)
        ok_b = verify_proposition18(F, H)
        print_check("$name: (α₁..αₙ)·Jac_lin F(x) = (x₁..xₙ)·H for all x", ok_b, io)
        ok_c = is_qam(F) == (differential_uniformity(F) == 2) == true
        print_check("$name: QAM ⟺ APN (YWL14 Th. 1)", ok_c, io)
        push!(results, ok_a && ok_b && ok_c)
    end

    # Non-APN homogeneous quadratic: derivative matrix is NOT a QAM
    Q = pseudo_random_multirank_quadratic(6)
    okq = !is_qam(Q) && differential_uniformity(Q) > 2 &&
          verify_proposition18(Q, quadratic_apn_matrix(Q))
    print_check("multirank quadratic n=6: Prop 18 identity, and not a QAM", okq, io)
    push!(results, okq)

    all_ok = all(results)
    print_check("Proposition 18 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition18_report()
end
