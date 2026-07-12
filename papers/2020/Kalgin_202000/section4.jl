# Implements §4 — On a cyclic approach to search for quadratic APN functions.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §4 — Cyclic matrix T construction, APN search, new n=7 function.
#
# Pseudocode:
#   1. Define cyclic matrix T(n): T[i,j] = e_{i+j-2} = 2^{i+j-3} when i+j ≤ n+2,
#      unknown (0) otherwise. Symmetric, zero diagonal.
#   2. For modified T (remove_e_n=true): also treat positions with i+j = n+2
#      as unknown (removes the sub-diagonal containing e_n).
#   3. Backtrack over unknown entries in {0,...,2^n-1}, check is_qam at completion.
#   4. New n=7 function: given in paper as univariate polynomial over GF(2^7)
#      with primitive element a (min poly x^7+x+1). Convert via polynomial_to_lut.
#   5. Verify: new function is APN (differential_uniformity=2), quadratic (deg=2),
#      and CCZ-inequivalent to the other 487 known n=7 quadratic APN classes
#      (sigma-mismatch certificate against the catalog's 488 representatives).
#
# VBF API used: is_qam, qam_to_sbox, quadratic_apn_matrix, apn_ea_mugshot,
#               ea_mappings_from_ortho_derivative, gold_apn,
#               differential_uniformity, algebraic_degree,
#               polynomial_to_lut, primitive_polynomial
# VBFCatalog API used: load_catalog, list_functions, load_sbox, sigma_hash,
#               classify_ccz

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

# ── Cyclic matrix T ──────────────────────────────────────────────────────────

"""
    kalgin_T(n; remove_e_n) -> (Matrix{Int}, Matrix{Bool})

The cyclic matrix T for dimension n (§4, eq. before §4.1):
  T[i,j] = e_{i+j-2} = 2^{i+j-3}  when  i+j ≤ n+2  (or i+j < n+2 if remove_e_n)
  T[i,j] = 0 (unknown)             otherwise.

Returns (M, known): M[i,j] is the value; known[i,j] is true iff the entry is fixed.
Symmetric, zero diagonal.
"""
function kalgin_T(n::Int; remove_e_n::Bool = false)
    M = zeros(Int, n, n)
    known = trues(n, n)
    threshold = remove_e_n ? (n + 1) : (n + 2)   # i+j ≤ threshold ⟹ fixed
    @inbounds for i = 1:n, j = (i+1):n
        if i + j <= threshold
            v = 1 << (i + j - 3)     # e_{i+j-2}
            M[i, j] = M[j, i] = v
        else
            known[i, j] = known[j, i] = false
        end
    end
    (M, known)
end

"""
    unknown_positions(known::Matrix{Bool}) -> Vector{Tuple{Int,Int}}

Return (i,j) pairs with i < j for which known[i,j] == false.
"""
function unknown_positions(known::AbstractMatrix{Bool})
    n = size(known, 1)
    [(i, j) for i = 1:n for j = (i+1):n if !known[i, j]]
end

# ── Cyclic search ────────────────────────────────────────────────────────────

"""
    cyclic_raw_qam_solutions(n; remove_e_n, limit) -> Vector{SBox}

Every completion of the cyclic matrix T that is a QAM, as an SBox — *no*
deduplication. Backtracks over the unknown positions and calls `is_qam` at
completion.
"""
function cyclic_raw_qam_solutions(
    n::Int;
    remove_e_n::Bool = false,
    limit::Int = typemax(Int),
)
    M, known = kalgin_T(n; remove_e_n = remove_e_n)
    upos = unknown_positions(known)
    field_size = 1 << n
    results = SBox[]

    function rec!(k)
        length(results) >= limit && return
        if k > length(upos)
            is_qam(M) && push!(results, qam_to_sbox(M))
            return
        end
        i, j = upos[k]
        for v = 0:(field_size-1)
            M[i, j] = M[j, i] = v
            rec!(k + 1)
            length(results) >= limit && return
        end
        M[i, j] = M[j, i] = 0
    end

    rec!(1)
    results
end

"""
    cyclic_apn_search(n; remove_e_n, limit) -> Vector{SBox}

Search for APN functions with the cyclic matrix T structure for dimension n:
one representative per CCZ-class among the QAM completions of T.

Deduplication goes through [`dedup_ea`](@ref), which buckets on `apn_ea_mugshot`
and then **confirms** each bucket with the exact EA decision. Using mugshot
equality alone as the class test (as this did before) collapses Gold x^3 and x^5
at n=5 into one class and reports 1 instead of 2.
"""
function cyclic_apn_search(
    n::Int;
    remove_e_n::Bool = false,
    limit::Int = typemax(Int),
)
    dedup_ea(cyclic_raw_qam_solutions(n; remove_e_n = remove_e_n, limit = limit))
end

# ── New n=7 function (§4) ────────────────────────────────────────────────────

"""
    new_apn_function_n7() -> SBox{7}

The new CCZ-class representative for n=7 from §4, given in univariate form:
  F(x) = a^100 x + a^88 x^2 + ... + a^20 x^96
where a is the primitive element of GF(2^7) with min poly x^7+x+1.
VBF's primitive_polynomial(7) = 0b10000011 = x^7+x+1, generator a = 2.
"""
function new_apn_function_n7()
    n = 7
    modulus = primitive_polynomial(n)   # x^7+x+1 = 0b10000011 = 131
    poly = join(
        [
            "a^100*x",
            "a^88*x^2", "a^89*x^3", "a^107*x^4", "a^57*x^5", "a^98*x^6",
            "a^56*x^8", "a^9*x^9", "a^58*x^10", "a^60*x^12",
            "a^109*x^16", "a^47*x^17", "a^44*x^18", "a^27*x^20", "a^91*x^24",
            "a^71*x^32", "a^96*x^33", "a^101*x^34", "a^7*x^36",
            "a^12*x^40", "a^34*x^48",
            "a^66*x^64", "a^4*x^65", "a^4*x^66", "a^73*x^68", "a^73*x^72",
            "a^56*x^80", "a^20*x^96",
        ],
        " + ",
    )
    lut = polynomial_to_lut(poly, n, modulus)
    SBox{n}(lut)
end

# ── Novelty / CCZ-classification of the new n=7 function ─────────────────────

"""
    n7_sigma_classification(F::SBox{7}) -> NamedTuple

Classify a quadratic APN `F` in 7 variables against **every** n=7 quadratic APN
representative in the catalog (the 488 known CCZ-classes) using the
ortho-derivative signature σ.

σ is a CCZ-invariant, so a σ-**mismatch** is a rigorous CCZ-inequivalence
certificate; a σ-**match** is only a candidate (`classify_ccz` returns
`:sigma_match`, not `:known`, for exactly this reason). The single σ-match is
therefore settled with the exact decision `are_ea_equivalent_quadratic`.

Returns `(; total, matches, mismatches, ea_confirmed, sigma)` where `matches` are
the catalog ids sharing F's σ and `ea_confirmed` the subset actually EA-equivalent
to `F`.
"""
function n7_sigma_classification(F::SBox{7})
    db = load_catalog()
    h = sigma_hash(F)
    total = 0
    matches = Int[]
    for r in list_functions(db; n = 7, is_apn = true)
        (r.is_quadratic == 1 || r.is_quadratic === true) || continue
        total += 1
        sigma_hash(load_sbox(db, r.id)) == h && push!(matches, Int(r.id))
    end
    confirmed = Int[]
    for id in matches
        S = load_sbox(db, id)
        are_ea_equivalent_quadratic(F, SBox{7}(Int.(S.lut))) && push!(confirmed, id)
    end
    (;
        total = total,
        matches = matches,
        mismatches = total - length(matches),
        ea_confirmed = confirmed,
        sigma = h,
    )
end

# ── Section report ───────────────────────────────────────────────────────────

"""
    section4_report(io; save_results) -> NamedTuple

§4 reproduction:
- Verify the cyclic T construction for n=3,4,5 covers *all* CCZ-classes of
  quadratic APN functions (1/1, 1/1, 2/2) — the paper's coverage claim.
- Verify the new n=7 function from the paper is APN and quadratic.
- Verify it is CCZ-inequivalent to the other 487 known n=7 classes (σ-mismatch).
"""
function section4_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§4 — Cyclic matrix T construction", io)

    # The paper (§4, p. 12): "For n = 3, 4 and 5 this construction covered all
    # CCZ-classes of quadratic APN functions. For n = 6 it covered 11 out of 13."
    # Known totals of quadratic-APN CCZ-classes: n=3 → 1, n=4 → 1, n=5 → 2
    # (Brinkmann–Leander 2008; the two are Gold x^3 and Gold x^5).
    known_classes = Dict(3 => 1, 4 => 1, 5 => 2)

    # n=3: T has no unknowns → unique function
    M3, known3 = kalgin_T(3)
    upos3 = unknown_positions(known3)
    print_kv("n=3 cyclic T unknowns", length(upos3), io)
    n3_apn = is_qam(M3)
    print_check("n=3 cyclic T represents an APN function", n3_apn, io)

    # n=4: 1 unknown
    M4, known4 = kalgin_T(4)
    upos4 = unknown_positions(known4)
    print_kv("n=4 cyclic T unknowns", length(upos4), io)
    raw4 = cyclic_raw_qam_solutions(4)
    fns4 = dedup_ea(raw4)
    print_kv("n=4 cyclic T: raw QAM solutions", length(raw4), io)
    print_kv("n=4 cyclic T: CCZ-classes (EA-confirmed)", length(fns4), io)
    print_check(
        "n=4 cyclic T covers all $(known_classes[4]) quadratic-APN CCZ-class(es)",
        length(fns4) == known_classes[4],
        io,
    )

    # n=5: 2 unknowns
    M5, known5 = kalgin_T(5)
    upos5 = unknown_positions(known5)
    print_kv("n=5 cyclic T unknowns", length(upos5), io)
    raw5 = cyclic_raw_qam_solutions(5)
    fns5 = dedup_ea(raw5)
    print_kv("n=5 cyclic T: raw QAM solutions", length(raw5), io)
    print_kv("n=5 cyclic T: CCZ-classes (EA-confirmed)", length(fns5), io)
    print_check(
        "n=5 cyclic T covers all $(known_classes[5]) quadratic-APN CCZ-class(es)",
        length(fns5) == known_classes[5],
        io,
    )
    g5_3 = gold_apn(5, 1)   # x^3
    g5_5 = gold_apn(5, 2)   # x^5
    hits_x3 = any(f -> are_ea_equivalent_quadratic(f, g5_3), fns5)
    hits_x5 = any(f -> are_ea_equivalent_quadratic(f, g5_5), fns5)
    print_check("n=5 cyclic T: one class is EA-equivalent to Gold x^3", hits_x3, io)
    print_check("n=5 cyclic T: one class is EA-equivalent to Gold x^5", hits_x5, io)
    print_kv(
        "  note",
        "the 12 raw n=5 solutions share one apn_ea_mugshot but split into 2 EA-classes; " *
        "mugshot equality is necessary, not sufficient — deduping on it reports 1",
        io,
    )

    # New n=7 function
    print_section("§4 — New n=7 APN function (paper's key result)", io)
    F7 = new_apn_function_n7()
    du7 = differential_uniformity(F7)
    deg7 = algebraic_degree(F7)
    print_kv("differential_uniformity", du7, io)
    print_kv("algebraic_degree", deg7, io)
    print_check("new n=7 function: APN (differential_uniformity = 2)", du7 == 2, io)
    print_check("new n=7 function: quadratic (algebraic_degree = 2)", deg7 == 2, io)

    # CCZ-classification against the full n=7 corpus (488 classes), via σ.
    cls = n7_sigma_classification(F7)
    print_kv("n=7 quadratic-APN classes in catalog", cls.total, io)
    print_kv("σ(F7)", cls.sigma[1:16] * "…", io)
    print_kv("catalog reps with σ ≠ σ(F7)", cls.mismatches, io)
    print_kv("catalog reps with σ = σ(F7)", length(cls.matches), io)
    print_check(
        "new n=7 function: CCZ-inequivalent to $(cls.mismatches) of the $(cls.total) " *
        "known classes (σ-mismatch is a rigorous certificate)",
        cls.mismatches == cls.total - 1,
        io,
    )
    print_check(
        "new n=7 function: σ occurs exactly once among the $(cls.total) classes",
        length(cls.matches) == 1,
        io,
    )
    print_check(
        "the single σ-match is EA-confirmed to be F7's own class (id $(cls.matches))",
        cls.ea_confirmed == cls.matches,
        io,
    )
    print_kv(
        "  note",
        "the class is present in the repo corpus as reprs7_487; the paper's claim is " *
        "inequivalence to the other 487, which the σ-mismatches certify. Beierle–Leander " *
        "found the same class independently (§2.3).",
        io,
    )
    distinct = sigma_hash(F7) != sigma_hash(gold_apn(7))

    result = (;
        n3_is_apn = n3_apn,
        n4_ea_classes = length(fns4),
        n5_ea_classes = length(fns5),
        n5_covers_gold_x3 = hits_x3,
        n5_covers_gold_x5 = hits_x5,
        new_n7_du = du7,
        new_n7_deg = deg7,
        new_n7_distinct_from_gold = distinct,
        n7_catalog_classes = cls.total,
        n7_sigma_mismatches = cls.mismatches,
        n7_sigma_matches = length(cls.matches),
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "section4.toml"), "w") do f
            println(f, "# section4 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
