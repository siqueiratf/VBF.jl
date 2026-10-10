# Aggregate report for the Beierle–Leander (2022) reproduction.
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "dataset_validation.jl"))
include(joinpath(@__DIR__, "table1_invariants.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))

"""
    paper_report(io::IO = stdout; save_results::Bool = false) -> NamedTuple

Run all bounded/default reproducible checks for Beierle–Leander (2022) and
print a structured report. Returns a NamedTuple of per-claim results.
"""
function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)

    r_counts   = dataset_counts(io; save_results)
    r_apn      = verify_apn(io; sample_size = 5, full_search = false, save_results)
    r_quad     = verify_quadratic(io; sample_size = 5, full_search = false, save_results)
    r_ranks    = check_ranks(io; max_dim = 6, save_results)
    r_walsh    = check_walsh(io; save_results)
    r_ccz      = ccz_distinctness(io; sample_size = 3, seed = 42, save_results)

    print_section("summary", io)
    print_check("dataset-counts",          r_counts.all_ok,  io)
    print_check("apn-verification",        r_apn.all_ok,     io)
    print_check("quadratic-degree",        r_quad.all_ok,    io)
    print_check("table1-rank-invariants",  r_ranks.all_ok,   io)
    print_check("table1-walsh-spectrum",   r_walsh.all_ok,   io)
    print_check("ccz-distinctness (sampled)", r_ccz.distinct_from_gold == r_ccz.sample_size, io)
    println(io, "\n  [NOTE] catalog-cross-validation requires VBFCatalog;" *
        " run catalog_validation.jl separately.")
    println(io, "  [NOTE] table1-multiplier-group is out-of-scope.")

    result = (;
        dataset_counts      = r_counts,
        apn_verification    = r_apn,
        quadratic_degree    = r_quad,
        table1_ranks        = r_ranks,
        table1_walsh        = r_walsh,
        ccz_distinctness    = r_ccz,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Beierle–Leander (2022) aggregate report")
            println(f, "dataset_counts_ok = $(r_counts.all_ok)")
            println(f, "apn_verification_ok = $(r_apn.all_ok)")
            println(f, "quadratic_degree_ok = $(r_quad.all_ok)")
            println(f, "table1_ranks_ok = $(r_ranks.all_ok)")
            println(f, "table1_walsh_ok = $(r_walsh.all_ok)")
            println(f, "ccz_distinct_from_gold = $(r_ccz.distinct_from_gold)")
        end
    end

    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
