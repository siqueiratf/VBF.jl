#!/usr/bin/env julia
#
# Sporadic KNOWN APN classes that no family constructor produces — they exist
# only as explicit representatives in the literature. These close the gap that
# family-instantiation alone cannot: a novelty oracle must know the sporadic
# known functions too, or it reports them as new.
#
# Concretely: Yu et al. (2020) name f7 as a KNOWN n=9 function, yet before this
# it read `:new` against the catalog — a proof the reference set was incomplete.
# Each function below was reconstructed and re-verified APN in the 2019–2020
# reproduction reviews (see the cited README).
#
# Every candidate is re-verified differential_uniformity == 2 before writing;
# exact-LUT duplicates are skipped. No novelty claim is attached — these are
# KNOWN functions being named.
#
# Usage: julia --project=packages/VBFCatalog/data-build data-build/import_sporadic_known.jl

using VBF
using VBFCatalog
using SQLite
using DBInterface
using Dates

const CONTRIB = "VBF.jl data-build"
const SRCREPO = "VBF.jl reproduction reviews (2019-2020 papers)"

# monomial-sum S-box: sum of c_j * x^e_j over GF(2^n)
function monomial_sum(n::Int, terms::Vector{Tuple{Int,Int}}; modulus = primitive_polynomial(n))
    lut = zeros(Int, 1 << n)
    @inbounds for x = 0:((1<<n)-1)
        acc = 0
        for (c, e) in terms
            acc ⊻= gf_mul(c, gf_pow(x, e, n; modulus = modulus), n; modulus = modulus)
        end
        lut[x+1] = acc
    end
    SBox{n}(lut)
end

# Tr_1^n(x^d) + x^e  (absolute trace GF(2^n) -> GF(2), embedded as 0/1)
function trace_plus_monomial(n::Int, d::Int, e::Int; modulus = primitive_polynomial(n))
    lut = zeros(Int, 1 << n)
    @inbounds for x = 0:((1<<n)-1)
        t = gf_trace(gf_pow(x, d, n; modulus = modulus), n; modulus = modulus)  # 0 or 1
        lut[x+1] = gf_pow(x, e, n; modulus = modulus) ⊻ (t & 1)
    end
    SBox{n}(lut)
end

# (name, builder, bib_key, notes) — each builder returns an SBox
function sporadic_known()
    out = Tuple{String,Function,String,String}[]

    # --- n=9, from Budaghyan et al. (2020) "Isotopic Shifts" Table I (known rows)
    #     and Yu et al. (2020). All quadratic, modulus x^9+x^4+1 = 529.
    push!(out, ("n9_BCL2008_Tr_x9_x3",
        () -> trace_plus_monomial(9, 9, 3; modulus = 529),
        "Budaghyan_200809",
        "Tr_1^9(x^9) + x^3 over GF(2^9), mod x^9+x^4+1. Budaghyan et al. 2020 Table I row 4 (Gamma-rank 47890); Budaghyan-Carlet-Leander 2008. See papers/Budaghyan_202008/README.md."))

    push!(out, ("n9_EdelPott2009_x3_x10_x136",
        () -> monomial_sum(9, [(1,3),(1,10),(_zeta_pow(9,438,529),136)]; modulus = 529),
        "Edel_200900",
        "x^3 + x^10 + z^438 x^136 over GF(2^9), z primitive, mod x^9+x^4+1. Budaghyan et al. 2020 Table I row 7 (Gamma-rank 48608); Edel-Pott 2009 Table 11 entry 8.1. See papers/Budaghyan_202008/README.md."))

    push!(out, ("n9_Yu2020_f7_known",
        () -> monomial_sum(9, [(1,e) for e in (264,160,144,132,80,72,66,40,17)]; modulus = 529),
        "Yu_202012",
        "x^264+x^160+x^144+x^132+x^80+x^72+x^66+x^40+x^17 over GF(2^9), mod x^9+x^4+1. Named as a KNOWN function by Yu et al. 2020; read :new against the catalog before this import (proof the n=9 index was incomplete). See papers/Yu_202012/README.md."))

    # --- n=7 CCZ class recovered from Yu 2020's corrupted Table 2 (its duplicate
    #     row hid this class). Present in the sboxU corpus as reprs7_3 but unnamed.
    push!(out, ("n7_Yu2020_recovered_x3_x5_x9_x40_x96",
        () -> monomial_sum(7, [(1,3),(1,5),(1,9),(1,40),(1,96)]; modulus = primitive_polynomial(7)),
        "Yu_202012",
        "x^3+x^5+x^9+x^40+x^96 over GF(2^7), mod x^7+x+1. The 15th n=7 CCZ class that Yu et al. 2020 Table 2's duplicated row hid; recovered by exhaustive search in the reproduction. See papers/Yu_202012/README.md."))

    out
end

# z^k where z = primitive element 2 under `modulus`
_zeta_pow(n, k, modulus) = gf_pow(2, k, n; modulus = modulus)

function _sha_exists(db, sha)
    for _ in DBInterface.execute(db, "SELECT id FROM functions WHERE lut_sha256 = " *
            VBFCatalog._sql_quote(sha) * " LIMIT 1")
        return true
    end
    false
end

function main()
    db = SQLite.DB(VBFCatalog.catalog_path())
    today = string(Dates.today())
    ins = 0; dup = 0; bad = 0
    for (name, build, bib, notes) in sporadic_known()
        local s
        try
            s = build()
        catch e
            println("  BUILD FAILED $name: ", e); bad += 1; continue
        end
        du = differential_uniformity(s)
        if du != 2
            println("  NOT APN (du=$du), skipping: $name"); bad += 1; continue
        end
        sha = VBFCatalog.lut_sha256_hex(s)
        if _sha_exists(db, sha)
            println("  already present (exact LUT): $name"); dup += 1; continue
        end
        n = inputbits(s); is_perm = is_permutation(s); algdeg = algebraic_degree(s)
        bu = is_perm ? boomerang_uniformity(s) : nothing
        blob = "X'" * bytes2hex(VBFCatalog.canonical_lut_bytes(s)) * "'"
        SQLite.execute(db, string(
            "INSERT INTO functions (family, n, m, lut_sha256, lut_blob, algebraic_form, ",
            "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
            "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
            "source_repo, contributor, added_date, notes) VALUES (",
            VBFCatalog._sql_quote("known-sporadic"), ", ", n, ", ", n, ", ",
            VBFCatalog._sql_quote(sha), ", ", blob, ", NULL, ",
            algdeg, ", ", 2, ", ", Int(linearity(s)), ", ",
            bu === nothing ? "NULL" : string(Int(bu)), ", ",
            1, ", ", Int(is_perm), ", ", Int(algdeg ≤ 2), ", ",
            VBFCatalog._sql_quote(name), ", ", VBFCatalog._sql_quote(bib), ", ",
            VBFCatalog._sql_quote(SRCREPO), ", ", VBFCatalog._sql_quote(CONTRIB), ", ",
            VBFCatalog._sql_quote(today), ", ", VBFCatalog._sql_quote(notes), ")"))
        println("  inserted: $name  (n=$n, deg=$algdeg)")
        ins += 1
    end
    println("\ninserted=$ins  already_present=$dup  rejected=$bad")
    close(db)
end

# Auto-run when included by build_catalog.jl (non-interactive), and when run as
# a script. The guard was `abspath(PROGRAM_FILE) == @__FILE__`, which is false
# under `include`, so chaining this importer from build_catalog.jl did nothing.
if !isinteractive() && get(ENV, "BFA_KNOWN_SPORADIC_NO_AUTORUN", "0") != "1"
    main()
end
