# Aggregate report for the Taniguchi et al. (2025) reproduction.
# Paper: Taniguchi, Polujan, Pott, Arshad (2025),
#        "Changing APN functions on affine subspaces of small codimensions"
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "table3_1.jl"))
include(joinpath(@__DIR__, "theorem3_7.jl"))
include(joinpath(@__DIR__, "example4_2.jl"))
include(joinpath(@__DIR__, "prior_art.jl"))

function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)

    r_table   = table3_1_report(io)
    r_expsum  = theorem3_7_report(io)
    r_codim2  = example4_2_report(io)
    r_prior_art = prior_art_report(io)

    print_section("Summary", io)
    print_check(io, "Table 3.1: all 13 APN",            r_table.all_apn)
    print_check(io, "Table 3.1: all quadratic",          r_table.all_quadratic)
    print_check(io, "Table 3.1: 13 distinct EA-classes", r_table.n_classes == 13)
    print_check(io, "Theorem 3.7: Eq.(3.1) all hold",   r_expsum.all_hold)
    print_check(io, "Example 4.2: G is APN",            r_codim2.is_apn)
    print_check(io, "Example 4.2: simplified form",     r_codim2.simplified_matches)
    print_check(io, "Example 4.2: G ≠_EA x^3",          r_codim2.ea_distinct)
    println(io, "\n  [NOTE] Theorem 3.2 counting (n=4,5) runs via 'make theorem3_2' (takes ~8s for n=5).")
    println(io, "  [NOTE] Γ-ranks out-of-scope (Magma).")

    result = (;
        table3_1      = r_table,
        theorem3_7    = r_expsum,
        example4_2    = r_codim2,
        prior_art     = r_prior_art,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Taniguchi et al. (2025) aggregate report")
            println(f, "table3_1_all_apn = $(r_table.all_apn)")
            println(f, "table3_1_all_quadratic = $(r_table.all_quadratic)")
            println(f, "table3_1_n_classes = $(r_table.n_classes)")
            println(f, "theorem3_7_all_hold = $(r_expsum.all_hold)")
            println(f, "example4_2_is_apn = $(r_codim2.is_apn)")
            println(f, "example4_2_simplified = $(r_codim2.simplified_matches)")
            println(f, "example4_2_ea_distinct = $(r_codim2.ea_distinct)")
        end
    end

    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
