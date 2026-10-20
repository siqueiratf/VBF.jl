# Complete switching of n = 10 functions with classification under EA and CCZ.
#
# Inputs are the quadratic catalog seeds and/or the EA-class representatives in
# results/ccz/<seed>/reps/ (written by ccz_reps.jl). Every APN neighbour G is
# classified once (deduplicated by LUT hash across all runs):
#
#   quadratic G      sigma; "known:<name>" only after are_ea_equivalent with the
#                    catalog function (EA = CCZ here, Yoshiara 2012); else NEW.
#   non-quadratic G  are_ccz_equivalent against the CCZ class of the input first,
#                    then against every known n = 10 class; the result is
#                    "ccz-known:<name>" or "NEW-CCZ". The fingerprint is not used
#                    to decide, because for n > 7 it holds only the differential
#                    and absolute Walsh spectra.
#
# Rows go at once to results/ccz/switch.tsv; inputs already in the file are
# skipped on restart. Columns:
#   input, input_degree, u, degree, lut_sha256, class, test, seconds
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/ccz_switch.jl seeds|reps [names...]
include(joinpath(@__DIR__, "switch_full.jl"))
using VBFCatalog, Dates

function known_classes(db)
    quad = Dict{String,Tuple{String,SBox{10,UInt16}}}(); all = Tuple{String,SBox{10,UInt16}}[]
    for r in list_functions(db; n = 10)
        F = load_sbox(db, r.id)
        VBF.differential_uniformity(F) == 2 || continue
        if VBF.algebraic_degree(F) == 2
            s = sigma_hash(F); haskey(quad, s) && continue
            quad[s] = (r.canonical_name, F)
        end
        any(x -> x[1] == r.canonical_name, all) || push!(all, (r.canonical_name, F))
    end
    quad, all
end

function classify(G, home, quad, all)
    if VBF.algebraic_degree(G) == 2
        s = sigma_hash(G)
        haskey(quad, s) && are_ea_equivalent(G, quad[s][2]) && return ("known:" * quad[s][1], "ea")
        return ("NEW-quadratic", "sigma")
    end
    are_ccz_equivalent(G, home[2]) && return ("ccz-known:" * home[1], "ccz-home")
    for (name, F) in all
        name == home[1] && continue
        are_ccz_equivalent(G, F) && return ("ccz-known:" * name, "ccz")
    end
    ("NEW-CCZ", "ccz-all")
end

function inputs(mode, names, db)
    base = joinpath(@__DIR__, "results", "ccz")
    out = Tuple{String,String,Vector{Int}}[]                 # (input id, home seed, lut)
    for name in names
        if mode == "seeds"
            push!(out, (name, name, Int.(load_sbox(db, name).lut)))
        else
            dir = joinpath(base, name, "reps")
            for l in readlines(joinpath(dir, "index.tsv"))[2:end]
                i = split(l, '\t')[1]
                push!(out, ("$name/rep$i", name, parse.(Int, split(readchomp(joinpath(dir, "rep$i.lut")), ','))))
            end
        end
    end
    out
end

function ccz_switch_main(mode, names)
    db = load_catalog()
    quad, all = known_classes(db)
    base = joinpath(@__DIR__, "results", "ccz"); mkpath(base)
    out = joinpath(base, "switch.tsv")
    isfile(out) || write(out, "input\tinput_degree\tu\tdegree\tlut_sha256\tclass\ttest\tseconds\n")
    rows = [split(l, '\t') for l in readlines(out)[2:end]]
    done = Set(r[1] for r in rows)
    seen = Dict(r[5] => r[6] for r in rows)                 # dedup across runs by LUT hash
    for (id, home, lut) in inputs(mode, names, db)
        id in done && continue
        F = SBox{10}(UInt16.(lut))
        VBF.differential_uniformity(F) == 2 || error("$id is not APN")
        homeF = (home, load_sbox(db, home))
        t = @elapsed r = switch_full(lut, 10)
        lines = String[]
        for (u, Gl) in r.neighbours
            G = SBox{10}(UInt16.(Gl)); h = lut_sha256_hex(G)
            t2 = @elapsed (cls, test) = haskey(seen, h) ? (seen[h], "dedup") : classify(G, homeF, quad, all)
            seen[h] = cls
            push!(lines, join([id, VBF.algebraic_degree(F), u, VBF.algebraic_degree(G), h, cls, test, round(t2, digits = 2)], '\t'))
            startswith(cls, "NEW") && (println(now(), " $cls from $id (u = $u)"); flush(stdout))
        end
        isempty(lines) && push!(lines, join([id, VBF.algebraic_degree(F), 0, 0, "-", "none", "-", 0], '\t'))
        open(io -> foreach(l -> println(io, l), lines), out, "a")
        cls = [split(l, '\t')[6] for l in lines]
        println(now(), " $id (degree ", VBF.algebraic_degree(F), "): ", length(r.neighbours), " neighbours in ",
                round(t, digits = 1), " s; ", join(["$k x$(count(==(k), cls))" for k in unique(cls)], ", "),
                isempty(r.capped) ? "" : "; CAPPED directions $(r.capped)"); flush(stdout)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    ccz_switch_main(ARGS[1], ARGS[2:end])
end
