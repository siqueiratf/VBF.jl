# CCZ pilot step 1: EA-class representatives inside the CCZ class of a seed.
#
# VBF.ea_class_representatives enumerates the n-dim subspaces of the Walsh zeros
# (Baudrin-Galissant-Perrin, Section 3.1) and builds one function per orbit with a
# verified CCZ graph map. With a time limit it keeps the representatives that it
# built before the limit (complete = false). Every representative is checked:
# APN (delta = 2), CCZ-equivalent to the seed through its recorded map, and its
# algebraic degree. The LUTs go to results/ccz/<seed>/reps/ with an index file;
# a seed with an index is skipped on restart.
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/ccz_reps.jl <timeout s> <seed names...>
using VBF, VBFCatalog, Dates

function ccz_reps_main(timeout, names)
    db = load_catalog()
    for name in names
        dir = joinpath(@__DIR__, "results", "ccz", name, "reps"); mkpath(dir)
        index = joinpath(dir, "index.tsv")
        isfile(index) && (println("$name: already done"); continue)
        F = load_sbox(db, name)
        t = @elapsed r = ea_class_representatives(F; timeout_seconds = timeout)
        rows = String[]
        for (i, G) in enumerate(r.representatives)
            VBF.differential_uniformity(G) == 2 || error("$name rep $i is not APN")
            d = VBF.algebraic_degree(G)
            write(joinpath(dir, "rep$i.lut"), join(Int.(G.lut), ','))
            push!(rows, join([i, d, is_permutation(G), ccz_fingerprint_hash(G), lut_sha256_hex(G)], '\t'))
        end
        open(index, "w") do io
            println(io, "rep\tdegree\tpermutation\tccz_fingerprint\tlut_sha256")
            foreach(r -> println(io, r), rows)
        end
        println(now(), " $name: ", length(r.representatives), " EA classes found (complete = ", r.complete,
                ", stop = ", r.stop_reason, ", ", round(t, digits = 1), " s); degrees ",
                [parse(Int, split(x, '\t')[2]) for x in rows]); flush(stdout)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    ccz_reps_main(parse(Float64, ARGS[1]), ARGS[2:end])
end
