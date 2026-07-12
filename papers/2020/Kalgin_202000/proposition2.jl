# Implements §3 — On a secondary approach to search for quadratic APN functions.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §3 — Theorem 1, Proposition 1, Examples 1-2, Proposition 2,
#               Proposition 3 (secondary APN extension criterion)
#
# Pseudocode:
#   1. Theorem 1 (Beth-Ding): in an APN function every quadratic term x_i x_j
#      (i != j) occurs in at least one coordinate ⟺ the symmetric matrix G has
#      no zero off-diagonal entry.
#   2. Proposition 1: G is APN iff x·G·aᵀ ≠ 0 for all x, a ∈ F_2^n \ {0}, x ≠ a.
#      (Implemented exactly, as `proposition1_apn`; cross-checked against is_qam.)
#   3. Given G (n-bit quadratic APN) with QAM M_G and extra-coord QAM M_extra:
#      build M' = M_G extended by extra bit from M_extra (entries in F_2^{n+1}).
#   4. For each candidate last column alpha (n-vector in F_2^{n+1}), build the
#      (n+1)×(n+1) QAM and apply Proposition 2: F is APN iff α·a' ∉ ⟨G'·a'ᵀ⟩ for
#      all nonzero a'. This is exactly Proposition 1 on the full (n+1)×(n+1)
#      matrix (proved in the paper), so `is_qam` decides it.
#   5. Collect APN extensions, deduplicate by EA-class (dedup_ea: mugshot buckets
#      confirmed by the exact EA decision).
#
# VBF API used: SBox, quadratic_apn_matrix, is_qam, qam_to_sbox, apn_ea_mugshot,
#               gold_apn, extend_quadratic_apn, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

# ── Theorem 1 (Beth–Ding) ────────────────────────────────────────────────────

"""
    beth_ding_all_terms_present(M) -> Bool

**Theorem 1** (Theorem 6 in Beth–Ding): if `F = (f_1,…,f_n)` is APN then every
quadratic term `x_i x_j`, `i ≠ j`, appears in at least one coordinate of `F`.
On the symmetric matrix `M` of a quadratic function that says exactly: no
off-diagonal entry is zero.

Necessary, not sufficient — see `proposition1_apn` for the exact criterion.
"""
function beth_ding_all_terms_present(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    all(M[i, j] != 0 for i = 1:n for j = 1:n if i != j)
end

# ── Proposition 1 ────────────────────────────────────────────────────────────

"""
    proposition1_apn(M) -> Bool

**Proposition 1**: the quadratic vectorial function `G` with symmetric matrix `M`
is APN **iff** `x·M·aᵀ ≠ 0` for all `x, a ∈ F_2^n \\ {0}` with `x ≠ a`, where
`x·M·aᵀ = ⊕_{i ∈ supp(x), j ∈ supp(a)} M[i,j] ∈ F_2^n`.

This is the paper's own criterion, implemented as stated (`is_qam` decides the
same predicate by a rank argument; `test_proposition2.jl` cross-checks them).
"""
function proposition1_apn(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    size(M, 2) == n || throw(ArgumentError("proposition1_apn: matrix must be square"))
    full = (1 << n) - 1
    r = zeros(Int, n)
    @inbounds for a = 1:full
        fill!(r, 0)
        for j = 1:n
            ((a >> (j - 1)) & 1) == 1 || continue
            for i = 1:n
                r[i] ⊻= Int(M[i, j])         # r = M · aᵀ
            end
        end
        for x = 1:full
            x == a && continue
            acc = 0
            for i = 1:n
                ((x >> (i - 1)) & 1) == 1 && (acc ⊻= r[i])
            end
            acc == 0 && return false
        end
    end
    true
end

# ── Examples 1 and 2 (§3) ────────────────────────────────────────────────────

"""
    example1_matrix() -> Matrix{Int}

**Example 1**: `G = (g₁,g₂,g₃) = (x₁x₂ + x₂x₃, x₂x₃, x₁x₂ + x₁x₃)` in 3 variables.
Its matrix, with entry `(i,j)` the F_2³ vector of coordinates containing `xᵢxⱼ`
(bit `k-1` ↔ `g_k`, matching VBF's QAM convention):

    G = [ (000) (101) (001) ;      [ 0 5 4 ;
          (101) (000) (110) ;   =    5 0 3 ;
          (001) (110) (000) ]        4 3 0 ]
"""
example1_matrix() = [0 5 4; 5 0 3; 4 3 0]

"""
    example2_matrix() -> Matrix{Int}

**Example 2**: the null `g₄` extension of Example 1's `G` to 4 variables,
`f₁ = g₁ + x₃x₄`, `f₂ = g₂`, `f₃ = g₃ + x₂x₄`, `f₄ = x₁x₄ + x₃x₄`:

    F = [ (0000) (1010) (0010) (0001) ;      [ 0 5 4 8 ;
          (1010) (0000) (1100) (0010) ;   =    5 0 3 4 ;
          (0010) (1100) (0000) (1001) ;        4 3 0 9 ;
          (0001) (0010) (1001) (0000) ]        8 4 9 0 ]

The paper states F is APN; it is quadratic by construction.
"""
example2_matrix() = [0 5 4 8; 5 0 3 4; 4 3 0 9; 8 4 9 0]

# ── Proposition 3 (§3) ───────────────────────────────────────────────────────

"""
    proposition3_example_matrix() -> Matrix{Int}

The explicit **differentially 4-uniform** 5-variable `G = (g₁,…,g₅)` given right
after **Proposition 3** (which states `Δ_G ≤ 4` whenever the construction (1)
extends `G` to an APN function in n+1 variables):

    g₁ = x₁x₂ + x₃x₅ + x₄x₅          g₄ = x₂x₄ + x₁x₅ + x₄x₅
    g₂ = x₁x₃ + x₄x₅                 g₅ = x₃x₄ + x₂x₅ + x₄x₅
    g₃ = x₂x₃ + x₁x₄ + x₃x₅ + x₄x₅

(The paper reports `g₆` = all quadratic terms then yields all 13 CCZ-classes of
APN functions in 6 variables.) `Δ_G = 4`, so G is *not* APN — Proposition 3's
bound is attained.
"""
proposition3_example_matrix() =
    [0 1 2 4 8; 1 0 4 8 16; 2 4 0 16 5; 4 8 16 0 31; 8 16 5 31 0]

"""
    build_extended_qam(M_base, M_extra, alpha, n) -> Matrix{Int}

Build the (n+1)×(n+1) QAM for the extension F of the n-bit function G.
- M_base:  n×n QAM of G (entries in {0,...,2^n-1}).
- M_extra: n×n matrix of extra bits from g_{n+1} (entries in {0,1}).
- alpha:   n-vector of last-column entries (each in {0,...,2^{n+1}-1}).
Proposition 2: F is APN iff is_qam of this matrix.
"""
function build_extended_qam(
    M_base::AbstractMatrix{<:Integer},
    M_extra::AbstractMatrix{<:Integer},
    alpha::AbstractVector{<:Integer},
    n::Int,
)
    Q = zeros(Int, n + 1, n + 1)
    @inbounds for i = 1:n, j = 1:n
        Q[i, j] = M_base[i, j] | (M_extra[i, j] << n)
    end
    @inbounds for i = 1:n
        Q[i, n+1] = alpha[i]
        Q[n+1, i] = alpha[i]
    end
    Q
end

"""
    zero_extra_qam(n) -> Matrix{Int}

QAM of g_{n+1} = 0 (null extra coordinate): all entries are 0.
"""
zero_extra_qam(n::Int) = zeros(Int, n, n)

"""
    allquad_extra_qam(n) -> Matrix{Int}

QAM of g_{n+1} = ⊕_{i<j} x_i x_j (all quadratic terms): all off-diagonal entries 1.
"""
function allquad_extra_qam(n::Int)
    M = zeros(Int, n, n)
    for i = 1:n, j = 1:n
        i != j && (M[i, j] = 1)
    end
    M
end

"""
    section3_search(G::SBox{N}, M_extra; limit) -> Vector{SBox{N+1}}

Search for APN extensions of G using Proposition 2 (§3).
Enumerate alpha vectors; keep those for which the extended QAM is APN.
"""
function section3_search(
    G::SBox{N},
    M_extra::AbstractMatrix{<:Integer};
    limit::Int = typemax(Int),
) where {N}
    n = N
    M_base = quadratic_apn_matrix(G)
    results = SBox{N + 1}[]
    full = 1 << (n + 1)

    # alpha_i ∈ {0,...,2^{n+1}-1}, there are n such entries
    function rec!(k, alpha)
        length(results) >= limit && return
        if k > n
            Q = build_extended_qam(M_base, M_extra, alpha, n)
            is_qam(Q) && push!(results, qam_to_sbox(Q))
            return
        end
        for v = 0:(full-1)
            alpha[k] = v
            rec!(k + 1, alpha)
            length(results) >= limit && return
        end
    end

    rec!(1, zeros(Int, n))
    results
end

"""
    section3_all_extensions(G::SBox{N}, M_extra; limit) -> Vector{SBox{N+1}}

Find all (up to limit) APN extensions of all EA-classes of G (deduped by EA).
"""
function section3_all_extensions(
    G::SBox{N},
    M_extra::AbstractMatrix{<:Integer};
    limit::Int = typemax(Int),
) where {N}
    raw = section3_search(G, M_extra; limit = limit)
    dedup_ea(raw)
end

"""
    section3_report(io; save_results) -> NamedTuple

§3 reproduction: Theorem 1, Proposition 1, Examples 1-2, Proposition 2,
Proposition 3, and the extension searches.
"""
function section3_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§3 — Theorem 1, Proposition 1, Examples 1 and 2", io)

    # Theorem 1 (Beth–Ding): an APN function's matrix has no zero off-diagonal.
    thm1_mats = [quadratic_apn_matrix(gold_apn(n)) for n = 3:7]
    thm1_holds = all(beth_ding_all_terms_present, thm1_mats)
    print_check("Theorem 1: no zero off-diagonal entry in any APN matrix (n=3..7)",
                thm1_holds, io)
    # …and it has teeth: zeroing one off-diagonal entry destroys the APN property.
    M5 = quadratic_apn_matrix(gold_apn(5))
    thm1_tight = all(
        begin
            Z = copy(M5)
            Z[i, j] = Z[j, i] = 0
            !proposition1_apn(Z)
        end for i = 1:5 for j = (i+1):5
    )
    print_check("Theorem 1 is not vacuous: zeroing any single off-diagonal entry " *
                "of the Gold n=5 matrix breaks APN", thm1_tight, io)

    # Proposition 1, implemented as stated, cross-checked against is_qam.
    G1 = example1_matrix()
    p1_agrees = all(
        proposition1_apn(M) == is_qam(M) == (differential_uniformity(qam_to_sbox(M)) == 2)
        for M in vcat(thm1_mats, [G1, example2_matrix()])
    )
    print_check("Proposition 1 ⟺ is_qam ⟺ differential_uniformity = 2", p1_agrees, io)

    # Example 1: G = (x1x2+x2x3, x2x3, x1x2+x1x3) is APN.
    print_kv("Example 1 matrix", G1, io)
    print_check("Example 1: G is APN (Proposition 1)", proposition1_apn(G1), io)

    # Example 2: null-g4 extension of Example 1 to 4 variables.
    F2 = example2_matrix()
    E2 = qam_to_sbox(F2)
    print_kv("Example 2 matrix", F2, io)
    print_check(
        "Example 2: F is APN and quadratic (du = 2, deg = 2)",
        differential_uniformity(E2) == 2 && algebraic_degree(E2) == 2,
        io,
    )
    print_check(
        "Example 2: F extends Example 1's G (upper-left 3×3 block agrees)",
        [F2[i, j] & 0b111 for i = 1:3, j = 1:3] == G1,
        io,
    )

    print_section("§3 — Secondary APN extension approach (Proposition 2)", io)

    # n=3 → n=4: extend Gold, g_4=null
    n3_gold = gold_apn(3)
    M_extra3 = zero_extra_qam(3)
    raw3_null = section3_search(n3_gold, M_extra3)
    ext3_null = dedup_ea(raw3_null)
    print_kv("n=3 Gold → n=4, g_4=null: raw APN extensions", length(raw3_null), io)
    print_kv("n=3 Gold → n=4, g_4=null: CCZ-classes found", length(ext3_null), io)
    # n=4 has exactly 1 CCZ-class of quadratic APN (Brinkmann–Leander 2008).
    print_check("n=3→n=4 (g_4=null): covers all 1 CCZ-class of n=4",
                length(ext3_null) == 1, io)

    # n=3 → n=4: extend Gold, g_4=all_quad
    M_extra3q = allquad_extra_qam(3)
    raw3_allq = section3_search(n3_gold, M_extra3q)
    ext3_allq = dedup_ea(raw3_allq)
    print_kv("n=3 Gold → n=4, g_4=all_quad: raw APN extensions", length(raw3_allq), io)
    print_kv("n=3 Gold → n=4, g_4=all_quad: CCZ-classes found", length(ext3_allq), io)
    print_check("n=3→n=4 (g_4=all_quad): covers all 1 CCZ-class of n=4",
                length(ext3_allq) == 1, io)

    # n=4 → n=5: extend Gold. EXPECTED NULL — see the note below.
    n4_gold = gold_apn(4)
    raw4_null = section3_search(n4_gold, zero_extra_qam(4))
    raw4_allq = section3_search(n4_gold, allquad_extra_qam(4))
    ext4_null = dedup_ea(raw4_null)
    print_kv("n=4 Gold → n=5, g_5=null: APN extensions", length(raw4_null), io)
    print_kv("n=4 Gold → n=5, g_5=all_quad: APN extensions", length(raw4_allq), io)
    print_check(
        "n=4→n=5: EXPECTED NULL — no APN extension of Gold n=4 for either g_5 " *
        "(exhaustive: all 2^20 = 1,048,576 α vectors enumerated, no limit hit)",
        isempty(raw4_null) && isempty(raw4_allq),
        io,
    )
    print_kv(
        "  note",
        "this 0 is a result, not a failure: neither of the 2 CCZ-classes of n=5 " *
        "quadratic APN (Gold x^3, x^5) is reachable from Gold n=4 with g_5 null or " *
        "all-quadratic. Remark 2 only guarantees *some* n=4 quadratic APN or " *
        "differentially-4-uniform preimage exists, not that Gold n=4 is one.",
        io,
    )

    # n=5 → n=6: g_6=null. Bounded sample — the exact EA decision costs ~0.8 s per
    # pair at n=6, so we confirm the paper's claim on the first `n5_limit` hits.
    n5_limit = 50
    n5_gold = gold_apn(5)
    ext5_null_raw = extend_quadratic_apn(n5_gold; limit = n5_limit)
    ext5_null = dedup_ea(ext5_null_raw)
    print_kv("n=5 Gold → n=6, g_6=null (sample of $(length(ext5_null_raw))): CCZ-classes",
             length(ext5_null), io)
    print_check(
        "n=5→n=6 (g_6=null): all sampled extensions fall in a single CCZ-class",
        length(ext5_null) == 1,
        io,
    )
    print_kv(
        "  note",
        "paper: g_6=null from any n=5 APN gives only 1 CCZ-class (class 11). " *
        "SUBSTITUTION: the enumeration uses VBF's extend_quadratic_apn " *
        "(Beierle–Leander–Perrin tree search), a different algorithm from §3's " *
        "Proposition-2 search; only the *set of extensions* is comparable.",
        io,
    )

    print_section("§3 — Proposition 3 (differentially 4-uniform preimages)", io)
    G3 = proposition3_example_matrix()
    G3s = qam_to_sbox(G3)
    du3 = differential_uniformity(G3s)
    print_kv("Proposition 3 example G (5 vars)", G3, io)
    print_kv("Δ_G", du3, io)
    print_check("Proposition 3: the paper's explicit 5-variable G is " *
                "differentially 4-uniform (Δ_G = 4 ≤ 4, and G is not APN)",
                du3 == 4 && !proposition1_apn(G3), io)

    result = (;
        theorem1_holds = thm1_holds,
        proposition1_agrees_with_is_qam = p1_agrees,
        example1_apn = proposition1_apn(G1),
        example2_du = differential_uniformity(E2),
        proposition3_du = du3,
        n3_to_4_null_classes = length(ext3_null),
        n3_to_4_allq_classes = length(ext3_allq),
        n4_to_5_null_classes = length(ext4_null),
        n4_to_5_allq_extensions = length(raw4_allq),
        n5_to_6_null_classes = length(ext5_null),
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition2.toml"), "w") do f
            println(f, "# proposition2 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
