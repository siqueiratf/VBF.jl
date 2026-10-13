# search/phase5_novelty.jl — PHASE 5 novelty test.
#
# For every distinct sigma found by the sweep (one per file in search/centers/):
#
#   MISMATCH against the sigma index  => CCZ-inequivalent to every indexed
#       function. Since CCZ and EA coincide for quadratic APN (Yoshiara) and the
#       ortho-derivative's linear-equivalence class is an EA-invariant
#       (Canteaut-Couvreur-Perrin), this is a sound novelty claim — but only
#       relative to what the index actually covers. See the coverage caveat
#       written into the output.
#
#   MATCH  => proves NOTHING about equivalence. Reported as
#       "candidate collision, needs explicit equivalence test", and then
#       ACTUALLY TESTED: both sides are quadratic APN, so
#       ea_mappings_from_ortho_derivative decides exactly. Non-empty => genuinely
#       equivalent (known); empty => CCZ-INEQUIVALENT despite the sigma match,
#       which would itself be a novelty finding.
#
# Every candidate is re-verified delta_F = 2 by a code path different from the
# one that found it: the sweep accepted it on rank(L_a) = 7 for all a, this
# recomputes the full DDT via VBF.differential_uniformity.
#
# Writes: results/candidates/*.toml and search/phase5_report.toml

include(joinpath(@__DIR__, "apn_subspace.jl"))

using VBFCatalog
using TOML

const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface
const ROOT = normpath(joinpath(@__DIR__, ".."))
const CENTERS = joinpath(ROOT, "search", "centers")
const CANDIDATES = joinpath(ROOT, "results", "candidates")

sql_quote(s) = "'" * replace(s, "'" => "''") * "'"

"""Rows in the sigma index carrying this hash, grouped by source."""
function index_hits(db, h::String)
    out = Tuple{String,Int}[]
    for r in DBInterface.execute(db,
        "SELECT source, COUNT(*) AS c FROM ccz_sigma_index WHERE sigma_hash = " *
        sql_quote(h) * " GROUP BY source")
        push!(out, (String(r.source), r.c))
    end
    out
end

"""A catalogued representative with this sigma, if the functions table has one."""
function functions_table_rep(cat, db, h::String)
    for r in DBInterface.execute(db,
        "SELECT member_idx FROM ccz_sigma_index WHERE sigma_hash = " * sql_quote(h) *
        " AND source = 'functions' LIMIT 1")
        return r.member_idx
    end
    nothing
end

function main()
    mkpath(CANDIDATES)
    idxpath = sigma_index_path()
    isfile(idxpath) || error("phase5: sigma index absent — run search/phase5_index_check.jl first")
    db = SQLite.DB(idxpath)
    cat = VBFCatalog.load_catalog()

    # Re-state the coverage every claim is relative to.
    total_rows = first(DBInterface.execute(db, "SELECT COUNT(*) AS c FROM ccz_sigma_index")).c
    n8_distinct = first(DBInterface.execute(db,
        "SELECT COUNT(DISTINCT sigma_hash) AS c FROM ccz_sigma_index WHERE n = 8")).c
    println("sigma index: $total_rows rows, $n8_distinct distinct sigma at n=8")

    allfiles = sort(filter(f -> endswith(f, ".toml"), readdir(CENTERS)))
    isempty(allfiles) && (println("no centers to test"); return)

    # One test per DISTINCT sigma. Distinct classes can carry the same sigma
    # (classes 13 and 19 share an A matrix, so in commutant mode they yield the
    # same subspace and the same 9 signatures), and the exact EA decision costs
    # ~400 s, so testing per file would pay for each one twice.
    byhash = Dict{String,Vector{String}}()
    for f in allfiles
        h = TOML.parsefile(joinpath(CENTERS, f))["sigma_hash"]
        push!(get!(byhash, h, String[]), f)
    end
    files = [v[1] for v in values(byhash)]
    sort!(files)
    println("centers: $(length(allfiles)) files, $(length(files)) distinct sigma to test")

    verdicts = []
    for f in files
        t = TOML.parsefile(joinpath(CENTERS, f))
        h = t["sigma_hash"]
        sharing = byhash[h]
        lut = Int.(t["lut"])
        cls = t["class"]
        F = SBox{8}(lut)

        # independent re-verification, different code path from the sweep
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        du == 2 || error("phase5: $f is NOT APN on re-verification (du = $du)")

        hits = index_hits(db, h)
        n_hits = sum(c for (_, c) in hits; init = 0)
        status = n_hits == 0 ? :sigma_mismatch : :candidate_collision

        println("\n$f")
        println("  class $cls  du=$du deg=$deg  sigma=$(h[1:16])…")
        length(sharing) > 1 && println("  same sigma also from: ", join(sharing[2:end], ", "))
        if status === :sigma_mismatch
            println("  SIGMA MISMATCH against the index => CCZ-inequivalent to every indexed function")
        else
            println("  SIGMA MATCH in $n_hits indexed row(s): ", hits)
            println("  -> candidate collision, needs explicit equivalence test")
        end

        # For a match, settle it exactly. Both sides quadratic APN =>
        # ea_mappings_from_ortho_derivative is a complete decision.
        equivalence = nothing
        if status === :candidate_collision
            # Prefer a functions-table representative; fall back to a corpus member.
            ref = nothing
            ref_name = ""
            mi = functions_table_rep(cat, db, h)
            if mi !== nothing
                names = apn_catalog_names()
                for nm in names
                    G = load_apn_function(nm)
                    inputbits(G) == 8 || continue
                    algebraic_degree(G) == 2 || continue
                    if sigma_hash(G) == h
                        ref = G
                        ref_name = nm
                        break
                    end
                end
            end
            if ref === nothing
                # take the first corpus member carrying this sigma
                for r in DBInterface.execute(db,
                    "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = " *
                    sql_quote(h) * " AND source != 'functions' LIMIT 1")
                    ref = VBFCatalog.corpus_function(cat, String(r.source), r.member_idx)
                    ref_name = "$(r.source)#$(r.member_idx)"
                    break
                end
            end
            if ref !== nothing
                println("  exact EA decision against $ref_name …")
                maps = ea_mappings_from_ortho_derivative(F, ref)
                equivalence = (; ref_name, n_mappings = length(maps),
                               equivalent = !isempty(maps))
                println("  => ", isempty(maps) ?
                        "NO mappings: CCZ-INEQUIVALENT despite the sigma match (novel!)" :
                        "$(length(maps)) mappings: genuinely EA/CCZ-equivalent to $ref_name (known)")
            else
                println("  no representative retrievable for this sigma — collision UNRESOLVED")
            end
        end

        novel = status === :sigma_mismatch ||
                (equivalence !== nothing && !equivalence.equivalent)
        push!(verdicts, (; file = f, class = cls, sigma = h, status, n_hits,
                         equivalence, novel, du, deg, lut))

        if novel
            out = joinpath(CANDIDATES, replace(f, ".toml" => "_candidate.toml"))
            open(out, "w") do io
                println(io, "# PHASE 5 novelty candidate")
                println(io, "source_center = ", repr(f))
                println(io, "class = ", cls)
                println(io, "mode = ", repr(get(t, "mode", "commutant")))
                println(io, "bbl2021_verdict = ", repr(t["bbl2021_verdict"]))
                println(io, "region = ", repr(t["region"]))
                # center files written before the selfequiv mode used dim_V_A
                println(io, "dim_V = ", get(t, "dim_V", get(t, "dim_V_A", -1)))
                println(io, "subspace_coordinate = ", t["subspace_coordinate"])
                println(io, "sigma_hash = ", repr(h))
                println(io, "novelty_basis = ", repr(string(status)))
                println(io, "index_rows_with_this_sigma = ", n_hits)
                println(io, "reverified_differential_uniformity = ", du)
                println(io, "reverified_by = \"VBF.differential_uniformity (full DDT) — different code path from the rank(L_a) test that found it\"")
                println(io, "algebraic_degree = ", deg)
                println(io, "is_permutation = ", is_permutation(F))
                println(io, "lut = ", lut)
                println(io, "anf_coefficients = ", t["anf_coefficients"])
                if equivalence !== nothing
                    println(io, "exact_ea_decision_against = ", repr(equivalence.ref_name))
                    println(io, "exact_ea_mappings = ", equivalence.n_mappings)
                end
            end
            println("  wrote $(basename(out))")
        end
    end

    n_novel = count(v -> v.novel, verdicts)
    n_mismatch = count(v -> v.status === :sigma_mismatch, verdicts)
    n_collision = count(v -> v.status === :candidate_collision, verdicts)
    n_resolved_known = count(v -> v.equivalence !== nothing && v.equivalence.equivalent, verdicts)

    open(joinpath(ROOT, "search", "phase5_report.toml"), "w") do io
        println(io, "# PHASE 5 novelty report")
        println(io, "sigma_index_rows = ", total_rows)
        println(io, "sigma_index_n8_distinct = ", n8_distinct)
        println(io, "distinct_sigma_tested = ", length(verdicts))
        println(io, "sigma_mismatches = ", n_mismatch)
        println(io, "candidate_collisions = ", n_collision)
        println(io, "collisions_resolved_as_known = ", n_resolved_known)
        println(io, "novel_candidates = ", n_novel)
        println(io, "coverage_caveat = \"\"\"")
        println(io, "A sigma MISMATCH certifies CCZ-inequivalence only against what the index")
        println(io, "covers: 8 bulk corpora (229,779 members) plus 625 functions-table rows.")
        println(io, "It does NOT cover the Beierle et al. 2025 set (3,775,599 classes, Zenodo")
        println(io, "10.5281/zenodo.16752428), which is not present in this repository (audit")
        println(io, "finding F024). Any novelty claim here is relative to the indexed sources")
        println(io, "and is NOT a claim of novelty against the published n=8 literature.")
        println(io, "\"\"\"")
        for v in verdicts
            println(io)
            println(io, "[[verdict]]")
            println(io, "file = ", repr(v.file))
            println(io, "class = ", v.class)
            println(io, "sigma_hash = ", repr(v.sigma))
            println(io, "status = ", repr(string(v.status)))
            println(io, "index_rows_with_this_sigma = ", v.n_hits)
            println(io, "novel = ", v.novel)
            if v.equivalence !== nothing
                println(io, "exact_ea_reference = ", repr(v.equivalence.ref_name))
                println(io, "exact_ea_mappings = ", v.equivalence.n_mappings)
                println(io, "exact_ea_equivalent = ", v.equivalence.equivalent)
            end
        end
    end

    println("\n=== PHASE 5 SUMMARY ===")
    println("distinct sigma tested        : ", length(verdicts))
    println("sigma mismatches (novel)     : ", n_mismatch)
    println("candidate collisions         : ", n_collision)
    println("  resolved as genuinely known: ", n_resolved_known)
    println("novel candidates             : ", n_novel)
end

main()
