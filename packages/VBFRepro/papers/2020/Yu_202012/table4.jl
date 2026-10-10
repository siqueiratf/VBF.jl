# Implements Section 3.2, Table 4
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 4 — n=9: 8 CCZ classes, 2 previously unknown (s₁, s₂)
#
# Scope: formula/APN/quadratic/AB checks on eight publication representatives,
# and signature separation from the explicitly enumerated curated n9 APN entries.
# This is not a complete literature corpus. Matching signatures only locate
# equivalence queries; nonquadratic references require full CCZ methods.
# No catalog writes or literature-novelty guarantee follows from this report.

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

# (exponents, label, is_new)
const TABLE4_FUNCTIONS = [
    ([3],                                   "x³",   false),
    ([5],                                   "x⁵",   false),
    ([17],                                  "x¹⁷",  false),
    ([136, 132, 96, 80, 36, 34, 18, 17, 12], "s₁",  true),
    ([257, 144, 130, 72, 65, 18, 9],        "f₅",   false),
    ([144, 130, 72, 65, 18, 9, 3],          "f₆",   false),
    ([264, 160, 144, 132, 80, 72, 66, 40, 17], "f₇", false),
    ([288, 272, 264, 160, 144, 130, 48, 34], "s₂",  true),
]

"""
    n9_catalog_split() -> (quadratic, non_quadratic)

Every n=9 APN row in the catalog functions table, split by whether σ can reach it.
Bulk-corpus/construction coverage and literature completeness are not asserted. `quadratic` entries are
`(name, sigma_key)`; `non_quadratic` are `(name, algebraic_degree)` — σ is undefined
there (no ortho-derivative), which is limit (a).
"""
function n9_catalog_split()
    quad = Tuple{String,Tuple}[]
    nonquad = Tuple{String,Int}[]
    db = VBFCatalog.load_catalog()
    try
        for row in VBFCatalog.list_functions(db; n = 9, is_apn = true)
            name = row.canonical_name === nothing ? "id:$(row.id)" : row.canonical_name
            F = VBFCatalog.load_sbox(db, row.id)
            d = algebraic_degree(F)
            differential_uniformity(F) == 2 || error("catalog APN flag failed independent derivative check: $name")
            d == 2 ? push!(quad, (name, sigma_key(F))) : push!(nonquad, (name, d))
        end
    finally
        VBFCatalog.SQLite.close(db)
    end
    (quad, nonquad)
end

"""
    table4_verify() -> NamedTuple
"""
function table4_verify()
    n = 9
    checks = Tuple{String,Bool}[]

    boxes = [(label, sbox_from_exponents(n, exps), isnew)
             for (exps, label, isnew) in TABLE4_FUNCTIONS]

    # 1. All 8 are APN, quadratic, and AB — the abstract's "s₁, s₂ are also AB" (R7).
    for (label, F, _) in boxes
        push!(checks, ("$label: APN (δ=2)", differential_uniformity(F) == 2))
        push!(checks, ("$label: quadratic (deg 2)", algebraic_degree(F) == 2))
        push!(checks, ("$label: AB (linearity 2⁵=32)", is_almost_bent(F)))
    end

    quad_entries, nonquad_entries = n9_catalog_split()
    push!(checks, ("n=9 catalog has quadratic entries to compare against",
                   !isempty(quad_entries)))

    # 2. Separation from the explicitly enumerated curated quadratic entries.
    for (label, F, isnew) in boxes
        isnew || continue
        h = sigma_key(F)
        mismatch_all = all(h != qh for (_, qh) in quad_entries)
        push!(
            checks,
            ("$label: σ-MISMATCH against all $(length(quad_entries)) quadratic n=9 catalog " *
             "entries ⟹ rigorously CCZ-inequivalent to each",
             mismatch_all),
        )
        push!(checks, ("$label: signature absent from the enumerated curated quadratic entries",
                       !isempty(quad_entries) && all(h != qh for (_, qh) in quad_entries)))
    end

    # 3. s₁ and s₂ are CCZ-inequivalent to each other (σ-mismatch, rigorous).
    s1 = sbox_from_exponents(n, TABLE4_FUNCTIONS[4][1])
    s2 = sbox_from_exponents(n, TABLE4_FUNCTIONS[8][1])
    push!(checks, ("σ(s₁) ≠ σ(s₂) ⟹ s₁ and s₂ are CCZ-inequivalent", sigma_key(s1) != sigma_key(s2)))

    # 4. LIMIT (a): σ is undefined on the non-quadratic n=9 entries, so the comparison
    #    above cannot reach them. Asserted, not just commented — sigma_key must THROW.
    push!(checks, ("limit (a): the n=9 catalog has non-quadratic entries σ cannot reach",
                   !isempty(nonquad_entries)))
    if !isempty(nonquad_entries)
        name = nonquad_entries[1][1]
        db = VBFCatalog.load_catalog()
        G = try
            VBFCatalog.load_sbox(db, startswith(name, "id:") ? parse(Int, name[4:end]) : name)
        finally
            VBFCatalog.SQLite.close(db)
        end
        threw = false
        try
            sigma_key(G)
        catch
            threw = true
        end
        push!(
            checks,
            ("limit (a) confirmed: sigma_key throws on non-quadratic $(name) " *
             "(deg $(nonquad_entries[1][2])) — CCZ does not preserve degree, so these " *
             "entries are NOT excluded by s₁/s₂ being quadratic",
             threw),
        )
    end

    # Positive controls locate reference candidates by signatures. They do not
    # establish equivalence or completeness of the wider literature database.
    f7 = sbox_from_exponents(n, TABLE4_FUNCTIONS[7][1])
    push!(
        checks,
        ("known f₇ has a signature match among curated references; exact equivalence is separate",
         any(sigma_key(f7) == h for (_,h) in quad_entries)),
    )

    # Guard against a vacuous novelty test: the catalog lookup must actually be able to
    # RECOGNISE something. f₅ and f₆ are in the catalog and must NOT read :new.
    f5 = sbox_from_exponents(n, TABLE4_FUNCTIONS[5][1])
    f6 = sbox_from_exponents(n, TABLE4_FUNCTIONS[6][1])
    push!(
        checks,
        ("non-vacuity: f₅ and f₆ ARE found in the catalog (σ-match) — the :new verdicts " *
         "above are not an artefact of an empty or broken index",
         any(sigma_key(f5) == h for (_,h) in quad_entries) && any(sigma_key(f6) == h for (_,h) in quad_entries)),
    )

    (; checks,
       n_quadratic_catalog = length(quad_entries),
       n_nonquadratic_catalog = length(nonquad_entries),
       literature_novelty = :unresolved,
       note = "s₁/s₂ are separated by signatures from the $(length(quad_entries)) explicitly " *
              "enumerated curated quadratic n9 references and from each other. Matching " *
              "signatures require exact witnesses. The $(length(nonquad_entries)) nonquadratic " *
              "curated references and other literature constructions remain unresolved; " *
              "no literature-completeness or novelty guarantee is established.")
end

function table4_report(io::IO = stdout)
    print_section(io, "Table 4 — n=9 (8 publication representatives; scoped separation)")
    result = table4_verify()
    print_kv(io, "note", result.note)
    print_kv(io, "quadratic n=9 catalog entries (σ-comparable)", result.n_quadratic_catalog)
    print_kv(io, "non-quadratic n=9 catalog entries (σ CANNOT reach)", result.n_nonquadratic_catalog)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table4_report()
end
