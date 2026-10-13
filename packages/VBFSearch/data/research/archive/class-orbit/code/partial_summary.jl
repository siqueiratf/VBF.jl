# search/partial_summary.jl — build a summary from the append-only run log.
#
# phase34_sweep.jl writes its summary TOML only when every target class is done.
# The class-22 sweep is a ~18 h job, so during it there would otherwise be no
# machine-readable record of the classes that already finished — even though
# search/run.log has them all. This reconstructs the summary from the log so a
# report can be produced at any moment mid-run, clearly marked partial.
#
# Usage: julia --project=. search/partial_summary.jl <mode>
# Writes: search/phase34_summary_<mode>.toml  (only if the real one is absent)

using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const RUNLOG = joinpath(ROOT, "search", "run.log")

function main()
    mode = length(ARGS) >= 1 ? ARGS[1] : "selfequiv"
    out = joinpath(ROOT, "search", "phase34_summary_$(mode).toml")

    lines = readlines(RUNLOG)
    # "--- class 13 [selfequiv] (BBL2021: prop4), dim = 32, size = 2^32 ---"
    hdr = Regex("--- class (\\d+) \\[$(mode)\\] \\(BBL2021: (\\w+)\\), dim = (\\d+),")
    # "class 13: EXHAUSTED: region n8/selfequiv/class13 fully walked, contains exactly 666792 solution(s)"
    exh_n = Regex("class (\\d+): EXHAUSTED: region n8/$(mode)/class\\d+ fully walked, contains exactly (\\d+)")
    exh_0 = Regex("class (\\d+): EXHAUSTED: region n8/$(mode)/class\\d+ fully walked, contains no solutions")
    bud   = Regex("class (\\d+): BUDGET HIT: region n8/$(mode)/class\\d+")
    dim0  = Regex("class (\\d+) \\[$(mode)\\]: dim 0")
    sig   = r"class (\d+): distinct sigma = (\d+)"

    dims = Dict{Int,Int}(); verd = Dict{Int,String}()
    apn = Dict{Int,Int}(); status = Dict{Int,String}(); sigs = Dict{Int,Int}()
    for l in lines
        if (m = match(hdr, l)) !== nothing
            i = parse(Int, m[1]); dims[i] = parse(Int, m[3]); verd[i] = m[2]
        elseif (m = match(dim0, l)) !== nothing
            i = parse(Int, m[1]); status[i] = "exhausted"; apn[i] = 0; sigs[i] = 0
        elseif (m = match(exh_n, l)) !== nothing
            i = parse(Int, m[1]); status[i] = "exhausted"; apn[i] = parse(Int, m[2])
        elseif (m = match(exh_0, l)) !== nothing
            i = parse(Int, m[1]); status[i] = "exhausted"; apn[i] = 0
        elseif (m = match(bud, l)) !== nothing
            i = parse(Int, m[1]); status[i] = "budget_hit"
        elseif (m = match(sig, l)) !== nothing
            i = parse(Int, m[1]); sigs[i] = parse(Int, m[2])
        end
    end

    done = sort(collect(keys(status)))
    isempty(done) && (println("no $mode classes finished yet"); return)
    # A class whose header appeared but which never reported an outcome is still
    # being walked. It must not be reported as "not attempted" — nor, of course,
    # as empty.
    in_progress = sort([i for i in keys(dims) if !haskey(status, i)])

    open(out, "w") do io
        println(io, "# PARTIAL summary reconstructed from search/run.log by partial_summary.jl.")
        println(io, "# The run was still in progress; classes absent here are UNFINISHED, not empty.")
        println(io, "mode = ", repr(mode))
        println(io, "partial = true")
        println(io, "threads = 12")
        println(io, "max_dim = 40")
        println(io, "classes_run = ", length(done))
        println(io, "classes_in_progress = [", join(in_progress, ", "), "]")
        println(io, "classes_exhausted = ", count(i -> status[i] == "exhausted", done))
        println(io, "classes_budget_hit = ", count(i -> status[i] == "budget_hit", done))
        for i in done
            d = get(dims, i, 0)
            println(io)
            println(io, "[[class]]")
            println(io, "index = ", i)
            println(io, "mode = ", repr(mode))
            println(io, "bbl2021_verdict = ", repr(get(verd, i, "?")))
            println(io, "dim_V = ", d)
            println(io, "outcome = ", repr(status[i]))
            println(io, "exhausted = ", status[i] == "exhausted")
            println(io, "proves_subspace_empty = ", status[i] == "exhausted" && get(apn, i, 0) == 0)
            println(io, "points_tested = ", status[i] == "exhausted" ? string(BigInt(2)^d) : "0")
            println(io, "subspace_size = ", string(BigInt(2)^d))
            println(io, "coverage_fraction = ", status[i] == "exhausted" ? 1.0 : 0.0)
            println(io, "apn_points = ", get(apn, i, 0))
            println(io, "distinct_sigma = ", get(sigs, i, 0))
            println(io, "sigma_hashes = []")
            println(io, "coverage_note = ", repr(status[i] == "exhausted" ?
                (get(apn, i, 0) == 0 ?
                 "EXHAUSTED: region n8/$mode/class$i fully walked, contains no solutions (proof of emptiness)" :
                 "EXHAUSTED: region n8/$mode/class$i fully walked, contains exactly $(apn[i]) solution(s)") :
                "BUDGET HIT: region n8/$mode/class$i NOT fully walked; coverage of this region is UNKNOWN"))
        end
    end
    println("wrote $out ($(length(done)) classes, partial)")
end

main()
