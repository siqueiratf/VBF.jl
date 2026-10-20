# E3: Edel-Pott switching from the quadratic n = 10 classes of the catalog.
#
# For each seed, VBF.switching_neighbors builds the complete constraint system for
# every output direction u and keeps the APN neighbours F + u*s. Each neighbour is
# classified at once and appended to results/switching/neighbours.tsv:
#   quadratic      sigma; known if sigma is in the catalog AND are_ea_equivalent
#                  confirms it (EA = CCZ for quadratic APN, Yoshiara 2012);
#   not quadratic  ccz_fingerprint_hash. This is a CCZ invariant only: a new
#                  fingerprint proves inequivalence to the non-quadratic catalog
#                  entries, an equal one does not prove equivalence.
# Seeds already in the file are skipped on restart.
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/e3_switching.jl [seed names...]
using VBF, VBFCatalog, Dates

function e3_main(names)
    db = load_catalog()
    quad = Dict{String,Tuple{String,SBox{10,UInt16}}}()      # sigma -> (name, F)
    nonquad = Dict{String,String}()                          # CCZ fingerprint -> name
    seeds = Tuple{String,SBox{10,UInt16}}[]
    for r in list_functions(db; n = 10)
        F = load_sbox(db, r.id)
        if VBF.algebraic_degree(F) == 2
            s = sigma_hash(F)
            haskey(quad, s) && continue
            quad[s] = (r.canonical_name, F); push!(seeds, (r.canonical_name, F))
        else
            nonquad[ccz_fingerprint_hash(F)] = r.canonical_name
        end
    end
    isempty(names) || filter!(s -> s[1] in names, seeds)
    dir = joinpath(@__DIR__, "results", "switching"); mkpath(dir)
    out = joinpath(dir, "neighbours.tsv")
    isfile(out) || write(out, "seed\tu\tdegree\tinvariant\tlabel\tea_confirmed\tlut_sha256\n")
    done = Set(split(l, '\t')[1] for l in readlines(out)[2:end])
    newluts = Dict{String,SBox{10,UInt16}}()                  # invariant -> first new representative
    for (name, F) in seeds
        name in done && continue
        t = @elapsed groups = switching_neighbors(F)
        rows = String[]; classes = Set{String}()
        for (u, Gs) in enumerate(groups), G in Gs
            d = VBF.algebraic_degree(G)
            if d == 2
                inv = sigma_hash(G)
                if haskey(quad, inv)
                    ok = are_ea_equivalent(G, quad[inv][2]); label = ok ? quad[inv][1] : "NEW(sigma collision)"
                elseif haskey(newluts, inv)
                    ok = are_ea_equivalent(G, newluts[inv]); label = ok ? "NEW(repeat)" : "NEW(sigma collision)"
                else
                    ok = false; label = "NEW"; newluts[inv] = G
                end
            else
                inv = ccz_fingerprint_hash(G); ok = false
                label = haskey(nonquad, inv) ? "fingerprint=" * nonquad[inv] : "NONQUADRATIC-NEW-FINGERPRINT"
            end
            push!(classes, inv)
            push!(rows, join([name, u, d, inv, label, ok, lut_sha256_hex(G)], '\t'))
            startswith(label, "NEW") || startswith(label, "NONQUAD") ?
                (println(now(), " $label from $name (u = $u, degree $d)"); flush(stdout)) : nothing
        end
        open(io -> foreach(r -> println(io, r), rows), out, "a")
        println(now(), " $name: ", length(rows), " APN neighbours, ", length(classes), " distinct invariants (",
                round(t, digits = 1), " s)"); flush(stdout)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    e3_main(ARGS)
end
