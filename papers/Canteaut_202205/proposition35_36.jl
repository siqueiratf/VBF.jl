# Implements Definition 33, Lemma 34 and Propositions 35–36 from
# Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 4.1.2 — Invariants of Quadratic APN Functions Based on the
#          Ortho-Derivative
#
# Definition 33: π is an ortho-derivative of quadratic F if
#   π(a) · (F(x)+F(x+a)+F(0)+F(a)) = 0 for all x, a.
# Lemma 34: F quadratic is APN iff it has a UNIQUE ortho-derivative with
#   π(0)=0 and π(a)≠0 for a≠0.
# Proposition 35: for quadratic APN F, π_F(a) is the unique nonzero vector in
#   the LEFT kernel of Jac_lin F(a), for every a ≠ 0.
# Proposition 36: for G = A∘F∘B + C (A,B affine permutations, C affine):
#   π_G = (A₀ᵀ)⁻¹ ∘ π_F ∘ B₀.
#
# Pseudocode:
#   35: π = ortho_derivative(F); for each a≠0:
#       π(a) ≠ 0, f2_dot(π(a), col) = 0 for every column of Jac_lin F(a),
#       and rank(Jac_lin F(a)) = n-1 (left kernel has dimension exactly 1,
#       so π(a) is unique).
#   36: G = A₀∘F∘B₀ + C₀ + a; check ortho_derivative(G) == (A₀ᵀ)⁻¹∘π_F∘B₀.
#   34 (negative direction): ortho_derivative of a non-APN quadratic is nothing.
# VBF API used: ortho_derivative, f2_dot, transpose, inv, gold_apn, kim_apn

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section3_2.jl"))   # _demo_maps

"""
    verify_proposition35(F::SBox{N,T}) -> Bool

π_F(a) is the unique nonzero left-kernel vector of Jac_lin F(a) for all a ≠ 0.
"""
function verify_proposition35(F::SBox{N,T}) where {N,T}
    π = ortho_derivative(F)
    π === nothing && return false
    π.lut[1] == 0 || return false
    for a in 1:((1 << N) - 1)
        πa = π.lut[a+1]
        πa == 0 && return false
        cols = jac_lin_cols(F, a)
        # left kernel membership: πaᵀ · Jac_lin F(a) = 0 ⟺ ⟨πa, col_j⟩ = 0 ∀j
        all(f2_dot(πa, c) == 0 for c in cols) || return false
        # uniqueness: rank n-1 ⟹ left kernel dimension m − (n−1) = 1
        jac_lin_rank(F, a) == N - 1 || return false
    end
    return true
end

"""
    verify_proposition36(F::SBox{N,T}) -> Bool

For G = A₀∘F∘B₀ + C₀ + a (demo maps), check π_G = (A₀ᵀ)⁻¹ ∘ π_F ∘ B₀.
"""
function verify_proposition36(F::SBox{N,T}) where {N,T}
    A0, B0 = _demo_maps(N, T)
    C0_cols = T[T(1) << (N-1-j) for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)
    a_const = T(3)
    G = build_ea_triple(F, A0, B0, C0, a_const)

    πF = ortho_derivative(F)
    πG = ortho_derivative(G)
    (πF === nothing || πG === nothing) && return false

    At_inv = inv(transpose(A0))
    return all(
        πG.lut[x+1] == At_inv(πF.lut[B0(x)+1]) for x in 0:((1 << N) - 1)
    )
end

"""
    proposition35_36_report(; io) -> NamedTuple

Verify Propositions 35 and 36 on Gold x³ (n=5, 6) and the Kim mapping, and
Lemma 34's negative direction on a non-APN quadratic.
"""
function proposition35_36_report(; io::IO = stdout)
    print_section("Propositions 35–36: ortho-derivative vs Jac_lin", io)
    results = Bool[]

    cases = [("Gold x^3 n=5", gold_apn(5)), ("Gold x^3 n=6", gold_apn(6)),
             ("Kim mapping κ", kim_apn())]
    for (name, F) in cases
        ok35 = verify_proposition35(F)
        push!(results, ok35)
        print_check("$name: π_F(a) unique nonzero left-kernel vector (Prop 35)", ok35, io)

        ok36 = verify_proposition36(F)
        push!(results, ok36)
        print_check("$name: π_G = (A₀ᵀ)⁻¹∘π_F∘B₀ (Prop 36)", ok36, io)
    end

    # Lemma 34, negative direction: non-APN quadratic has no (unique nonzero)
    # ortho-derivative — core returns nothing.
    Q = pseudo_random_multirank_quadratic(6)
    okq = ortho_derivative(Q) === nothing && differential_uniformity(Q) > 2
    push!(results, okq)
    print_check("non-APN quadratic n=6: no ortho-derivative (Lemma 34)", okq, io)

    all_ok = all(results)
    print_check("Propositions 35–36 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition35_36_report()
end
