using VBF
# Implements the aggregate census report (results/report.toml)
# Study: census of quadratic APN functions on F_2^8 (packages/VBFCatalog/data/research/archive/census)
#
# Pseudocode:
#   1. Exact tree sizes T(n,m) for small (n,m) by DFS; T(3,m) also by the closed form
#      (2^m-1)(2^m-2)(2^m-4) (n = 3: every nonzero 2-vector is decomposable).
#   2. Small-n validation against the exact masses (bounded sample counts).
#   3. Optional recomputation of the exact masses from the catalog (exact_nmax > 0).
#   4. Census analysis of the (8,8) sample files (full TSVs or the compact manifest
#      data/legacy_chunks.tsv); compare with the published numbers and new_classes_553.tsv.
#   5. Write everything to results/report.toml and the new sigma list to results/new_sigma.tsv.
# VBF API used: SBox, differential_uniformity, is_quadratic_apn,
#   automorphisms_from_ortho_derivative (through the included scripts)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "sampler.jl"))
include(joinpath(@__DIR__, "analyze.jl"))
include(joinpath(@__DIR__, "validate.jl"))
include(joinpath(@__DIR__, "exact_masses.jl"))

"Exact `T(n,m)` by DFS for the small cases in `EXACT_T`."
function exact_counts_report(io::IO = stdout)
    print_section("Exact tree sizes T(n,m)", io)
    out = Dict{String,Any}()
    for (n, m) in sort(collect(keys(EXACT_T)))
        t = @elapsed T = VBF.QuadraticAPNTree.exact_count(n, m)
        closed = n == 3 ? (2^m - 1) * (2^m - 2) * (2^m - 4) : nothing
        mass = T // (VBF.QuadraticAPNTree.gl_order(n) * VBF.QuadraticAPNTree.gl_order(m))
        @printf(io, "  T(%d,%d) = %d  (expected %d%s)  mass = %s  [%.1fs]\n", n, m, T, EXACT_T[(n, m)],
                closed === nothing ? "" : ", closed form $closed", string(mass), t)
        out["T_$(n)_$(m)"] = (value = T, expected = EXACT_T[(n, m)], closed_form = closed,
                              mass = mass, pass = T == EXACT_T[(n, m)])
    end
    out
end

"""
    census_report(; data, samples66, samples77, seed, data77 = "", exact_nmax = 0,
                  save_results = true, io = stdout)

Run the bounded report. `data` lists the (8,8) sample files or directories.
"""
function census_report(; data::AbstractString, samples66::Int, samples77::Int, seed::Int,
                       data77::AbstractString = "", exact_nmax::Int = 0,
                       save_results::Bool = true, io::IO = stdout)
    print_header(io)
    println(io, "Julia : ", VERSION, "   threads: ", nthreads(), "   date: ",
            Dates.format(Dates.now(), dateformat"yyyy-mm-dd"))
    println(io, "Data  : ", data)

    results = Dict{String,Any}()
    results["meta"] = Dict("title" => STUDY_TITLE, "julia" => string(VERSION),
                           "threads" => nthreads(), "data" => data, "seed" => seed,
                           "samples66" => samples66, "samples77" => samples77,
                           "data77" => data77, "exact_nmax" => exact_nmax,
                           "date" => Dates.format(Dates.now(), dateformat"yyyy-mm-dd"))
    results["exact_counts"] = exact_counts_report(io)
    results["exact_mass_constants"] = Dict("n$(k[1])m$(k[2])" => (rational = v, float = Float64(v))
                                           for (k, v) in EXACT_MASS)
    if exact_nmax > 0
        print_section("Exact masses from the catalog", io)
        em = exact_masses(4, exact_nmax; io)
        results["exact_masses_recomputed"] = Dict("n$n" => r for (n, r) in em)
    end
    results["validation"] = validate_report(; samples66, samples77, seed, data77, io)

    newp = joinpath(results_dir(), "new_sigma.tsv")
    a = analyze_census(expand_paths(data); new_path = newp, io)
    results["census"] = a
    results["literature_novelty"] = "unresolved"
    if save_results
        path = write_results_toml(results, "report.toml")
        println(io, "\nWrote ", path)
    end
    results
end
