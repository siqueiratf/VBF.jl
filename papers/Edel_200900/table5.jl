# Implements Table 5 — Known switching classes of APN's in F_2^6.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 4 — Computational results (Table 5, page listing the n=6 catalogue).
#
# Pseudocode:
#   1. Build every representative 1.1, 1.2, 2.1..2.12 (helpers.edelpott_table5).
#   2. For each: assert differential_uniformity == 2 (APN).
#   3. For each: compute algebraic_degree; every entry is quadratic (deg 2)
#      EXCEPT 2.11 which has degree 3 — the paper's central "not quadratic" claim.
# VBF API used: differential_uniformity, algebraic_degree, print_section,
#               print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    table5_report(io = stdout; save_results = false) -> NamedTuple

Verify the whole `n = 6` Table-5 catalogue is APN and report each algebraic
degree. The one non-quadratic entry (degree 3) is 2.11 = Theorem 11.
"""
function table5_report(io::IO = stdout; save_results::Bool = false)
    print_section("Table 5 — n=6 switching classes: APN + algebraic degree", io)
    rows = edelpott_table5()

    all_apn = true
    degrees = Dict{String,Int}()
    nonquad = String[]
    for r in rows
        du  = differential_uniformity(r.sbox)
        deg = algebraic_degree(r.sbox)
        degrees[r.name] = deg
        apn = du == 2
        all_apn &= apn
        deg == 3 && push!(nonquad, r.name)
        print_check("F$(r.name): APN (Δ-uniformity=$du), algebraic degree $deg", apn, io)
    end

    print_kv("representatives", length(rows), io)
    print_kv("all APN", all_apn, io)
    print_kv("quadratic (degree 2)", count(==(2), values(degrees)), io)
    print_kv("non-quadratic (degree 3)", nonquad, io)
    print_check("central claim: exactly one non-quadratic entry, 2.11 (Theorem 11)",
        nonquad == ["2.11"], io)
    print_kv("completeness", "exhaustive (all 14 Table-5 representatives)", io)

    result = (; all_apn, degrees, nonquad, count = length(rows))
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table5.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Table 5 — n=6 APN + degree")
            println(f, "all_apn = $(all_apn)")
            println(f, "non_quadratic = $(nonquad)")
            for r in rows
                println(f, "[\"$(r.name)\"]\ndegree = $(degrees[r.name])")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table5_report()
end
