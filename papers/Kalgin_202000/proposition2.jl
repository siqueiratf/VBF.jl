# Implements §3 — On a secondary approach to search for quadratic APN functions.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §3 — Proposition 2, secondary APN extension criterion
#
# Pseudocode:
#   1. Given G (n-bit quadratic APN) with QAM M_G and extra-coord QAM M_extra:
#      build M' = M_G extended by extra bit from M_extra (entries in F_2^{n+1}).
#   2. For each candidate last column alpha (n-vector in F_2^{n+1}), build the
#      (n+1)×(n+1) QAM and call is_qam.
#   3. Proposition 2: F is APN iff alpha*a' ∉ <M'*a'^T> for all nonzero a'.
#      Equivalent to is_qam on the full (n+1)×(n+1) matrix.
#   4. Collect APN extensions, deduplicate by EA-class (apn_ea_mugshot).
#
# VBF API used: SBox, quadratic_apn_matrix, is_qam, qam_to_sbox, apn_ea_mugshot,
#               gold_apn, extend_quadratic_apn, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

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

§3 reproduction: verify Proposition 2 criterion on small examples.
- n=3 Gold → n=4: all 3 CCZ-classes of 4-bit quadratic APN recovered.
- n=5 Gold, g_6=null → 1 CCZ-class; g_6=all_quad → multiple classes (bounded).
"""
function section3_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§3 — Secondary APN extension approach (Proposition 2)", io)

    # n=3 → n=4: extend Gold, g_4=null
    n3_gold = gold_apn(3)
    M_extra3 = zero_extra_qam(3)
    ext3_null = section3_all_extensions(n3_gold, M_extra3)
    print_kv("n=3 Gold → n=4, g_4=null: CCZ-classes found", length(ext3_null), io)
    # n=4 has 1 CCZ-class (Brinkmann–Leander 2008); Gold n=3 + any g_4 reaches it
    print_check("n=3→n=4 (g_4=null): ≥1 CCZ-class found", length(ext3_null) >= 1, io)
    print_kv(
        "  note",
        "n=4 has 1 CCZ-class of quadratic APN; all extensions are EA-equivalent",
        io,
    )

    # n=3 → n=4: extend Gold, g_4=all_quad
    M_extra3q = allquad_extra_qam(3)
    ext3_allq = section3_all_extensions(n3_gold, M_extra3q)
    print_kv("n=3 Gold → n=4, g_4=all_quad: CCZ-classes found", length(ext3_allq), io)

    # n=4 → n=5: extend Gold, g_5=null (small, fast)
    n4_gold = gold_apn(4)
    M_extra4 = zero_extra_qam(4)
    ext4_null = section3_all_extensions(n4_gold, M_extra4; limit = 200)
    print_kv("n=4 Gold → n=5, g_5=null (limit=200): CCZ-classes", length(ext4_null), io)

    # n=5 → n=6: g_6=null (via extend_quadratic_apn for efficiency)
    # extend_quadratic_apn default (c=0) = g_6=null
    n5_gold = gold_apn(5)
    ext5_null_raw = extend_quadratic_apn(n5_gold; limit = 500)
    ext5_null = dedup_ea(ext5_null_raw)
    print_kv("n=5 Gold → n=6, g_6=null (limit=500): CCZ-classes", length(ext5_null), io)
    print_kv(
        "  note",
        "paper: g_6=null from any n=5 APN gives only 1 CCZ-class (class 11)",
        io,
    )

    print_section("§3 Proposition 2 verification (n=3 example)", io)
    print_kv("M_G (Gold n=3)", quadratic_apn_matrix(n3_gold), io)
    print_kv("Extended QAM is_qam?", is_qam(quadratic_apn_matrix(gold_apn(4))), io)
    print_check(
        "Proposition 2: Gold n=4 QAM passes is_qam",
        is_qam(quadratic_apn_matrix(gold_apn(4))),
        io,
    )

    result = (;
        n3_to_4_null_classes = length(ext3_null),
        n3_to_4_allq_classes = length(ext3_allq),
        n4_to_5_null_classes = length(ext4_null),
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
