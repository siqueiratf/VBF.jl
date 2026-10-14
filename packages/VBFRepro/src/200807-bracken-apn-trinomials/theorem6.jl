# Implements Theorem 6 — CCZ equivalence and coding theory consequences.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: 5 — CCZ equivalence and coding theory
#
# Pseudocode:
#   Theorem 6 (thm:code-ccz): f CCZ-equivalent to g iff [Ĉ_f] = [Ĉ_g]  (Dillon, proved here).
#     forward: f ~ g ⇒ X·Ĥ_f is a column permutation of Ĥ_g, where
#              X = [[1, 0], [γ, M]] comes from the affine CCZ map (x,f(x)) ↦ M(x,f(x))+γ
#     necessary: [Ĉ_f] = [Ĉ_g] ⇒ equal code weight enumerators
#                (= equal Walsh spectra, by the paper's own remark)
#   Computational consequences at n=6:
#     1. Walsh spectra of Family 1 and Family 2 equal Gold x^3 spectrum.
#     2. Family 1 (n=6) CCZ-equiv to Dillon T1 = x^3 + θ^{11}x^6 + θx^9.
#     3. Family 2 (v≠0, n=6) CCZ-equiv to Dillon T2 = x^3 + θx^{24} + x^{10} = Kim.
#     4. Family 2 (v=0, n=6) CCZ-equiv to Gold x^3  (binomials from [2]).
#     5. Family 1 and Family 2 (v≠0) are NOT CCZ-equivalent to Gold (power mapping).
# VBF API used: SBox, absolute_walsh_spectrum, lat, are_ccz_equivalent, gold_apn,
#               kim_apn, ccz_matrix, code_weight_enumerator, rank_f2,
#               ea_mappings_from_ortho_derivative, differential_uniformity

include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))


"""
    dillon_T1(; modulus) -> SBox

Dillon's APN trinomial T1 on GF(64): F(x) = x^3 + θ^{11}·x^6 + θ·x^9, θ=2 (primitive).
Listed in Dillon (2006) Banff slides [ref. 7]; CCZ-class representative for Family 1 (n=6).
Uses the primitive polynomial (x^6+x+1); APN under both primitive and Conway polynomials.
"""
function dillon_T1(; modulus::Int = primitive_polynomial(6))
    n, θ  = 6, 2
    θ11   = gf_pow(θ, 11, n; modulus)
    SBox([gf_pow(x, 3, n; modulus) ⊻
          gf_mul(θ11, gf_pow(x, 6, n; modulus), n; modulus) ⊻
          gf_mul(θ,   gf_pow(x, 9, n; modulus), n; modulus)
          for x in 0:(1 << n) - 1])
end

"""
    dillon_T2() -> SBox

Dillon's APN trinomial T2 on GF(64): F(x) = x^3 + θ·x^{24} + x^{10}, θ=2 (primitive).
Listed in Dillon (2006) Banff slides [ref. 7]; CCZ-class representative for Family 2 v≠0 (n=6).
Must be built under the Conway polynomial x^6+x^4+x^3+x+1 — it is not APN under x^6+x+1.

**T2 is the Kim function.** Under the Conway modulus this polynomial form is
byte-identical to `kim_apn()`, which VBF already exports (and which the catalog
stores as `n6_Kim`), so this returns the core construction and asserts the
identity instead of re-deriving it.
"""
function dillon_T2()
    n, θ, m = 6, 2, conway_polynomial(6)
    paper_form = [gf_pow(x, 3, n; modulus=m) ⊻
                  gf_mul(θ, gf_pow(x, 24, n; modulus=m), n; modulus=m) ⊻
                  gf_pow(x, 10, n; modulus=m)
                  for x in 0:(1 << n) - 1]
    F = kim_apn()
    @assert Int.(F.lut) == paper_form "kim_apn() must equal Dillon's T2 = x^3+θx^{24}+x^{10} \
under the Conway modulus"
    F
end


# ── Theorem 6 proper: the code side ──────────────────────────────────────────

"""
    paper_code_matrix(F) -> BitMatrix

The paper's `Ĥ_f` (Section 5): the `(2n+1) × 2ⁿ` binary matrix whose columns are
`(1, x, f(x))ᵀ`. This is exactly VBF's `ccz_matrix`: row 1 is the constant row,
rows `2..n+1` hold the `x` bits and rows `n+2..2n+1` the `f(x)` bits, LSB-first,
as in the paper's display. This differs from the `FunctionGraph` packing
`(x ≪ n) | f(x)`, so `theorem6_forward_certificate` maps the packed bits to these
rows. Row order is irrelevant to Theorem 6: it changes neither
`Ĉ_f = Null(Ĥ_f)` nor the column-permutation relation the theorem is about.
"""
paper_code_matrix(F::SBox) = ccz_matrix(F)


"""
    code_dimension(F) -> (rank, dim)

Rank of `Ĥ_f` and the dimension `2ⁿ − rank` of the code `Ĉ_f = Null(Ĥ_f)`.
For an APN `F` with `F(0) = 0` no nonzero component `⟨b, f⟩` is affine, so the
`2n+1` rows are independent and `dim Ĉ_f = 2ⁿ − (2n+1)` (51 at n=6).
"""
function code_dimension(F::SBox{N,T}) where {N,T}
    H    = paper_code_matrix(F)
    ncol = size(H, 2)
    rows = [reduce(⊻, (UInt64(1) << (j - 1) for j = 1:ncol if H[i, j]); init = UInt64(0))
            for i = 1:size(H, 1)]
    r = rank_f2(rows; nbits = ncol)
    (r, ncol - r)
end


"""
    code_weight_distribution(F) -> Vector{Int}

Weight distribution of the code spanned by the rows of `Ĥ_f`, i.e. of the dual
`Ĉ_f^⊥`. `Ĉ_f` itself has 2^51 codewords at n=6, so its own enumerator is not
directly computable; the MacWilliams identity makes the two determine each other,
which is why the dual's is the computable form of "the codes have the same weight
distribution".
"""
code_weight_distribution(F::SBox) = code_weight_enumerator(paper_code_matrix(F))


"""
    weight_distribution_matches_walsh(F) -> Bool

The paper's Section 5 remark, "the weight distribution is the same thing as the
Walsh spectrum", verified rather than quoted. A codeword of `Ĉ_f^⊥` is
`x ↦ ε ⊕ ⟨a,x⟩ ⊕ ⟨b,f(x)⟩`, whose Hamming weight is `2^{n−1} − (−1)^ε·W_f(a,b)/2`.
This rebuilds the whole weight distribution from `lat(F)` alone and compares it
against `code_weight_distribution(F)`.
"""
function weight_distribution_matches_walsh(F::SBox{N,T}) where {N,T}
    L         = lat(F)
    half      = 1 << (N - 1)
    predicted = zeros(Int, (1 << N) + 1)
    for a = 1:(1 << N), b = 1:(1 << N)
        w = L[a, b]
        predicted[half - w ÷ 2 + 1] += 1     # ε = 0
        predicted[half + w ÷ 2 + 1] += 1     # ε = 1
    end
    predicted == code_weight_distribution(F)
end


"""
    theorem6_forward_certificate(F, G) -> Union{Nothing, Tuple{Matrix{Int}, UInt32}}

Theorem 6's forward direction, made constructive. If `F ~ G` then the affine CCZ
map is `(x, f(x)) ↦ M(x, f(x))ᵀ + γ`, and the paper sets

    X = [[1, 0], [γ, M]]      (a (2n+1) × (2n+1) invertible binary matrix)

so that `X·Ĥ_f` has columns `(1, M(x,f(x))+γ)ᵀ = (1, y, g(y))ᵀ`, i.e. it is a
column permutation of `Ĥ_g`. The linear part `M` is taken from
`ea_mappings_from_ortho_derivative` (complete for quadratic APN) and the
translation `γ` is recovered by matching the two graphs. Returns `(X, γ)` or
`nothing` when no CCZ map is found.
"""
function theorem6_forward_certificate(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    maps = ea_mappings_from_ortho_derivative(G, F)     # graph(G) = L(graph(F)) ⊕ γ
    isempty(maps) && return nothing
    L = first(maps)

    packF = UInt32[(UInt32(x) << N) | UInt32(F.lut[x+1]) for x = 0:(1 << N) - 1]
    packG = sort(UInt32[(UInt32(x) << N) | UInt32(G.lut[x+1]) for x = 0:(1 << N) - 1])
    imgs  = sort(UInt32[L(p) for p in packF])

    γ = nothing
    for t in packG
        cand = imgs[1] ⊻ t
        if sort(imgs .⊻ cand) == packG
            γ = cand
            break
        end
    end
    γ === nothing && return nothing

    # X = [[1, 0], [γ, M]] in the row layout of `paper_code_matrix`. `L` and `γ`
    # act on the packed point `(x ≪ n) | f(x)`, whose bit i < n is f-bit i and
    # whose bit i ≥ n is x-bit i-n. `ccz_matrix` puts x-bit k in row k+2 and f-bit
    # i in row n+i+2, so packed bit i goes to code row `row(i)`.
    row(i) = (i < N ? N + i : i - N) + 2
    X = zeros(Int, 2N + 1, 2N + 1)
    X[1, 1] = 1
    for i = 0:(2N - 1)
        X[row(i), 1] = Int((γ >> i) & 1)
        for j = 0:(2N - 1)
            X[row(i), row(j)] = Int((L.cols[j+1] >> i) & 1)
        end
    end
    (X, γ)
end


"""
    is_column_permutation(A, B) -> Bool

Whether the binary matrices `A` and `B` have the same multiset of columns.
"""
function is_column_permutation(A::AbstractMatrix, B::AbstractMatrix)
    size(A) == size(B) || return false
    enc(M) = sort([reduce(⊻, (UInt64(1) << (i - 1) for i = 1:size(M, 1)
                              if M[i, j] % 2 == 1); init = UInt64(0))
                   for j = 1:size(M, 2)])
    enc(A) == enc(B)
end


"""
    theorem6_forward_holds(F, G) -> Bool

`F ~ G ⇒ [Ĉ_F] = [Ĉ_G]`, checked constructively: build `X` from the CCZ
certificate and verify `X·Ĥ_F` is a column permutation of `Ĥ_G` (equal column
multisets ⇒ the two matrices lie in `[Ĥ_G]` ⇒ their nullspaces lie in `[Ĉ_G]`,
and `X` invertible gives `Null(X·Ĥ_F) = Null(Ĥ_F) = Ĉ_F`).
"""
function theorem6_forward_holds(F::SBox, G::SBox)
    cert = theorem6_forward_certificate(F, G)
    cert === nothing && return false
    X, _ = cert
    HF = Int.(paper_code_matrix(F))
    HG = Int.(paper_code_matrix(G))
    is_column_permutation((X * HF) .% 2, HG)
end


function theorem6_code_report(io::IO = stdout)
    print_section("Theorem 6 — the code criterion itself (Section 5)", io)
    println(io, "  Ĥ_f: (2n+1) × 2ⁿ with columns (1, x, f(x))ᵀ;  Ĉ_f = Null(Ĥ_f).")
    println(io, "  Theorem 6: f ~ g ⟺ [Ĉ_f] = [Ĉ_g].")
    println(io)

    modulus = primitive_polynomial(6)
    gold    = gold_apn(6, 1)
    T1      = dillon_T1(; modulus)
    T2      = dillon_T2()
    F1      = theorem1_sbox(3, 1, [nothing, nothing]; modulus)
    F2_0    = theorem3_sbox(2, 1, nothing)
    F2_v    = theorem3_sbox(2, 1, 21)

    named = ["Family 1"        => F1,
             "Family 2 v=0"    => F2_0,
             "Family 2 v≠0"    => F2_v,
             "Dillon T1"       => T1,
             "Dillon T2 (Kim)" => T2,
             "Gold x^3"        => gold]

    # Shape of Ĥ_f and dimension of Ĉ_f.
    dims_ok = true
    for (name, F) in named
        H = paper_code_matrix(F)
        r, d = code_dimension(F)
        ok = size(H) == (13, 64) && r == 13 && d == 51
        dims_ok &= ok
        print_check("$name: Ĥ_f is 13×64, rank 13, dim Ĉ_f = $d", ok, io)
    end
    println(io)

    # The paper's remark: weight distribution ≡ Walsh spectrum.
    walsh_ok = all(weight_distribution_matches_walsh(F) for (_, F) in named)
    print_check("weight distribution of Ĉ_f^⊥ = Walsh spectrum (paper's Sect. 5 remark)",
                walsh_ok, io)

    # Forward direction of Theorem 6, constructively.
    fwd = [("Family 1 → Dillon T1",     F1,   T1),
           ("Family 2 v≠0 → Dillon T2", F2_v, T2),
           ("Family 2 v=0 → Gold x^3",  F2_0, gold)]
    fwd_ok = true
    for (label, F, G) in fwd
        ok = theorem6_forward_holds(F, G)
        fwd_ok &= ok
        print_check("forward direction: $label — X·Ĥ_f is a column perm. of Ĥ_g",
                    ok, io)
    end
    println(io)

    # Necessary condition: CCZ-equivalent ⇒ equal code weight enumerators.
    wd = Dict(name => code_weight_distribution(F) for (name, F) in named)
    eq_ok = wd["Family 1"] == wd["Dillon T1"] &&
            wd["Family 2 v≠0"] == wd["Dillon T2 (Kim)"] &&
            wd["Family 2 v=0"] == wd["Gold x^3"]
    print_check("CCZ-equivalent pairs have equal code weight enumerators", eq_ok, io)

    # ... and why that is not enough to *decide* Theorem 6: every function here
    # has the Gold weight distribution, exactly as the paper reports, so the
    # enumerator cannot separate T1 from T2 even though they are CCZ-inequivalent.
    all_gold = all(wd[name] == wd["Gold x^3"] for (name, _) in named)
    print_check("all six have the Gold x^3 weight distribution (paper's Sect. 5 remark)",
                all_gold, io)
    print_check("⇒ the weight enumerator cannot separate T1 from T2: the converse " *
                "of Theorem 6 needs full code equivalence", wd["Dillon T1"] == wd["Dillon T2 (Kim)"], io)
    println(io)

    all_pass = dims_ok & walsh_ok & fwd_ok & eq_ok & all_gold
    print_check("All Theorem 6 code checks pass", all_pass, io)
    print_kv("scope",
             "forward direction and the weight-enumerator necessary condition are " *
             "reproduced at n=6; the converse needs binary code permutation-" *
             "equivalence (Leon's algorithm), which VBF does not implement — see " *
             "packages/VBF/src/equivalence/ccz/linear_code.jl", io)
    println(io)
end


function theorem6_report(io::IO = stdout)
    print_section("Theorem 6 — CCZ ↔ code equivalence + Walsh spectrum (Section 5)", io)
    println(io, "  Theorem 6 (Dillon, proved in paper): f CCZ-equiv g iff [Ĉ_f]=[Ĉ_g].")
    println(io, "  Computational consequences verified at n=6:")
    println(io)

    n       = 6
    modulus = primitive_polynomial(n)
    gold    = gold_apn(n, 1)     # Gold x^3 on GF(64)
    gold_ws = absolute_walsh_spectrum(gold)

    T1      = dillon_T1(; modulus)
    T2      = dillon_T2()          # = kim_apn(), Conway modulus — see docstring

    F1      = theorem1_sbox(3, 1, [nothing, nothing]; modulus)   # Family 1 trinomial
    F2_0    = theorem3_sbox(2, 1, nothing)                       # Family 2 v=0 (binomial)
    F2_v    = theorem3_sbox(2, 1, 21)                            # Family 2 v≠0 (trinomial)

    # ── APN sanity checks ──────────────────────────────────────────────────────
    println(io, "  Dillon trinomial APN checks (n=6):")
    t1_apn = differential_uniformity(T1) == 2
    t2_apn = differential_uniformity(T2) == 2
    print_check("Dillon T1 = x^3+θ^{11}x^6+θx^9 is APN on GF(64)", t1_apn, io)
    print_check("Dillon T2 = x^3+θx^{24}+x^{10}  is APN on GF(64)", t2_apn, io)
    println(io)

    # ── Walsh spectrum checks (paper: "same as Gold x^3, at least for F_{64}") ─
    println(io, "  Walsh spectrum equality to Gold x^3 (n=6):")
    ws_T1   = absolute_walsh_spectrum(T1) == gold_ws
    ws_T2   = absolute_walsh_spectrum(T2) == gold_ws
    ws_F1   = absolute_walsh_spectrum(F1) == gold_ws
    ws_F2_0 = absolute_walsh_spectrum(F2_0) == gold_ws
    ws_F2_v = absolute_walsh_spectrum(F2_v) == gold_ws
    print_check("Dillon T1 Walsh spectrum = Gold", ws_T1, io)
    print_check("Dillon T2 Walsh spectrum = Gold", ws_T2, io)
    print_check("Family 1 trinomial Walsh spectrum = Gold", ws_F1, io)
    print_check("Family 2 v=0 (binomial) Walsh spectrum = Gold", ws_F2_0, io)
    print_check("Family 2 v≠0 trinomial Walsh spectrum = Gold", ws_F2_v, io)
    println(io)

    # ── CCZ equivalence checks ──────────────────────────────────────────────────
    println(io, "  CCZ-equivalence checks (n=6, both sides quadratic APN → CCZ=EA via ortho-deriv):")
    ccz_F1_T1   = are_ccz_equivalent(F1, T1)
    ccz_F2v_T2  = are_ccz_equivalent(F2_v, T2)
    ccz_F2_0_G  = are_ccz_equivalent(F2_0, gold)
    ccz_F1_G    = are_ccz_equivalent(F1, gold)
    ccz_F2v_G   = are_ccz_equivalent(F2_v, gold)
    ccz_T1_T2   = are_ccz_equivalent(T1, T2)
    print_check("Family 1 CCZ-equiv Dillon T1  (paper claim)", ccz_F1_T1, io)
    print_check("Family 2 v≠0 CCZ-equiv Dillon T2 (paper claim)", ccz_F2v_T2, io)
    print_check("Family 2 v=0 CCZ-equiv Gold x^3 (binomial from [2])", ccz_F2_0_G, io)
    print_check("Family 1 NOT CCZ-equiv Gold  (not a power mapping CCZ class)", !ccz_F1_G, io)
    print_check("Family 2 v≠0 NOT CCZ-equiv Gold", !ccz_F2v_G, io)
    print_check("Dillon T1 and T2 are in distinct CCZ classes (not equiv)", !ccz_T1_T2, io)
    println(io)

    all_pass = t1_apn & t2_apn & ws_T1 & ws_T2 & ws_F1 & ws_F2_0 & ws_F2_v &
               ccz_F1_T1 & ccz_F2v_T2 & ccz_F2_0_G & !ccz_F1_G & !ccz_F2v_G & !ccz_T1_T2
    print_check("All Theorem 6 consequence checks pass", all_pass, io)
    print_kv("completeness",
             "Walsh+CCZ exhaustive for n=6; Theorem 6's own statement is checked " *
             "in theorem6_code_report", io)
    println(io)

    theorem6_code_report(io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
