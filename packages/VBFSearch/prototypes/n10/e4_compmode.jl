# E4: re-extension inside the component space ("comp mode") for the quadratic
# n = 10 classes of the catalog. For each seed, `k` random 8-dim U < C2(F) (kernel
# of a random 2-dim annihilator in the 10-dim coefficient space) are re-extended
# with ISD; every APN space found is classified by sigma, and a catalog label is
# accepted only after are_ea_equivalent confirms it. One line per seed goes to
# results/comp/summary.tsv at once; new classes go to results/comp/new/.
# Seeds already in summary.tsv are skipped on restart. The sample is reproducible
# (seeded by the seed name).
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/e4_compmode.jl [k] [iters]
include(joinpath(@__DIR__, "pilot_check.jl"))           # lut_of, isd_fast.jl, VBF, VBFCatalog
using Dates, Random

function random_u8(C, rng)
    while true
        a1, a2 = rand(rng, 1:1023), rand(rng, 1:1023)
        (a1 != a2) || continue
        U = [reduce(⊻, (C[k] for k in 1:10 if (c >> (k - 1)) & 1 == 1); init = UInt64(0))
             for c in 0:1023 if iseven(count_ones(c & a1)) && iseven(count_ones(c & a2)) && c != 0]
        B = UInt64[]
        for u in U
            rank_f2([B; u]) > length(B) && push!(B, u)
        end
        length(B) == 8 && return B
    end
end

function e4_main(k, iters)
    db = load_catalog()
    quad = Dict{String,Tuple{String,SBox{10,UInt16}}}()
    seeds = Tuple{String,SBox{10,UInt16}}[]
    for r in list_functions(db; n = 10)
        F = load_sbox(db, r.id)
        VBF.algebraic_degree(F) == 2 || continue
        s = sigma_hash(F); haskey(quad, s) && continue
        quad[s] = (r.canonical_name, F); push!(seeds, (r.canonical_name, F))
    end
    flats = all_flats()
    dir = joinpath(@__DIR__, "results", "comp"); mkpath(joinpath(dir, "new"))
    out = joinpath(dir, "summary.tsv")
    isfile(out) || write(out, "seed\tsamples\titers\tspaces\tseed_space_found\tclasses\tlabels\n")
    done = Set(split(l, '\t')[1] for l in readlines(out)[2:end])
    newreps = Dict{String,SBox{10,UInt16}}()
    for (name, F) in seeds
        name in done && continue
        C = comp_basis(Int.(F.lut)); own = canon(C)
        rng = Xoshiro(hash(name))
        Us = [random_u8(C, rng) for _ in 1:k]
        found = [Set{Vector{UInt64}}() for _ in 1:Threads.maxthreadid()]
        t = @elapsed Threads.@threads :dynamic for i in eachindex(Us)
            sols, _, _ = extensions_fast(Us[i], flats; iters, rng = Xoshiro(hash((name, i))))
            union!(found[Threads.threadid()], sols)
        end
        S = reduce(union, found)
        labels = Dict{String,String}()                      # sigma -> label
        for s in S
            G = SBox{10}(lut_of(s)); sg = sigma_hash(G)
            haskey(labels, sg) && continue
            if haskey(quad, sg) && are_ea_equivalent(G, quad[sg][2])
                labels[sg] = quad[sg][1]
            elseif haskey(newreps, sg) && are_ea_equivalent(G, newreps[sg])
                labels[sg] = "NEW(seen before)"
            else
                labels[sg] = "NEW"; newreps[sg] = G
                write(joinpath(dir, "new", "$(sg[1:16]).lut"), join(Int.(G.lut), ','))
                println(now(), " NEW class sigma ", sg[1:16], "... from $name"); flush(stdout)
            end
        end
        line = join([name, k, iters, length(S), own in S, length(labels), join(sort(collect(values(labels))), ";")], '\t')
        open(io -> println(io, line), out, "a")
        println(now(), " $name: ", length(S), " spaces, ", length(labels), " classes (", round(t / 60, digits = 1), " min): ",
                join(sort(collect(values(labels))), ", ")); flush(stdout)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    e4_main(length(ARGS) > 0 ? parse(Int, ARGS[1]) : 120, length(ARGS) > 1 ? parse(Int, ARGS[2]) : 120_000)
end
