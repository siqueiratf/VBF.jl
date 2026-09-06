# search/phase5_negative_control.jl — negative control for the novelty oracle.
#
# Phase 2 swept the Frobenius commutant exhaustively and found 7 distinct sigma.
# That subspace is the F_2-coefficient quadratic APN functions on GF(2^8) — the
# most-studied corner of the n=8 landscape, containing the Gold classes. Every
# one of those 7 should therefore be a sigma MATCH against the index.
#
# If any comes back as a mismatch, the index has a coverage hole and NO novelty
# claim from this run is safe. This is the counterpart to Phase 2: Phase 2 checks
# the search finds what is there, this checks the oracle recognises what is known.
#
# Writes: search/phase5_negative_control.toml

using VBFCatalog
using VBF
using TOML

const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface
const ROOT = normpath(joinpath(@__DIR__, ".."))

sql_quote(s) = "'" * replace(s, "'" => "''") * "'"

function main()
    src = joinpath(ROOT, "search", "control", "phase2_sigmas.toml")
    isfile(src) || error("negative control: $src absent — run search/phase2_control.jl first")
    t = TOML.parsefile(src)
    entries = t["sigma"]

    db = SQLite.DB(sigma_index_path())
    results = []
    println("negative control: $(length(entries)) sigma from the Frobenius commutant")
    for e in entries
        h = e["hash"]
        lut = Int.(e["representative_lut"])
        F = SBox{8}(lut)
        du = differential_uniformity(F)
        n = first(DBInterface.execute(db,
            "SELECT COUNT(*) AS c FROM ccz_sigma_index WHERE sigma_hash = " * sql_quote(h))).c
        srcs = [String(r.source) for r in DBInterface.execute(db,
            "SELECT DISTINCT source FROM ccz_sigma_index WHERE sigma_hash = " * sql_quote(h))]
        known = n > 0
        push!(results, (; hash = h, multiplicity = e["multiplicity"], du,
                        index_rows = n, sources = srcs, known))
        println("  ", h[1:16], "…  mult=", lpad(e["multiplicity"], 6),
                "  du=", du, "  index_rows=", lpad(n, 7), "  ", known ? "KNOWN" : "*** NOT IN INDEX ***")
        isempty(srcs) || println("      sources: ", join(srcs, ", "))
    end

    n_known = count(r -> r.known, results)
    passed = n_known == length(results)

    open(joinpath(ROOT, "search", "phase5_negative_control.toml"), "w") do io
        println(io, "# negative control for the novelty oracle")
        println(io, "sigma_tested = ", length(results))
        println(io, "sigma_found_in_index = ", n_known)
        println(io, "passed = ", passed)
        println(io, "interpretation = \"\"\"")
        println(io, "All sigma from the Frobenius commutant (the F_2-coefficient quadratic APN")
        println(io, "functions on GF(2^8), which include the Gold classes) must already be in")
        println(io, "the index. A miss here means the index has a coverage hole and no novelty")
        println(io, "claim from this run would be trustworthy.")
        println(io, "\"\"\"")
        for r in results
            println(io)
            println(io, "[[sigma]]")
            println(io, "hash = ", repr(r.hash))
            println(io, "multiplicity_in_V_A = ", r.multiplicity)
            println(io, "differential_uniformity = ", r.du)
            println(io, "index_rows = ", r.index_rows)
            println(io, "sources = [", join(map(repr, r.sources), ", "), "]")
            println(io, "known = ", r.known)
        end
    end

    println("\nNEGATIVE CONTROL: ", passed ? "PASS — the oracle recognises all 7 as known" :
                                             "FAIL — index coverage hole, novelty claims unsafe")
    passed
end

main()
