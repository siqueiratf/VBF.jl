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
    print_kv("dataset-counts", String(r_counts.status), io)
    print_kv("apn-verification", String(r_apn.status), io)
    print_kv("quadratic-degree", String(r_quad.status), io)
    print_kv("table1-rank-invariants", String(r_ranks.status), io)
    print_kv("table1-walsh-spectrum", String(r_walsh.status), io)
    print_kv("ccz-distinctness", String(r_ccz.status), io)
    if r_ccz.status == :sampled
        print_check("sample differs from Gold", r_ccz.sample_size > 0 && r_ccz.distinct_from_gold == r_ccz.sample_size, io)
    end
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
            println(f, "dataset_counts_status = \"$(r_counts.status)\"")
            println(f, "dataset_counts_ok = $(r_counts.all_ok)")
            println(f, "apn_verification_status = \"$(r_apn.status)\"")
            println(f, "apn_verification_ok = $(r_apn.all_ok)")
            println(f, "quadratic_degree_status = \"$(r_quad.status)\"")
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
