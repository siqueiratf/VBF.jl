# Aggregate report for the Yu–Perrin 2022 (QAM method) reproduction.
#
# Runs only the bounded / default reproducible checks — no long search. Each
# section maps to a paper claim (Definition QAM, Theorem 1, Conjecture 2,
# Theorem 2, Proposition 3, Theorem 6, the class invariants) or to the
# VBFCatalog corpus.

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "qam_correspondence.jl"))
include(joinpath(@__DIR__, "conjecture2_search.jl"))
include(joinpath(@__DIR__, "proposition3_partitions.jl"))
include(joinpath(@__DIR__, "theorem6_model.jl"))
include(joinpath(@__DIR__, "paper_invariants.jl"))
include(joinpath(@__DIR__, "small_searches.jl"))
include(joinpath(@__DIR__, "catalog_validation.jl"))

function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)
    println(io, "Paper : Yu and Perrin (2022), \"Constructing more quadratic APN")
    println(io, "        functions with the QAM method\"")
    println(io, "Field : F_{2^8}, g^8+g^4+g^3+g^2+1=0 (Magma default), normal basis γ=g^11")
    println(io, "Julia : ", VERSION, "   Date: ", first(split(string(using_now()), 'T')))
    println(io, "Scope : bounded/default reproducible checks; the full ≈2^50 n=8")
    println(io, "        search (Conjecture 3) is intentionally not run.")

    results = Dict{String,Any}(
        "qam_correspondence" => qam_correspondence_report(io),
        "conjecture2" => conjecture2_report(io),
        "proposition3" => proposition3_report(io),
        "theorem6" => theorem6_report(io),
        "invariants" => paper_invariants_report(io),
        "small_searches" => small_searches_report(; io),
        "catalog" => catalog_validation_report(; io),
    )

    println(io)
    println(io, "## Summary")
    println(io, "  Exact reproductions : Definition QAM / Theorem 1 correspondence,")
    println(io, "    Conjecture 2 H_8 block, Proposition 3 candidate sizes (7,112,3,96),")
    println(io, "    Theorem 2 reduction, Theorem 6 model (≡ is_qam under its hypothesis).")
    println(io, "  Bounded demos       : Conjecture 2 modified-entry search, small QAM")
    println(io, "    searches (n=4,5), ortho-derivative/Σ_4 class separation (n=6).")
    println(io, "  Loaded artifacts    : VBFCatalog corpus.")
    println(io, "  Not executed        : full n=8 traversal; n=8 Γ/Δ-ranks (≈1500 h).")

    if save_results
        artifact = Dict{String,Any}("meta" => report_meta(), "results" => results)
        path = write_results_toml(artifact, "report.toml")
        println(io)
        println(io, "  Report artifact written to: ", path)
    end

    results
end

"Metadata banner stored in the saved report artifact."
function report_meta()
    Dict{String,Any}(
        "paper" => "Yu and Perrin (2022)",
        "title" => "Constructing more quadratic APN functions with the QAM method",
        "field" => "F_{2^8}, g^8+g^4+g^3+g^2+1=0 (Magma default), normal basis γ=g^11",
        "julia_version" => string(VERSION),
        "generated" => string(using_now()),
        "scope" => "bounded/default reproducible checks; full ≈2^50 n=8 search not run",
        "full_n8_search" => false,
        "n8_design_ranks_computed" => false,
    )
end

# Timestamp without pulling Dates as a hard dependency of every script.
using_now() = let t = time()
    # ISO-8601 UTC seconds; good enough for a report banner.
    Base.Libc.strftime("%Y-%m-%dT%H:%M:%S", t)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
