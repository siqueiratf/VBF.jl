# Implements Section 3: Properties and remarks on CCZ-equivalence.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 3 — Properties and remarks on CCZ-equivalence
#
# Pseudocode:
#   1. Observation 1: F₁ = A₁ + A₂∘F is a permutation iff
#      W_F(A₁*(λ), A₂*(λ)) = 0 for all λ ≠ 0 (eq. 3). Verified as a genuine
#      equivalence: LAT-side criterion vs direct bijectivity check, on
#      Procedure-2 pairs (true case), (invertible, 0) pairs (true case), and
#      random pairs (both sides evaluated, must agree).
#   2. Procedure 2 (k = 1 case): construct admissible (A₁, A₂) with A₂ ≠ 0
#      from ZW/S_F data — A₂*(β₁) = u ∈ S_F, A₁*(β₁) = a₁ ∈ ZW(u),
#      A₁*(β_i) = wᵢ with Span(w₂..w_n) ⊆ a₁ + ZW(u)  (conditions (P1)-(P3)).
#   3. Corollary 1: #EA-classes ≤ #n-dim Walsh-zero subspaces (simplex codes);
#      exact counts asserted for Gold n=4 (16), Gold n=5 (64), Kasami n=5 (2).
#   4. Proposition 1: L₁' = L∘L₁ gives EA-equivalent (in fact affine-equivalent,
#      per the proof) graph functions — checked with real CCZ graph transforms.
# VBF API used: lat, walsh_zeroes, extract_linear_subspaces, F2LinearMap,
#               ccz_equivalent_function, F2AffineMap, are_affine_equivalent,
#               is_invertible, is_permutation, load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    admissible_check(F, A1_cols, A2_cols) -> Bool

Direct check that F₁(x) = A₁(x) + A₂∘F(x) is a permutation (the admissibility
of L₁ in Observation 1 / Procedure 2). `A1_cols`, `A2_cols` are the images of
the standard basis under the F₂-linear maps A₁, A₂.
"""
function admissible_check(F::SBox{N,T}, A1_cols::Vector{T}, A2_cols::Vector{T}) where {N,T}
    n_size = 1 << N
    A1 = F2LinearMap{N,T}(A1_cols)
    A2 = F2LinearMap{N,T}(A2_cols)
    F1_lut = T[A1(T(x)) ⊻ A2(F.lut[x + 1]) for x = 0:(n_size - 1)]
    return is_permutation(SBox{N,T}(F1_lut))
end

"""
    observation1_criterion(F, A1_cols, A2_cols) -> Bool

Walsh-side criterion of Observation 1 (eq. 3): F₁ = A₁ + A₂∘F is a permutation
iff W_F(A₁*(λ), A₂*(λ)) = 0 for every λ ≠ 0, with * the adjoint (bit-matrix
transpose in the standard dot-product convention used by `lat`).
"""
function observation1_criterion(
    F::SBox{N,T},
    A1_cols::Vector{T},
    A2_cols::Vector{T},
) where {N,T}
    n_size = 1 << N
    A1t = transpose(F2LinearMap{N,T}(A1_cols))
    A2t = transpose(F2LinearMap{N,T}(A2_cols))
    L = lat(F)
    return all(L[Int(A1t(T(λ))) + 1, Int(A2t(T(λ))) + 1] == 0 for λ = 1:(n_size - 1))
end

"""
    procedure2_admissible_pair(F) -> Union{NamedTuple,Nothing}

Procedure 2 (k = 1): find an admissible pair (A₁, A₂) with A₂ ≠ 0.
Chooses u ∈ S_F*, a₁ ∈ ZW(u) and an (n-1)-dim subspace W ⊆ a₁ + ZW(u),
then sets A₂*(β₁) = u, A₂*(βᵢ) = 0 (i ≥ 2), A₁* = [a₁ | basis of W].
Returns `(; A1_cols, A2_cols, u, a1)` or `nothing`.
"""
function procedure2_admissible_pair(F::SBox{N,T}) where {N,T}
    for u in sf_set(F)
        u == 0 && continue
        zw = zw_set(F, u)
        for a1 in zw
            coset = sort!(unique(UInt32[UInt32(a1 ⊻ v) for v in zw]))
            bases = extract_linear_subspaces(coset, N - 1; max_bits = N)
            isempty(bases) && continue
            W = bases[1]
            A1star = T[T(a1); T.(W)]
            A2star = T[i == 1 ? T(u) : T(0) for i = 1:N]
            A1map = transpose(F2LinearMap{N,T}(A1star))
            A2map = transpose(F2LinearMap{N,T}(A2star))
            A1_cols = T[A1map(T(1) << i) for i = 0:(N - 1)]
            A2_cols = T[A2map(T(1) << i) for i = 0:(N - 1)]
            return (; A1_cols, A2_cols, u, a1)
        end
    end
    return nothing
end

"Columns of a uniformly random invertible F₂-linear map on F₂ᴺ (rejection)."
function random_invertible_cols(N::Int, ::Type{T}) where {T}
    n_size = 1 << N
    while true
        cols = T.(rand(0:(n_size - 1), N))
        is_invertible(F2LinearMap{N,T}(cols)) && return cols
    end
end

"""
    complete_ccz_map(A1_cols, A2_cols, N) -> F2LinearMap{2N,UInt32}

Complete the top block L₁ = (A₁ | A₂) to an invertible linear map
𝓛 = [[A₁ A₂]; [A₃ A₄]] on F₂²ⁿ (packed (x << N) | y convention of
`ccz_equivalent_function`), choosing random A₃, A₄ until invertible.
"""
function complete_ccz_map(A1_cols::Vector{T}, A2_cols::Vector{T}, N::Int) where {T}
    n_size = 1 << N
    for _ = 1:1000
        A3 = rand(0:(n_size - 1), N)
        A4 = rand(0:(n_size - 1), N)
        cols = Vector{UInt32}(undef, 2N)
        for i = 1:N
            cols[i] = (UInt32(A2_cols[i]) << N) | UInt32(A4[i])       # y-bit i
            cols[N + i] = (UInt32(A1_cols[i]) << N) | UInt32(A3[i])   # x-bit i
        end
        L = F2LinearMap{2 * N,UInt32}(cols)
        is_invertible(L) && return L
    end
    error("complete_ccz_map: no invertible completion found (rank(A1|A2) < n?)")
end

"""
    observation1_demo(F, io) -> Bool

Observation 1 as a genuine equivalence check. Returns overall success.
"""
function observation1_demo(F::SBox{N,T}, io::IO = stdout) where {N,T}
    n_size = 1 << N
    S = sf_set(F)
    print_kv(io, "|S_F|", length(S))
    print_kv(io, "S_F", S)

    ok = true

    # (a) Procedure 2 pair: admissible with A₂ ≠ 0, both sides must say true.
    pr = procedure2_admissible_pair(F)
    if pr === nothing
        print_check(io, "Procedure 2 (k=1) found an admissible pair", false)
        ok = false
    else
        adm = admissible_check(F, pr.A1_cols, pr.A2_cols)
        crit = observation1_criterion(F, pr.A1_cols, pr.A2_cols)
        print_kv(io, "Procedure 2 pair (u, a1)", (pr.u, pr.a1))
        print_check(io, "Procedure-2 pair: F₁ = A₁ + A₂∘F is a permutation", adm)
        print_check(io, "Procedure-2 pair: Walsh criterion (eq. 3) also true", crit)
        ok &= adm && crit
    end

    # (b) A₂ = 0, A₁ invertible: F₁ = A₁ trivially a permutation; both true.
    A1_cols = random_invertible_cols(N, T)
    A2_cols = zeros(T, N)
    b_adm = admissible_check(F, A1_cols, A2_cols)
    b_crit = observation1_criterion(F, A1_cols, A2_cols)
    print_check(io, "(A₁ invertible, A₂=0): permutation and criterion agree", b_adm && b_crit)
    ok &= b_adm && b_crit

    # (c) random pairs: the two sides must agree (usually both false).
    agree = true
    for _ = 1:20
        rA1 = T.(rand(0:(n_size - 1), N))
        rA2 = T.(rand(0:(n_size - 1), N))
        agree &= admissible_check(F, rA1, rA2) == observation1_criterion(F, rA1, rA2)
    end
    print_check(io, "20 random (A₁,A₂): bijectivity ⟺ Walsh criterion", agree)
    ok &= agree

    return ok
end

"""
    corollary1_upper_bound(F; io) -> Int

Corollary 1: upper bound on #EA-classes in the CCZ-class of F =
number of n-dim subspaces of Z(F) (= number of simplex codes in C(F)).
"""
function corollary1_upper_bound(F::SBox{N,T}; io::IO = stdout) where {N,T}
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, N; max_bits = 2N)
    n_subspaces = length(bases)
    print_kv(io, "|Z(F)|", length(Z))
    print_kv(io, "#simplex codes in C(F) (= upper bound on EA-classes)", n_subspaces)
    return n_subspaces
end

"""
    proposition1_check(F; io) -> Bool

Proposition 1, checked with real graph transforms: take an admissible
𝓛 = [[A₁ A₂]; [A₃ A₄]] (Procedure 2 top block, random completion), build
G = 𝓛(G_F); replace the top block by L∘L₁ (random invertible L, same bottom
block) and build G'. Per the proof, G and G' are affine-equivalent (hence
EA-equivalent). Returns the computed boolean.
"""
function proposition1_check(F::SBox{N,T}; io::IO = stdout) where {N,T}
    pr = procedure2_admissible_pair(F)
    if pr === nothing
        print_check(io, "Proposition 1: admissible pair available", false)
        return false
    end
    Lfull = complete_ccz_map(pr.A1_cols, pr.A2_cols, N)
    G = ccz_equivalent_function(F, F2AffineMap(Lfull, UInt32(0)))
    if G === nothing
        print_check(io, "Proposition 1: 𝓛(G_F) is a function graph", false)
        return false
    end

    Lr = F2LinearMap{N,T}(random_invertible_cols(N, T))
    A1p = T[Lr(pr.A1_cols[i]) for i = 1:N]
    A2p = T[Lr(pr.A2_cols[i]) for i = 1:N]
    # Same bottom block: read A3/A4 back out of Lfull's columns.
    cols = UInt32[Lfull(UInt32(1) << (i - 1)) for i = 1:(2N)]
    mask = (UInt32(1) << N) - UInt32(1)
    colsp = Vector{UInt32}(undef, 2N)
    for i = 1:N
        colsp[i] = (UInt32(A2p[i]) << N) | (cols[i] & mask)
        colsp[N + i] = (UInt32(A1p[i]) << N) | (cols[N + i] & mask)
    end
    Lfullp = F2LinearMap{2 * N,UInt32}(colsp)
    if !is_invertible(Lfullp)
        print_check(io, "Proposition 1: diag(L,I)·𝓛 invertible", false)
        return false
    end
    Gp = ccz_equivalent_function(F, F2AffineMap(Lfullp, UInt32(0)))
    if Gp === nothing
        print_check(io, "Proposition 1: 𝓛'(G_F) is a function graph", false)
        return false
    end
    same = are_affine_equivalent(G, Gp)
    print_check(io, "Proposition 1: 𝓛 and diag(L,I)·𝓛 give affine-equivalent functions", same)
    return same
end

"""
    section3_report(io)

Section 3: Observation 1 + Procedure 2 (Gold x³ n=4), Corollary 1 exact counts
(Gold n=4,5; Kasami n=5; Kim n=6), Proposition 1 (real check, Gold n=5).
"""
function section3_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 3: CCZ-equivalence and Procedure 2")
    println(io, "# Scope: Observation 1 + Procedure 2 k=1 (exact), Corollary 1 (exact),")
    println(io, "#        Proposition 1 (exact via graph transforms)")

    print_section(io, "Observation 1 — Admissibility criterion via ZW sets (Gold x³, n=4)")
    F4 = power_sbox(4, 3)
    observation1_demo(F4, io)

    print_section(io, "Corollary 1 — Upper bound on EA-classes via simplex-code count")
    println(io, "  Exact EA-class counts inside the bound are computed in Section 5")
    println(io, "  (automorphism orbits); MAGMA is only needed for code equivalence.")

    println(io, "\n  Gold x³, n=4:")
    ub4g = corollary1_upper_bound(power_sbox(4, 3); io)
    print_check(io, "Gold x³ n=4: 16 simplex codes", ub4g == 16)

    println(io, "\n  Gold x³, n=5:")
    ub5g = corollary1_upper_bound(load_apn_function("n5_Gold_x3"); io)
    print_check(io, "Gold x³ n=5: 64 simplex codes", ub5g == 64)

    println(io, "\n  Kasami x¹⁵, n=5:")
    ub5k = corollary1_upper_bound(load_apn_function("n5_Kasami_x15"); io)
    print_check(io, "Kasami x¹⁵ n=5: 2 simplex codes (cf. Theorem 8)", ub5k == 2)

    print_section(io, "Proposition 1 — L∘L₁ yields the same EA-class (Gold x³, n=5)")
    proposition1_check(load_apn_function("n5_Gold_x3"); io)
end
