# Proposition 3 — candidate-set restrictions for the H_8 search.
#
# ── Paper mapping ───────────────────────────────────────────────────────────
# Source: Yu and Perrin (2022), Section "Avoiding EA-equivalent APN functions",
# Theorem 2 (Yu–Wang–Li 2014) and Proposition 3.
#
# Theorem 2. If H' = P^t H P with P ∈ F_2^{n×n} invertible, then the quadratic
#   functions of H and H' are EA-equivalent, and H is a QAM iff H' is. Adding
#   column/row i into column/row j is such a P (a transvection).
#
# Proposition 3 (the four candidate sets). With H_8 as in Conjecture 2:
#   * V = Span(g^34, g^81, g^83, g^170, g^106)   (column 1, rows 2..6).
#     A QAM forces x_13 ∉ V; the transvection P above moves x_13 inside its
#     coset of V, so we only need x_13 ∈ A = {reps of the 7 non-trivial
#     cosets of V}.                                          |A| = 7.
#   * U = Span(g^34, g^68, g^162, g^166, g^85)   (column 2, rows 1,3..6).
#     With B ∪ (B+g^34) a partition of F_{2^8}∖U we need only x_12 ∈ B.
#                                                            |B| = 2^7 − 2^4 = 112.
#   * E = Span(V, x_13); with E ∪ (E+c_1) ∪ (E+c_2) ∪ (E+c_3) = F_{2^8} we need
#     only x_7 ∈ {c_1, c_2, c_3}.                            |{c_i}| = 3.
#   * F = Span(U, x_12); with G ∪ (G+g^34) a partition of F_{2^8}∖F we need only
#     x_6 ∈ G.                                               |G| = 2^7 − 2^5 = 96.
#
# This file builds those sets from the actual H_8 block (so the spanning
# elements are exactly the paper's), checks the four cardinalities, and
# demonstrates Theorem 2 by reducing the seed's x_13 into A while preserving
# both the QAM property and the EA-class.

isdefined(@__MODULE__, :h8_base) || include(joinpath(@__DIR__, "conjecture2_search.jl"))
using VBF

# Spanning sets straight from H_8 (column 1 / column 2 off-diagonal entries).
prop3_V_basis() = (H = h8_base(); [H[2, 1], H[3, 1], H[4, 1], H[5, 1], H[6, 1]])
prop3_U_basis() = (H = h8_base(); [H[1, 2], H[3, 2], H[4, 2], H[5, 2], H[6, 2]])

# Candidate sets of Proposition 3.
prop3_candidates_x13() = nontrivial_coset_reps(prop3_V_basis())          # A, |A| = 7
prop3_candidates_x12() = coset_involution_half(prop3_U_basis(), gpow(34))  # B, |B| = 112

"Candidate set {c_1,c_2,c_3} for x_7 given x_13: reps of cosets of E=Span(V,x_13)."
prop3_candidates_x7(x13::Integer) = nontrivial_coset_reps(vcat(prop3_V_basis(), Int(x13)))

"Candidate set G for x_6 given x_12: half of F_{2^8}∖F with F=Span(U,x_12)."
prop3_candidates_x6(x12::Integer) =
    coset_involution_half(vcat(prop3_U_basis(), Int(x12)), gpow(34))

"""
    prop3_cardinalities(; x13, x12) -> NamedTuple

The four candidate-set sizes `(A, B, c, G)` of Proposition 3. `x13`/`x12` select
the `E`/`F` spans for the dependent sets (defaults: the first element of `A`/`B`).
The paper's expected values are `7, 112, 3, 96`.
"""
function prop3_cardinalities(; x13::Integer = first(prop3_candidates_x13()),
                               x12::Integer = first(prop3_candidates_x12()))
    (
        A = length(prop3_candidates_x13()),
        B = length(prop3_candidates_x12()),
        c = length(prop3_candidates_x7(x13)),
        G = length(prop3_candidates_x6(x12)),
        expected = (A = 7, B = 2^7 - 2^4, c = 3, G = 2^7 - 2^5),
    )
end

"""
    f2_decompose(x, basis) -> Union{Vector{Int}, Nothing}

The F_2 coordinates `(λ_1,…,λ_k)` of `x` in `span(basis)`, or `nothing` if
`x ∉ span(basis)`. Brute force over the `2^k` combinations (`k` small here).
"""
function f2_decompose(x::Integer, basis::AbstractVector{<:Integer})
    k = length(basis)
    for mask = 0:((1 << k) - 1)
        acc = 0
        for t = 1:k
            ((mask >> (t - 1)) & 1) == 1 && (acc ⊻= Int(basis[t]))
        end
        acc == Int(x) && return [(mask >> (t - 1)) & 1 for t = 1:k]
    end
    nothing
end

"""
    congruence_transvection(H, tcol, scols, lambdas) -> Matrix{Int}

`H' = P^t H P` where `P` is the F_2 transvection adding `λ_k·(column scols[k])`
into column `tcol` (Theorem 2). Computed directly over `GF(2^n)` (the entries
combine by XOR since `P` is a 0/1 matrix). Keeps `H'` symmetric.
"""
function congruence_transvection(
    H::AbstractMatrix{<:Integer},
    tcol::Int,
    scols::AbstractVector{<:Integer},
    lambdas::AbstractVector{<:Integer},
)
    n = size(H, 1)
    # H P : add λ-combination of source columns into column tcol
    HP = Matrix{Int}(copy(H))
    for r = 1:n
        acc = Int(H[r, tcol])
        for (k, sc) in enumerate(scols)
            lambdas[k] == 1 && (acc ⊻= Int(H[r, Int(sc)]))
        end
        HP[r, tcol] = acc
    end
    # P^t (H P) : add λ-combination of source rows into row tcol
    H2 = Matrix{Int}(copy(HP))
    for c = 1:n
        acc = Int(HP[tcol, c])
        for (k, sc) in enumerate(scols)
            lambdas[k] == 1 && (acc ⊻= Int(HP[Int(sc), c]))
        end
        H2[tcol, c] = acc
    end
    H2
end

"""
    reduce_x13_into_A(; H = h8_base()) -> NamedTuple

Demonstrate Theorem 2 / Proposition 3: take `H` (whose `x_13 = H[1,7] ∉ V`),
find `(λ_1,…,λ_5)` and `a ∈ A` with `x_13 = (⊕ λ_k V_k) ⊕ a`, apply the
transvection that adds those `λ_k` columns (2..6) into column 7, and check the
result `H'` has `x_13' = a ∈ A`, is still a QAM, and is EA-equivalent to `H`.
"""
function reduce_x13_into_A(; H::AbstractMatrix{<:Integer} = h8_base())
    Vb = prop3_V_basis()
    A = prop3_candidates_x13()
    x13 = Int(H[1, 7])
    # find a ∈ A and λ with x13 ⊕ a ∈ span(V), i.e. x13 = (λ·V) ⊕ a
    λ = nothing
    a = nothing
    for cand in A
        d = f2_decompose(x13 ⊻ cand, Vb)
        if d !== nothing
            λ = d
            a = cand
            break
        end
    end
    λ === nothing && return (ok = false,)
    # P adds λ_k·column(k+1) into column 7  (V_k lives in column 1, rows 2..6;
    # the transvection on H_8 uses source columns 2..6 — see Prop 3's P).
    Hp = congruence_transvection(H, 7, [2, 3, 4, 5, 6], λ)
    symmetric = Hp == permutedims(Hp)
    same_qam = is_qam(Hp) == is_qam(H)
    ea_equiv = apn_ea_mugshot(qam_to_sbox(Hp)) == apn_ea_mugshot(qam_to_sbox(H))
    (
        ok = true,
        x13 = x13,
        reduced_x13 = Int(Hp[1, 7]),
        a = a,
        reduced_in_A = Int(Hp[1, 7]) in A,
        symmetric = symmetric,
        same_qam = same_qam,
        ea_equiv = ea_equiv,
    )
end

function proposition3_report(io::IO = stdout)
    print_section("Proposition 3: candidate-set restrictions (n = 8)", io)

    card = prop3_cardinalities()
    print_check("x_13 candidate set A has size 7", card.A == card.expected.A, io)
    print_kv("    |A| (cosets of V)", card.A, io)
    print_check("x_12 candidate set B has size 2^7 − 2^4 = 112",
                card.B == card.expected.B, io)
    print_kv("    |B| (half of F∖U)", card.B, io)
    print_check("x_7 candidate set {c_1,c_2,c_3} has size 3", card.c == card.expected.c, io)
    print_kv("    |{c_i}| (cosets of E=Span(V,x_13))", card.c, io)
    print_check("x_6 candidate set G has size 2^7 − 2^5 = 96",
                card.G == card.expected.G, io)
    print_kv("    |G| (half of F∖F̂, F̂=Span(U,x_12))", card.G, io)

    r = reduce_x13_into_A()
    print_check("Theorem 2 reduction: seed x_13 moved into A",
                r.ok && r.reduced_in_A, io)
    print_check("Theorem 2 reduction: result stays a QAM", r.ok && r.same_qam, io)
    print_check("Theorem 2 reduction: result is EA-equivalent to the seed",
                r.ok && r.ea_equiv, io)
    if r.ok
        println(io, "    x_13: $(r.x13) → $(r.reduced_x13) ∈ A = $(prop3_candidates_x13())")
    end

    (
        A = card.A,
        B = card.B,
        c = card.c,
        G = card.G,
        expected = card.expected,
        reduction_ok = r.ok,
        reduced_in_A = r.ok && r.reduced_in_A,
        reduction_same_qam = r.ok && r.same_qam,
        reduction_ea_equiv = r.ok && r.ea_equiv,
        x13 = r.ok ? r.x13 : -1,
        reduced_x13 = r.ok ? r.reduced_x13 : -1,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition3_report()
end
