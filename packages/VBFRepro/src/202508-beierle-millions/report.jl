# Implements aggregate bounded reproduction report
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 2-5
#
# Pseudocode:
#   1. Print paper metadata and reproduction scope.
#   2. Run exact and bounded default checks from each experiment file.
#   3. Optionally write machine-readable results under results/.
# VBF API used: SBox, gold_apn, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "paper_counts.jl"))
include(joinpath(@__DIR__, "component_profiles.jl"))
include(joinpath(@__DIR__, "extension_criteria.jl"))
include(joinpath(@__DIR__, "estimators.jl"))
include(joinpath(@__DIR__, "dataset_validation.jl"))
include(joinpath(@__DIR__, "catalog_validation.jl"))

"Run the default bounded reproduction report."
function paper_report(
    io::IO = stdout;
    dataset_path::AbstractString = "",
    dataset_sample_size::Integer = 0,
    check_ortho::Bool = false,
    save_results::Bool = false,
)
    print_header(io)
    println(io, "Paper : ", PAPER_AUTHORS, " (", PAPER_YEAR, ")")
    println(io, "Title : ", PAPER_TITLE)
    println(io, "Field : F_2^8, quadratic APN functions, EA/CCZ classes")
    println(io, "Julia : ", VERSION, "   Date: ", Dates.format(Dates.now(), dateformat"yyyy-mm-dd"))
    println(io, "Scope : exact arithmetic and small theorem checks; full millions-scale")
    println(io, "        generation and sboxU inequivalence labels are not run by default.")

    results = Dict{String,Any}(
        "paper_counts" => paper_counts_report(io),
        "component_profiles" => component_profiles_report(io),
        "extension_criteria" => extension_criteria_report(io),
        "estimators" => estimators_report(io),
        "dataset_validation" => dataset_validation_report(
            io;
            dataset_path,
            sample_size = dataset_sample_size,
            check_ortho,
        ),
        "catalog_validation" => catalog_validation_report(io),
    )

    print_section("Summary", io)
    println(io, "  Exact reproductions : Table 4.1 count sum, Theorem 5.1 arithmetic,")
    println(io, "    Theorem 2.3 component moment on Gold n=4, Lemma 4.6, Lemma 4.7")
    println(io, "    on n=4 examples, Theorem 4.9 on all n=2 linear maps, Section 5 estimators.")
    println(io, "  Bounded checks      : Zenodo LUT sample validation when sample_size>0.")
    println(io, "  Diagnostic checks   : local VBFCatalog pre-2025 corpus counts.")
    println(io, "  Not executed        : full extension search, full J_2 classification,")
    println(io, "    full Zenodo scan, and sboxU inequivalence/permutation checks.")

    if save_results
        path = write_results_toml(
            Dict(
                "meta" => report_meta(),
                "results" => results,
            ),
            "report.toml",
        )
        println(io)
        println(io, "  Report artifact written to: ", path)
    end

    results
end

"Metadata stored with optional report artifacts."
function report_meta()
    Dict{String,Any}(
        "paper" => "Beierle et al. (2025)",
        "title" => PAPER_TITLE,
        "generated" => string(Dates.now()),
        "zenodo" => ZENODO_DOI,
        "default_scope" => "bounded/default checks only",
        "full_dataset_scan" => false,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
